import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'dart:js_util' as js_util;


class PickResult {
  final Uint8List bytes;
  final String filename;
  final String mime;
  PickResult(this.bytes, this.filename, this.mime);
}

bool get isSafari {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('safari') &&
      !ua.contains('chrome') &&
      !ua.contains('crios') &&
      !ua.contains('fxios');
}

Future<PickResult?> _readFile(html.File file) async {
  // 1) Intento preferente: JS File.arrayBuffer() → ByteBuffer directo
  try {
    final ab = await js_util.promiseToFuture<Object?>(js_util.callMethod(file, 'arrayBuffer', []));
    if (ab is ByteBuffer) {
      final bytes = Uint8List.view(ab);
      var mime = (file.type ?? '').trim();
      if (!mime.startsWith('image/') && !mime.startsWith('video/')) {
        // sniffing mínimo
        if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          mime = 'image/jpeg';
        } else if (bytes.length >= 8 &&
            bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
            bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
          mime = 'image/png';
        } else {
          mime = 'application/octet-stream';
        }
      }
      return PickResult(bytes, file.name, mime);
    }
  } catch (e) {
    // ignore: avoid_print
    print('[WEB][io] arrayBuffer() falló, fallback a FileReader: $e');
  }

  // 2) Fallback: FileReader con más casos cubiertos
  final reader = html.FileReader();
  final completer = Completer<PickResult?>();

  void doneError(Object err) {
    print('[WEB][io] FileReader ERROR: $err');
    if (!completer.isCompleted) completer.completeError(err);
  }

  reader.onError.listen(doneError);

  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    print('[WEB][io] onLoadEnd resultType=${result.runtimeType}');

    // ByteBuffer
    if (result is ByteBuffer) {
      final bytes = Uint8List.view(result);
      var mime = (file.type ?? '').trim();
      if (!mime.startsWith('image/') && !mime.startsWith('video/')) {
        if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          mime = 'image/jpeg';
        } else if (bytes.length >= 8 &&
            bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
            bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A) {
          mime = 'image/png';
        } else {
          mime = 'application/octet-stream';
        }
      }
      if (!completer.isCompleted) completer.complete(PickResult(bytes, file.name, mime));
      return;
    }

    // Algunos navegadores pueden entregar directamente un Uint8List o List<int>
    if (result is Uint8List) {
      var mime = (file.type ?? '').trim();
      if (!mime.startsWith('image/') && !mime.startsWith('video/')) mime = 'application/octet-stream';
      if (!completer.isCompleted) completer.complete(PickResult(result, file.name, mime));
      return;
    }
    if (result is List<int>) {
      final bytes = Uint8List.fromList(result);
      var mime = (file.type ?? '').trim();
      if (!mime.startsWith('image/') && !mime.startsWith('video/')) mime = 'application/octet-stream';
      if (!completer.isCompleted) completer.complete(PickResult(bytes, file.name, mime));
      return;
    }

    // Data URL
    if (result is String && result.startsWith('data:')) {
      try {
        final comma = result.indexOf(',');
        final header = result.substring(5, comma); // "image/png;base64"
        final b64 = result.substring(comma + 1);
        final bytes = base64Decode(b64);
        var mime = file.type.isNotEmpty ? file.type : header.split(';').first;
        if (!completer.isCompleted) completer.complete(PickResult(bytes, file.name, mime));
      } catch (e) {
        doneError('base64 decode failed: $e');
      }
      return;
    }

    // Null o tipo no reconocido → devuelvo null (casi siempre cancelación)
    if (result == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    // Último recurso: trata de convertir a bytes si es iterable
    if (result is Iterable) {
      try {
        final bytes = Uint8List.fromList(List<int>.from(result));
        var mime = (file.type ?? '').trim();
        if (!mime.startsWith('image/') && !mime.startsWith('video/')) mime = 'application/octet-stream';
        if (!completer.isCompleted) completer.complete(PickResult(bytes, file.name, mime));
        return;
      } catch (_) {}
    }

    doneError('Formato desconocido (tipo=${result.runtimeType})');
  });

  try {
    reader.readAsArrayBuffer(file);
  } catch (e) {
    print('[WEB][io] readAsArrayBuffer fallback a readAsDataUrl: $e');
    reader.readAsDataUrl(file);
  }

  return completer.future.timeout(const Duration(seconds: 20), onTimeout: () {
    print('[WEB][io] FileReader TIMEOUT');
    return null;
  });
}


Future<PickResult?> _pickWith({
  required String accept,
  String? capture, // 'environment' para cámara trasera
}) async {
  final input = html.FileUploadInputElement()
    ..setAttribute('type', 'file')
    ..accept = accept
    ..multiple = false;

  if (capture != null) {
    input.setAttribute('capture', capture);
  }

  // Invisible e inert
  input.style
    ..position = 'fixed'
    ..opacity = '0'
    ..pointerEvents = 'none'
    ..width = '0'
    ..height = '0';

  final completer = Completer<PickResult?>();
  Timer? watchdog;

  input.onChange.listen((_) async {
    try {
      final files = input.files;
      print('[WEB][io] onChange files=${files?.length ?? 0}');
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files.first;
      print('[WEB][io] file name=${file.name} type=${file.type} size=${file.size}');
      final res = await _readFile(file);
      if (!completer.isCompleted) completer.complete(res);
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    } finally {
      watchdog?.cancel();
      input.remove();
    }
  });

  // Cancelación/timeout (por si no llega onChange)
  watchdog = Timer(const Duration(seconds: 30), () {
    if (!completer.isCompleted) {
      print('[WEB][io] input TIMEOUT/CANCEL');
      input.remove();
      completer.complete(null);
    }
  });

  html.document.body?.append(input);
  scheduleMicrotask(() {
    print('[WEB][io] input.click()');
    input.click();
  });

  return completer.future;
}

// === API pública ===
Future<PickResult?> pickAnyFileWeb()   => _pickWith(accept: 'image/*,video/*');
Future<PickResult?> capturePhotoWeb()  => _pickWith(accept: 'image/*',  capture: 'environment');
Future<PickResult?> captureVideoWeb()  => _pickWith(accept: 'video/*',  capture: 'environment');
