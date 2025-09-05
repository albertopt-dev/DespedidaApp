import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import '../models/media_item.dart';
import 'package:get/get.dart';
// Solo Web
import 'package:despedida/web/io_stub.dart'
    if (dart.library.html) 'package:despedida/web/io_web.dart' as webio;
import 'dart:typed_data'; // <- para ByteBuffer / Uint8List


/// Excepción para controlar el flujo cuando no cabe en la cuota.
class GalleryQuotaExceeded implements Exception {
  final String message;
  GalleryQuotaExceeded(this.message);
  @override
  String toString() => message;
}

class GalleryService {
  GalleryService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  // Añade este getter
  String? get userUid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _mediaCol(String groupId) =>
      _db.collection('groups').doc(groupId).collection('media');

  DocumentReference<Map<String, dynamic>> _statsDoc(String groupId) =>
      _db.doc('groups/$groupId/stats/storage');

  DocumentReference<Map<String, dynamic>> _configDoc() =>
      _db.doc('app/config');

  /// Lee bytes usados y cuota (usa la del grupo o el default global).
  Future<(int used, int quota)> getQuota(String groupId) async {
    final stats = await _statsDoc(groupId).get();
    int used = 0;
    int? quota;
    if (stats.exists) {
      used = (stats.data()?['storageBytesUsed'] ?? 0) as int;
      quota = (stats.data()?['storageBytesQuota'] as int?);
    }
    if (quota == null) {
      final cfg = await _configDoc().get();
      quota =
          (cfg.data()?['storageBytesQuotaDefault'] ?? (2 * 1024 * 1024 * 1024))
              as int;
    }
    return (used, quota);
  }

  /// Sube imagen o video. Si es vídeo, comprime y adjunta durationSec.
  /// Emite progreso (0..1), y al final el MediaItem creado.
  Stream<({double progress, MediaItem? item, Object? error})> upload({
    required String groupId,
    required int? baseIndex, // null = general
    required File file,
    required String contentType, // "image/jpeg" | "video/mp4"...
    String? explicitExt,
    String? thumbnailPath, // opcional
    num? durationSec, // si es video: si no viene, se calcula
  }) async* {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      yield (
        progress: 0.0,
        item: null,
        error: StateError('User not signed in'),
      );
      return;
    }

    File uploadFile = file;
    String uploadContentType = contentType;
    num? videoDuration = durationSec;

