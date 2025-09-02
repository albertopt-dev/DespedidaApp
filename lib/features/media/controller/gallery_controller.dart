// lib/features/media/controller/gallery_controller.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/media_item.dart';
import '../services/gallery_service.dart';

class GalleryController extends GetxController {
  GalleryController({required this.groupId, this.baseIndex});

  final String groupId;
  final int? baseIndex;

  final service = GalleryService();

  // Estado de la lista/paginación
  final items = <MediaItem>[].obs;
  final isLoading = false.obs;

  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;

  // Estado de subida
  final uploading = false.obs;
  final uploadProgress = 0.0.obs;

  // Selección múltiple
  final isSelectionMode = false.obs;
  final selectedIds = <String>{}.obs; // ids seleccionados

  // Acciones masivas (progreso)
  final bulkWorking = false.obs;
  final bulkProgress = 0.0.obs; // 0..1

  @override
  void onInit() {
    super.onInit();
    loadInitial();
  }

  // ======================
  // Carga / paginación
  // ======================
  Future<void> loadInitial() async {
    isLoading.value = true;
    _lastDoc = null;
    _hasMore = true;
    items.clear();
    await loadMore();
    isLoading.value = false;
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final res = await service.list(
      groupId: groupId,
      baseIndex: baseIndex,
      limit: 30,
      startAfter: _lastDoc,
    );
    items.addAll(res.items);
    _lastDoc = res.lastDoc;
    if (res.items.isEmpty) _hasMore = false;
  }

  // ======================
  // Subidas
  // ======================
  /// Subida de un archivo con reporte de progreso.
  Future<void> uploadFile({
    required File file,
    required String contentType,
    String? thumbnailPath,
    num? durationSec,
  }) async {
    uploading.value = true;
    uploadProgress.value = 0.0;

    await for (final event in service.upload(
      groupId: groupId,
      baseIndex: baseIndex,
      file: file,
      contentType: contentType,
      thumbnailPath: thumbnailPath,
      durationSec: durationSec,
    )) {
      if (event.error != null) {
        uploading.value = false;
        Get.snackbar('Aviso', event.error.toString());
        break;
      }
      uploadProgress.value = event.progress;
      if (event.item != null) {
        items.insert(0, event.item!);
        uploading.value = false;
      }
    }
  }

  // ======================
  // Borrado
  // ======================
  Future<void> deleteItem(MediaItem item) async {
    await service.delete(groupId: groupId, item: item);
    items.removeWhere((e) => e.id == item.id);
  }

  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty) return;
    bulkWorking.value = true;
    try {
      final toDelete = selectedItems;
      for (var i = 0; i < toDelete.length; i++) {
        await deleteItem(toDelete[i]);
        bulkProgress.value = (i + 1) / toDelete.length;
      }
      Get.snackbar('Listo', 'Elementos eliminados');
    } finally {
      bulkWorking.value = false;
      bulkProgress.value = 0;
      clearSelection();
    }
  }

  // ======================
  // Selección múltiple
  // ======================
  void enterSelection(String mediaId) {
    isSelectionMode.value = true;
    selectedIds.add(mediaId);
  }

  void toggleSelection(String mediaId) {
    if (!isSelectionMode.value) return;
    if (selectedIds.contains(mediaId)) {
      selectedIds.remove(mediaId);
      if (selectedIds.isEmpty) isSelectionMode.value = false;
    } else {
      selectedIds.add(mediaId);
    }
  }

  void clearSelection() {
    selectedIds.clear();
    isSelectionMode.value = false;
  }

  // Items seleccionados (getter calculado, no RxList)
  List<MediaItem> get selectedItems =>
      items.where((m) => selectedIds.contains(m.id)).toList();

  // ======================
  // Descarga (gal)
  // ======================
  /// Descarga la selección a la galería del dispositivo usando `gal`.
  /// Intenta reutilizar el caché de `CachedNetworkImage` para evitar red cuando sea posible.
  Future<void> downloadSelected() async {
    if (selectedIds.isEmpty) return;

    bulkWorking.value = true;
    try {
      // Permisos (Android 13+: photos/videos; iOS: photosAddOnly)
      await [
        Permission.photos,
        Permission.photosAddOnly,
        Permission.videos,
        Permission.storage, // legacy Android
      ].request();

      final toDownload = selectedItems;

      for (var i = 0; i < toDownload.length; i++) {
        final item = toDownload[i];

        // 1) Intentar obtener del caché local
        File? localFile;
        try {
          localFile = await DefaultCacheManager().getSingleFile(item.downloadURL);
        } catch (_) {
          localFile = null;
        }

        // 2) Si no está en caché, descargar temporalmente con Dio
        if (localFile == null || !await localFile.exists()) {
          localFile = await _downloadToTemp(item);
        }

        // 3) Guardar en la galería
        if (item.type == 'image') {
          await Gal.putImage(localFile.path);
        } else {
          await Gal.putVideo(localFile.path);
        }

        bulkProgress.value = (i + 1) / toDownload.length;
      }

      Get.snackbar('Descarga completada', 'Guardado en tu galería');
    } catch (e) {
      Get.snackbar('Error al descargar', e.toString());
    } finally {
      bulkWorking.value = false;
      bulkProgress.value = 0;
      clearSelection();
    }
  }

  // ------ helpers privados ------
  /// Descarga un único item a un archivo temporal y devuelve el File.
  Future<File> _downloadToTemp(MediaItem item) async {
    final isVideo = item.type == 'video';
    final tempDir = await getTemporaryDirectory();
    final fileName = '${item.id}${isVideo ? '.mp4' : '.jpg'}';
    final savePath = '${tempDir.path}/$fileName';

    final dio = Dio();
    await dio.download(item.downloadURL, savePath);
    return File(savePath);
  }

  /// (Opcional) Descarga directa para un solo elemento.
  Future<void> _downloadOne(MediaItem item) async {
    final file = await _downloadToTemp(item);
    if (item.type == 'video') {
      await Gal.putVideo(file.path);
    } else {
      await Gal.putImage(file.path);
    }
  }
}
