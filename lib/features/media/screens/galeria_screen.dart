import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controller/gallery_controller.dart';
import '../models/media_item.dart';
import '../widgets/media_detail_view.dart';

class GaleriaScreen extends StatelessWidget {
  const GaleriaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;
    final String groupId = args['groupId'] as String;
    final int? baseIndex = args['baseIndex'] as int?;

    // Tag único por grupo+base para poder encontrar el controller desde /camara si hace falta.
    final tag = 'gallery-$groupId-$baseIndex';

    final c = Get.put(
      GalleryController(groupId: groupId, baseIndex: baseIndex),
      tag: tag,
    );

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Obx(() {
          final selecting = c.isSelectionMode.value;
          final count = c.selectedIds.length;

          return AppBar(
            centerTitle: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0D1B1E), // mismo tono que la pantalla de cámara
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.blue), // ← back arrow azul

            leading: selecting
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.blue), // ← también azul cuando hay selección
                    onPressed: c.clearSelection,
                  )
                : null,

            title: selecting
                ? Text('$count seleccionados')
                : Text(baseIndex == null ? 'Galería' : 'Base ${baseIndex + 1}'),

            actions: [
              if (!selecting)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.green), // ← refresh verde
                  onPressed: c.loadInitial,
                )
              else ...[
                IconButton(
                  tooltip: 'Descargar selección',
                  icon: const Icon(Icons.download),
                  onPressed: c.bulkWorking.value ? null : c.downloadSelected,
                ),
                IconButton(
                  tooltip: 'Eliminar selección',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final ok = await _confirmMassDelete(context, c);
                    if (ok == true) c.deleteSelected();
                  },
                ),
              ],
            ],
          );
        }),
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1B1E),
              Color(0xFF102A30),
              Color(0xFF133940),
            ],
          ),
        ),
        child: Obx(() {
          if (c.isLoading.value && c.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.items.isEmpty) {
            // ← para que se lea sobre fondo oscuro
            return const Center(
              child: Text('Sin contenido', style: TextStyle(color: Colors.white70)),
            );
          }
          return Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                    c.loadMore();
                  }
                  return false;
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1,
                  ),
                  itemCount: c.items.length,
                  itemBuilder: (context, i) {
                    final item = c.items[i];
                    final thumb = item.thumbnailURL ?? item.downloadURL;
                    final isSelected = c.selectedIds.contains(item.id);

                    return GestureDetector(
                      onLongPress: () async {
                        if (c.isSelectionMode.value) {
                          c.toggleSelection(item.id);
                        } else {
                          final action = await showModalBottomSheet<_LongPressAction>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.check_circle_outline),
                                    title: const Text('Seleccionar'),
                                    onTap: () => Navigator.pop(ctx, _LongPressAction.select),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: const Text('Borrar'),
                                    onTap: () => Navigator.pop(ctx, _LongPressAction.delete),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (action == _LongPressAction.select) {
                            c.enterSelection(item.id);
                          } else if (action == _LongPressAction.delete) {
                            _confirmDelete(context, c, item);
                          }
                        }
                      },
                      onTap: () {
                        if (c.isSelectionMode.value) {
                          c.toggleSelection(item.id);
                        } else {
                          Get.to(
                            () => MediaDetailView(
                              items: c.items,
                              initialIndex: i,
                              tagBase: tag,
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: '$tag-${item.id}',
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: thumb,
                              fit: BoxFit.cover,
                              placeholder: (ctx, __) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (ctx, __, ___) =>
                                  const ColoredBox(color: Colors.black12),
                            ),
                            if (item.type == 'video')
                              const Align(
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            if (isSelected)
                              Container(
                                color: Colors.black26,
                                child: const Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Barra de progreso para acciones masivas (descarga/borrado)
              Obx(() => c.bulkWorking.value
                  ? Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(value: c.bulkProgress.value),
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          );
        }),
      ),

      floatingActionButton: Obx(() {
        // Ocultar FAB en modo selección
        if (c.isSelectionMode.value) return const SizedBox.shrink();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (c.uploading.value)
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (c.uploadProgress.value > 0 &&
                              c.uploadProgress.value <= 1)
                          ? c.uploadProgress.value
                          : null,
                    ),
                    const Icon(Icons.cloud_upload),
                  ],
                ),
              )
            else
              FloatingActionButton.extended(
                onPressed: () => _pickAndUpload(context, c, tag),
                icon: const Icon(Icons.add),
                label: const Text('Subir'),
              ),
          ],
        );
      }),
    );
  }

  // --------------------- Subidas ---------------------
  Future<void> _pickAndUpload(
    BuildContext context,
    GalleryController c,
    String tag,
  ) async {
    await _ensurePermissions();

    final source = await showModalBottomSheet<_PickAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Foto (cámara)'),
              onTap: () => Navigator.pop(ctx, _PickAction.cameraPhoto),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Foto (galería)'),
              onTap: () => Navigator.pop(ctx, _PickAction.galleryPhoto),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Vídeo (galería)'),
              onTap: () => Navigator.pop(ctx, _PickAction.galleryVideo),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();

    try {
      switch (source) {
        case _PickAction.cameraPhoto:
          final x = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85, // compresión básica
          );
          if (x == null) return;
          await c.uploadFile(file: File(x.path), contentType: 'image/jpeg');
          break;

        case _PickAction.galleryPhoto:
          final x = await picker.pickImage(source: ImageSource.gallery);
          if (x == null) return;
          final file = File(x.path);
          final mime = lookupMimeType(file.path) ?? 'image/jpeg';
          await c.uploadFile(file: file, contentType: mime);
          break;

        case _PickAction.galleryVideo:
          final x = await picker.pickVideo(source: ImageSource.gallery);
          if (x == null) return;
          final file = File(x.path);
          final mime = lookupMimeType(file.path) ?? 'video/mp4';

          // Subimos con el servicio para poder capturar errores de cuota/duración
          await for (final e in c.service.upload(
            groupId: c.groupId,
            baseIndex: c.baseIndex,
            file: file,
            contentType: mime,
          )) {
            if (e.error != null) {
              try {
                if (mime.startsWith('video/')) {
                  await Gal.putVideo(file.path);
                } else {
                  await Gal.putImage(file.path);
                }
                Get.snackbar(
                    'Nube llena / no permitido', 'Se guardó en tu dispositivo.');
              } catch (_) {
                Get.snackbar('Error', 'No se pudo guardar localmente.');
              }
              break; // 👈 importante: salir del stream
            }
            c.uploadProgress.value = e.progress;
            if (e.item != null) {
              c.items.insert(0, e.item!);
              break;
            }
          }
          break;
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    }
  }

  Future<void> _ensurePermissions() async {
    await [
      Permission.photos,
      Permission.camera,
      Permission.storage, // Android antiguos
      Permission.videos, // Android 13+
      Permission.photosAddOnly // iOS 14+
    ].request();
  }

  // --------------------- Confirmaciones ---------------------
  void _confirmDelete(
    BuildContext context,
    GalleryController c,
    MediaItem item,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar elemento'),
        content: const Text('¿Seguro que quieres borrar este elemento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await c.deleteItem(item);
              Get.snackbar('Borrado', 'Se eliminó el elemento.');
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmMassDelete(
    BuildContext context,
    GalleryController c,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar selección'),
        content: Text(
            '¿Seguro que quieres borrar ${c.selectedIds.length} elementos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }
}

enum _PickAction { cameraPhoto, galleryPhoto, galleryVideo }
enum _LongPressAction { select, delete }