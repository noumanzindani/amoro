import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, photo, video }

class Message {
  final String id;
  final String senderId;
  final MessageType type;
  final String text;

  /// Storage path (never a download URL — those bypass security rules).
  final String? mediaPath;
  final bool viewOnce;
  final DateTime? openedAt;
  final DateTime? createdAt;

  const Message({
    required this.id,
    required this.senderId,
    this.type = MessageType.text,
    this.text = '',
    this.mediaPath,
    this.viewOnce = false,
    this.openedAt,
    this.createdAt,
  });

  bool get isMedia => type != MessageType.text;
  bool get opened => openedAt != null;

  factory Message.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Message(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      type: MessageType.values.asNameMap()[d['type']] ?? MessageType.text,
      text: d['text'] as String? ?? '',
      mediaPath: d['mediaPath'] as String?,
      viewOnce: d['viewOnce'] == true,
      openedAt: (d['openedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Text used for the match list preview.
  static String previewFor(
    MessageType type, {
    required bool viewOnce,
    String text = '',
  }) {
    switch (type) {
      case MessageType.text:
        return text;
      case MessageType.photo:
        return viewOnce ? '🔥 View-once photo' : '📷 Photo';
      case MessageType.video:
        return viewOnce ? '🔥 View-once video' : '🎥 Video';
    }
  }
}
