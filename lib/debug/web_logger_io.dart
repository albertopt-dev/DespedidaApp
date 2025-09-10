// lib/debug/web_logger_io.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WebLogger {
  static Future<void> imageError({
    required String url,
    required String place,
    String? itemId,
    String? extra,
  }) async {
    // No-op en Android/iOS. Si quieres registrar igualmente:
    // await FirebaseFirestore.instance.collection('debug_web_image').add({
    //   'ts': FieldValue.serverTimestamp(),
    //   'url': url,
    //   'place': place,
    //   'itemId': itemId,
    //   'ua': 'unknown',
    //   'extra': extra,
    // });
  }
}
