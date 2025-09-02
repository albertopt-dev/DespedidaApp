// login_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:despedida/routes/app_router.dart';

class LoginController extends GetxController {
  final isLoading = false.obs;
  final obscurePass = true.obs;
  void toggleObscure() => obscurePass.value = !obscurePass.value;

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email': return 'Correo con formato inválido.';
      case 'user-disabled': return 'El usuario está deshabilitado.';
      case 'user-not-found': return 'No existe un usuario con ese correo.';
      case 'wrong-password': return 'Contraseña incorrecta.';
      case 'invalid-credential':
        return 'No se pudo verificar el dispositivo.\nAñade SHA-1/SHA-256 en Firebase y recompila.';
      case 'network-request-failed': return 'Sin conexión a Internet.';
      default: return e.message ?? 'Error de autenticación.';
    }
  }

  Future<void> loginUser({
    required String email,
    required String password,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Campos requeridos', 'Introduce email y contraseña');
      return;
    }

    isLoading.value = true;
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      final data = userDoc.data();
      if (data == null) {
        Get.snackbar('Error', 'No se encontró el perfil de usuario.');
        return;
      }

      final role = data['role'] as String?;
      final groupRefId = data['groupRefId'];

      // Como el código de grupo ya se pide en el registro, aquí solo validamos.
      if (groupRefId == null) {
        // Usuario legacy o registro incompleto (no debería pasar con el flujo nuevo).
        Get.snackbar(
          'Falta unirte al grupo',
          'Tu cuenta no está asociada a ningún grupo. Vuelve a registrarte para completar la unión.',
          duration: const Duration(seconds: 4),
        );
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (role == 'novio') {
        Get.offAllNamed(AppRoutes.homeNovio);
      } else if (role == 'amigo') {
        Get.offAllNamed(AppRoutes.homeAmigo);
      } else {
        Get.snackbar('Error', 'Rol no válido');
      }
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Error de autenticación', _mapAuthError(e));
    } catch (e) {
      Get.snackbar('Error', 'No se pudo iniciar sesión: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
