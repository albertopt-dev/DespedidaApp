// lib/debug/web_logger_web.dart
import 'dart:html' as html; // solo Web
import 'package:cloud_firestore/cloud_firestore.dart';

class WebLogger {
  static Future<void> imageError({
    required String url,
    required String place,
    String? itemId,
    String? extra,
  }) async {
    final ua = _userAgent();
    await FirebaseFirestore.instance.collection('debug_web_image').add({
      'ts': FieldValue.serverTimestamp(),
      'url': url,
      'place': place,
      'itemId': itemId,
      'ua': ua,
      'extra': extra,
    });
  }

  static String _userAgent() {
    try {
      return html.window.navigator.userAgent;
    } catch (_) {
      return 'unknown';
    }
  }
}
