import 'dart:async';
import 'dart:typed_data';
import 'package:despedida/features/media/controller/gallery_controller.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:despedida/web/io_stub.dart'
    if (dart.library.html) 'package:despedida/web/io_web.dart' as webio;

class WebVideoRecorderPage extends StatefulWidget {
  final String groupId;
  final int? baseIndex;
  const WebVideoRecorderPage({super.key, required this.groupId, this.baseIndex});

  @override
  State<WebVideoRecorderPage> createState() => _WebVideoRecorderPageState();
}

class _WebVideoRecorderPageState extends State<WebVideoRecorderPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _recording = false;

  bool get _isSafari {
    return webio.isSafari;
  }

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  Future<void> _initCam() async {
    if (!kIsWeb) {
      Get.snackbar('Web', 'Esta pantalla es solo para Web/PWA');
      return;
    }
    try {
      // En Safari NO usamos camera_web: lo gestionaremos con captura nativa
      if (_isSafari) {
        setState(() => _initializing = false);
        return;
      }

      // Resto de navegadores (Chrome/Edge/Firefox): usar cámara trasera si existe
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (e) {
      setState(() => _initializing = false);
      Get.snackbar('Cámara', 'No se pudo inicializar: $e');
    }
  }

  // HUD de progreso reutilizable
  Future<T> _withProgress<T>(Future<T> Function() task, {String text = 'Subiendo...'}) async {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black54)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 12),
                Text(text,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    try {
      final r = await task();
      return r;
    } finally {
      if (Get.isDialogOpen ?? false) Get.back();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    // 1) Safari: NO usamos CameraController; abrimos captura nativa
    if (_isSafari) {
      await _captureAndUploadVideoSafari();
      return;
    }

    // 2) Resto: requiere controller inicializado
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_recording) {
      try {
        final XFile xfile = await _controller!.stopVideoRecording();
        setState(() => _recording = false);

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          Get.snackbar('Sesión', 'Debes iniciar sesión');
          return;
        }

        // En web (camera_web) se obtiene WEBM
        final bytes = await xfile.readAsBytes();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final folderBase = widget.baseIndex == null ? 'general' : '${widget.baseIndex}';

        const String ext = 'webm';
        const String mime = 'video/webm';

        final storagePath = 'uploads/groups/${widget.groupId}/bases/$folderBase/${ts}_$uid.$ext';
        final ref = FirebaseStorage.instance.ref(storagePath);
        final metadata = SettableMetadata(
          contentType: mime,
          customMetadata: {'compressed': 'true'},
        );

        await _withProgress(() async {
          await ref.putData(bytes, metadata);
          final downloadURL = await ref.getDownloadURL();

          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('media')
              .add({
            'groupId': widget.groupId,
            'baseIndex': widget.baseIndex,
            'ownerUid': uid,
            'type': 'video',
            'storagePath': storagePath,
            'downloadURL': downloadURL,
            'contentType': mime,
            'ext': ext,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }, text: 'Subiendo vídeo...');

        Get.snackbar('Éxito', 'Vídeo subido', snackPosition: SnackPosition.BOTTOM);
        // 🔄 Fuerza recarga de la galería abierta (si existe)
        final tag = 'gallery-${widget.groupId}-${widget.baseIndex}';
        try {
          final gc = Get.find<GalleryController>(tag: tag);
          await gc.loadInitial();            // recarga lista
        } catch (_) {
          // si no existe el controller (se abrió desde otro flujo), no pasa nada
        }

        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        Get.snackbar('Grabación', 'Error al detener/subir: $e');
      }
    } else {
      try {
        await _controller!.startVideoRecording();
        setState(() => _recording = true);
      } catch (e) {
        Get.snackbar('Grabación', 'No se pudo iniciar: $e');
      }
    }
  }

  Future<void> _captureAndUploadVideoSafari() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Sesión', 'Debes iniciar sesión');
        return;
      }

      // Usa el helper de web (io_web) — en Android/iOS devolverá null por el stub.
      final pick = await webio.pickAnyFileWeb(); // <- helper
      if (pick == null) return;

      final bytes = pick.bytes;
      final name  = pick.filename.toLowerCase();
      // El helper ya debería dar mime correcto; si no, ajusta por extensión:
      var mime = 'video/mp4';
      var ext  = 'mp4';
      if (name.endsWith('.mov')) { ext = 'mov'; mime = 'video/quicktime'; }
      else if (name.endsWith('.webm')) { ext = 'webm'; mime = 'video/webm'; }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final folderBase = widget.baseIndex == null ? 'general' : '${widget.baseIndex}';
      final storagePath = 'uploads/groups/${widget.groupId}/bases/$folderBase/${ts}_$uid.$ext';

      await _withProgress(() async {
        final ref = FirebaseStorage.instance.ref(storagePath);
        await ref.putData(bytes, SettableMetadata(contentType: mime));
        final url = await ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('media')
            .add({
          'groupId': widget.groupId,
          'baseIndex': widget.baseIndex,
          'ownerUid': uid,
          'type': 'video',
          'storagePath': storagePath,
          'downloadURL': url,
          'contentType': mime,
          'ext': ext,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }, text: 'Subiendo vídeo...');

      Get.snackbar('Éxito', 'Vídeo subido', snackPosition: SnackPosition.BOTTOM);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      Get.snackbar('Grabación', 'Error al capturar/subir: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grabar vídeo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Safari: UI sin preview; botón que abre la cámara nativa
    if (_isSafari) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grabar vídeo')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Safari usará la cámara nativa del iPhone para grabar.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _captureAndUploadVideoSafari,
          icon: const Icon(Icons.videocam),
          label: const Text('Abrir cámara'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    }

    // Resto de navegadores: preview con camera_web (trasera)
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grabar vídeo')),
        body: const Center(child: Text('Cámara no disponible')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Grabar vídeo')),
      body: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: CameraPreview(_controller!),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleRecord,
        icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
        label: Text(_recording ? 'Detener' : 'Grabar'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
