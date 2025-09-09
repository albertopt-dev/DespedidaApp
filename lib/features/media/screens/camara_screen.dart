import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:despedida/features/media/controller/camara_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:despedida/routes/app_router.dart';


class CamaraScreen extends StatelessWidget {
  final String grupoId;
  final int? baseIndex;

  const CamaraScreen({
    super.key,
    required this.grupoId,
    this.baseIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (grupoId.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar('Error', 'groupId vacío (navegación incorrecta)');
        Get.back();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }


    final controller = Get.put(
      CamaraController(groupId: grupoId, baseIndex: baseIndex),
    );

    controller.pedirPermisos();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Capturar contenido"),
        centerTitle: true,iconTheme: const IconThemeData(color: Colors.blueAccent),
        elevation: 0,
        backgroundColor: const Color(0xFF0D1B1E),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Fondo con degradado
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0D1B1E),
                  Color(0xFF102A30),
                  Color(0xFF133940),
                ],
              ),
            ),
          ),

          // Contenido
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Tarjeta superior
                    Container(
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(width: 10),
                          Text(
                            '¿Qué deseas hacer?',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),

                    if (!kIsWeb) ...[
                      // Botón: Tomar foto (solo Android/iOS)
                      _ActionButton(
                        color: const Color(0xFF00E5FF),
                        foreground: Colors.black,
                        icon: Icons.photo_camera_outlined,
                        label: 'Tomar foto',
                        onTap: controller.tomarFoto,
                      ),
                      const SizedBox(height: 14),

                      // Botón: Grabar video (solo Android/iOS)
                      _ActionButton(
                        color: const Color(0xFF4286F4),
                        foreground: Colors.white,
                        icon: Icons.videocam_outlined,
                        label: 'Grabar video',
                        onTap: controller.grabarVideo,
                      ),
                      const SizedBox(height: 26),
                    ] else ...[
                      // Web → mismos 3 botones con funciones web
                      _ActionButton(
                        color: const Color(0xFF00E5FF),
                        foreground: Colors.black,
                        icon: Icons.photo_camera_outlined,
                        label: 'Tomar foto',
                        onTap: controller.capturarFotoWeb,
                      ),
                      const SizedBox(height: 14),
                      _ActionButton(
                        color: const Color(0xFF4286F4),
                        foreground: Colors.white,
                        icon: Icons.videocam_outlined,
                        label: 'Grabar video',
                        onTap: controller.capturarVideoWeb,
                      ),
                      const SizedBox(height: 14),
                      _ActionButton(
                        color: const Color(0xFF9C27B0),
                        foreground: Colors.white,
                        icon: Icons.photo_library_outlined,
                        label: 'Subir desde galería',
                        onTap: controller.pickDesdeGaleriaWeb,
                      ),
                      const SizedBox(height: 30),
                    ],

                    const Text(
                      'Se guardará en la galería de la app \ny en la del dispositivo.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

              ),
            ),
          ),

          // Overlay de subida (cuando isUploading = true)
          Obx(() => controller.isUploading.value
            ? Container(
                color: const Color.fromARGB(223, 189, 255, 145),
                alignment: Alignment.center,
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Subiendo…',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                          value: controller.uploadProgress.value, // 0..1
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(controller.uploadProgress.value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

