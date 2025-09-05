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

class CamaraController extends GetxController {
  final String groupId;
  final int? baseIndex;

  CamaraController({required this.groupId, this.baseIndex});

  final picker = ImagePicker();

  final isUploading = false.obs;
  final uploadProgress = 0.0.obs;

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

    if (galleryCtrl != null) {
      // 🚀 Subida usando la galería activa
      await galleryCtrl.uploadFile(
        file: File(file.path),
        contentType: contentType,
      );
    } else {
      // fallback: subida directa con GalleryService
      await for (final event in GalleryService().upload(
        groupId: groupId,
        baseIndex: baseIndex,
        file: File(file.path),
        contentType: contentType,
      )) {
        if (event.error != null) {
          Get.snackbar("Error", event.error.toString());
          break;
        }
        uploadProgress.value = event.progress;
      }
    }

    Get.snackbar("Éxito", "Archivo subido correctamente");
  }

  /// Tomar foto
  Future<void> tomarFoto() async {
    final imagen = await picker.pickImage(source: ImageSource.camera);
    if (imagen != null) {
      await _subirArchivo(imagen, "image/jpeg");
    }
  }

  /// Grabar vídeo
  Future<void> grabarVideo() async {
    final video = await picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      await _subirArchivo(video, "video/mp4");
    }
  }

    // ------ WEB ------
    // FOTO WEB
    Future<void> capturarFotoWeb() async {
      if (!kIsWeb) return;
      try {
        final pick = await webio.capturePhotoWeb();
        if (pick == null) return;

        var mime = pick.mime;
        final n = pick.filename.toLowerCase();
        if (mime.isEmpty || mime == 'application/octet-stream') {
          if (n.endsWith('.jpg') || n.endsWith('.jpeg')) mime = 'image/jpeg';
          else if (n.endsWith('.png')) mime = 'image/png';
          else if (n.endsWith('.webp')) mime = 'image/webp';
          else if (n.endsWith('.heic') || n.endsWith('.heif')) mime = 'image/heic';
        }

        print('[WEB] capturarFotoWeb pick: name=${pick.filename} mime=$mime bytes=${pick.bytes.length}');

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          Get.snackbar('Sesión', 'Debes iniciar sesión');
          return;
        }

        isUploading.value = true;
        uploadProgress.value = 0;
        await Future<void>.delayed(const Duration(milliseconds: 16));

        final uploadFuture = GalleryService().uploadBytesWeb(
          groupId: groupId,
          baseIndex: baseIndex,
          bytes: pick.bytes,
          filename: pick.filename,
          mime: mime,
          onProgress: (p) {
            uploadProgress.value = p;
            if (p == 0 || p == 1) {
              print('[WEB] foto progreso ${(p * 100).toStringAsFixed(0)}%');
            }
          },
        );

        // 60s watchdog
        await uploadFuture.timeout(const Duration(seconds: 60), onTimeout: () {
          print('[WEB] upload TIMEOUT');
          Get.snackbar('Red lenta', 'La subida está tardando demasiado. Reintenta.');
          // No lanzamos excepción: retornamos para salir y cerrar overlay en finally
          return;
        });

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

      var mime = pick.mime;
      final n = pick.filename.toLowerCase();
      if (mime.isEmpty || mime == 'application/octet-stream') {
        if (n.endsWith('.webm')) mime = 'video/webm';
        else if (n.endsWith('.mov')) mime = 'video/quicktime';
        else mime = 'video/mp4';
      }

      print('[WEB] capturarVideoWeb pick: name=${pick.filename} mime=$mime bytes=${pick.bytes.length}');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Sesión', 'Debes iniciar sesión');
        return;
      }

      isUploading.value = true;
      uploadProgress.value = 0;
      await Future<void>.delayed(const Duration(milliseconds: 16));

      final uploadFuture = GalleryService().uploadBytesWeb(
        groupId: groupId,
        baseIndex: baseIndex,
        bytes: pick.bytes,
        filename: pick.filename,
        mime: mime,
        onProgress: (p) {
          uploadProgress.value = p;
          if (p == 0 || p == 1) {
            print('[WEB] video progreso ${(p * 100).toStringAsFixed(0)}%');
          }
        },
      );

      await uploadFuture.timeout(const Duration(seconds: 60), onTimeout: () {
        print('[WEB] upload TIMEOUT');
        Get.snackbar('Red lenta', 'La subida está tardando demasiado. Reintenta.');
        return;
      });

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

      var mime = pick.mime;
      final n = pick.filename.toLowerCase();
      if (mime.isEmpty || mime == 'application/octet-stream') {
        if (n.endsWith('.jpg') || n.endsWith('.jpeg')) mime = 'image/jpeg';
        else if (n.endsWith('.png')) mime = 'image/png';
        else if (n.endsWith('.webp')) mime = 'image/webp';
        else if (n.endsWith('.webm')) mime = 'video/webm';
        else if (n.endsWith('.mov')) mime = 'video/quicktime';
        else if (n.endsWith('.mp4')) mime = 'video/mp4';
        else if (n.endsWith('.heic') || n.endsWith('.heif')) mime = 'image/heic';
      }

      print('[WEB] pickDesdeGaleriaWeb pick: name=${pick.filename} mime=$mime bytes=${pick.bytes.length}');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Sesión', 'Debes iniciar sesión');
        return;
      }

      isUploading.value = true;
      uploadProgress.value = 0;
      await Future<void>.delayed(const Duration(milliseconds: 16));

      final uploadFuture = GalleryService().uploadBytesWeb(
        groupId: groupId,
        baseIndex: baseIndex,
        bytes: pick.bytes,
        filename: pick.filename,
        mime: mime,
        onProgress: (p) {
          uploadProgress.value = p;
          if (p == 0 || p == 1) {
            print('[WEB] galería progreso ${(p * 100).toStringAsFixed(0)}%');
          }
        },
      );

      await uploadFuture.timeout(const Duration(seconds: 60), onTimeout: () {
        print('[WEB] upload TIMEOUT');
        Get.snackbar('Red lenta', 'La subida está tardando demasiado. Reintenta.');
        return;
      });

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
