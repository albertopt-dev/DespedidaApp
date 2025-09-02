import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pantalla de chat de grupo (estilo WhatsApp)
/// Espera en los argumentos un 'groupId' que puede ser:
///  - el docId REAL del grupo, o
///  - el código del grupo (campo 'codigo') -> lo resolvemos.
class ChatAmigosScreen extends StatelessWidget {
  final String groupId;

  // Quita const para permitir parámetros
  const ChatAmigosScreen({super.key, required this.groupId});

  @override
Widget build(BuildContext context) {

  return Scaffold(
      backgroundColor: const Color(0xFFFFFDE7),  // fondo cálido en claro
      appBar: AppBar(
      title: const Text('Chat del grupo'),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.blueAccent),
      backgroundColor: const Color.fromARGB(255, 15, 15, 15),
      foregroundColor: Colors.white, // el texto e iconos en blanco para que contraste
      elevation: 0,
    ),
      body: _ChatBody(groupId: groupId),
    );
  }

}

class _ChatBody extends StatefulWidget {
  final String groupId;

  const _ChatBody({required this.groupId});

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _groupDocId; // docId real de groups/*
  bool _resolving = true;
  bool _sending = false;

  String? _myName;

  // cache simple de nombres para no pedirlos cada mensaje
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _resolveGroupId();
  }

  Future<String> _getMyName() async {
    if (_myName != null) return _myName!;
    final uid = _auth.currentUser!.uid;
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data() ?? {};
    // En tu BD el campo es "name"
    _myName = (data['name'] ?? data['displayName'] ?? data['email'] ?? 'Anónimo').toString();
    return _myName!;
  }

  Future<void> _resolveGroupId() async {
    // 1º usa el que llega por constructor
    String raw = (widget.groupId).toString().trim();

    // fallback a Get.arguments si viene vacío
    if (raw.isEmpty) {
      final args = Get.arguments as Map<String, dynamic>? ?? {};
      raw = (args['groupId'] ?? '').toString().trim();
    }

    if (raw.isEmpty) {
      Get.snackbar('Chat', 'Falta groupId para abrir el chat');
      setState(() => _resolving = false);
      return;
    }

    try {
      final maybe = await _db.collection('groups').doc(raw).get();
      if (maybe.exists) {
        _groupDocId = maybe.id;
      } else {
        final q = await _db.collection('groups').where('codigo', isEqualTo: raw).limit(1).get();
        if (q.docs.isEmpty) {
          Get.snackbar('Chat', 'No encontré el grupo ($raw).');
        } else {
          _groupDocId = q.docs.first.id;
        }
      }
    } catch (e) {
      Get.snackbar('Chat', 'Error resolviendo grupo: $e');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }


  Stream<QuerySnapshot<Map<String, dynamic>>>? get _chatStream {
    if (_groupDocId == null) return null;
    return _db
        .collection('groups')
        .doc(_groupDocId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(300)
        .snapshots();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending || _groupDocId == null) return;

    setState(() => _sending = true);
    try {
      // lee el nombre del usuario actual desde users/{uid}
      final uid = _auth.currentUser!.uid;
      final name = await _getMyName();

      await _db
          .collection('groups')
          .doc(_groupDocId)
          .collection('chat')
          .add({
        'text': text,
        'senderId': uid,
        'senderName': name,          // 👈 guarda el nombre en el mensaje
        'timestamp': FieldValue.serverTimestamp(),
      });

      _textCtrl.clear();
      _scrollToBottomSoon();
    } catch (e) {
      Get.snackbar('Chat', 'Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }


  void _scrollToBottomSoon() {
    // lista está en reverse:true, así que “abajo” es offset 0.0
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<String> _displayName(String uid) async {
    if (_nameCache.containsKey(uid)) return _nameCache[uid]!;
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final name = (data['displayName'] ?? data['name'] ?? data['email'] ?? uid).toString(); // 👈 añade 'name'
      _nameCache[uid] = name;
      return name;
    } catch (_) {
      return uid;
    }
  }


  Future<void> _deleteMessage(String messageId) async {
    if (_groupDocId == null) return;
    await _db
        .collection('groups')
        .doc(_groupDocId)
        .collection('chat')
        .doc(messageId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid;

    if (_resolving) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chatStream == null) {
      return const Center(child: Text('No hay grupo para chatear'));
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _chatStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Sin mensajes aún'));
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final m = docs[i];
                  final data = m.data();
                  final text = (data['text'] ?? '').toString();
                  final sender = (data['senderId'] ?? '').toString();
                  final ts = data['timestamp'];
                  final isMine = sender == myUid;

                  final nameFromMsg = (data['senderName'] ?? '').toString();
                  if (nameFromMsg.isNotEmpty) {
                    return _MessageBubble(
                      id: m.id,
                      text: text,
                      name: nameFromMsg,
                      isMine: isMine,
                      timeLabel: _fmtTime(ts),
                      onLongPress: isMine ? () => _showDelete(ctx, () => _deleteMessage(m.id)) : null,
                    );
                  }
                  return FutureBuilder<String>(
                    future: _displayName(sender),
                    builder: (ctx, snap) {
                      final name = snap.data ?? '...';
                      return _MessageBubble(
                        id: m.id,
                        text: text,
                        name: name,
                        isMine: isMine,
                        timeLabel: _fmtTime(ts),
                        onLongPress: isMine ? () => _showDelete(ctx, () => _deleteMessage(m.id)) : null,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        _InputBar(
          controller: _textCtrl,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }


  void _showDelete(BuildContext context, VoidCallback onDelete) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar mensaje'),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(dynamic ts) {
    try {
      final dt = (ts is Timestamp) ? ts.toDate() : DateTime.now();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

/// Burbuja de mensaje
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.id,
    required this.text,
    required this.name,
    required this.isMine,
    required this.timeLabel,
    this.onLongPress,
  });

  final String id;
  final String text;
  final String name;
  final bool isMine;
  final String timeLabel;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isMine
        ? const Color.fromARGB(255, 183, 252, 131) // verde claro estilo WhatsApp
        : (isDark ? const Color.fromARGB(255, 119, 216, 255) : Colors.white); // Quita el ! después del color

    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
    );

    final nameStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.black,
    );
    final textStyle = TextStyle(
      fontSize: 16,
      color: Colors.black,
    );
    final timeStyle = TextStyle(
      fontSize: 12,
      color: Colors.black45,
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 6, top: 6),
              child: Text(name, style: nameStyle),
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))
              ],
            ),
            child: Text(text, style: textStyle),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(timeLabel, style: timeStyle),
          ),
        ],
      ),
    );
  }
}


/// Barra de entrada inferior
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 232, 255, 179), //color barra mensajes
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(color: Colors.black),
                cursorColor: Colors.black,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje…',
                  hintStyle: const TextStyle(color: Colors.black54),
                  filled: true,
                  fillColor: Colors.white, // fondo blanco para escribir
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                  // Borde normal
                  enabledBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide(
                      color: const Color.fromARGB(255, 255, 65, 65), // 👈 color del borde cuando no está enfocado
                      width: 1,
                    ),
                  ),

                  // Borde cuando el campo está enfocado
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide(
                      color: Color.fromARGB(255, 67, 253, 98), // 👈 verde oliva suave al enfocar
                      width: 2,
                    ),
                  ),
                ),

                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.send),
                    color: const Color.fromARGB(255, 8, 2, 2),
                    onPressed: onSend,
                  ),
          ],
        ),
      ),
    );
  }
}
