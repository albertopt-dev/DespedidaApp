import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:despedida/features/group/controller/group_controller.dart';

class JoinGroupScreen extends StatelessWidget {
  final TextEditingController _codigoController = TextEditingController();
  final GroupController controller = Get.find<GroupController>();

  // Añade este constructor con el parámetro key
  JoinGroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Unirse a un grupo")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _codigoController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onJoin(),
              decoration: const InputDecoration(
                labelText: "Código del grupo",
                border: OutlineInputBorder(),
                hintText: "Ej: 123456",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _onJoin,
              child: const Text("Unirse"),
            ),
          ],
        ),
      ),
    );
  }

  /// Lógica de unión con feedback de carga + navegación.
  Future<void> _onJoin() async {
    final code = _codigoController.text.trim();

    if (code.isEmpty) {
      Get.snackbar("Código requerido", "Introduce el código del grupo.");
      return;
    }

    // Indicador de carga modal
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      // Usa tu método del controlador (ya lo estabas llamando)
      await controller.joinGroupWithCode(code);

      // Cierra el loader
      Get.back();

      // Éxito
      Get.snackbar("¡Listo!", "Te has unido al grupo correctamente.");

      // Navega a la pantalla de amigos (ajusta la ruta si quieres otra)
      Get.offAllNamed('/home-amigo');
    } catch (e) {
      // Cierra el loader
      if (Get.isDialogOpen ?? false) Get.back();

      // Muestra error legible
      Get.snackbar(
        "Error",
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }
}
