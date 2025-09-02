import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatController extends GetxController {
  ChatController({required this.groupId});
  final String groupId;

  final _service = ChatService();

  final messages = <ChatMessage>[].obs; // ordenados desc (más nuevos primero)
  final isSending = false.obs;
  final text = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _service.streamLatest(groupId).listen((list) {
      messages.value = list;
    });
  }

  Future<void> send() async {
    final content = text.value.trim();
    if (content.isEmpty) return;
    isSending.value = true;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _service.sendText(groupId: groupId, uid: uid, text: content);
      text.value = '';
    } finally {
      isSending.value = false;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await _service.deleteMessage(groupId: groupId, messageId: messageId);
  }
}
