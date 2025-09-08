import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:despedida/features/group/controller/group_controller.dart';
import 'package:despedida/features/home/screens/celebracion_dialog.dart';
import 'package:despedida/features/auth/services/signout_helper.dart';

class HomeAmigoScreen extends StatelessWidget {
  final GroupController groupController = Get.put(GroupController());

  HomeAmigoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amigachos'),
        centerTitle: true,
        actions: [
          if (groupController.group.value != null &&
              !groupController.group.value!.isStarted)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Iniciar juego',
              onPressed: () async {
                await groupController.iniciarJuego();
                Get.snackbar('¡Juego iniciado!', 'Las pruebas ya están visibles para todos.');
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text("Cerrar sesión"),
                  content: const Text("¿Estás seguro de que deseas salir?"),
                  actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  actionsAlignment: MainAxisAlignment.spaceBetween,
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Cancelar"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await AuthUtils.signOutAndDetachToken();
                        Get.offAllNamed('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Cerrar sesión", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
          //boton chat
          IconButton(
            icon: const Icon(Icons.forum_outlined, color: Colors.green),
            tooltip: 'Abrir chat',
            onPressed: () {
              final g = groupController.group.value;
              if (g == null) return;
              Get.toNamed('/chat', arguments: {
                'groupId': g.codigo, // ⚠️ si tu ruta espera el CÓDIGO o el docId real, pon el correcto
                // si tu ChatAmigosScreen usa docId real, pásale groupController._groupDocId
              });
            },
          ),
        ],
      ),
      body: Obx(() {
        if (groupController.group.value == null) {
          // Evita llamadas múltiples en hot rebuilds
          Future.microtask(() => groupController.loadGroup());
          return const Center(child: CircularProgressIndicator());
        }

        final grupo = groupController.group.value!;
        final pruebas = grupo.pruebas;

        // Coordenadas normalizadas (0..1) de cada base
        final posicionesBases = <Offset>[
          const Offset(0.20, 0.30),
          const Offset(0.40, 0.28),
          const Offset(0.60, 0.30),
          const Offset(0.80, 0.40),
          const Offset(0.65, 0.46),
          const Offset(0.48, 0.46),
          const Offset(0.30, 0.54),
          const Offset(0.30, 0.69),
          const Offset(0.50, 0.65),
          const Offset(0.64, 0.70),
          const Offset(0.45, 0.82),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final mapWidth = constraints.maxWidth;
            final mapHeight = constraints.maxHeight;

            // ⚠️ Ajusta a la relación real de tu asset si no es cuadrado
            const imageRatio = 1.0; // ancho/alto

            double visibleWidth, visibleHeight, offsetX, offsetY;
            if (mapWidth / mapHeight > imageRatio) {
              // sobran lados
              visibleHeight = mapHeight;
              visibleWidth  = mapHeight * imageRatio;
              offsetX = (mapWidth - visibleWidth) / 2;
              offsetY = 0;
            } else {
              // sobran arriba/abajo
              visibleWidth  = mapWidth;
              visibleHeight = mapWidth / imageRatio;
              offsetX = 0;
              offsetY = (mapHeight - visibleHeight) / 2;
            }

            // Usamos el grupo ya calculado arriba
            final grupo = groupController.group.value!;
            final pruebas = grupo.pruebas;

            return Stack(
              children: [
                // Fondo del mapa
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/mapa_isla.png',
                    fit: BoxFit.cover,
                  ),
                ),

                // Bases
                for (int i = 0; i < posicionesBases.length; i++)
                  Positioned(
                    left: offsetX + visibleWidth  * posicionesBases[i].dx - 22,
                    top:  offsetY + visibleHeight * posicionesBases[i].dy - 22,
                    child: BaseCirculo(
                      numero: i + 1,
                      superada: pruebas.length > i && pruebas[i]['superada'] == true,
                      pruebaExistente: pruebas.length > i,
                      onAdd: () {
                        final nombreBase = "Base ${i + 1}";

                        if (pruebas.length > i && pruebas[i]['prueba'] != null) {
                          Get.dialog(
                            AlertDialog(
                              title: Text("Base ya asignada"),
                              content: Text("La $nombreBase ya tiene una prueba. ¿Qué quieres hacer?"),
                              actions: [
                                TextButton(onPressed: () => Get.back(), child: const Text("Cancelar")),
                                TextButton(
                                  onPressed: () async {
                                    final grupo = groupController.group.value;
                                    if (grupo == null) return;

                                    final nuevasPruebas = List<Map<String, dynamic>>.from(grupo.pruebas);
                                    if (nuevasPruebas.length > i) {
                                      nuevasPruebas.removeAt(i);
                                      await groupController.actualizarPruebas(nuevasPruebas);
                                      Get.back();
                                      Get.snackbar("Base eliminada", "$nombreBase ha sido reseteada.");
                                    }
                                  },
                                  child: const Text("Eliminar base", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // Sin prueba → abrir diálogo para crearla
                        Get.dialog(PruebaDialog(nombreBase: nombreBase, baseIndex: i));
                      },
                      onView: pruebas.length > i
                          ? () {
                              final prueba = pruebas[i];
                              showDialog(
                                context: context,
                                builder: (_) => VistaPruebaDialog(
                                  nombreBase: "Base ${i + 1}",
                                  titulo: prueba['prueba']?['titulo'] ?? 'Sin título',
                                  descripcion: prueba['prueba']?['descripcion'] ?? '',
                                  baseIndex: i,
                                  prueba: pruebas[i],
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
              ],
            );
          },
        );

      }),
      floatingActionButton: Obx(() {
        final grupo = groupController.group.value;
        if (grupo == null || !grupo.isStarted) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20, right: 34),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              heroTag: 'galeria_general',
              backgroundColor: const Color.fromARGB(255, 216, 196, 104),
              onPressed: () {
                final g = groupController.group.value!;
                Get.toNamed(
                  '/galeria?groupId=${g.codigo}&baseIndex=-1',
                  arguments: {'groupId': g.codigo, 'baseIndex': -1},
                );

              },
              child: const Icon(Icons.photo_library, color: Colors.black, size: 32),
            ),
          ),
        );
      }),

    );
  }
}

/// ---------- Widgets auxiliares ----------

class BaseCirculo extends StatelessWidget {
  final int numero;
  final bool superada;
  final bool pruebaExistente;
  final VoidCallback? onAdd;
  final VoidCallback? onView;



  const BaseCirculo({
    super.key,
    required this.numero,
    required this.superada,
    required this.pruebaExistente,
    this.onAdd,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: pruebaExistente ? onView : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: superada ? Colors.greenAccent : Colors.white,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: superada
                  ? [BoxShadow(color: Colors.green.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)]
                  : [],
            ),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Contorno (blanco) para que destaque en cualquier color de burbuja
                Text(
                  '$numero',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = Colors.white,
                  ),
                ),
                // Relleno negro (el número visible)
                const SizedBox.shrink(), // ← elimina esta línea si la tenías
                Text(
                  '$numero',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

          ),
          if (!pruebaExistente)
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.add, size: 16, color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class PruebaDialog extends StatefulWidget {
  final String nombreBase;
  final int baseIndex;

  const PruebaDialog({required this.nombreBase, required this.baseIndex, super.key});

  @override
  State<PruebaDialog> createState() => _PruebaDialogState();
}

class _PruebaDialogState extends State<PruebaDialog> {
  final TextEditingController customController = TextEditingController();
  String? seleccionada;
  String? descripcionPreview;

  final List<Map<String, String>> pruebasPredefinidas = const [
    {'titulo': 'La llamada incómoda', 'descripcion': 'Llama a alguien random y declárate con voz sexy. Sin reírte.'},
    {'titulo': 'Selfie con policía', 'descripcion': 'Hazte una foto con un policía o alguien muy serio. Saca la lengua.'},
    {'titulo': 'El ligón atrevido', 'descripcion': 'Pide el número a un desconocido con una frase cutre. Si lo consigue, doble punto.'},
    {'titulo': 'Karaoke callejero', 'descripcion': 'Canta una canción mítica en mitad de la calle. Bonus si bailas.'},
    {'titulo': 'Cazalla Challenge', 'descripcion': 'Chupito de lo más feo que haya, sin manos. Prohibido llorar.'},
    {'titulo': 'Desfile de moda', 'descripcion': 'Ponte ropa prestada de los colegas y desfila como un modelo en la calle.'},
    {'titulo': 'Pide un abrazo', 'descripcion': 'Abraza a un desconocido con drama: “Necesitaba esto, gracias.”'},
    {'titulo': 'TikTok Cringe', 'descripcion': 'Baila una coreografía ridícula en público. Y grábalo, claro.'},
    {'titulo': '¡Sí, chef!', 'descripcion': 'Métete en una cocina y grita “¿Dónde está la sal, chef?”. Aguanta lo que pase.'},
    {'titulo': 'Confesionario ambulante', 'descripcion': 'Cuéntale tu “secreto más oscuro” a alguien que no conoces. Con cara seria.'},
    {'titulo': 'El rey del ligue', 'descripcion': 'Haz que un amigo intente ligar, pero tú haces toda la entrada... mal.'},
    {'titulo': 'Cuerpo de verano', 'descripcion': 'Quítate la camiseta, posa sexy estilo Baywatch y hazte una foto.'},
    {'titulo': 'Amigo invisible', 'descripcion': 'Habla con una pared durante 30 segundos como si fuera tu bro de toda la vida.'},
    {'titulo': 'El brindis del siglo', 'descripcion': 'Sube a una silla y haz un discurso emotivo sobre lo mucho que amas el queso.'},
    {'titulo': 'Tatuaje improvisado', 'descripcion': 'Deja que todos te pinten algo en el brazo sin que tú lo veas. Aguántalo toda la noche.'},
  ];

  @override
  Widget build(BuildContext context) {
    final GroupController groupController = Get.find();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.grey[900],
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(minHeight: 320, maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Prueba para ${widget.nombreBase}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Selecciona una prueba',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
              dropdownColor: Colors.grey[900],
              value: seleccionada,
              items: pruebasPredefinidas
                  .map((p) => DropdownMenuItem<String>(
                        value: p['titulo'],
                        child: Text(p['titulo'] ?? '', style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  seleccionada = value;
                  descripcionPreview =
                      pruebasPredefinidas.firstWhere((p) => p['titulo'] == value)['descripcion'];
                  customController.clear();
                });
              },
            ),

            if (descripcionPreview != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
                  child: Text(descripcionPreview!,
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ),

            const SizedBox(height: 16),

            TextField(
              controller: customController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'O escribe tu propia prueba',
                hintStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: () => Get.back(), child: const Text("Cancelar", style: TextStyle(color: Colors.cyanAccent))),
                ElevatedButton(
                  onPressed: () {
                    final esPersonalizada = customController.text.trim().isNotEmpty;

                    final String titulo = esPersonalizada ? 'Prueba personalizada' : (seleccionada ?? '');
                    final String descripcion = esPersonalizada
                        ? customController.text.trim()
                        : (pruebasPredefinidas.firstWhere(
                              (p) => p['titulo'] == seleccionada,
                              orElse: () => {'descripcion': ''},
                            )['descripcion'] ??
                            '');

                    if (titulo.isEmpty || descripcion.isEmpty) {
                      Get.snackbar("Atención", "Debes seleccionar o escribir una prueba");
                      return;
                    }

                    Get.dialog(
                      AlertDialog(
                        title: Text(titulo),
                        content: Text(descripcion),
                        actions: [
                          TextButton(onPressed: () => Get.back(), child: const Text("Seguir buscando")),
                          ElevatedButton(
                            onPressed: () {
                              groupController.addPrueba(
                                nombreBase: widget.nombreBase,
                                prueba: {'titulo': titulo, 'descripcion': descripcion},
                                baseIndex: widget.baseIndex,
                              );
                              Get.back(); // confirmación
                              Get.back(); // diálogo
                              Get.snackbar("Prueba asignada", "La prueba se guardó en la base");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Confirmar"),
                          ),
                        ],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Guardar", style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VistaPruebaDialog extends StatelessWidget {
  final String nombreBase;
  final String titulo;
  final String descripcion;
  final int baseIndex;
  final Map<String, dynamic> prueba;

  const VistaPruebaDialog({
    super.key,
    required this.nombreBase,
    required this.titulo,
    required this.descripcion,
    required this.baseIndex,
    required this.prueba,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupController>();
    final bool puedeIniciar = !controller.esNovio && prueba['pruebaActiva'] != true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFFDBFFF4), // Color de fondo mint claro
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título de la base
            // Encabezado limpio con menú de opciones
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fila superior: "Base X" centrado + menú de acciones a la derecha
                Row(
                  children: [
                    const SizedBox(width: 36), // para compensar visualmente el menú de la derecha
                    Expanded(
                      child: Text(
                        nombreBase, // p.ej. "Base 1"
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'Opciones',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (context) => [
                        PopupMenuItem<int>(
                          value: 1,
                          child: Row(
                            children: const [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Modificar'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 8),
                        PopupMenuItem<int>(
                          value: 2,
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) async {
                        final controller = Get.find<GroupController>();
                        if (val == 1) {
                          // Modificar: reabrimos el diálogo de asignación
                          Navigator.of(context).pop();
                          Get.dialog(PruebaDialog(nombreBase: nombreBase, baseIndex: baseIndex));
                        } else if (val == 2) {
                          // Eliminar / resetear la base
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Eliminar base'),
                              content: Text(
                                'Vas a eliminar el contenido de $nombreBase.\n\n'
                                '¿Seguro que quieres continuar?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    foregroundColor: Colors.cyan, // color del texto
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    elevation: 3,
                                  ),
                                  onPressed: () async {
                                    final g = controller.group.value;
                                    if (g != null && baseIndex < g.pruebas.length) {
                                      final nuevas = List<Map<String, dynamic>>.from(g.pruebas);
                                      nuevas.removeAt(baseIndex);
                                      await controller.actualizarPruebas(nuevas);
                                    }
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                    Get.snackbar('Base eliminada', '$nombreBase ha sido reseteada.');
                                  },
                                  child: const Text('Eliminar'),
                                ),
                              ],

                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.more_horiz, color: Colors.black87),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Título centrado
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),
              ],
            ),

            const SizedBox(height: 20),

            // Card con la descripción
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8D5), // Amarillo claro
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                descripcion,
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),

            const SizedBox(height: 24),

            // Grid de botones 2x2
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.0,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Botón de cámara
                _buildButton(
                  context: context,
                  icon: Icons.camera_alt,
                  label: "Cámara",
                  color: const Color(0xFF30D1DD), // Cian
                  textColor: Colors.black,
                  onPressed: () {
                    Navigator.of(context).pop();
                    Get.toNamed(
                      '/camara?groupId=${controller.group.value!.codigo}&baseIndex=$baseIndex',
                      arguments: {'groupId': controller.group.value!.codigo, 'baseIndex': baseIndex},
                    );
                  },
                ),

                // Botón de iniciar prueba
                _buildButton(
                  context: context,
                  icon: Icons.flag,
                  label: "Iniciar",
                  color: puedeIniciar ? const Color(0xFF4286F4) : Colors.grey[300]!, // Azul o gris
                  textColor: puedeIniciar ? Colors.white : Colors.grey[600]!,
                  onPressed: puedeIniciar
                      ? () async {
                          Navigator.of(context).pop(); // 👈 Cierra el diálogo primero

                          await controller.iniciarPrueba(baseIndex);

                          // Mostramos el SnackBar en el Scaffold principal
                          ScaffoldMessenger.of(Get.context!).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Prueba iniciada. El novio será notificado.",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green, // 👈 verde más visible
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(12),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      : null,
                ),


                // Botón de galería
                _buildButton(
                  context: context,
                  icon: Icons.photo_library,
                  label: "Galería",
                  color: const Color(0xFFFEE683), // Amarillo claro
                  textColor: Colors.black,
                  onPressed: () {
                    Navigator.of(context).pop();
                    Get.toNamed('/galeria', arguments: {
                      'groupId': controller.group.value?.codigo,
                      'baseIndex': baseIndex,
                    });
                  },
                ),

                // Botón de votar
                _buildButton(
                  context: context,
                  icon: Icons.how_to_vote,
                  label: "Votar",
                  color: const Color(0xFFFCE519), // Amarillo intenso
                  textColor: Colors.black,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => VotacionDialog(baseIndex: baseIndex),
                    );
                  },
                ),
              ],
            ),

            // Botón cerrar
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _buildRoundButton(
                context: context,
                label: "Cerrar",
                color: const Color(0xFFFF6A6A), // Rojo
                textColor: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para construir botones cuadrados
  Widget _buildButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Método para construir botón redondeado (Cerrar)
  Widget _buildRoundButton({
    required BuildContext context,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 200,
      height: 45,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VotacionDialog extends StatelessWidget {
  final int baseIndex;
  const VotacionDialog({super.key, required this.baseIndex});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GroupController>();
    final prueba = controller.group.value?.pruebas[baseIndex];
    final votos = Map<String, dynamic>.from(prueba?['votos'] ?? {});
    final total = votos.length;

    return AlertDialog(
      title: const Text("¿Ha superado la prueba?", textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 18),
          _buildVotoButton(context, controller, "Ni de coña", "nodecona", votos, total),
          const SizedBox(height: 12),
          _buildVotoButton(context, controller, "Repetir", "repetir", votos, total),
          const SizedBox(height: 12),
          _buildVotoButton(context, controller, "Pa' lante", "palante", votos, total),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))],
    );
  }

  Widget _buildVotoButton(
    BuildContext context,
    GroupController controller,
    String texto,
    String tipo,
    Map<String, dynamic> votos,
    int total,
  ) {
    final count = votos.values.where((v) => v == tipo).length;
    final porcentaje = total > 0 ? (count / total * 100).round() : 0;

    Color colorBase;
    switch (tipo) {
      case 'nodecona':
        colorBase = Colors.red;
        break;
      case 'repetir':
        colorBase = Colors.orange;
        break;
      case 'palante':
        colorBase = Colors.green;
        break;
      default:
        colorBase = Colors.grey;
    }

    return ElevatedButton(
      onPressed: () async {
        final uid = FirebaseAuth.instance.currentUser?.uid;

        if (votos.containsKey(uid)) {
          Get.snackbar("Ya has votado", "Solo puedes votar una vez por prueba");
          return;
        }

        await controller.votarPrueba(baseIndex: baseIndex, voto: tipo);
        Get.back();
        Get.snackbar("Voto enviado", "Tu voto ha sido registrado.");

        final prueba = controller.group.value?.pruebas[baseIndex];
        if (prueba == null) return;

        final votosActualizados = Map<String, dynamic>.from(prueba['votos'] ?? {});
        final resultado = _contarVotos(votosActualizados);

        final total = votosActualizados.length;
        final votosPalante = resultado['palante'] ?? 0;
        final porcentajePalante = total > 0 ? (votosPalante / total) * 100 : 0;

        // ✅ ahora pedimos al menos 80% "pa'lante"
        if (porcentajePalante >= 80) {
          await controller.marcarPruebaSuperada(baseIndex);

          // Celebración
          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const CelebracionDialog(),
          );
        } else if (total == resultado['nodecona']! + resultado['repetir']!) {
          // 👈 opcional: si TODOS votan en contra
          Get.snackbar("Prueba no superada", "Habrá que intentarlo de nuevo...");
        }
      },

      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
        backgroundColor: colorBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$porcentaje% - $count voto${count != 1 ? 's' : ''}",
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(texto, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Map<String, int> _contarVotos(Map<String, dynamic> votos) {
    final Map<String, int> contador = {'nodecona': 0, 'repetir': 0, 'palante': 0};
    for (final v in votos.values) {
      if (contador.containsKey(v)) contador[v] = contador[v]! + 1;
    }
    return contador;
  }
}




