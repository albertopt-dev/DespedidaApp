import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

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
            return Center(
              child: Hero(
                tag: '${widget.tagBase}-${it.id}',
                child: it.type == 'image'
                    ? PhotoView(
                        backgroundDecoration:
                            const BoxDecoration(color: Colors.transparent),
                        imageProvider:
                            CachedNetworkImageProvider(it.downloadURL),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                      )
                    : _vpc == null
                        ? const CircularProgressIndicator()
                        : AspectRatio(
                            aspectRatio: _vpc!.value.aspectRatio,
                            child: VideoPlayer(_vpc!),
                          ),
              ),
            );
          },
        ),
      ),
    );
  }
}
