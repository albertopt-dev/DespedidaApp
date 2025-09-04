import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthUtils {
  /// Cierra sesión y despega el token de FCM del usuario actual en Firestore.
  /// En Web/Safari fuerza la persistencia a NONE antes del signOut para evitar
  /// sesiones "pegadas", y la deja en SESSION tras cerrar sesión.
  static Future<void> signOutAndDetachToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? token;

    // En iOS Safari el Messaging puede no estar disponible, por eso envolvemos en try
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (_) {
      token = null;
    }

    if (uid != null && token != null) {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      try {
        await functions
            .httpsCallable('detachTokenFromUser')
            .call({'uid': uid, 'token': token});
      } catch (_) {
        // No bloquear el logout por esto.
      }
    }

    // Opcional: fuerza token nuevo en próximo login
    // try { await FirebaseMessaging.instance.deleteToken(); } catch (_) {}

    if (kIsWeb) {
      // Safari/Web: evitar que quede la sesión cacheada
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.NONE);
      } catch (_) {}

      await FirebaseAuth.instance.signOut();

      // Deja preparada la persistencia por sesión para el próximo login en Web
      try {
        await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
      } catch (_) {}
    } else {
      // Android/iOS nativo
      await FirebaseAuth.instance.signOut();
    }
  }
}
