import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Asegúrate de tener estos archivos creados en tu proyecto
import 'package:despedida/features/media/controller/gallery_controller.dart';
import 'package:despedida/features/media/services/gallery_service.dart';
import 'package:despedida/web/io_stub.dart'
  if (dart.library.html) 'package:despedida/web/io_web.dart' as webio;
import 'package:despedida/web/mime_detector.dart';
import 'dart:typed_data';

import 'package:media_scanner/media_scanner.dart';
import 'package:gal/gal.dart'; // <- FALTABA

import 'package:flutter/material.dart'; // para Get.dialog y widgets




class CamaraController extends GetxController {
  final String groupId;
  final int? baseIndex;

  CamaraController({required this.groupId, this.baseIndex})
  : assert(groupId.isNotEmpty, 'groupId no puede ser vacío');

  final picker = ImagePicker();

  final isUploading = false.obs;
  final uploadProgress = 0.0.obs;

  

  // ============================================================

  /// Pedir permisos de cámara/galería
  Future<void> pedirPermisos() async {
    await Permission.camera.request();
    await Permission.photos.request();
  }

  /// Subida genérica (usa GalleryController si está activo)
  Future<void> _subirArchivo(XFile file, String contentType) async {
    final tag = 'gallery-$groupId-$baseIndex';

    final galleryCtrl = Get.isRegistered<GalleryController>(tag: tag)
        ? Get.find<GalleryController>(tag: tag)
        : null;

    bool hadError = false; // <-- NUEVO

    if (galleryCtrl != null) {
      // 🚀 Subida usando la galería activa
      try {
        await galleryCtrl.uploadFile(
          file: File(file.path),
          contentType: contentType,
        );
      } catch (e) {
        hadError = true;
        Get.snackbar("Error", e.toString());
      }
    } else {
      // fallback: subida directa con GalleryService
      await for (final event in GalleryService().upload(
        groupId: groupId,
        baseIndex: baseIndex,
        file: File(file.path),
        contentType: contentType,
      )) {
        if (event.error != null) {
          hadError = true; // <-- NUEVO
          Get.snackbar("Error", event.error.toString());
          break;
        }
        uploadProgress.value = event.progress;
      }
    }

    // ⬇️ Mostrar éxito y guardar en galería SOLO si NO hubo error
    if (!hadError) {
      Get.snackbar("Éxito", "Archivo subido correctamente");

      // Guardar también en la galería del dispositivo (Android)
      try {
        if (contentType.startsWith('video/')) {
          await Gal.putVideo(file.path);
        } else if (contentType.startsWith('image/')) {
          await Gal.putImage(file.path);
        }
        final savedPath = file.path;
        await MediaScanner.loadMedia(path: savedPath); // o MediaScanner.scanFile(savedPath)
      } catch (_) {
        // Silencioso: no rompas UX si MediaStore falla
      }
    }
  }


  /// Tomar foto
  Future<void> tomarFoto() async {
    await pedirPermisos();
    final imagen = await picker.pickImage(source: ImageSource.camera);
    if (imagen != null) {
      uploadProgress.value = 0.0;
      isUploading.value    = true;
      try {
        await _subirArchivo(imagen, "image/jpeg");
      } finally {
        isUploading.value    = false;
        uploadProgress.value = 0.0;
      }
    }

  }

