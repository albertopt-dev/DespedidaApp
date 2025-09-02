import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controller/login_controller.dart';
import '../../../routes/app_router.dart';
import 'package:flutter/services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ✅ Controladores locales (evita el crash por dispose)
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();

  late final LoginController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<LoginController>(); // o Get.put(LoginController());
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try { await SystemChannels.textInput.invokeMethod('TextInput.hide'); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 30));

    await controller.loginUser(
      email: emailCtrl.text.trim(),
      password: passCtrl.text,
    );

    // Si tu login navega por dentro del controller, no hace falta más aquí.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/bg_login.json',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Iniciar sesión", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),

                      // EMAIL
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Email",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 6, 247, 255)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: emailCtrl, // ⬅️ local
                            onTapOutside: (_) => FocusScope.of(context).unfocus(),
                            style: const TextStyle(color: Colors.black),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: "tucorreo@ejemplo.com",
                              hintStyle: TextStyle(color: Colors.black54),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Color.fromARGB(255, 6, 247, 255), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: Color(0xFF8BC34A), width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // CONTRASEÑA
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Contraseña",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 6, 247, 255)),
                          ),
                          const SizedBox(height: 6),
                          Obx(() => TextField(
                                controller: passCtrl, // ⬅️ local
                                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                style: const TextStyle(color: Colors.black),
                                obscureText: controller.obscurePass.value,
                                obscuringCharacter: '•',
                                enableSuggestions: false,
                                autocorrect: false,
                                keyboardType: TextInputType.visiblePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _doLogin(),
                                decoration: InputDecoration(
                                  hintText: "Tu contraseña",
                                  hintStyle: const TextStyle(color: Colors.black54),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color.fromARGB(255, 6, 247, 255), width: 1),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFF8BC34A), width: 2),
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: controller.obscurePass.value ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                    icon: Icon(
                                      controller.obscurePass.value ? Icons.visibility : Icons.visibility_off,
                                      color: const Color.fromARGB(255, 6, 247, 255),
                                    ),
                                    onPressed: controller.toggleObscure,
                                  ),
                                ),
                              )),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Obx(() => controller.isLoading.value
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _doLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text("Entrar"),
                              ),
                            )),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          try { await SystemChannels.textInput.invokeMethod('TextInput.hide'); } catch (_) {}
                          await Future.delayed(const Duration(milliseconds: 30));
                          Get.toNamed('/register');
                        },
                        child: const Text("¿No tienes cuenta? Regístrate"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Botón reglas
          Positioned(
            right: 30,
            bottom: 80,
            child: TextButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.rules),
              icon: const Icon(Icons.help_outline, color: Colors.white),
              label: const Text(
                "Reglas del Juego",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                backgroundColor: Colors.black.withOpacity(0.92),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.cyan),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
