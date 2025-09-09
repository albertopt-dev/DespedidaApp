import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reglas del Juego"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("📜 ¿De qué va el juego?", Icons.help_outline),
            _buildParagraph(
              "El objetivo es organizar una despedida de soltero inolvidable. Los 'Amigos' preparan una serie de pruebas o retos que el 'Novio' debe superar. ¡La coordinación y la diversión son la clave!"
            ),
            const Divider(height: 30),

            _buildSectionTitle("🔑 Registro y Grupos", Icons.group_add),
            _buildRule(
              icon: Icons.vpn_key,
              title: "Unirse a un grupo existente",
              description: "Si tus amigos ya han creado un grupo, te darán un 'Código de Grupo'. Introdúcelo durante el registro para unirte a ellos. Tu rol será 'Amigo'."
            ),
            _buildRule(
              icon: Icons.add_circle_outline,
              title: "Crear un grupo nuevo",
              description: "Si eres el primero en registrarte (normalmente el organizador o el novio), deja el campo 'Código de Grupo' vacío. La app creará un grupo nuevo para ti y te dará un código para que lo compartas con los demás."
            ),
            const Divider(height: 30),

            _buildSectionTitle("🎭 Roles: Novio vs. Amigo", Icons.people),
            _buildRule(
              icon: Icons.star,
              title: "El Novio",
              description: "Es el protagonista. Su misión es superar las pruebas que los amigos le pongan. No puede iniciar pruebas, solo puede verlas una vez que un amigo las activa. ¡Prepárate para lo que sea!"
            ),
            _buildRule(
              icon: Icons.shield,
              title: "Los Amigos",
              description: "Son los 'Game Masters'. Su trabajo es:\n"
                  "1. Añadir pruebas en las bases del mapa.\n"
                  "2. Iniciar una prueba para notificar al novio.\n"
                  "3. Subir fotos/vídeos como prueba de que el novio ha cumplido.\n"
                  "4. Votar si el novio ha superado el reto."
            ),
            const Divider(height: 30),

            _buildSectionTitle("🗺️ Flujo de una Prueba", Icons.flag),
            _buildStep("1.", "Un 'Amigo' pulsa en una base del mapa y añade una prueba (título y descripción)."),
            _buildStep("2.", "Cuando sea el momento, un 'Amigo' entra en la prueba y pulsa 'Iniciar Prueba'. Esto envía una notificación al 'Novio'."),
            _buildStep("3.", "El 'Novio' recibe el aviso, realiza la prueba y avisa a los amigos."),
            _buildStep("4.", "Cualquier miembro del grupo puede usar la 'Cámara' o la 'Galería' para subir las fotos o vídeos que demuestren que la prueba se ha completado."),
            _buildStep("5.", "Los 'Amigos' votan usando los botones: 'Pa'lante' (superada), 'Repetir' o 'Ni de coña' (no superada)."),
            _buildStep("6.", "Si la mayoría vota 'Pa'lante', la base se marcará como superada en el mapa. ¡A por la siguiente!"),
            const Divider(height: 30),

            _buildSectionTitle("🛠️ Otras Funciones", Icons.widgets),
             _buildRule(
              icon: Icons.chat,
              title: "Chat de Grupo",
              description: "Usa el chat para coordinar, enviar pistas o simplemente para reírte del novio. Todos los mensajes son visibles para todos."
            ),
             _buildRule(
              icon: Icons.photo_library,
              title: "Galería de Pruebas",
              description: "Cada prueba tiene su propia galería. Todas las fotos y vídeos que se suban quedarán guardados ahí como recuerdo. También se podrán descargar o eliminar. En Safari para guardar las imagenes te saltara una opción una vez se haya hecho la foto para poder descargarlas en tu carpeta de descargas."
            ),
            const SizedBox(height: 30), 
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 28, color: Colors.cyan),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, height: 1.5));
  }

  Widget _buildRule({required IconData icon, required String title, required String description}) {
    return ListTile(
      leading: Icon(icon, size: 24, color: Colors.amber),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      subtitle: Text(description, style: const TextStyle(fontSize: 15, height: 1.4)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyan)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.4))),
        ],
      ),
    );
  }
}