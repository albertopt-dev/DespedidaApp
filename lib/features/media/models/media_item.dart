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
  });

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
      };
}

extension MediaItemFormat on MediaItem {
  String get createdAtFormatted {
    final dt = createdAt;
    // dd/MM/yyyy y HH:mm (24h). Ajusta a tu gusto.
    return DateFormat('dd/MM/yyyy\nHH:mm').format(dt);
  }
}
