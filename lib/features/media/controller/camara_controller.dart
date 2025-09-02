import 'dart:io';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Asegúrate de tener estos archivos creados en tu proyecto
import 'package:despedida/features/media/controller/gallery_controller.dart';
import 'package:despedida/features/media/services/gallery_service.dart';

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
}
