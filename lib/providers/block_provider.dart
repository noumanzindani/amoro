import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/block_repository.dart';
import 'session_provider.dart';

/// Live set of people hidden from me: those I blocked and those who blocked
/// me. Every list of users (Discover, Community, Chats) filters through it.
class BlockProvider extends ChangeNotifier {
  final BlockRepository repo;
  final SessionProvider session;

  BlockProvider(this.repo, this.session) {
    session.addListener(_onSession);
    _onSession();
  }

  String? _uid;
  StreamSubscription<Set<String>>? _mine;
  StreamSubscription<Set<String>>? _theirs;
  Set<String> _blockedByMe = {};
  Set<String> _blockingMe = {};

  Set<String> get blockedByMe => _blockedByMe;
  Set<String> get hiddenIds => {..._blockedByMe, ..._blockingMe};
  bool isHidden(String uid) =>
      _blockedByMe.contains(uid) || _blockingMe.contains(uid);
  bool iBlocked(String uid) => _blockedByMe.contains(uid);

  void _onSession() {
    final uid = session.uid;
    if (uid == _uid) return;
    _uid = uid;
    _mine?.cancel();
    _theirs?.cancel();
    _blockedByMe = {};
    _blockingMe = {};
    notifyListeners();
    if (uid == null) return;
    _mine = repo.watchBlockedByMe(uid).listen((s) {
      _blockedByMe = s;
      notifyListeners();
    }, onError: (Object e) => debugPrint('blocks stream: $e'));
    _theirs = repo.watchBlockingMe(uid).listen((s) {
      _blockingMe = s;
      notifyListeners();
    }, onError: (Object e) => debugPrint('blocked-by stream: $e'));
  }

  Future<void> block(String other) => repo.block(_uid!, other);
  Future<void> unblock(String other) => repo.unblock(_uid!, other);

  @override
  void dispose() {
    session.removeListener(_onSession);
    _mine?.cancel();
    _theirs?.cancel();
    super.dispose();
  }
}
