import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../controller/gallery_controller.dart';
import '../models/media_item.dart';
import '../widgets/media_detail_view.dart';
import 'package:despedida/web/io_stub.dart'
    if (dart.library.html) 'package:despedida/web/io_web.dart' as webio;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';  

class GaleriaScreen extends StatelessWidget {
  GaleriaScreen({super.key});

  final picker = ImagePicker(); // <- Añade esta línea

  @override
  Widget build(BuildContext context) {
    final raw = Get.arguments;
    final Map<String, dynamic> args = (raw is Map)
        ? Map<String, dynamic>.from(
            raw.map((k, v) => MapEntry(k.toString(), v)),
          )
        : const <String, dynamic>{};

    final String groupId = (args['groupId'] ?? '') as String;
    final int? baseIndex = args['baseIndex'] is int
        ? args['baseIndex'] as int
        : int.tryParse('${args['baseIndex']}');


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
    // ------ WEB (Safari/Chrome/Firefox) ------
    if (kIsWeb) {
      try {
        await _withProgress(context, () async {
          final pick = await webio.pickAnyFileWeb();
          if (pick == null) return;

          final lowerName = pick.filename.toLowerCase();
          String mime = pick.mime.isNotEmpty ? pick.mime : 'application/octet-stream';

          // Decide mediaType por MIME, no por extensión
          String mediaType = 'file';
          if (mime.startsWith('image/')) mediaType = 'image';
          else if (mime.startsWith('video/')) mediaType = 'video';

          // Saca la extensión: primero por nombre, si no, por MIME
          String ext = '';
          final dot = lowerName.lastIndexOf('.');
          if (dot != -1 && dot < lowerName.length - 1) {
            ext = lowerName.substring(dot + 1);
          }
          if (ext.isEmpty) {
            // fallback por MIME
            if (mime == 'image/jpeg') ext = 'jpg';
            else if (mime == 'image/png') ext = 'png';
            else if (mime == 'image/webp') ext = 'webp';
            else if (mime == 'image/heic') ext = 'heic';
            else if (mime == 'video/mp4') ext = 'mp4';
            else if (mime == 'video/quicktime') ext = 'mov';
            else if (mime == 'video/webm') ext = 'webm';
            else ext = 'bin';
          }

          final uid = c.service.userUid ?? FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            Get.snackbar('Sesión', 'Debes iniciar sesión');
            return;
          }

          final ts = DateTime.now().millisecondsSinceEpoch;
          final folderBase = c.baseIndex == null ? 'general' : '${c.baseIndex}';
          final storagePath = 'uploads/groups/${c.groupId}/bases/$folderBase/${ts}_$uid.$ext';

          final ref = FirebaseStorage.instance.ref(storagePath);
          await ref.putData(pick.bytes, SettableMetadata(contentType: mime));
          final url = await ref.getDownloadURL();

          await FirebaseFirestore.instance
              .collection('groups')
              .doc(c.groupId)
              .collection('media')
              .add({
            'groupId': c.groupId,
            'baseIndex': c.baseIndex,
            'ownerUid': uid,
            'type': mediaType,          // ⬅️ 'image' o 'video' según MIME real
            'storagePath': storagePath,
            'downloadURL': url,
            'contentType': mime,
            'ext': ext,
            'createdAt': FieldValue.serverTimestamp(),
          });
        });

        await c.loadInitial();
        Get.snackbar('Listo', 'Contenido subido', snackPosition: SnackPosition.BOTTOM);
      } catch (e) {
        Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
      }
      return;
    }




    // ------ ANDROID / iOS nativo (lo tuyo de siempre) ------
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

    // ... tu flujo actual móvil tal cual (no lo toco)
    try {
      switch (source) {
        case _PickAction.cameraPhoto: {
          final x = await picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85, // compresión básica
          );
          if (x == null) return;
          await c.uploadFile(file: File(x.path), contentType: 'image/jpeg');
          break;
        }

        case _PickAction.galleryPhoto: {
          final x = await picker.pickImage(source: ImageSource.gallery);
          if (x == null) return;
          final file = File(x.path);
          final mime = lookupMimeType(file.path) ?? 'image/jpeg';
          await c.uploadFile(file: file, contentType: mime);
          break;
        }

        case _PickAction.galleryVideo: {
          final x = await picker.pickVideo(source: ImageSource.gallery);
          if (x == null) return;
          final file = File(x.path);
          final mime = lookupMimeType(file.path) ?? 'video/mp4';

          // Mantenemos tu flujo original con compresión/validación vía service.upload
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
                Get.snackbar('Nube llena / no permitido', 'Se guardó en tu dispositivo.');
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
      }

    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
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

  Future<T> _withProgress<T>(
      BuildContext context,
      Future<T> Function() task, {
      String text = 'Subiendo…',
    }) async {
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Stack(
            children: [
              // Fondo a pantalla completa (mismo degradado que la app)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromARGB(255, 86, 212, 143),
                        Color.fromARGB(255, 48, 143, 106),
                        Color.fromARGB(255, 19, 64, 42),
                      ],
                    ),
                  ),
                ),
              ),
              // Blur sutil para separar el HUD del fondo
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: const SizedBox.expand(),
                ),
              ),
              // Tarjeta centrada
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(blurRadius: 12, color: Colors.black54),
                    ],
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        text, // ⬅️ ahora respeta el parámetro
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
        barrierColor: Colors
            .transparent, // ⬅️ sin velo negro por encima del fondo
      );

      try {
        final r = await task();
        return r;
      } finally {
        if (Get.isDialogOpen ?? false) Get.back();
      }
    }


}

enum _PickAction { cameraPhoto, galleryPhoto, galleryVideo }
enum _LongPressAction { select, delete }