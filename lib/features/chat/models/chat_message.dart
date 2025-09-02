import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final String senderUid;
  final DateTime createdAt;
  final String type;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.createdAt,
    this.type = 'text',
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ChatMessage(
      id: doc.id,
      text: (data['text'] ?? '') as String,
      senderUid: data['senderUid'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      type: (data['type'] ?? 'text') as String,
    );
  }

  static Map<String, dynamic> createMap({
    required String uid,
    required String text,
  }) {
    return {
      'text': text,
      'senderUid': uid,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(), // <- regla lo exige
    };
  }
}
