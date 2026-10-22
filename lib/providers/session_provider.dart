import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../onboarding/questions.dart';
import '../services/auth_service.dart';
import '../services/user_repository.dart';

enum SessionStatus { loading, signedOut, onboarding, ready }

/// Who is signed in and their live profile. The router listens to this to
/// decide which screen to show.
class SessionProvider extends ChangeNotifier {
  final AuthService auth;
  final UserRepository users;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _profileSub;
  StreamSubscription<Map<String, dynamic>>? _privateSub;

  User? _user;
  AppUser? _profile;
  Map<String, dynamic>? _private;
  bool _loading = true;

  SessionProvider(this.auth, this.users) {
    _authSub = auth.authStateChanges().listen(_onAuth);
  }

  User? get user => _user;
  AppUser? get profile => _profile;
  String? get uid => _user?.uid;

  /// The current answer to [q], from the public profile or the private doc.
  dynamic answerOf(ProfileQuestion q) {
    if (q.private) return _private?[q.id];
    return _profile?[q.id];
  }

  /// Every answer, public and private, keyed by question id.
  Map<String, dynamic> get allAnswers => {...?_profile?.data, ...?_private};

  SessionStatus get status {
    if (_loading) return SessionStatus.loading;
    if (_user == null) return SessionStatus.signedOut;
    if (_profile == null || _private == null) return SessionStatus.loading;
    return _profile!.onboardingComplete
        ? SessionStatus.ready
        : SessionStatus.onboarding;
  }

  Future<void> _onAuth(User? user) async {
    _user = user;
    _profile = null;
    _private = null;
    await _profileSub?.cancel();
    await _privateSub?.cancel();
    _profileSub = null;
    _privateSub = null;
    if (user == null) {
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      await users.ensureExists(user.uid);
    } catch (e) {
      debugPrint('ensureExists failed: $e');
    }
    _profileSub = users
        .watch(user.uid)
        .listen(
          (p) {
            _profile = p;
            _loading = false;
            notifyListeners();
          },
          onError: (Object e) {
            debugPrint('profile stream error: $e');
            _loading = false;
            notifyListeners();
          },
        );
    _privateSub = users
        .watchPrivate(user.uid)
        .listen(
          (data) {
            _private = data;
            notifyListeners();
          },
          onError: (Object e) {
            debugPrint('private profile stream error: $e');
            _private = const {}; // don't hold the app on the loading screen
            notifyListeners();
          },
        );
  }

  Future<void> updateProfile(Map<String, dynamic> fields) =>
      users.update(uid!, fields);

  /// Saves one answer where it belongs; [extra] fields always go on the
  /// public profile (e.g. onboarding progress) and are written last.
  Future<void> saveAnswer(
    ProfileQuestion q,
    dynamic value, {
    Map<String, dynamic> extra = const {},
  }) async {
    if (!q.private) return updateProfile({q.id: value, ...extra});
    await users.updatePrivate(uid!, {q.id: value});
    if (extra.isNotEmpty) await updateProfile(extra);
  }

  /// Runs while still signed in, e.g. to remove this device's push token.
  Future<void> Function()? beforeSignOut;

  Future<void> signOut() async {
    await beforeSignOut?.call();
    await auth.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _privateSub?.cancel();
    super.dispose();
  }
}
