// lib/main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'routes/app_router.dart';
import 'firebase_options.dart';

// ====== CANALES ANDROID ======
// (solo los usa Android; en Web/iOS quedan ignorados)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'appdespedida_channel_v3',
  'Notificaciones AppDespedida',
  description: 'Canal principal con sonido',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notificacion'),
);

const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
  'appdespedida_default',
  'Notificaciones generales',
  description: 'Chat y otras notificaciones',
  importance: Importance.high,
  playSound: true,
);

// Plugin de notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// BG handler (Android/iOS; Web no lo usa)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // En BG, inicializamos sin opciones (Android/iOS).
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
}

// Permiso de notificaciones (solo Android 13+). En Web no aplica.
Future<void> _ensureAndroidNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  // Evitamos dart:io y permission_handler aquí para no romper Web.
  // Usa permission_handler en Android si ya lo tienes integrado en otra parte.
  // Si quieres mantenerlo, muévelo a un servicio solo-Android.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Un único initializeApp con opciones multiplataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Solo Web: persistencia por sesión (se borra al cerrar pestaña)
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }


  // ===== CONFIG SOLO ANDROID/IOS (no Web) =====
  if (!kIsWeb) {
    // 1) Inicializa notificaciones locales
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // 2) Android 13+: (si usas permission_handler, pide permiso aquí)
    await _ensureAndroidNotificationPermission();

    // 3) Crea canales antes de recibir notificaciones (Android)
    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
    await androidImpl?.createNotificationChannel(chatChannel);

    // 4) BG handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

    // iOS/Web: presentación en foreground (Web lo ignora sin romper)
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Foreground: muestra notificación local (Android). En Web no hace nada.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      final type = message.data['type'] ?? ''; // "prueba" | "chat" | ""

      final title = n?.title ?? 'Notificación';
      final body  = n?.body  ?? '';

      if (type == 'prueba') {
        _mostrarNotificacionNovio(title, body);
      } else {
        _mostrarNotificacionChat(title, body);
      }
    });

    // (Opcional) ver token
    FirebaseMessaging.instance.getToken().then((t) {
      // print('📱 Token FCM: $t');
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Despedida Pau',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00F0FF),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          labelLarge: TextStyle(color: Color(0xFFB0BEC5)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white70),
          hintStyle: TextStyle(color: Colors.white38),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00F0FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00F0FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00F0FF),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.black.withOpacity(0.85),
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.routes,
    );
  }

  // ===== Helpers: notificaciones locales (Android) =====
  Future<void> _mostrarNotificacionNovio(String titulo, String mensaje) async {
    if (kIsWeb) return; // Web no soporta flutter_local_notifications
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titulo,
      mensaje,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appdespedida_channel_v3',
          'Notificaciones AppDespedida',
          channelDescription: 'Canal principal con sonido',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notificacion'),
        ),
      ),
    );
  }

  Future<void> _mostrarNotificacionChat(String titulo, String mensaje) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titulo,
      mensaje,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appdespedida_default',
          'Notificaciones generales',
          channelDescription: 'Chat y otras notificaciones',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }
}
