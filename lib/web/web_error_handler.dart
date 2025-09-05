// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

typedef ErrorSink = void Function(String title, String details);

ErrorSink? _sink;

/// Llama a esto pronto en main() y pásale cómo quieres mostrarlo (snackbar, card, etc.)
void setupGlobalWebErrorHandler({ErrorSink? show}) {
  _sink = show;

  // Errores de JS
  html.window.addEventListener('error', (e) {
    final ev = e as html.ErrorEvent;
    final msg = ev.message ?? 'JS Error';
    final file = ev.filename ?? '';
    final line = ev.lineno?.toString() ?? '?';
    final col  = ev.colno?.toString() ?? '?';
    final err  = '${ev.error}';

    if (_isNoise(msg) || _isNoise(err)) return;

    final details = '$msg\n$file:$line:$col\n$err';
    debugPrint('[WEB][onerror] $details');
    _sink?.call('JS Error', details);
  });

  // Promesas sin catch (muy típico con Firebase)
  html.window.addEventListener('unhandledrejection', (e) {
    final ev = e as html.PromiseRejectionEvent;
    final reason = '${ev.reason}';
    if (_isNoise(reason)) return;

    debugPrint('[WEB][unhandledrejection] $reason');
    _sink?.call('Promise rejection', reason);
  });
}

bool _isNoise(String s) {
  final t = s.toLowerCase();
  return t.contains('favicon') ||
         t.contains('stylesheet') && t.contains('not found') ||
         t.contains('messaging/unsupported-browser') ||   // FCM en Safari
         t.contains('net::') ||
         t.contains('err_blocked_by_response');
}
