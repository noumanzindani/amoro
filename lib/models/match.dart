import 'package:cloud_firestore/cloud_firestore.dart';

class Match {
  final String id;
  final List<String> users;
  final String? lastMessage;
  final String? lastSenderId;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final Map<String, int> unreadCount;
  final Map<String, DateTime> lastRead;
  final Map<String, DateTime> typing;

  const Match({
    required this.id,
    required this.users,
    this.lastMessage,
    this.lastSenderId,
    this.lastMessageAt,
    this.createdAt,
    this.unreadCount = const {},
    this.lastRead = const {},
    this.typing = const {},
  });

  factory Match.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Match(
      id: doc.id,
      users: List<String>.from(d['users'] ?? const []),
      lastMessage: d['lastMessage'] as String?,
      lastSenderId: d['lastSenderId'] as String?,
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      unreadCount: {
        for (final e in (d['unreadCount'] as Map? ?? const {}).entries)
          if (e.value is num) e.key as String: (e.value as num).toInt(),
      },
      lastRead: _timestamps(d['lastRead']),
      typing: _timestamps(d['typing']),
    );
  }

  static Map<String, DateTime> _timestamps(dynamic raw) => {
    for (final e in (raw as Map? ?? const {}).entries)
      if (e.value is Timestamp)
        e.key as String: (e.value as Timestamp).toDate(),
  };

  /// For sorting the match list: latest activity first. Pending server
  /// timestamps (null) count as now.
  DateTime get activityAt => lastMessageAt ?? createdAt ?? DateTime.now();

  String otherUser(String me) =>
      users.firstWhere((u) => u != me, orElse: () => me);

  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  /// True if [uid] typed within the last few seconds. The timestamp is
  /// refreshed while they type and cleared on send, so a stale value (app
  /// killed mid-typing) simply expires.
  bool isTyping(String uid, DateTime now) {
    final t = typing[uid];
    return t != null && now.difference(t).inSeconds.abs() < 6;
  }

  /// Both users compute the same id, so a match is one document no matter
  /// who swiped last.
  static String idFor(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }
}
