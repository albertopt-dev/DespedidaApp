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

      final mime = DetectorMimeSafari.detectarTipoMime(
        nombreArchivo: pick.filename,
        mimeOriginal: pick.mime,
        bytes: pick.bytes,
      );

      print('[WEB] capturarFotoWeb name=${pick.filename} mimeOrig=${pick.mime} mimeDet=$mime bytes=${pick.bytes.length}');

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


  // VÍDEO WEB
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

      final tag = 'gallery-$groupId-$baseIndex';
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

}