import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coll(String groupId) =>
      _db.collection('groups').doc(groupId).collection('chat_amigos');

  Query<Map<String, dynamic>> _baseQuery(String groupId) =>
      _coll(groupId).orderBy('createdAt', descending: true);

  // stream en tiempo real de los últimos N
  Stream<List<ChatMessage>> streamLatest(String groupId, {int limit = 50}) {
    return _baseQuery(groupId).limit(limit).snapshots().map((snap) {
      return snap.docs
          .where((d) => d.data()['createdAt'] != null) // ignora pending writes
          .map((d) => ChatMessage.fromDoc(d))
          .toList();
    });
  }

  Future<void> sendText({
    required String groupId,
    required String uid,
    required String text,
  }) async {
    await _coll(groupId).add(ChatMessage.createMap(uid: uid, text: text));
  }

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _coll(groupId).doc(messageId).delete();
  }
}
