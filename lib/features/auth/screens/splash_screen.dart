import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:despedida/features/group/controller/group_controller.dart'; // Añade esta línea

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _bgController;


 @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _boot();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(seconds: 4)); // animación breve

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.offAllNamed('/login');
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!snap.exists) {
        Get.offAllNamed('/login');
        return;
      }

      final role = snap.data()!['role'] as String? ?? 'amigo';

       // 👇 Aquí cargamos el grupo ANTES de mandar a home
    final groupController = Get.put(GroupController());
    await groupController.loadGroup();

     // Si no tiene grupo, lo mandamos a que meta código
    if (groupController.group.value == null) {
      Get.offAllNamed('/join-group');
      return;
    }
      // Opcional: aquí podrías llamar a GroupController.loadGroup() antes de navegar
      if (role == 'novio') {
        Get.offAllNamed('/home-novio');
      } else {
        Get.offAllNamed('/home-amigo');
      }
    } catch (e) {
      // Si las reglas bloquean, no te quedes colgado
      Get.snackbar('Aviso', 'No se pudo cargar tu perfil. Inicia sesión de nuevo.');
      Get.offAllNamed('/login');
    }
  }



  @override
  void dispose() {
    _rotationController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(color: Color.fromARGB(255, 14, 13, 13)),
            child: Stack(
              children: [
                // Lottie (arriba centrado)
                Align(
                  alignment: const Alignment(0, -0.5),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double size = constraints.maxWidth * 0.45;
                      return SizedBox(
                        width: size,
                        height: size,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Lottie.asset('assets/animations/beer_cheers.json'),
                        ),
                      );
                    },
                  ),
                ),

                // ✨ NUEVO: lema superior en amarillo
                Align(
                  alignment: const Alignment(0, -0.05), // un poco más arriba
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20), // margen lateral
                    child: Text(
                      '¡ESTE DÍA NO SE OLVIDARÁ FÁCILMENTE!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24, // más pequeño que 32
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.amber, // amarillo
                        shadows: [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black54,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Texto principal SIN recuadro
                Align(
                  alignment: const Alignment(0, 0.20), // un pelín más bajo
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "La última gran fiesta... como soltero",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Delius-Regular', // Cambiado a Delius
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Color.fromARGB(137, 255, 86, 86),
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Imagen girando
                Align(
                  alignment: const Alignment(0, 0.75), // más abajo todavía
                  child: RotationTransition(
                    turns: Tween(begin: 0.0, end: 1.0).animate(_rotationController),
                    child: Image.asset(
                      'assets/images/pau.png',
                      width: 170, // más grande
                      height: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              ],
            ),
          );
        },
      ),
    );
  }


}
