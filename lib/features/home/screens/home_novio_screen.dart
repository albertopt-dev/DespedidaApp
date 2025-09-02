import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:despedida/features/group/controller/group_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:despedida/features/home/screens/home_amigo_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:despedida/features/auth/services/signout_helper.dart';

// ✅ Usa SIEMPRE el mismo canal que en main.dart y en la Function
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'appdespedida_channel_v3',
  'Notificaciones AppDespedida',
  description: 'Canal principal con sonido',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notificacion'),
);

class HomeNovioScreen extends StatefulWidget {
  const HomeNovioScreen({super.key});

  @override
  State<HomeNovioScreen> createState() => _HomeNovioScreenState();
}

class _HomeNovioScreenState extends State<HomeNovioScreen> {
  final GroupController groupController = Get.put(GroupController());
  final ValueNotifier<bool> _dialogShown = ValueNotifier(false);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    // 1) Grupo (esto adjunta el token en tu loadGroup si lo haces allí)
    groupController.loadGroup();

    // 2) Notificaciones locales + canal
    _inicializarNotificacionesLocales();

    // 3) Adjuntar token al novio logeado
    _attachCurrentToken(); // ahora
    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _attachCurrentToken(token: t); // también cuando cambie
    });

    // 4) Foreground: mostrar noti local con el mismo canal/sonido
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      flutterLocalNotificationsPlugin.show(
        0,
        message.notification?.title ?? 'Notificación',
        message.notification?.body ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            importance: Importance.max,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('notificacion'),
          ),
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      // Navegación si quieres reaccionar al tap
    });
  }

    @override
    void dispose() {
    _dialogShown.dispose(); // ✅ evita fugas
    super.dispose();
  }

  Future<void> _inicializarNotificacionesLocales() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings settings =
        const InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(settings);

    // Crear (o idempotentemente recrear) el canal que usa FCM
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _attachCurrentToken({String? token}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final tok = token ?? await FirebaseMessaging.instance.getToken();
    if (uid == null || tok == null) return;

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions
          .httpsCallable('attachTokenToUser')
          .call({'uid': uid, 'token': tok});
      // 🔕 Importante: NO escribas 'fcmToken' en Firestore aquí.
    } catch (e) {
      // no bloquees la app por esto
      debugPrint('attachTokenToUser error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantalla de Novio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              Get.dialog(
                AlertDialog(
                  title: const Text("Cerrar sesión"),
                  content: const Text("¿Estás seguro de que deseas salir de tu cuenta?"),
                  // un pelín de margen para la fila de botones
                  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        await AuthUtils.signOutAndDetachToken(); // ✅ helper
                        Get.offAllNamed('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Cerrar sesión"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Obx(() {
        final grupo = groupController.group.value;

        if (grupo == null) {
          // por si aún no se cargó
          return const Center(child: CircularProgressIndicator());
        }

        if (!grupo.isStarted) {
          return const Center(
            child: Text(
              "Esperando a que los amigos inicien el juego...",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          );
        }

        final pruebas = grupo.pruebas;
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
            const imageRatio = 1.0;

            double visibleWidth, visibleHeight, offsetX, offsetY;
            if (mapWidth / mapHeight > imageRatio) {
              visibleHeight = mapHeight;
              visibleWidth = mapHeight * imageRatio;
              offsetX = (mapWidth - visibleWidth) / 2;
              offsetY = 0;
            } else {
              visibleWidth = mapWidth;
              visibleHeight = mapWidth / imageRatio;
              offsetX = 0;
              offsetY = (mapHeight - visibleHeight) / 2;
            }

            return Stack(
              children: [
                // Fondo del mapa con fallback para evitar pantalla negra si falla el asset
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0E1B2B), Color(0xFF12324A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      image: DecorationImage(
                        image: const AssetImage('assets/images/mapa_isla.png'),
                        fit: BoxFit.cover,
                        onError: (e, st) => debugPrint('❌ Error mapa_isla.png: $e'),
                      ),
                    ),
                  ),
                ),

                // Bases
                for (int i = 0; i < posicionesBases.length; i++)
                  Positioned(
                    left: offsetX + visibleWidth * posicionesBases[i].dx - 22,
                    top: offsetY + visibleHeight * posicionesBases[i].dy - 22,
                    child: BaseCirculo(
                      numero: i + 1,
                      superada: pruebas.length > i && pruebas[i]['superada'] == true,
                      pruebaExistente: pruebas.length > i,
                      onAdd: null,
                      onView: pruebas.length > i
                          ? () {
                              final raw = pruebas[i]['prueba'];
                              final pruebaData = (raw is Map<String, dynamic>)
                                  ? Map<String, dynamic>.from(raw)
                                  : const <String, dynamic>{};
                              showDialog(
                                context: context,
                                builder: (_) => VistaPruebaDialogNovio(
                                  nombreBase: "Base ${i + 1}",
                                  titulo: pruebaData['titulo'] as String,
                                  descripcion: pruebaData['descripcion'] as String,
                                  baseIndex: i,
                                  groupId: groupController.group.value!.codigo, // Pasa el ID aquí
                                ),
                              );
                            }
                          : null,
                    ),
                  ),

                // Observa cambios para abrir el diálogo (robusto; no bloquea la UI)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupController.group.value!.codigo)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();

                    final raw = snapshot.data!.data();
                    if (raw is! Map<String, dynamic>) return const SizedBox.shrink();

                    final pruebasRaw = raw['pruebas'];
                    final List<Map<String, dynamic>> pruebasList =
                        (pruebasRaw is List)
                            ? pruebasRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
                            : const [];

                    final baseActivaIndex = pruebasList.indexWhere(
                      (p) => p['pruebaActiva'] == true && p['notificada'] != true,
                    );

                    // Texto informativo (igual que en tu copia que funcionaba)
                    if (baseActivaIndex == -1) {
                      return const Positioned(
                        bottom: 40, left: 20, right: 20,
                        child: Text(
                          'Aún no hay prueba activa.\nEspera a que te asignen una.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }

                    if (_dialogShown.value) return const SizedBox.shrink();
                    _dialogShown.value = true;

                    final rawPrueba = pruebasList[baseActivaIndex]['prueba'];
                    final pruebaData = (rawPrueba is Map<String, dynamic>)
                        ? Map<String, dynamic>.from(rawPrueba)
                        : const <String, dynamic>{};

                    final titulo = (pruebaData['titulo'] is String && (pruebaData['titulo'] as String).isNotEmpty)
                        ? pruebaData['titulo'] as String
                        : 'Sin título';
                    final descripcion = (pruebaData['descripcion'] is String)
                        ? (pruebaData['descripcion'] as String)
                        : '';

                    // Abrir diálogo sin bloquear la build
                    Future.microtask(() async {
                      try {
                        await Get.dialog(
                          VistaPruebaDialogNovio(
                            nombreBase: "Base ${baseActivaIndex + 1}",
                            titulo: titulo,
                            descripcion: descripcion,
                            baseIndex: baseActivaIndex,
                            groupId: grupo.codigo,
                          ),
                        );
                        // marcar como notificada
                        pruebasList[baseActivaIndex]['notificada'] = true;
                        await FirebaseFirestore.instance
                            .collection('groups')
                            .doc(groupController.group.value!.codigo)
                            .update({'pruebas': pruebasList});
                      } catch (e, st) {
                        debugPrint('❌ diálogo novio: $e\n$st');
                      } finally {
                        _dialogShown.value = false;
                      }
                    });

                    return const SizedBox.shrink();
                  },
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
          padding: const EdgeInsets.only(bottom: 40, right: 30),
          child: FloatingActionButton(
            heroTag: 'galeria_general_novio',
            backgroundColor: const Color.fromARGB(255, 216, 196, 104),
            onPressed: () {
              final g = groupController.group.value!;
              Get.toNamed('/galeria', arguments: {
                'groupId': g.codigo,
                'baseIndex': -1, // 👈 -1 indica galería general
              });
            },
            child: const Icon(Icons.photo_library, color: Colors.black, size: 32),
          ),
        );
      }),
    );
  }
}

