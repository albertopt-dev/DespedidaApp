import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../routes/app_router.dart';

class RegisterController extends GetxController {
  final isLoading = false.obs;
  final obscurePass = true.obs;
  void toggleObscure() => obscurePass.value = !obscurePass.value;

  // 'novio' o 'amigo'
  final role = 'amigo'.obs;

  String _mapAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use': return 'Ese email ya está registrado.';
        case 'invalid-email':        return 'Correo con formato inválido.';
        case 'weak-password':        return 'Contraseña demasiado débil.';
        case 'network-request-failed': return 'Sin conexión a Internet.';
        default: return e.message ?? 'Error de autenticación.';
      }
    }
    return e.toString();
  }

  Future<void> registerUser({
    required String name,
    required String email,
    required String password,
    String? groupCode, // ya no se usa aquí
  }) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      Get.snackbar('Campos requeridos', 'Completa nombre, email y contraseña');
      return;
    }

    isLoading.value = true;
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = cred.user!.uid;

      final userData = <String, dynamic>{
        'name': name,
        'email': email,
        'role': role.value,
        'groupRefId': null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData, SetOptions(merge: true));

      // Apaga el loading global antes del diálogo
      isLoading.value = false;

      // Pedir código y unirse
      await _pedirCodigoGrupoTrasRegistro(uid);

      // Logout y a login
      isLoading.value = true;
      await FirebaseAuth.instance.signOut();
      Get.deleteAll(force: true); // <-- limpia controladores (clave en Web)
      Get.snackbar('Cuenta creada', 'Te has unido correctamente. Inicia sesión para continuar');
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
      Get.snackbar('Error al registrarse', _mapAuthError(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _pedirCodigoGrupoTrasRegistro(String uid) async {
    final codeCtrl = TextEditingController();
    final joinLoading = false.obs; // loading del diálogo
    bool completado = false;

    await Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              color: const Color.fromARGB(255, 22, 22, 22),
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Unirse a un grupo",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Código del grupo",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF06F7FF)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeCtrl,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      cursorColor: Colors.black,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                        hintText: "Ejemplo: 12356",
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
                    const SizedBox(height: 16),

                    Obx(() => joinLoading.value
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () async {
                              final code = codeCtrl.text.trim();
                              if (code.isEmpty) {
                                Get.snackbar('Falta el código', 'Escribe un código válido');
                                return;
                              }

                              joinLoading.value = true;
                              try {
                                // --- Buscar por ID (docId == código) ---
                                final doc = await FirebaseFirestore.instance
                                    .collection('groups')
                                    .doc(code)
                                    .get();

                                if (!doc.exists) {
                                  Get.snackbar('Código inválido', 'No existe un grupo con ese código');
                                  return; // deja abierto el diálogo
                                }

                                // 1) Guardar el id del grupo en el usuario
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .update({
                                      'groupRefId': doc.id,
                                      // si también usas 'groupId' en otras pantallas, mantenlo sincronizado:
                                      'groupId': doc.id,
                                    });

                                // 2) (Opcional) añadir uid al array "miembros" del grupo
                                await doc.reference.update({
                                  'miembros': FieldValue.arrayUnion([uid]),
                                }).catchError((_) {
                                  // si no existe 'miembros', no rompas el flujo
                                });

                                completado = true;
                                Get.back(); // cierra el diálogo
                              } catch (e) {
                                Get.snackbar('Error', 'No se pudo unir al grupo: $e');
                              } finally {
                                joinLoading.value = false;
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D8FF),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Aceptar"),
                          )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

    if (!completado) {
      throw Exception('La unión al grupo no se completó.');
    }
  }
}
