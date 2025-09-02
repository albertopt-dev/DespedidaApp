import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:despedida/main.dart'; // para acceder al plugin y al canal

Future<void> mostrarNotificacion(String titulo, String mensaje) async {
  await flutterLocalNotificationsPlugin.show(
    0,
    titulo,
    mensaje,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('notificacion'),
      ),
    ),
  );
}
