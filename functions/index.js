// --------- IMPORTS ÚNICOS (no repetir) ----------
const { onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onObjectFinalized, onObjectDeleted } = require("firebase-functions/v2/storage");

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, FieldPath } = require("firebase-admin/firestore"); // <<< añadimos FieldPath
const { getMessaging } = require("firebase-admin/messaging");

// Inicializa Admin UNA sola vez
initializeApp();

// Instancias reutilizables
const db = getFirestore();
const messaging = getMessaging();


// ==================================================
// ============== NOTIFICACIONES ====================
// ==================================================

/**
 * Envía la notificación SOLO si el novio tiene tokens activos.
 * SIN fallback a fcmToken legado.
 */
exports.enviarNotificacionAlNovio = onCall({ region: "us-central1" }, async (request) => {
  const novioUid = request.data?.novioUid;
  if (!novioUid) throw new Error("novioUid es requerido.");

  const userRef = db.collection("users").doc(novioUid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) throw new Error("Usuario no encontrado.");
  const userData = userDoc.data() || {};

  const tokens = Array.isArray(userData.fcmTokens)
    ? [...new Set(userData.fcmTokens.filter(Boolean))]
    : [];

  if (tokens.length === 0) {
    console.log("ℹ️ No hay tokens del novio -> no se envía.");
    return { success: false, reason: "NO_TOKENS" };
  }

  const payload = {
    notification: {
      title: "🎉 Nueva prueba activada",
      body: "Tu grupo ha activado una nueva prueba. ¡Échale un ojo!",
    },
    data: { type: "prueba" },
    android: {
      priority: "high",
      notification: {
        channelId: "appdespedida_channel_v3",
        sound: "notificacion",
      },
    },
    apns: {
      payload: { aps: { sound: "notificacion" } },
    },
  };

  const res = await messaging.sendEachForMulticast({ tokens, ...payload });

  const invalid = [];
  res.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code || r.error?.errorInfo?.code || "";
      if (code.includes("registration-token-not-registered")) invalid.push(tokens[i]);
    }
  });
  if (invalid.length) {
    await userRef.update({ fcmTokens: FieldValue.arrayRemove(...invalid) });
  }

  console.log("✅ Notificación procesada", { novioUid, sent: res.successCount, fail: res.failureCount });
  return { success: true, sent: res.successCount };
});

/**
 * Adjunta token al usuario actual y lo despega de cualquier otro.
 * Además borra el campo legado fcmToken en TODOS los usuarios donde coincida.
 */
exports.attachTokenToUser = onCall({ region: "us-central1" }, async (request) => {
  const { uid, token } = request.data || {};
  if (!uid || !token) throw new Error("uid y token son requeridos.");

  const batch = db.batch();

  // quitar de otros users (array)
  const snapArr = await db.collection("users").where("fcmTokens", "array-contains", token).get();
  snapArr.forEach((doc) => {
    if (doc.id !== uid) batch.update(doc.ref, { fcmTokens: FieldValue.arrayRemove(token) });
  });

  // quitar legado fcmToken en todos los users donde coincida
  const snapLegacy = await db.collection("users").where("fcmToken", "==", token).get();
  snapLegacy.forEach((doc) => {
    batch.update(doc.ref, { fcmToken: FieldValue.delete() });
  });

  // añadir al user actual (y borrar legado en él)
  const userRef = db.collection("users").doc(uid);
  batch.set(userRef, { fcmTokens: FieldValue.arrayUnion(token), fcmToken: FieldValue.delete() }, { merge: true });

  await batch.commit();
  return { success: true };
});

/**
 * Logout: quita el token del array y borra fcmToken legado si existiera.
 */
exports.detachTokenFromUser = onCall({ region: "us-central1" }, async (request) => {
  const { uid, token } = request.data || {};
  if (!uid || !token) throw new Error("uid y token son requeridos.");

  const userRef = db.collection("users").doc(uid);
  await userRef.update({
    fcmTokens: FieldValue.arrayRemove(token),
    fcmToken: FieldValue.delete(),
  });

  return { success: true };
});


// ==================================================
// ======= CREAR stats/storage AL CREAR UN GROUP =====
// ==================================================

/**
 * Crea automáticamente groups/{groupId}/stats/storage con cuota por defecto
 * cuando se crea un nuevo grupo.
 */
