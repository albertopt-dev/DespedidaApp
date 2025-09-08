// lib/web/mime_detector.dart
import 'dart:typed_data';

class DetectorMimeSafari {
  /// Devuelve un MIME fiable para Safari/iOS y web en general.
  /// - Respeta mimeOriginal si es útil.
  /// - Si no, detecta por "magic numbers" y, en último caso, por extensión.
  static String detectarTipoMime({
    required String nombreArchivo,
    required String mimeOriginal,
    required List<int> bytes,
  }) {
    final t = mimeOriginal.trim().toLowerCase();

    // 1) Si el navegador da algo válido, lo normalizamos y usamos.
    if (t.isNotEmpty &&
        t != 'application/octet-stream' &&
        !t.startsWith('minified:')) {
      final norm = _normalizeNavigatorType(t);
      if (norm != null) return norm;
    }

    // 2) Detección por cabecera (magic numbers)
    final head = (bytes is Uint8List) ? bytes : Uint8List.fromList(bytes);

    // JPEG: FF D8 FF
    if (head.length >= 3 &&
        head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (head.length >= 8 &&
        head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47 &&
        head[4] == 0x0D && head[5] == 0x0A && head[6] == 0x1A && head[7] == 0x0A) {
      return 'image/png';
    }

    // GIF: "GIF87a" / "GIF89a"
    if (_startsWithAscii(head, 'GIF87a') || _startsWithAscii(head, 'GIF89a')) {
      return 'image/gif';
    }

    // WEBP: "RIFF" .... "WEBP"
    if (_startsWithAscii(head, 'RIFF') && _containsAsciiAt(head, 'WEBP', 8)) {
      return 'image/webp';
    }

    // WebM: 1A 45 DF A3
    if (head.length >= 4 &&
        head[0] == 0x1A && head[1] == 0x45 && head[2] == 0xDF && head[3] == 0xA3) {
      return 'video/webm';
    }

    // ISO BMFF (ftyp...) para HEIC/HEIF/MP4/MOV
    if (_containsAsciiAt(head, 'ftyp', 4)) {
      // brand principal en bytes 8..11
      String brand = '';
      if (head.length >= 12) {
        brand = String.fromCharCodes(head.sublist(8, 12));
      }

      // HEIC/HEIF
      const heicBrands = {
        'heic', 'heix', 'hevc', 'heif', 'mif1', 'msf1', 'heis', 'hevm'
      };
      if (heicBrands.contains(brand) ||
          _containsAnyAscii(head, heicBrands)) {
        return 'image/heic';
      }

      // MOV QuickTime
      if (brand == 'qt  ') return 'video/quicktime';

      // MP4 común
      const mp4Brands = {'isom', 'iso2', 'mp41', 'mp42', 'avc1'};
      if (mp4Brands.contains(brand) || _containsAnyAscii(head, mp4Brands)) {
        return 'video/mp4';
      }
    }

    // 3) Fallback por extensión
    final n = nombreArchivo.toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    if (n.endsWith('.heif')) return 'image/heif';
    if (n.endsWith('.mp4')) return 'video/mp4';
    if (n.endsWith('.mov')) return 'video/quicktime';
    if (n.endsWith('.webm')) return 'video/webm';

    // 4) Último recurso: algo razonable para fotos de cámara
    return 'image/jpeg';
  }

  /// Mapea MIME -> extensión
  static String obtenerExtensionDeMime(String tipoMime) {
    switch (tipoMime) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'video/mp4':
        return 'mp4';
      case 'video/quicktime':
        return 'mov';
      case 'video/webm':
        return 'webm';
      default:
        return 'bin';
    }
  }

  // ----------------- helpers internos -----------------

  static String? _normalizeNavigatorType(String t) {
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

  static bool _startsWithAscii(Uint8List bytes, String ascii) {
    final sig = ascii.codeUnits;
    if (bytes.length < sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[i] != sig[i]) return false;
    }
    return true;
  }

  static bool _containsAsciiAt(Uint8List bytes, String ascii, int at) {
    final sig = ascii.codeUnits;
    if (bytes.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[at + i] != sig[i]) return false;
    }
    return true;
  }

  static bool _containsAnyAscii(Uint8List bytes, Set<String> words) {
    for (final w in words) {
      if (_containsAscii(bytes, w)) return true;
    }
    return false;
  }

  static bool _containsAscii(Uint8List bytes, String ascii) {
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
}
