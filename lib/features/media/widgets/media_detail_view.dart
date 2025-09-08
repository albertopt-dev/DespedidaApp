import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:despedida/web/io_stub.dart'
  if (dart.library.html) 'package:despedida/web/io_web.dart' as webio;

import '../models/media_item.dart';

class MediaDetailView extends StatefulWidget {
  const MediaDetailView({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.tagBase,
  });

  final List<MediaItem> items;
  final int initialIndex;
  final String tagBase;

  @override
  State<MediaDetailView> createState() => _MediaDetailViewState();
}

class _MediaDetailViewState extends State<MediaDetailView> {
  late final PageController _pc;
  int _index = 0;
  VideoPlayerController? _vpc;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pc = PageController(initialPage: _index);
    _prepareVideoIfNeeded(widget.items[_index]);
  }

  @override
  void dispose() {
    _vpc?.dispose();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _prepareVideoIfNeeded(MediaItem item) async {
    _vpc?.dispose();
    _vpc = null;
    if (item.type == 'video') {
      final c = VideoPlayerController.networkUrl(Uri.parse(item.downloadURL));
      await c.initialize();
      c.setLooping(true);
      setState(() => _vpc = c);
      await c.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => Share.share(item.downloadURL),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (_) => Get.back(),
        child: PageView.builder(
          controller: _pc,
          onPageChanged: (i) {
            setState(() => _index = i);
            _prepareVideoIfNeeded(widget.items[i]);
          },
          itemCount: widget.items.length,
          itemBuilder: (_, i) {
            final it = widget.items[i];

            // --------- CONTENIDO (sin Hero en Web) ----------
            Widget content;
            if (it.type == 'image') {
              if (kIsWeb) {
                final isHeic = ((it.contentType?.contains('heic') ?? false) ||
                                (it.contentType?.contains('heif') ?? false) ||
                                it.ext == 'heic' || it.ext == 'heif');
                // HEIC/HEIF en Web no-Safari -> fallback (no intentar decodificar)
                if (isHeic && !webio.isSafari) {
                  content = const _HeicNoPreview();
                } else {
                  content = CachedNetworkImage(
                    imageUrl: it.downloadURL,
                    fit: BoxFit.contain,
                    imageRenderMethodForWeb: ImageRenderMethodForWeb.HtmlImage,
                    useOldImageOnUrlChange: true,
                    fadeInDuration: const Duration(milliseconds: 120),
                    placeholder: (ctx, __) => const SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (ctx, url, err) {
                      // ignore: avoid_print
                      print('[WEB][image-error][detail] url=$url error=$err');
                      return const Icon(Icons.broken_image_outlined,
                          size: 40, color: Colors.white54);
                    },
                  );
                }
              } else {
                // Android/iOS => PhotoView
                content = PhotoView(
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.transparent),
                  imageProvider: CachedNetworkImageProvider(it.downloadURL),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                );
              }
            } else {
              // Vídeo
              content = (_vpc == null)
                  ? const CircularProgressIndicator()
                  : AspectRatio(
                      aspectRatio: _vpc!.value.aspectRatio,
                      child: VideoPlayer(_vpc!),
                    );
            }

            // --------- HERO solo en Android/iOS ----------
            if (!kIsWeb) {
              content = Hero(
                tag: '${widget.tagBase}-${it.id}',
                child: content,
              );
            }

            return Center(child: content);
          },
        ),
      ),
    );
  }
}

class _HeicNoPreview extends StatelessWidget {
  const _HeicNoPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.image_not_supported, size: 48, color: Colors.white70),
            SizedBox(height: 10),
            Text(
              'Vista previa no compatible en este navegador (HEIC).\n'
              'Ábrela en un dispositivo compatible o descárgala.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
