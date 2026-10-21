import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/swipe_repository.dart';
import '../services/user_repository.dart';

/// The stack of profiles on the Discover tab.
class DeckProvider extends ChangeNotifier {
  final UserRepository users;
  final SwipeRepository swipes;

  DeckProvider(this.users, this.swipes);

  List<AppUser> _cards = [];
  bool _loading = false;
  String? _error;

  List<AppUser> get cards => _cards;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load(AppUser me, {Set<String> hidden = const {}}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        users.candidates(me.interestedIn),
        swipes.swipedIds(me.uid),
      ]);
      final candidates = results[0] as List<AppUser>;
      final swiped = results[1] as Set<String>;
      _cards =
          candidates
              .where((c) => c.uid != me.uid && !hidden.contains(c.uid))
              .where((c) => !swiped.contains(c.uid))
              // Mutual interest: they must also want to meet someone of my gender.
              .where(
                (c) => me.gender != null && c.interestedIn.contains(me.gender),
              )
              .where((c) => c.photoUrls.isNotEmpty)
              .toList()
            ..shuffle();
    } catch (e) {
      debugPrint('deck load failed: $e');
      _error = 'Couldn\'t load profiles. Pull to retry.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> like(String me, AppUser other) => swipes.like(me, other.uid);

  Future<void> pass(String me, AppUser other) => swipes.pass(me, other.uid);
}