exports.onGroupCreateInitStats = onDocumentCreated(
  { document: "groups/{groupId}", region: "us-central1" },
  async (event) => {
    const groupId = event.params.groupId;

    const statsRef = db.doc(`groups/${groupId}/stats/storage`);
    const appConfigRef = db.doc("app/config");

    // Lee la cuota por defecto (si existe app/config), si no, 2GB
    const appCfg = await appConfigRef.get().catch(() => null);
    const defaultQuota = appCfg?.exists && appCfg.get("storageBytesQuotaDefault")
      ? Number(appCfg.get("storageBytesQuotaDefault"))
      : 2147483648; // 2 GB

    await statsRef.set({
      storageBytesUsed: 0,
      storageBytesQuota: defaultQuota,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
);


// ==================================================
// =========== CONTADOR DE BYTES EN STORAGE =========
// ==================================================

// helper: obtiene groupId desde "uploads/groups/<groupId>/bases/..."
function parseGroupId(objectName) {
  if (!objectName) return null;
  const parts = objectName.split("/");
  const idx = parts.indexOf("groups");
  if (idx === -1 || idx + 1 >= parts.length) return null;
  return parts[idx + 1];
}

exports.onUploadFinalize = onObjectFinalized({ region: "us-central1" }, async (event) => {
  const object = event.data;
  const name = object.name;
  const size = Number(object.size || 0);
  if (!name || !size) return;
  if (!name.startsWith("uploads/")) return;

  const groupId = parseGroupId(name);
  if (!groupId) return;

  const statsRef = db.doc(`groups/${groupId}/stats/storage`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(statsRef);
    const used = snap.exists && snap.get("storageBytesUsed") ? Number(snap.get("storageBytesUsed")) : 0;
    const newUsed = used + size;
    tx.set(statsRef, { storageBytesUsed: newUsed }, { merge: true });
  });
});

exports.onUploadDelete = onObjectDeleted({ region: "us-central1" }, async (event) => {
  const object = event.data;
  const name = object.name;
  const size = Number(object.size || 0);
  if (!name || !size) return;
  if (!name.startsWith("uploads/")) return;

  const groupId = parseGroupId(name);
  if (!groupId) return;

  const statsRef = db.doc(`groups/${groupId}/stats/storage`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(statsRef);
    const used = snap.exists && snap.get("storageBytesUsed") ? Number(snap.get("storageBytesUsed")) : 0;
    const newUsed = Math.max(0, used - size);
    tx.set(statsRef, { storageBytesUsed: newUsed }, { merge: true });
  });
});


// ==================================================
// =========== NOTIFICACIONES DE CHAT ===============
// ==================================================

exports.onChatMessageCreate = onDocumentCreated(
  { document: "groups/{groupId}/chat/{messageId}", region: "us-central1" },
  async (event) => {
    const { groupId } = event.params;
    const data = event.data?.data();
    if (!data) return;

    const text = data.text || "";
    const senderId = data.senderId;

    // 1. Obtener el grupo y sus miembros
    const groupSnap = await db.collection("groups").doc(groupId).get();
    if (!groupSnap.exists) return;
    const miembros = groupSnap.get("miembros") || [];

    // 2. Excluir al remitente
    const destinatarios = miembros.filter((uid) => uid !== senderId);
    if (destinatarios.length === 0) return;

    // 3. Buscar tokens de esos destinatarios (en lotes de 10 por query)
    const tokens = [];
    const chunk = (arr, size) => arr.reduce((all, one, i) => {
      const ch = Math.floor(i / size);
      all[ch] = [].concat((all[ch] || []), one);
      return all;
    }, []);
    const batches = chunk(destinatarios, 10);
    /// si no funciona cambiar justo lo de debajo por lo que esta comentado
    /*for (const batch of batches) {
      const snap = await db.collection("users")
        .where(FieldPath.documentId(), "in", batch) // <<< corregido: usamos FieldPath importado
        .get();
      snap.forEach((doc) => {
        const userData = doc.data();
        const fcmTokens = userData.fcmTokens || [];
        if (Array.isArray(fcmTokens)) {
          tokens.push(...fcmTokens.filter(Boolean));
        }
      });
    }*/
   for (const batch of batches) {
    const snap = await db.collection("users")
      .where(FieldPath.documentId(), "in", batch)
      .get();

    snap.forEach((doc) => {
      const userData = doc.data() || {};

      // 👇 Aseguramos comparar el rol SOLO si corresponde al mismo grupo
      const sameGroup =
        String(userData.groupId || userData.groupRefId || "") === String(groupId);
      const role = (userData.role || "").toLowerCase();

      // ❌ EXCLUIR novio del chat (pero solo si es novio de ESTE grupo)
      if (sameGroup && role === "novio") return;

      const fcmTokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];
      tokens.push(...fcmTokens.filter(Boolean));
    });
  }


    if (!tokens.length) return;

    // CHAT (usar sonido por defecto del dispositivo)
    const payload = {
      notification: {
        title: "Nuevo mensaje en el chat",
        body: text.length > 80 ? text.slice(0, 80) + "…" : text,
      },
      android: {
        priority: "high",
        // 👇 sin channelId y sin sound -> usa el sonido por defecto
      },
      apns: { payload: { aps: { /* sin sound para usar default */ } } },
      data: { type: "chat" },   // <- para diferenciar en la app
    };

    const res = await messaging.sendEachForMulticast({ tokens, ...payload });

    // 5. Limpieza de tokens inválidos
    const invalid = [];
    res.responses.forEach((r, i) => {
      if (!r.success) {
        const code = r.error?.code || "";
        if (code.includes("registration-token-not-registered")) invalid.push(tokens[i]);
      }
    });
    if (invalid.length) {
      // elimina los tokens inválidos de TODOS los users
      const batch = db.batch();
      const snaps = await db.collection("users").where("fcmTokens", "array-contains-any", invalid).get();
      snaps.forEach((doc) => {
        batch.update(doc.ref, { fcmTokens: FieldValue.arrayRemove(...invalid) });
      });
      await batch.commit();
    }

    console.log("✅ Notificación de chat enviada", { groupId, sent: res.successCount });
  }
);


// ==================================================
// =============== UNIRSE POR CÓDIGO =================
// ==================================================
// Permite a un usuario autenticado unirse a un grupo si conoce el "codigo"
exports.joinGroupByCode = onCall({ region: "us-central1" }, async (request) => { // <<< NUEVO
  const uid = request.auth?.uid;
  const code = request.data?.code;

  if (!uid) throw new Error("UNAUTHENTICATED");
  if (!code) throw new Error("Falta 'code'");

  // Buscar grupo por código
  const snap = await db.collection("groups").where("codigo", "==", code).limit(1).get();
  if (snap.empty) throw new Error("Código no válido");

  const groupRef = snap.docs[0].ref;
  const groupId = groupRef.id;

  // Añadir al usuario a miembros (idempotente)
  await groupRef.update({ miembros: FieldValue.arrayUnion(uid) });

  return { groupId };
});
