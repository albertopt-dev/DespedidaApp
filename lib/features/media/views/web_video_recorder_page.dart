// lib/features/media/views/web_video_recorder_page.dart
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        front,
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecord() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_recording) {
      try {
        final XFile xfile = await _controller!.stopVideoRecording();
        setState(() => _recording = false);

        // ====== SUBIR A STORAGE + CREAR DOC EN FIRESTORE (sin usar File) ======
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          Get.snackbar('Sesión', 'Debes iniciar sesión');
          return;
        }

        final bytes = await xfile.readAsBytes(); // <- en Web obtenemos bytes
        final ts = DateTime.now().millisecondsSinceEpoch;
        final folderBase = widget.baseIndex == null ? 'general' : '${widget.baseIndex}';
        final storagePath = 'uploads/groups/${widget.groupId}/bases/$folderBase/${ts}_$uid.mp4';

        final ref = FirebaseStorage.instance.ref(storagePath);
        final metadata = SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'compressed': 'true',
            // si quisieras duración, necesitarías calcularla aparte en web
          },
        );

        // Sube bytes (no File)
        await ref.putData(bytes, metadata);
        final downloadURL = await ref.getDownloadURL();

        // Crea doc igual que GalleryService
        final docRef = await FirebaseFirestore.instance
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
          'createdAt': FieldValue.serverTimestamp(),
        });

        // éxito
        Get.snackbar('Listo', 'Vídeo subido');
        if (mounted) {
          Navigator.of(context).pop(); // vuelve a la galería
        }
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

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Grabar vídeo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
