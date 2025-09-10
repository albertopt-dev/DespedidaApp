// lib/debug/web_logger.dart
// Fachada: exporta la implementación correcta según plataforma.
export 'web_logger_io.dart'
  if (dart.library.html) 'web_logger_web.dart';
