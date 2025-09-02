import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import '../controller/register_controller.dart';


class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores LOCALES (no en el GetxController)
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final groupCodeController = TextEditingController();

  late final RegisterController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<RegisterController>(); // o Get.put(RegisterController());
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    groupCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a login',
          onPressed: () async {
            FocusManager.instance.primaryFocus?.unfocus();
            try { await SystemChannels.textInput.invokeMethod('TextInput.hide'); } catch (_) {}
            await Future.delayed(const Duration(milliseconds: 30));
            Get.back();
          },
        ),
      ),
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
                  child: Obx(() => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- NOMBRE ---
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Nombre",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06F7FF))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: nameController,
                                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                style: const TextStyle(color: Colors.black),
                                decoration: const InputDecoration(
                                  hintText: "Tu nombre completo",
                                  hintStyle: TextStyle(color: Colors.black54),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFF06F7FF), width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFF8BC34A), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // --- EMAIL ---
                          const SizedBox(height: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Email",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06F7FF))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: emailController,
                                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                style: const TextStyle(color: Colors.black),
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  hintText: "tucorreo@ejemplo.com",
                                  hintStyle: TextStyle(color: Colors.black54),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFF06F7FF), width: 1),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFF8BC34A), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // --- CONTRASEÑA ---
                          const SizedBox(height: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Contraseña",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06F7FF))),
                              const SizedBox(height: 6),
                              TextField(
                                controller: passwordController,
                                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                style: const TextStyle(color: Colors.black),
                                obscureText: controller.obscurePass.value,
                                obscuringCharacter: '•',
                                enableSuggestions: false,
                                autocorrect: false,
                                keyboardType: TextInputType.visiblePassword,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  hintText: "Tu contraseña",
                                  hintStyle: const TextStyle(color: Colors.black54),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                    borderSide: BorderSide(color: Color(0xFF06F7FF), width: 1),
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
                              ),
                            ],
                          ),
                        
                          const SizedBox(height: 18),

                          // --- ROL ---
                          Row(
                            children: [
                              const Text("Rol: "),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: controller.role.value,
                                onChanged: (value) {
                                  if (value != null) controller.role.value = value;
                                },
                                items: const [
                                  DropdownMenuItem(value: 'novio', child: Text("Novio")),
                                  DropdownMenuItem(value: 'amigo', child: Text("Amigo")),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          controller.isLoading.value
                              ? const CircularProgressIndicator()
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      FocusManager.instance.primaryFocus?.unfocus();
                                      try { await SystemChannels.textInput.invokeMethod('TextInput.hide'); } catch (_) {}
                                      await Future.delayed(const Duration(milliseconds: 30));
                                      await controller.registerUser(
                                        name: nameController.text.trim(),
                                        email: emailController.text.trim(),
                                        password: passwordController.text,
                                        groupCode: groupCodeController.text.trim().isEmpty
                                            ? null
                                            : groupCodeController.text.trim(),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text("Registrarse"),
                                  ),
                                ),
                        ],
                      )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}