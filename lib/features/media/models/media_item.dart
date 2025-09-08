import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MediaItem {
  final String id;
  final String groupId;
  final int? baseIndex; // null = galería general
  final String ownerUid;
  final String type; // "image" | "video"
  final String storagePath;
  final String downloadURL;
  final DateTime createdAt;
  final String? thumbnailURL;
  final num? durationSec;

  // 👇 NUEVO
  final String? contentType; // p.ej. "image/heic", "image/jpeg", "video/mp4"
  final String? ext;         // p.ej. "heic", "jpg", "mp4"

  MediaItem({
    required this.id,
    required this.groupId,
    required this.baseIndex,
    required this.ownerUid,
    required this.type,
    required this.storagePath,
    required this.downloadURL,
    required this.createdAt,
    this.thumbnailURL,
    this.durationSec,
    this.contentType, // nuevo
    this.ext,         // nuevo
  });

  // Helpers
  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isHeicLike {
    final ct = (contentType ?? '').toLowerCase();
    final e = (ext ?? '').toLowerCase();
    return ct.contains('heic') || ct.contains('heif') || e == 'heic' || e == 'heif';
  }

  // Fecha formateada (versión simple)
  String get createdAtFormatted {
    try {
      return DateFormat('dd/MM HH:mm').format(createdAt);
    } catch (_) {
      return '';
    }
  }

  factory MediaItem.fromDoc(String id, Map<String, dynamic> d) {
    return MediaItem(
      id: id,
      groupId: d['groupId'] as String,
      baseIndex: d['baseIndex'],
      ownerUid: d['ownerUid'] as String,
      type: d['type'] as String,
      storagePath: d['storagePath'] as String,
      downloadURL: d['downloadURL'] as String,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      thumbnailURL: d['thumbnailURL'],
      durationSec: d['durationSec'],
      // 👇 lee lo que ya guardas en Firestore
      contentType: d['contentType'],
      ext: d['ext'],
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'baseIndex': baseIndex,
        'ownerUid': ownerUid,
        'type': type,
        'storagePath': storagePath,
        'downloadURL': downloadURL,
        'createdAt': Timestamp.fromDate(createdAt),
        if (thumbnailURL != null) 'thumbnailURL': thumbnailURL,
        if (durationSec != null) 'durationSec': durationSec,
        if (contentType != null) 'contentType': contentType, // nuevo
        if (ext != null) 'ext': ext,                         // nuevo
      };
}
