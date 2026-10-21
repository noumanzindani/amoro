import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../backend.dart';
import '../models/match.dart';
import '../models/message.dart';

class ChatRepository {
  DocumentReference<Map<String, dynamic>> _match(String matchId) =>
      Backend.matches.doc(matchId);

  /// Opens (creating if needed) a one-on-one chat started from Community.
  /// Shares the match document/id scheme, so an existing match is reused.
  Future<String> openDirect(String me, String other) async {
    final id = Match.idFor(me, other);
    final ref = _match(id);
    if (!(await ref.get()).exists) {
      await ref.set({
        'users': [me, other]..sort(),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'community',
        'startedBy': me,
      });
    }
    return id;
  }

  Stream<Match> watchMatch(String matchId) =>
      _match(matchId).snapshots().map(Match.fromDoc);

  Stream<List<Message>> watchMessages(String matchId) => _match(matchId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Message.fromDoc).toList());

  Future<void> sendText(Match match, String me, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value();
    return _write(match, me, _match(match.id).collection('messages').doc(), {
      'type': MessageType.text.name,
      'text': trimmed,
    }, preview: trimmed);
  }

  /// Uploads [file] then posts the message. Media is addressed by Storage
  /// path only, so every read goes through the Storage security rules.
  Future<void> sendMedia(
    Match match,
    String me,
    File file, {
    required MessageType type,
    required bool viewOnce,
  }) async {
    final doc = _match(match.id).collection('messages').doc();
    final isVideo = type == MessageType.video;
    final path = 'amore_chats/${match.id}/${doc.id}.${isVideo ? 'mp4' : 'jpg'}';
    await Backend.storage
        .ref(path)
        .putFile(
          file,
          SettableMetadata(contentType: isVideo ? 'video/mp4' : 'image/jpeg'),
        );
    await _write(match, me, doc, {
      'type': type.name,
      'mediaPath': path,
      'viewOnce': viewOnce,
    }, preview: Message.previewFor(type, viewOnce: viewOnce));
  }

  Future<void> _write(
    Match match,
    String me,
    DocumentReference<Map<String, dynamic>> doc,
    Map<String, dynamic> data, {
    required String preview,
  }) {
    final other = match.otherUser(me);
    final batch = Backend.db.batch()
      ..set(doc, {
        ...data,
        'senderId': me,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(_match(match.id), {
        'lastMessage': preview,
        'lastSenderId': me,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$other': FieldValue.increment(1),
        'typing.$me': FieldValue.delete(),
      });
    return batch.commit();
  }

  Future<void> markRead(String matchId, String me) => _match(matchId).update({
    'unreadCount.$me': 0,
    'lastRead.$me': FieldValue.serverTimestamp(),
  });

  Future<void> setTyping(String matchId, String me, bool typing) =>
      _match(matchId).update({
        'typing.$me': typing
            ? FieldValue.serverTimestamp()
            : FieldValue.delete(),
      });

  /// Downloads media to a temp file through the authenticated SDK.
  /// Regular media is cached by path; view-once media never is.
  Future<File> downloadMedia(Message m) async {
    final name = m.mediaPath!.replaceAll('/', '_');
    final file = File(
      '${Directory.systemTemp.path}/${m.viewOnce ? 'once_' : ''}$name',
    );
    if (!m.viewOnce && await file.exists() && await file.length() > 0) {
      return file;
    }
    await Backend.storage.ref(m.mediaPath!).writeToFile(file);
    return file;
  }

  /// Called when the receiver closes a view-once photo/video: marks it opened
  /// and deletes the file from Storage so it can't be fetched again.
  Future<void> consumeViewOnce(
    String matchId,
    Message m,
    File? localCopy,
  ) async {
    await _match(matchId).collection('messages').doc(m.id).update({
      'openedAt': FieldValue.serverTimestamp(),
    });
    try {
      await Backend.storage.ref(m.mediaPath!).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    } finally {
      if (localCopy != null && await localCopy.exists()) {
        await localCopy.delete();
      }
    }
  }
}