// --- (Tus diálogos y painters se quedan iguales) ---
class VistaPruebaDialogNovio extends StatelessWidget {
  final String nombreBase;
  final String titulo;
  final String descripcion;
  final int baseIndex;
  final String groupId;

  const VistaPruebaDialogNovio({
    super.key,
    required this.nombreBase,
    required this.titulo,
    required this.descripcion,
    required this.baseIndex,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color.fromARGB(255, 195, 253, 234),
        ),
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(minHeight: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título de la base
            Column(
              children: [
                Text(
                  nombreBase,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Card con la descripción
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              constraints: const BoxConstraints(minHeight: 150),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 253, 240, 174),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                descripcion,
                style: const TextStyle(fontSize: 18, color: Colors.black87),
              ),
            ),

            const SizedBox(height: 24),

            // Botones mejorados
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 24),
                      label: const Text(
                        "Abrir galería",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[200],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Get.toNamed('/galeria', arguments: {
                          'groupId': groupId, // Cambiado de 'grupoId' a 'groupId'
                          'baseIndex': baseIndex,
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            // Botón Cerrar
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Cerrar",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class VotacionDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final VoidCallback onAceptar;
  final VoidCallback onCancelar;

  const VotacionDialog({
    super.key,
    required this.titulo,
    required this.mensaje,
    required this.onAceptar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8D5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: const TextStyle(fontSize: 18, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: onCancelar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Cancelar",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: onAceptar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Aceptar",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
  final GroupController controller = Get.find<GroupController>();
  final String nombreBase;
  final String descripcion;
  final int baseIndex;

  VistaPruebaDialog({
    super.key,
    required this.nombreBase,
    required this.descripcion,
    required this.baseIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(minHeight: 300, maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8D5), // fondo general claro
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nombreBase,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                descripcion,
                style: const TextStyle(fontSize: 20, color: Colors.black87),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text("Abrir galería"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                backgroundColor: Colors.cyanAccent[400],
                foregroundColor: Colors.black,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Get.toNamed('/camara', arguments: {
                  'groupId': controller.group.value!.codigo, // ✅ clave correcta y non-null
                  'baseIndex': baseIndex,
                });
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Cerrar",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


