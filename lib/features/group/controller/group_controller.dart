import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../group/models/group_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class GroupController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  /// Estado del grupo
  Rxn<GroupModel> group = Rxn<GroupModel>();

  /// Stream en vivo del doc del grupo
  Stream<DocumentSnapshot<Map<String, dynamic>>>? groupStream;

  /// docId REAL en Firestore del grupo (no el código)
  String? _groupDocId;

  /// UID actual
  String? get uid => _auth.currentUser?.uid;

  /// ¿Este usuario es el novio?
  bool get esNovio => uid == group.value?.novioUid;

  // -----------------------------------------------------------
  // CARGA DE GRUPO (resuelve docId real a partir del código)
  // -----------------------------------------------------------
Future<void> loadGroup() async {
  final currentUid = _auth.currentUser?.uid;
  if (currentUid == null) return;

  try {
    final userRef = _firestore.collection('users').doc(currentUid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      Get.snackbar('Usuario', 'No existe el documento de usuario.');
      return;
    }

    final userData = userSnap.data() ?? {};

    // Campos posibles en usuarios (compatibilidad hacia atrás)
    final String? cachedDocId = userData['groupRefId'] as String?;
    final String? legacyGroupId = userData['groupId'] as String?;   // puede ser docId o código
    final String? groupCode     = userData['groupCode'] as String?; // código seguro

    String? resolvedDocId;

    // 1) Si ya tenemos docId cacheado -> úsalo
    if (cachedDocId != null && cachedDocId.isNotEmpty) {
      resolvedDocId = cachedDocId;
    } else if (legacyGroupId != null && legacyGroupId.isNotEmpty) {
      // 2) Probar primero si legacyGroupId es un *docId real*
      final byId = await _firestore.collection('groups').doc(legacyGroupId).get();
      if (byId.exists) {
        // Verificamos pertenencia para evitar fugas
        final miembros = List<String>.from(byId.data()?['miembros'] ?? const []);
        if (miembros.contains(currentUid)) {
          resolvedDocId = legacyGroupId;
          // cachear para próximas veces
          await userRef.set({'groupRefId': resolvedDocId}, SetOptions(merge: true));
        }
      }
    }

    // 3) Si aún no tenemos docId, y tenemos un código -> resolver por query
    if (resolvedDocId == null && (groupCode != null && groupCode.isNotEmpty)) {
      final q = await _firestore
          .collection('groups')
          .where('codigo', isEqualTo: groupCode)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        Get.snackbar('Grupo', 'No se encontró grupo con código $groupCode.');
        return;
      }
      resolvedDocId = q.docs.first.id;
      await userRef.set({'groupRefId': resolvedDocId, 'groupCode': groupCode}, SetOptions(merge: true));
    }


    // --- A partir de aquí ya tenemos _groupDocId seguro ---
    _groupDocId = resolvedDocId;

    // 5) Suscripción en tiempo real al doc del grupo
    groupStream = _firestore.collection('groups').doc(_groupDocId).snapshots();
    groupStream!.listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        group.value = GroupModel.fromMap(snapshot.data()!);
      }
      await guardarTokenFCM();
    });

    // 6) Carga inicial
    final groupSnap = await _firestore.collection('groups').doc(_groupDocId).get();
    if (groupSnap.exists && groupSnap.data() != null) {
      final data = groupSnap.data()!;
      group.value = GroupModel.fromMap(data);

      // Deducir novioUid si falta
      if ((data['novioUid'] == null || (data['novioUid'] as String?)?.isEmpty == true) &&
          data['miembros'] != null) {
        final miembros = List<String>.from(data['miembros'] as List);
        for (final mUid in miembros) {
          final u = await _firestore.collection('users').doc(mUid).get();
          final uData = u.data();
          if (uData != null && uData['role'] == 'novio') {
            await _firestore.collection('groups').doc(_groupDocId).update({'novioUid': mUid});
            break;
          }
        }
      }
    }

    // Logs
    // ignore: avoid_print
    print('➡️ uid: $currentUid');
    // ignore: avoid_print
    print('➡️ resolved groupRefId (docId): $_groupDocId');
  } catch (e) {
    Get.snackbar('Error', 'No se pudo cargar el grupo: $e');
  }
}



  // -----------------------------------------------------------
  // PRUEBAS / ESTADO DE JUEGO
  // -----------------------------------------------------------
  Future<void> addPrueba({
    required String nombreBase,
    required Map<String, String> prueba,
    required int baseIndex,
  }) async {
    final g = group.value;
    if (g == null || _groupDocId == null) return;

    final pruebas = List<Map<String, dynamic>>.from(g.pruebas);

    if (pruebas.length > baseIndex) {
      pruebas[baseIndex]['prueba'] = prueba;
      pruebas[baseIndex]['nombreBase'] = nombreBase;
      pruebas[baseIndex]['superada'] = false;
      pruebas[baseIndex]['votos'] = {};
      pruebas[baseIndex]['notificada'] = false;
      pruebas[baseIndex]['pruebaActiva'] = false;
      pruebas[baseIndex]['mostradaCelebracion'] = false;
    } else {
      pruebas.add({
        'prueba': prueba,
        'nombreBase': nombreBase,
        'superada': false,
        'votos': {},
        'notificada': false,
        'pruebaActiva': false,
        'mostradaCelebracion': false,
      });
    }

    await _firestore.collection('groups').doc(_groupDocId).update({'pruebas': pruebas});
    group.value = g.copyWith(pruebas: pruebas);
  }

  Future<void> actualizarPruebas(List<Map<String, dynamic>> nuevasPruebas) async {
    final g = group.value;
    if (g == null || _groupDocId == null) return;

    await _firestore.collection('groups').doc(_groupDocId).update({'pruebas': nuevasPruebas});
    group.value = g.copyWith(pruebas: nuevasPruebas);
  }

  Future<void> eliminarPrueba(int index) async {
    final g = group.value;
    if (g == null || _groupDocId == null) return;

    final pruebas = List<Map<String, dynamic>>.from(g.pruebas);
    if (index < 0 || index >= pruebas.length) return;

    pruebas.removeAt(index);

    await _firestore.collection('groups').doc(_groupDocId).update({'pruebas': pruebas});
    group.value = g.copyWith(pruebas: pruebas);
  }

  Future<void> borrarTodasLasPruebas() async {
    if (_groupDocId == null || group.value == null) return;

    await _firestore.collection('groups').doc(_groupDocId).update({'pruebas': []});
    group.value = group.value!.copyWith(pruebas: []);
  }

  Future<void> iniciarJuego() async {
    if (_groupDocId == null) return;
    await _firestore.collection('groups').doc(_groupDocId).update({'isStarted': true});
  }

  Future<void> iniciarPrueba(int baseIndex) async {
    final g = group.value;
    if (g == null || _groupDocId == null) return;

    final docRef = _firestore.collection('groups').doc(_groupDocId);
    final pruebas = List<Map<String, dynamic>>.from(g.pruebas);

    for (int i = 0; i < pruebas.length; i++) {
      pruebas[i]['pruebaActiva'] = i == baseIndex;
      pruebas[i]['notificada'] = false;
    }

    await docRef.update({'pruebas': pruebas});
    group.value = g.copyWith(pruebas: pruebas);

    // Si quien inicia no es el novio, notifica al novio
    if (!esNovio) {
      await loadGroup();
      await notificarAlNovio();
    }
  }

  Future<void> marcarPruebaSuperada(int index) async {
    if (_groupDocId == null || group.value == null) return;

    final pruebas = List<Map<String, dynamic>>.from(group.value!.pruebas);
    if (index < 0 || index >= pruebas.length) return;

    pruebas[index]['superada'] = true;

    await _firestore.collection('groups').doc(_groupDocId).update({'pruebas': pruebas});
    group.value = group.value!.copyWith(pruebas: pruebas);
  }

  Future<void> marcarCelebracionMostrada(int baseIndex) async {
    final g = group.value;
    if (g == null || _groupDocId == null) return;

    final docRef = _firestore.collection('groups').doc(_groupDocId);
    final pruebas = List<Map<String, dynamic>>.from(g.pruebas);

    if (baseIndex < pruebas.length) {
      pruebas[baseIndex]['mostradaCelebracion'] = true;
      await docRef.update({'pruebas': pruebas});
      group.value = g.copyWith(pruebas: pruebas);
    }
  }

  Future<void> votarPrueba({
    required int baseIndex,
    required String voto,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    final g = group.value;
    if (g == null || currentUid == null || _groupDocId == null) return;

    final pruebas = List<Map<String, dynamic>>.from(g.pruebas);
    if (baseIndex >= pruebas.length) return;

    final prueba = Map<String, dynamic>.from(pruebas[baseIndex]);
    final votos = Map<String, dynamic>.from(prueba['votos'] ?? {});
    votos[currentUid] = voto;

    prueba['votos'] = votos;
    pruebas[baseIndex] = prueba;

    await _firestore.collection('groups').doc(_groupDocId).update({'pruebas': pruebas});
    group.value = g.copyWith(pruebas: pruebas);
  }

  // -----------------------------------------------------------
  // TOKENS / NOTIFICACIONES
  // -----------------------------------------------------------
  Future<void> guardarTokenFCM() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    // Vincula el token al usuario (y lo desasocia de otros)
    await functions.httpsCallable('attachTokenToUser').call({
      'uid': currentUid,
      'token': token,
    });

    // Re-adjuntar si rota
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await functions.httpsCallable('attachTokenToUser').call({
        'uid': currentUid,
        'token': newToken,
      });
    });
  }

  Future<void> notificarAlNovio() async {
    final novioUid = group.value?.novioUid;
    if (novioUid == null || novioUid.isEmpty) {
      Get.snackbar('Sin novio configurado', 'El grupo no tiene novio asignado.');
      return;
    }

    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
    final callable = functions.httpsCallable('enviarNotificacionAlNovio');

    try {
      final result = await callable.call({'novioUid': novioUid});
      final data = (result.data is Map)
          ? Map<String, dynamic>.from(result.data)
          : <String, dynamic>{};

      if (data['success'] == true) {
        // ignore: avoid_print
        print('✅ Notificación enviada');
      } else if (data['reason'] == 'NO_TOKENS') {
        Get.snackbar('No hay novio logeado', 'Ningún dispositivo del novio tiene sesión activa.');
      } else {
        Get.snackbar('Aviso', 'No se pudo enviar la notificación.');
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error al notificar al novio: $e');
      Get.snackbar('Error', 'No se pudo enviar la notificación.');
    }
  }

  /// Llama a la CF y devuelve el docId real del grupo
Future<String> _joinGroupByCodeCF(String code) async {
  final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('joinGroupByCode');
  final res = await callable.call({'code': code});
  final data = (res.data as Map);
  return data['groupId'] as String; // <- docId
}

/// Punto de entrada público que usarás desde la UI
Future<void> joinGroupWithCode(String code) async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) throw Exception('No hay sesión');

  // 1) Me uno vía CF (valida, añade miembro y devuelve docId)
  final groupId = await _joinGroupByCodeCF(code);

  // 2) Guardo en el usuario el docId real y el código (para mostrar)
  await _firestore.collection('users').doc(uid).set({
    'groupRefId': groupId,
    'groupCode' : code,
  }, SetOptions(merge: true));

  // 3) Refresco el estado cargando el grupo directamente por docId
  final snap = await _firestore.collection('groups').doc(groupId).get();
  if (!snap.exists) throw Exception('El grupo no existe (id: $groupId)');
  group.value = GroupModel.fromMap(snap.data()!);
  _groupDocId = groupId;

  Get.snackbar("Éxito", "Te uniste al grupo correctamente.");
}

  /// Flujo completo: unirse por código, cargar doc del grupo y refrescar estado.
  Future<void> joinByCode(String code) async {
  final groupId = await _joinGroupByCodeCF(code.trim());

  // guarda docId real + el código introducido (para mostrarlo si quieres)
  await _firestore.collection('users').doc(uid).set({
    'groupRefId': groupId,
    'groupCode' : code.trim(),
  }, SetOptions(merge: true));

  final snap = await _firestore.collection('groups').doc(groupId).get();
  if (!snap.exists) throw Exception('El grupo no existe (id: $groupId)');

  group.value = GroupModel.fromMap(snap.data()!);
  update();
}

}
