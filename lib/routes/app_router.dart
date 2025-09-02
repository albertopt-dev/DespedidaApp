import 'package:get/get.dart';

import 'package:despedida/features/auth/screens/splash_screen.dart';
import 'package:despedida/features/auth/screens/login_screen.dart';
import 'package:despedida/features/auth/screens/register_screen.dart';
import 'package:despedida/features/home/screens/home_novio_screen.dart';
import 'package:despedida/features/home/screens/home_amigo_screen.dart';
import 'package:despedida/features/media/screens/galeria_screen.dart';
import 'package:despedida/features/media/screens/camara_screen.dart';
import 'package:despedida/features/chat/screens/chat_amigos_screen.dart';
import 'package:despedida/features/rules/rules_screen.dart';
import '../features/auth/bindings/home_binding.dart'; // <- Ruta corregida
import 'package:despedida/features/media/views/web_video_recorder_page.dart';
import '../features/auth/bindings/login_binding.dart';
import '../features/auth/bindings/register_binding.dart';

class AppRoutes {
  static const String splash     = '/splash';
  static const String login      = '/login';
  static const String register   = '/register';
  static const String homeNovio  = '/home-novio';
  static const String homeAmigo  = '/home-amigo';
  static const String galeria    = '/galeria';
  static const String camara     = '/camara';
  static const String chat       = '/chat';
  static const String rules      = '/rules';
  static const webVideoRecorder = '/web-video-recorder';

  static final routes = <GetPage>[
    GetPage(
      name: splash,
      page: () => const SplashScreen(),
    ),

    // ✅ SOLO una definición y con binding
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: register,
      page: () => const RegisterScreen(),
      binding: RegisterBinding(),
    ),

    GetPage(
      name: homeNovio,
      page: () => HomeNovioScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: homeAmigo,
      page: () => HomeAmigoScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: galeria,
      page: () => const GaleriaScreen(),
    ),
    GetPage(
      name: camara,
      page: () {
        final args = (Get.arguments ?? {}) as Map<String, dynamic>;
        final String groupId = args['groupId'] as String;
        final int? baseIndex = args['baseIndex'] as int?;
        return CamaraScreen(grupoId: groupId, baseIndex: baseIndex);
      },
    ),
    GetPage(
      name: chat,
      page: () {
        final args = (Get.arguments ?? {}) as Map<String, dynamic>;
        final String groupId = args['groupId'] as String;
        return ChatAmigosScreen(groupId: groupId);
      },
    ),
    GetPage(
      name: rules,
      page: () => const RulesScreen(),
      transition: Transition.downToUp,
    ),

    GetPage(
      name: webVideoRecorder,
      page: () {
        final params = Get.parameters;
        final groupId = params['groupId'] ?? '';
        final base = params['baseIndex'];
        final int? baseIndex = (base == null || base.isEmpty) ? null : int.tryParse(base);
        return WebVideoRecorderPage(groupId: groupId, baseIndex: baseIndex);
      },
    ),

  ];
}
