import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
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
import 'package:despedida/debug/web_logger.dart';

import 'package:despedida/web/io_stub.dart'
  if (dart.library.html) 'package:despedida/web/io_web.dart' as webio;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:despedida/web/mime_detector.dart';

class GaleriaScreen extends StatelessWidget {
  GaleriaScreen({super.key});

  final picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    // === Lectura robusta de args (Get.arguments) + params (Get.parameters) ===
    final raw = Get.arguments;
    final Map<String, dynamic> args = (raw is Map)
        ? Map<String, dynamic>.from(
            raw.map((k, v) => MapEntry(k.toString(), v)),
          )
        : const <String, dynamic>{};

    final params = Get.parameters;

    final String groupId =
        ((args['groupId'] as String?) ?? params['groupId'] ?? '').trim();

    final dynamic b = args['baseIndex'] ?? params['baseIndex'];
    final int? baseIndex = (b is int) ? b : int.tryParse('$b');

    if (groupId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar('Error', 'groupId vacío (navegación incorrecta)');
        Get.back();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
            backgroundColor: const Color(0xFF0D1B1E),
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.blue),
            leading: selecting
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.blue),
                    onPressed: c.clearSelection,
                  )
                : null,
            title: selecting
                ? Text('$count seleccionados')
                : Text(baseIndex == null ? 'Galería' : 'Base ${baseIndex + 1}'),
            actions: [
              if (!selecting)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.green),
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
      // 👇 Aquí metemos el overlay en un Stack
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1B1E), Color(0xFF102A30), Color(0xFF133940)],
              ),
            ),
            child: Obx(() {
              final items = c.items;

              if (c.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return const Center(child: Text('No hay contenido aún'));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _buildGridItem(items[i], c),
              );
            }),
          ),

          // --- OVERLAY EXACTO ---
          Obx(() => c.uploading.value
              ? Container(
                  color: const Color.fromARGB(223, 189, 255, 145),
                  alignment: Alignment.center,
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Subiendo…',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF00E5FF)),
                            value: c.uploadProgress.value,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(c.uploadProgress.value * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink()),
        ],
      ),

      floatingActionButton: Obx(() {
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

  // ---------- Subidas ----------
  Future<void> _pickAndUpload(
    
    BuildContext context,
    GalleryController c,
    String tag,
    
  ) async {
    if (kIsWeb) {
      final action = await showModalBottomSheet<_PickAction>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería (fotos)'),
                // reutilizamos cameraPhoto para NO tocar el enum ni más lógica
                onTap: () => Navigator.pop(ctx, _PickAction.cameraPhoto),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Galería (vídeos)'),
                onTap: () => Navigator.pop(ctx, _PickAction.recordVideo),
              ),
              // (Opcional) deja esta tercera si quieres mixto (cualquier archivo)
              // ListTile(
              //   leading: const Icon(Icons.perm_media),
              //   title: const Text('Galería (cualquier archivo)'),
              //   onTap: () => Navigator.pop(ctx, _PickAction.gallery),
              // ),
            ],
          ),
        ),
      );
      if (action == null) return;

      // Log útil
      // ignore: avoid_print
      print(
          '[WEB] _pickAndUpload: groupId=${c.groupId} baseIndex=${c.baseIndex} action=$action');

      final uid = c.service.userUid ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        Get.snackbar('Sesión', 'Debes iniciar sesión');
        return;
      }

      // Captura
      dynamic pick;
      switch (action) {
        case _PickAction.cameraPhoto:
          // En Web: “Galería (fotos)”
          pick = await webio.pickImagesFromLibrary();
          break;
        case _PickAction.recordVideo:
          // En Web: “Galería (vídeos)”
          pick = await webio.pickVideosFromLibrary();
          break;
        case _PickAction.gallery:
          // (Opcional) Mixto: fotos o vídeos desde galería/archivos
          pick = await webio.pickAnyFileWeb();
          break;
      }

      if (pick == null) return;

      // MIME robusto (DetectorMimeSafari)
      final mime = DetectorMimeSafari.detectarTipoMime(
        nombreArchivo: pick.filename,
        mimeOriginal: pick.mime,
        bytes: pick.bytes,
      );
      final mediaType = mime.startsWith('image/')
          ? 'image'
          : (mime.startsWith('video/') ? 'video' : 'file');

      // ⛔️ Límite de duración (30s) para vídeos en Web
      if (mediaType == 'video') {
        final dur = await webio.probeVideoDurationSeconds(pick.bytes, mime: mime);
        if (dur != null && dur > 30.0) {
          Get.snackbar('Límite de duración', 'El vídeo supera 30s');
          return;
        }
      }


      // Usa el overlay propio de la galería (c.uploading + c.uploadProgress)
      c.uploadProgress.value = 0.0;
      c.uploading.value = true;
      try {
        await c.service.uploadBytesWeb(
          groupId: c.groupId,
          baseIndex: c.baseIndex,
          bytes: pick.bytes,
          filename: pick.filename,
          mime: mime,
          onProgress: (p) => c.uploadProgress.value = p,
        );

        await c.loadInitial();

        Get.snackbar(
          'Listo',
          mediaType == 'image'
              ? 'Foto subida'
              : (mediaType == 'video' ? 'Vídeo subido' : 'Archivo subido'),
          snackPosition: SnackPosition.BOTTOM,
        );
      } finally {
        c.uploading.value = false;
        c.uploadProgress.value = 0.0;
      }

      return;
    }

    // ------ ANDROID / iOS ------
    await _ensurePermissions();

    final source = await showModalBottomSheet<_PickAction>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Foto (galería)'),
              onTap: () => Navigator.pop(ctx, _PickAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Vídeo (galería)'),
              onTap: () => Navigator.pop(ctx, _PickAction.recordVideo),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      switch (source) {
        case _PickAction.cameraPhoto: // (no se mostrará si quitaste el botón, pero queda OK)
        final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (x == null) return;

        c.uploadProgress.value = 0.0;
        c.uploading.value = true;
        try {
          await c.uploadFile(file: File(x.path), contentType: 'image/jpeg');
        } finally {
          c.uploading.value = false;
          c.uploadProgress.value = 0.0;
        }
        break;

      case _PickAction.gallery:
        final x = await picker.pickImage(source: ImageSource.gallery);
        if (x == null) return;
        final file = File(x.path);
        final mime = lookupMimeType(file.path) ?? 'image/jpeg';

        c.uploadProgress.value = 0.0;
        c.uploading.value = true;
        try {
          await c.uploadFile(file: file, contentType: mime);
        } finally {
          c.uploading.value = false;
          c.uploadProgress.value = 0.0;
        }
        break;

      case _PickAction.recordVideo:
        final x = await picker.pickVideo(source: ImageSource.gallery);
        if (x == null) return;
        final file = File(x.path);
        final mime = lookupMimeType(file.path) ?? 'video/mp4';

        c.uploadProgress.value = 0.0;
        c.uploading.value = true;
        try {
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
              break;
            }
            // ⬇️ Esto alimenta la barra del overlay
            c.uploadProgress.value = e.progress;

            if (e.item != null) {
              c.items.insert(0, e.item!);
              break;
            }
          }
        } finally {
          c.uploading.value = false;
          c.uploadProgress.value = 0.0;
        }
        break;

      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _ensurePermissions() async {
    await [
      Permission.photos,
      Permission.camera,
      Permission.storage,
      Permission.videos,
      Permission.photosAddOnly
    ].request();
  }

  Future<bool?> _confirmMassDelete(
      BuildContext context, GalleryController c) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar selección'),
        content: Text(
            '¿Seguro que quieres borrar ${c.selectedIds.length} elementos?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Borrar')),
        ],
      ),
    );
  }

  Future<T> _withProgress<T>(
    BuildContext context,
    Future<T> Function() task, {
    String text = 'Subiendo…',
  }) async {
    await Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F2A33),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black54)],
                border: Border.all(color: const Color(0xFF00E5FF), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
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
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
    );

    try {
      return await task();
    } finally {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
    }
  }

  // ---------- Render de cada celda ----------
  Widget _buildGridItem(MediaItem item, GalleryController c) {
    return Obx(() {
      final bool selecting = c.isSelectionMode.value;
      final bool selected  = c.selectedIds.contains(item.id);

      return GestureDetector(
        onLongPress: () {
          if (!selecting) c.enterSelection(item.id);
        },
        onSecondaryTap: () {
          if (!selecting) c.enterSelection(item.id);
        },
        onTap: () {
          if (selecting) {
            c.toggleSelection(item.id);
          } else {
            Get.to(() => MediaDetailView(
                  items: [item],
                  initialIndex: 0,
                  tagBase: 'grid',
                ));
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1) thumbnail
            _buildGridThumbnail(item),

            // 2) velo leve si está seleccionado
            if (selected)
              Container(color: Colors.white.withOpacity(0.14)),

            // 3) fecha/hora (si la usas)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.createdAtFormatted, // tu getter formateado
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),

            // 4) checker cuadrado arriba-derecha SOLO en modo selección
            if (selecting)
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => c.toggleSelection(item.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected ? Colors.blueAccent : Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white70, width: 1),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }



  // Encapsula el render del thumbnail (Web/HEIC/HTML img y móvil con Hero)
  Widget _buildGridThumbnail(MediaItem item) {
      // === NUEVO: manejo explícito de videos para todas las plataformas ===
      if (item.isVideo) {
        final thumb = item.thumbnailURL;
        if (thumb != null && thumb.isNotEmpty) {
          // Tenemos miniatura -> mostrarla como imagen
          if (kIsWeb) {
            // Web: <img> nativo
            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: thumb,
                  fit: BoxFit.cover,
                  imageRenderMethodForWeb: ImageRenderMethodForWeb.HtmlImage,
                  placeholder: (_, __) => const ColoredBox(
                    color: Colors.black12,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, url, err) {
                    WebLogger.imageError(
                      url: url,
                      place: 'grid-video',
                      itemId: item.id,
                      extra: err.toString(),
                    );
                    return const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.videocam),
                    );
                  },

                ),
                const Positioned(
                  right: 6, bottom: 6,
                  child: Icon(Icons.play_circle_fill, size: 22, color: Colors.white70),
                ),
              ],
            );
          } else {
            // Android/iOS: con Hero como hacías
            return Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: item.id,
                  child: CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                      color: Colors.black12,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.videocam),
                    ),
                  ),
                ),
                const Positioned(
                  right: 6, bottom: 6,
                  child: Icon(Icons.play_circle_fill, size: 22, color: Colors.white70),
                ),
              ],
            );
          }
        } else {
          // Aún no hay miniatura -> placeholder (NO intentes decodificar el mp4 como imagen)
          return Container(
            color: Colors.black12,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, size: 28, color: Colors.white70),
                  SizedBox(height: 4),
                  Text('Miniatura no disponible',
                      style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          );
        }
      }


    if (kIsWeb) {
    // 1) Si el MIME dice que es VÍDEO pero el 'type' no, trátalo como vídeo para no intentar <img> del mp4/mov
    final isVideoByMime = (item.contentType ?? '').toLowerCase().startsWith('video/');
    if (!item.isVideo && isVideoByMime) {
      final thumb = item.thumbnailURL;
      if (thumb != null && thumb.isNotEmpty) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumb,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, err, __) {
                print('[WEB][image-error][grid-video-thumb] url=$thumb err=$err');
                return const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.videocam),
                );
              },
            ),
            const Positioned(
              right: 6, bottom: 6,
              child: Icon(Icons.play_circle_fill, size: 22, color: Colors.white70),
            ),
          ],
        );

      } else {
        // Sin miniatura: NO intentes pintar el vídeo como imagen
        return Container(
          color: Colors.black12,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, size: 28, color: Colors.white70),
                SizedBox(height: 4),
                Text('Miniatura no disponible',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        );
      }
    }

    // 2) HEIC/HEIF en Web: fallback universal (incluye Safari)
    if (item.isHeicLike) {
      return InkWell(
        onTap: () {
          Get.to(() => MediaDetailView(
                items: [item],
                initialIndex: 0,
                tagBase: 'gallery',
              ));
        },
        child: Container(
          color: Colors.black12,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.image_not_supported, size: 28, color: Colors.white70),
                SizedBox(height: 4),
                Text('HEIC no compatible',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Toca para ver/descargar',
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ),
      );
    }

    // Usamos SIEMPRE derivados JPEG en Web si existen
    final baseUrl = item.thumbnailURL ?? item.displayURL ?? item.downloadURL;
    // Último recurso: fuerza inline para el original (por si es legacy)
    final gridUrl = (item.thumbnailURL == null && item.displayURL == null)
        ? webio.forceInlineImageUrl(baseUrl, contentType: 'image/jpeg', filename: 'image.jpg')
        : baseUrl;


    return CachedNetworkImage(
      imageUrl: gridUrl,
      fit: BoxFit.cover,
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HtmlImage,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (_, url, err) {
        WebLogger.imageError(
          url: url,
          place: 'grid-image',
          itemId: item.id,
          extra: err.toString(),
        );
        return const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.image_not_supported),
        );
      },
    );


  }


    // ANDROID/iOS: mantenemos Hero
    return Hero(
      tag: item.id,
      child: CachedNetworkImage(
        imageUrl: item.thumbnailURL ?? item.downloadURL,
        fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(
          color: Colors.black12,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, __, ___) => const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.error),
        ),
      ),
    );
  }
}

enum _PickAction { cameraPhoto, gallery, recordVideo }