    // Si es video: obtener duración real y comprimir en cliente.
    if (contentType.startsWith('video/')) {
      final info = await VideoCompress.getMediaInfo(file.path);
      videoDuration = videoDuration ?? ((info.duration ?? 0) / 1000.0);
      if ((videoDuration ?? 0) > 30) {
        yield (
          progress: 0.0,
          item: null,
          error: StateError('El vídeo supera 30s'),
        );
        return;
      }
      final comp = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );
      if (comp != null && comp.path != null) {
        uploadFile = File(comp.path!);
      }
    }

    // Chequeo previo de cuota (UX).
    try {
      final (used, quota) = await getQuota(groupId);
      final fileSize = await uploadFile.length();
      if (used + fileSize > quota) {
        throw GalleryQuotaExceeded('Nube llena (cuota excedida)');
      }
    } catch (e) {
      if (e is GalleryQuotaExceeded) {
        yield (progress: 0.0, item: null, error: e);
        return;
      }
      // Si falla la lectura de cuota, continuamos y dejamos que Storage Rules decidan.
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = explicitExt ??
        _extFromContentType(uploadContentType) ??
        _extFromFile(uploadFile);
    final folderBase = baseIndex == null ? 'general' : '$baseIndex';
    final filename = '${ts}_$uid.$ext';
    final storagePath =
        'uploads/groups/$groupId/bases/$folderBase/$filename';

    try {
      final ref = _storage.ref(storagePath);
      final metadata = SettableMetadata(
        contentType: uploadContentType,
        customMetadata: {
          if (uploadContentType.startsWith('video/'))
            'durationSec': '${videoDuration?.round() ?? 0}',
          if (uploadContentType.startsWith('video/')) 'compressed': 'true',
        },
      );

      final task = ref.putFile(uploadFile, metadata);

      await for (final s in task.snapshotEvents) {
        final prog =
            s.totalBytes == 0 ? 0.0 : s.bytesTransferred / s.totalBytes;
        yield (progress: prog, item: null, error: null);
      }

      final downloadURL = await ref.getDownloadURL();

      // Subir thumbnail si lo pasaste (opcional).
      String? thumbUrl;
      if (thumbnailPath != null) {
        final thumbRef = _storage.ref('$storagePath.thumb.jpg');
        final thumbTask = thumbRef.putFile(
          File(thumbnailPath),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        await thumbTask;
        thumbUrl = await thumbRef.getDownloadURL();
      }

      final docRef = await _mediaCol(groupId).add({
        'groupId': groupId,
        'baseIndex': baseIndex,
        'ownerUid': uid,
        'type':
            uploadContentType.startsWith('video/') ? 'video' : 'image',
        'storagePath': storagePath,
        'downloadURL': downloadURL,
        'createdAt': FieldValue.serverTimestamp(),
        if (thumbUrl != null) 'thumbnailURL': thumbUrl,
        if (videoDuration != null) 'durationSec': videoDuration,
        'contentType': uploadContentType,
        'ext': ext,

      });

      // Leer createdAt server y construir modelo
      final snap = await docRef.get();
      final item = MediaItem.fromDoc(snap.id, snap.data()!);
      yield (progress: 1.0, item: item, error: null);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        yield (
          progress: 0.0,
          item: null,
          error: GalleryQuotaExceeded('Nube llena o vídeo > 30s'),
        );
      } else {
        yield (progress: 0.0, item: null, error: e);
      }
    } catch (e) {
      yield (progress: 0.0, item: null, error: e);
    }
  }

  /// Listado paginado por grupo y base (null = general).

  Future<({List<MediaItem> items, DocumentSnapshot? lastDoc})> list({
    required String groupId,
    int? baseIndex,          // null = SOLO generales; >=0 = base concreta; -1 = TODAS
    int limit = 30,
    DocumentSnapshot? startAfter,
  }) async {
    Query q = _mediaCol(groupId)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true) // paginación estable
        .limit(limit);

    // Filtro por base:
    if (baseIndex == null) {
      // SOLO generales (los que subes en la galería general)
      q = q.where('baseIndex', isNull: true);
    } else if (baseIndex >= 0) {
      // Solo una base concreta
      q = q.where('baseIndex', isEqualTo: baseIndex);
    }
    // baseIndex == -1 => TODAS (no aplicamos filtro)

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    final items = snap.docs.map((d) {
      // Asegúrate de que data no sea null y sea un Map antes de procesarlo
      final data = d.data();
      if (data is Map<String, dynamic>) {
        return MediaItem.fromDoc(d.id, data);
      } else {
        // Proporciona un mapa vacío como fallback o maneja el error
        return MediaItem.fromDoc(d.id, <String, dynamic>{});
      }
    }).toList();

    return (items: items, lastDoc: snap.docs.isEmpty ? null : snap.docs.last);
  }


  /// Borrado (Storage + Firestore). Las rules permiten borrar solo al owner.
  Future<void> delete({
    required String groupId,
    required MediaItem item,
  }) async {
    await _storage.ref(item.storagePath).delete().catchError((_) {});
    if (item.thumbnailURL != null) {
      final thumbRef = _storage.ref('${item.storagePath}.thumb.jpg');
      await thumbRef.delete().catchError((_) {});
    }
    await _mediaCol(groupId).doc(item.id).delete();
  }

  String? _extFromContentType(String ct) {
    const map = {
    'image/jpeg': 'jpg',
    'image/jpg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/heic': 'heic',
    'image/heif': 'heif',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'video/webm': 'webm',
    'video/x-matroska': 'mkv',
  };

    return map[ct];
  }

  String _extFromFile(File f) {
    final name = f.path.split('/').last;
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'dat';
  }

  Future<void> pickAndUploadFromWeb({
    required String groupId,
    int? baseIndex,
  }) async {
    if (!kIsWeb) return; // seguridad: solo web

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true, // necesitamos bytes en memoria
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov', 'webm'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    final name = (file.name ?? '').toLowerCase();

    if (bytes == null || name.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Get.snackbar('Sesión', 'Debes iniciar sesión');
      return;
    }

    // Detecta tipo por extensión
    String ext = 'bin';
    String contentType = 'application/octet-stream';
    String mediaType = 'file';

    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      ext = 'jpg'; contentType = 'image/jpeg'; mediaType = 'image';
    } else if (name.endsWith('.png')) {
      ext = 'png'; contentType = 'image/png'; mediaType = 'image';
    } else if (name.endsWith('.webp')) {
      ext = 'webp'; contentType = 'image/webp'; mediaType = 'image';
    } else if (name.endsWith('.webm')) {
      ext = 'webm'; contentType = 'video/webm'; mediaType = 'video';
    } else if (name.endsWith('.mp4')) {
      ext = 'mp4'; contentType = 'video/mp4'; mediaType = 'video';
    } else if (name.endsWith('.mov')) {
      ext = 'mov'; contentType = 'video/quicktime'; mediaType = 'video';
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final folderBase = baseIndex == null ? 'general' : '$baseIndex';
    final storagePath = 'uploads/groups/$groupId/bases/$folderBase/${ts}_$uid.$ext';

    final ref = _storage.ref(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await _db
        .collection('groups')
        .doc(groupId)
        .collection('media')
        .add({
      'groupId': groupId,
      'baseIndex': baseIndex,
      'ownerUid': uid,
      'type': mediaType,         // 'image' | 'video'
      'storagePath': storagePath,
      'downloadURL': url,
      'contentType': contentType, // <-- una sola vez
      'ext': ext,                 // <-- una sola vez
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> capturePhotoFromWeb({
    required String groupId,
    int? baseIndex,
  }) async {
    if (!kIsWeb) return;

    final pick = await webio.capturePhotoWeb(); // helper web, null en móvil
    if (pick == null) return;

    final bytes = pick.bytes;
    final name  = pick.filename.toLowerCase();

    String ext = 'jpg';
    String contentType = 'image/jpeg';
    if (name.endsWith('.png')) {
      ext = 'png'; contentType = 'image/png';
    } else if (name.endsWith('.webp')) {
      ext = 'webp'; contentType = 'image/webp';
    } else if (name.endsWith('.heic') || name.endsWith('.heif')) {
      ext = 'heic'; contentType = 'image/heic';
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      Get.snackbar('Sesión', 'Debes iniciar sesión');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final folderBase = baseIndex == null ? 'general' : '$baseIndex';
    final path = 'uploads/groups/$groupId/bases/$folderBase/${ts}_$uid.$ext';

    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await _db.collection('groups').doc(groupId).collection('media').add({
      'groupId': groupId,
      'baseIndex': baseIndex,
      'ownerUid': uid,
      'type': 'image',
      'storagePath': path,
      'downloadURL': url,
      'contentType': contentType,
      'ext': ext,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Get.snackbar('Subido', 'Imagen subida', snackPosition: SnackPosition.BOTTOM);
  }



  Future<void> captureVideoFromWeb({
    required String groupId,
    int? baseIndex,
  }) async {
    if (!kIsWeb) return;

    final pick = await webio.captureVideoWeb(); // helper web, null en móvil
    if (pick == null) return;

    final bytes = pick.bytes;
    final name  = pick.filename.toLowerCase();

    String ext = 'mp4';
    String contentType = 'video/mp4';
    if (name.endsWith('.mov')) {
      ext = 'mov'; contentType = 'video/quicktime';
    } else if (name.endsWith('.webm')) {
      ext = 'webm'; contentType = 'video/webm';
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      Get.snackbar('Sesión', 'Debes iniciar sesión');
      return;
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final folderBase = baseIndex == null ? 'general' : '$baseIndex';
    final path = 'uploads/groups/$groupId/bases/$folderBase/${ts}_$uid.$ext';

    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await _db.collection('groups').doc(groupId).collection('media').add({
      'groupId': groupId,
      'baseIndex': baseIndex,
      'ownerUid': uid,
      'type': 'video',
      'storagePath': path,
      'downloadURL': url,
      'contentType': contentType,
      'ext': ext,
      'createdAt': FieldValue.serverTimestamp(),
    });

    Get.snackbar('Subido', 'Vídeo subido', snackPosition: SnackPosition.BOTTOM);
  }

  // En GalleryService
  // dentro de class GalleryService
  Future<void> uploadBytesWeb({
    required String groupId,
    int? baseIndex,
    required Uint8List bytes,
    required String filename,
    required String mime,
    void Function(double p)? onProgress,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User not signed in');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final folderBase = baseIndex == null ? 'general' : '$baseIndex';

    // saca extensión desde contentType o nombre
    String ext = _extFromContentType(mime) ?? (() {
      final n = filename.toLowerCase();
      final i = n.lastIndexOf('.');
      return i >= 0 ? n.substring(i + 1) : 'bin';
    })();

    final storagePath = 'uploads/groups/$groupId/bases/$folderBase/${ts}_$uid.$ext';

    try {
      final ref = _storage.ref(storagePath);
      final task = ref.putData(bytes, SettableMetadata(contentType: mime));

      await for (final s in task.snapshotEvents) {
        final p = s.totalBytes == 0 ? 0.0 : s.bytesTransferred / s.totalBytes;
        onProgress?.call(p.clamp(0.0, 1.0));
      }

      final url = await ref.getDownloadURL();

      await _db.collection('groups').doc(groupId).collection('media').add({
        'groupId': groupId,
        'baseIndex': baseIndex,
        'ownerUid': uid,
        'type': mime.startsWith('image/')
            ? 'image'
            : (mime.startsWith('video/') ? 'video' : 'file'),
        'storagePath': storagePath,
        'downloadURL': url,
        'contentType': mime,
        'ext': ext,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e, st) {
      // ignore: avoid_print
      print('[WEB] uploadBytesWeb FirebaseException: ${e.code} ${e.message}\n$st');
      rethrow;
    } catch (e, st) {
      // ignore: avoid_print
      print('[WEB] uploadBytesWeb ERROR: $e\n$st');
      rethrow;
    }
  }


}
