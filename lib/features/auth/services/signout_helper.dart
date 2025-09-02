// lib/core/auth/signout_helper.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthUtils {
  /// Cierra sesión y despega el token de FCM del usuario actual en Firestore.
  static Future<void> signOutAndDetachToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final token = await FirebaseMessaging.instance.getToken();

    if (uid != null && token != null) {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      try {
        await functions.httpsCallable('detachTokenFromUser').call({'uid': uid, 'token': token});
      } catch (e) {
        // No bloquees el logout por errores transitorios de red.
        // debugPrint('detachTokenFromUser error: $e');
      }
    }

    // Opcional: fuerza que el dispositivo genere un token nuevo en el próximo login:
    // await FirebaseMessaging.instance.deleteToken();

    await FirebaseAuth.instance.signOut();
  }
}
