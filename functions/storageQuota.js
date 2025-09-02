const functions = require("firebase-functions/v2/storage");
const { getFirestore } = require("firebase-admin/firestore");
const db = getFirestore();

function parseGroupId(objectName) {
  if (!objectName) return null;
  const parts = objectName.split("/");
  const idx = parts.indexOf("groups");
  if (idx === -1 || idx + 1 >= parts.length) return null;
  return parts[idx + 1];
}

exports.onUploadFinalize = functions.onObjectFinalized({ region: "us-central1" }, async (event) => {
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

exports.onUploadDelete = functions.onObjectDeleted({ region: "us-central1" }, async (event) => {
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
