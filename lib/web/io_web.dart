// lib/web/io_web.dart
// Web-only. Mantiene API pública existente:
// - PickResult(bytes, filename, mime)
// - pickAnyFileWeb(), capturePhotoWeb(), captureVideoWeb()
// Robusto: sin decodificación de imagen, sin canvas, sin throw.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

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
  try {
    // 1) Preferente: File.arrayBuffer() (rápido y estable)
    final ab = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(file, 'arrayBuffer', const []),
    );

    if (ab is ByteBuffer) {
      final bytes = Uint8List.view(ab);
      final mime = _sniffMime(
        explicitType: file.type,
        head: _head(bytes),
        filename: file.name,
      );
      return PickResult(bytes, file.name, mime);
    }
  } catch (_) {
    // caemos a FileReader
  }

  // 2) Fallback: FileReader.readAsArrayBuffer
  try {
    final reader = html.FileReader();
    final completer = Completer<PickResult?>();

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.onLoad.listen((_) {
      try {
        final result = reader.result;

        if (result is ByteBuffer) {
          final bytes = Uint8List.view(result);
          final mime = _sniffMime(
            explicitType: file.type,
            head: _head(bytes),
            filename: file.name,
          );
          if (!completer.isCompleted) {
            completer.complete(PickResult(bytes, file.name, mime));
          }
          return;
        }

        if (result is Uint8List) {
          final mime = _sniffMime(
            explicitType: file.type,
            head: _head(result),
            filename: file.name,
          );
          if (!completer.isCompleted) {
            completer.complete(PickResult(result, file.name, mime));
          }
          return;
        }

        if (result is List<int>) {
          final bytes = Uint8List.fromList(result);
          final mime = _sniffMime(
            explicitType: file.type,
            head: _head(bytes),
            filename: file.name,
          );
          if (!completer.isCompleted) {
            completer.complete(PickResult(bytes, file.name, mime));
          }
          return;
        }

        if (result is String && result.startsWith('data:')) {
          // Algunos navegadores pueden devolver dataURL
          final comma = result.indexOf(',');
          if (comma != -1) {
            final header = result.substring(5, comma); // "image/png;base64"
            final b64 = result.substring(comma + 1);
            final bytes = base64Decode(b64);
            final fromHeader = header.split(';').first;
            final mime = _sniffMime(
              explicitType: file.type.isNotEmpty ? file.type : fromHeader,
              head: _head(bytes),
              filename: file.name,
            );
            if (!completer.isCompleted) {
              completer.complete(PickResult(bytes, file.name, mime));
            }
            return;
          }
        }

        if (!completer.isCompleted) completer.complete(null);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    try {
      reader.readAsArrayBuffer(file);
    } catch (_) {
      reader.readAsDataUrl(file);
    }

    return completer.future
        .timeout(const Duration(seconds: 20), onTimeout: () => null);
  } catch (_) {
    // Último recurso: cancelación silenciosa
    return null;
  }
}

Uint8List _head(Uint8List bytes, [int n = 64]) {
  if (bytes.length <= n) return bytes;
  return Uint8List.sublistView(bytes, 0, n);
}

String _sniffMime({
  required String explicitType,
  required Uint8List head,
  required String filename,
}) {
  // 1) Si el navegador indica un tipo útil, nos fiamos.
  final t = (explicitType).toLowerCase().trim();
  final byType = _normalizeNavigatorType(t);
  if (byType != null) return byType;

  // 2) Magic numbers (cabecera)
  if (head.length >= 3 &&
      head[0] == 0xFF &&
      head[1] == 0xD8 &&
      head[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (head.length >= 8 &&
      head[0] == 0x89 &&
      head[1] == 0x50 &&
      head[2] == 0x4E &&
      head[3] == 0x47 &&
      head[4] == 0x0D &&
      head[5] == 0x0A &&
      head[6] == 0x1A &&
      head[7] == 0x0A) {
    return 'image/png';
  }
  // GIF: "GIF87a"/"GIF89a"
  if (_startsWithAscii(head, 'GIF87a') || _startsWithAscii(head, 'GIF89a')) {
    return 'image/gif';
  }
  // WEBP: "RIFF....WEBP"
  if (_startsWithAscii(head, 'RIFF') && _containsAsciiAt(head, 'WEBP', 8)) {
    return 'image/webp';
  }
  // ISO BMFF (ftyp...) para HEIC/HEIF/MP4/MOV
  if (_containsAsciiAt(head, 'ftyp', 4)) {
    // HEIC/HEIF marcas
    const heicBrands = [
      'heic', 'heix', 'hevc', 'heif', 'mif1', 'msf1', 'heis', 'hevm'
    ];
    for (final b in heicBrands) {
      if (_containsAscii(head, b)) return 'image/heic';
    }
    // MP4 genérico
    const mp4Brands = ['isom', 'iso2', 'mp41', 'mp42', 'avc1'];
    for (final b in mp4Brands) {
      if (_containsAscii(head, b)) return 'video/mp4';
    }
    // MOV QuickTime
    if (_containsAscii(head, 'qt  ')) return 'video/quicktime';
  }
  // WebM: 1A 45 DF A3
  if (head.length >= 4 &&
      head[0] == 0x1A &&
      head[1] == 0x45 &&
      head[2] == 0xDF &&
      head[3] == 0xA3) {
    return 'video/webm';
  }

  // 3) Fallback por extensión
  final name = filename.toLowerCase();
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
  if (name.endsWith('.mp4')) return 'video/mp4';
  if (name.endsWith('.mov')) return 'video/quicktime';
  if (name.endsWith('.webm')) return 'video/webm';

  // Desconocido
  return 'application/octet-stream';
}

String? _normalizeNavigatorType(String t) {
  if (t.isEmpty) return null;
  switch (t) {
    case 'image/jpg':
    case 'image/jpeg':
      return 'image/jpeg';
    case 'image/png':
      return 'image/png';
    case 'image/webp':
      return 'image/webp';
    case 'image/gif':
      return 'image/gif';
    case 'image/heic':
    case 'image/heif':
      return 'image/heic';
    case 'video/mp4':
      return 'video/mp4';
    case 'video/quicktime':
      return 'video/quicktime';
    case 'video/webm':
      return 'video/webm';
  }
  if (t.contains('quicktime')) return 'video/quicktime';
  return null;
}

bool _startsWithAscii(Uint8List bytes, String ascii) {
  final sig = ascii.codeUnits;
  if (bytes.length < sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) return false;
  }
  return true;
}

bool _containsAsciiAt(Uint8List bytes, String ascii, int at) {
  final sig = ascii.codeUnits;
  if (bytes.length < at + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (bytes[at + i] != sig[i]) return false;
  }
  return true;
}

bool _containsAscii(Uint8List bytes, String ascii) {
  final sig = ascii.codeUnits;
  for (var i = 0; i <= bytes.length - sig.length; i++) {
    var ok = true;
    for (var j = 0; j < sig.length; j++) {
      if (bytes[i + j] != sig[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

void _forceCaptureAttribute(html.FileUploadInputElement input, String value) {
  // Algunos runtimes de Safari exponen 'capture' solo como propiedad JS.
  try {
    (input as dynamic).capture = value; // 'environment' o 'user'
  } catch (_) {
    // ignore
  }
  // Y además como atributo HTML (cubre otros navegadores)
  input.setAttribute('capture', value);
}


Future<PickResult?> _pickWith({
  required String accept,
  String? capture, // 'environment' para cámara trasera
}) async {
  try {
    final input = html.FileUploadInputElement()
      ..accept = accept
      ..multiple = false;
    if (capture != null) {
      _forceCaptureAttribute(input, capture);
    }


    // Oculto
    input.style
      ..position = 'fixed'
      ..opacity = '0'
      ..pointerEvents = 'none'
      ..width = '0'
      ..height = '0';

    final completer = Completer<PickResult?>();
    Timer? watchdog;

    void cleanup() {
      watchdog?.cancel();
      input.remove();
    }

    input.onChange.listen((_) async {
      try {
        final files = input.files;
        if (files == null || files.isEmpty) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final file = files.first;
        final res = await _readFile(file);
        if (!completer.isCompleted) completer.complete(res);
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      } finally {
        cleanup();
      }
    });

    watchdog = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete(null);
      }
    });

    html.document.body?.append(input);
    scheduleMicrotask(() => input.click());

    return await completer.future;
  } catch (_) {
    return null;
  }
  
}

// API pública (igual que la tuya)
Future<PickResult?> pickAnyFileWeb()  => _pickWith(accept: 'image/*,video/*');
Future<PickResult?> capturePhotoWeb() => _pickWith(accept: 'image/*',  capture: 'environment');
Future<PickResult?> captureVideoWeb() => _pickWith(accept: 'video/*',  capture: 'environment');
// GALERÍA (solo fotos): sin 'capture' para no abrir cámara
Future<PickResult?> pickImagesFromLibrary() {
  return _pickWith(accept: 'image/*', capture: null);
}

// GALERÍA (solo vídeos): sin 'capture'
Future<PickResult?> pickVideosFromLibrary() {
  return _pickWith(accept: 'video/*', capture: null);
}

// Lee la duración del vídeo (en segundos) a partir de los bytes, sin adjuntar al DOM.
Future<double?> probeVideoDurationSeconds(Uint8List bytes, {String? mime}) async {
  try {
    final blob = html.Blob([bytes], mime ?? 'video/mp4');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final video = html.VideoElement()
      ..preload = 'metadata'
      ..src = url;

    final completer = Completer<double?>();
    late StreamSubscription subLoaded;
    late StreamSubscription subError;

    void cleanup() {
      try { subLoaded.cancel(); } catch (_) {}
      try { subError.cancel(); } catch (_) {}
      try { video.src = ''; } catch (_) {}
      try { html.Url.revokeObjectUrl(url); } catch (_) {}
    }

    subLoaded = video.onLoadedMetadata.listen((_) {
      final raw = video.duration; // num
      cleanup();
      // Safari puede reportar NaN/Infinity si falla metadata
      if (raw is num && raw.isFinite && raw > 0) {
        completer.complete(raw.toDouble()); // <- convertir a double
      } else {
        completer.complete(null);
      }
    });


    subError = video.onError.listen((_) {
      cleanup();
      completer.complete(null);
    });

    // timeout de cortesía
    return await completer.future
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
  } catch (_) {
    return null;
  }
}


// --- Guardar en dispositivo (Share Sheet en iOS/Android web; fallback: descarga) ---
Future<void> saveToDeviceWeb({
  required Uint8List bytes,
  required String filename,
  required String mime,
}) async {
  // Construir Blob y File
  final blob = html.Blob([bytes], mime);
  final file = html.File([blob], filename, {'type': mime});

  // Intentar Web Share API con archivos (iOS 15+/16+ lo soporta en Safari)
  final nav = html.window.navigator as dynamic;
  try {
    final canShare = js_util.hasProperty(nav, 'canShare') &&
        (js_util.callMethod(nav, 'canShare', [
          js_util.jsify({'files': [file]})
        ]) as bool);

    if (canShare && js_util.hasProperty(nav, 'share')) {
      await js_util.promiseToFuture(js_util.callMethod(nav, 'share', [
        js_util.jsify({
          'files': [file],
          'title': filename,
          'text': mime.startsWith('image/')
              ? 'Imagen'
              : (mime.startsWith('video/') ? 'Vídeo' : 'Archivo')
        })
      ]));
      return; // Compartido (el usuario puede "Guardar imagen/vídeo")
    }
  } catch (_) {
    // seguimos a fallback
  }

  // Fallback universal: forzar descarga (el usuario puede guardarlo en Archivos/Fotos)
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final a = html.AnchorElement(href: url)..download = filename;
    a.style.display = 'none';
    html.document.body?.append(a);
    a.click();
    a.remove();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}