  /// Grabar vídeo
  Future<void> grabarVideo() async {
    await pedirPermisos();
    final video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      uploadProgress.value = 0.0;
      isUploading.value    = true;
      try {
        await _subirArchivo(video, "video/mp4");
      } finally {
        isUploading.value    = false;
        uploadProgress.value = 0.0;
      }
    }

  }

    // ------ WEB ------
   // FOTO WEB
  Future<void> capturarFotoWeb() async {
    if (!kIsWeb) return;
    try {
      final pick = await webio.capturePhotoWeb();
      if (pick == null) return;

      final mimeDet = DetectorMimeSafari.detectarTipoMime(
        nombreArchivo: pick.filename,
        mimeOriginal: pick.mime,
        bytes: pick.bytes,
      );
      print('[WEB] capturarFotoWeb name=${pick.filename} mimeOrig=${pick.mime} mimeDet=$mimeDet bytes=${pick.bytes.length}');

      // Forzamos JPEG si no lo es, para compatibilidad en Safari
      Uint8List uploadBytes = pick.bytes;
      String uploadFilename = pick.filename;
      String uploadMime = mimeDet;

      if (!uploadMime.toLowerCase().startsWith('image/jpeg')) {
        final jpg = await webio.transcodeImageToJpegWeb(pick.bytes, quality: 0.9);
        if (jpg != null && jpg.isNotEmpty) {
          uploadBytes = jpg;
          uploadMime = 'image/jpeg';
          final dot = uploadFilename.lastIndexOf('.');
          uploadFilename = (dot > 0 ? uploadFilename.substring(0, dot) : uploadFilename) + '.jpg';
        }
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Sesión', 'Debes iniciar sesión');
        return;
      }

      isUploading.value = true;
      uploadProgress.value = 0;
      await Future<void>.delayed(const Duration(milliseconds: 16));

      await GalleryService().uploadBytesWeb(
        groupId: groupId,
        baseIndex: baseIndex,
        bytes: uploadBytes,
        filename: uploadFilename,
        mime: uploadMime,
        onProgress: (p) => uploadProgress.value = p,
      );

      // refrescar galería
      final tag = 'gallery-$groupId-$baseIndex';
      if (Get.isRegistered<GalleryController>(tag: tag)) {
        await Get.find<GalleryController>(tag: tag).loadInitial();
      }

      Get.snackbar('Listo', 'Foto subida');
    } catch (e, st) {
      print('[WEB] capturarFotoWeb ERROR: $e\n$st');
      Get.snackbar('Error', e.toString());
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0;
    }
  }


  Future<void> capturarVideoWeb() async {
    if (!kIsWeb) return;
    try {
      final pick = await webio.captureVideoWeb();
      if (pick == null) return;

      final mime = DetectorMimeSafari.detectarTipoMime(
        nombreArchivo: pick.filename,
        mimeOriginal: pick.mime,
        bytes: pick.bytes,
      );
      print('[WEB] capturarVideoWeb name=${pick.filename} mimeOrig=${pick.mime} mimeDet=$mime bytes=${pick.bytes.length}');

      // Límite 30s antes de subir
      final dur = await webio.probeVideoDurationSeconds(pick.bytes, mime: mime);
      if (dur != null && dur > 30.0) {
        Get.snackbar('Límite de duración', 'El vídeo supera 30s');
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Sesión', 'Debes iniciar sesión');
        return;
      }

      isUploading.value = true;
      uploadProgress.value = 0;
      await Future<void>.delayed(const Duration(milliseconds: 16));

      await GalleryService().uploadBytesWeb(
        groupId: groupId,
        baseIndex: baseIndex,
        bytes: pick.bytes,
        filename: pick.filename,
        mime: mime,
        onProgress: (p) => uploadProgress.value = p,
      );

      // refrescar galería
      final tag = 'gallery-$groupId-$baseIndex';
      if (Get.isRegistered<GalleryController>(tag: tag)) {
        await Get.find<GalleryController>(tag: tag).loadInitial();
      }

      Get.snackbar('Listo', 'Vídeo subido');
    } catch (e, st) {
      print('[WEB] capturarVideoWeb ERROR: $e\n$st');
      Get.snackbar('Error', e.toString());
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0;
    }
  }



  // DESDE GALERÍA WEB
  Future<void> pickDesdeGaleriaWeb() async {
    if (!kIsWeb) return;
    try {
      final pick = await webio.pickAnyFileWeb();
      if (pick == null) return;

      final mime = DetectorMimeSafari.detectarTipoMime(
        nombreArchivo: pick.filename,
        mimeOriginal: pick.mime,
        bytes: pick.bytes,
      );

      print('[WEB] pickDesdeGaleriaWeb name=${pick.filename} mimeOrig=${pick.mime} mimeDet=$mime bytes=${pick.bytes.length}');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Sesión', 'Debes iniciar sesión');
        return;
      }

      isUploading.value = true;
      uploadProgress.value = 0;
      await Future<void>.delayed(const Duration(milliseconds: 16));

      await GalleryService().uploadBytesWeb(
        groupId: groupId,
        baseIndex: baseIndex,
        bytes: pick.bytes,
        filename: pick.filename,
        mime: mime,
        onProgress: (p) => uploadProgress.value = p,
      );

      final tag = baseIndex != null ? 'gallery-$groupId-$baseIndex' : 'gallery-$groupId';
      if (Get.isRegistered<GalleryController>(tag: tag)) {
        await Get.find<GalleryController>(tag: tag).loadInitial();
      }

      Get.snackbar('Listo', 'Archivo subido');
    } catch (e, st) {
      print('[WEB] pickDesdeGaleriaWeb ERROR: $e\n$st');
      Get.snackbar('Error', e.toString());
    } finally {
      isUploading.value = false;
      uploadProgress.value = 0;
    }
  }
  
  Future<void> _showDownloadCardWeb({
    required String filename,
    required String downloadUrl,
  }) async {
    await Get.dialog(
      Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F2A33),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black54)],
            border: Border.all(color: const Color(0xFF00E5FF), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download, color: Colors.white, size: 28),
              const SizedBox(height: 12),
              Text(
                filename,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                '¿Quieres descargar este archivo?',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Get.back(),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    child: const Text('Descargar'),
                    onPressed: () {
                      // Forzamos alert nativo de Safari (Descargar/Cancelar)
                      webio.promptDownloadFromUrlWeb(downloadUrl, filename: filename);
                      Get.back();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.45),
    );
  }


}