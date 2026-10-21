import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
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

  User? _user;
  AppUser? _profile;
  bool _loading = true;

  SessionProvider(this.auth, this.users) {
    _authSub = auth.authStateChanges().listen(_onAuth);
  }

  User? get user => _user;
  AppUser? get profile => _profile;
  String? get uid => _user?.uid;

  SessionStatus get status {
    if (_loading) return SessionStatus.loading;
    if (_user == null) return SessionStatus.signedOut;
    if (_profile == null) return SessionStatus.loading;
    return _profile!.onboardingComplete
        ? SessionStatus.ready
        : SessionStatus.onboarding;
  }

  Future<void> _onAuth(User? user) async {
    _user = user;
    _profile = null;
    await _profileSub?.cancel();
    _profileSub = null;
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
  }

  Future<void> updateProfile(Map<String, dynamic> fields) =>
      users.update(uid!, fields);

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
    super.dispose();
  }
}
