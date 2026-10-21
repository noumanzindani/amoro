import 'dart:async';

// Uses FCM registration tokens (getToken/onTokenRefresh/deleteToken), which
// firebase_messaging 17 deprecates in favour of FID direct-send. Tokens are
// still what firebase-admin's sendEachForMulticast targets; migrate together
// with functions/index.js when moving to register()/onRegistered.
// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../backend.dart';
import '../providers/session_provider.dart';
import '../theme.dart';

/// Registers this device for push (token stored on amore_users/{uid}.fcmTokens),
/// opens the right chat when a notification is tapped, and shows an in-app
/// banner for pushes that arrive while the app is open.
class PushService {
  final GoRouter router;
  final SessionProvider session;
  final GlobalKey<ScaffoldMessengerState> messenger;

  PushService({
    required this.router,
    required this.session,
    required this.messenger,
  });

  final _fcm = FirebaseMessaging.instance;
  final _subs = <StreamSubscription<dynamic>>[];
  String? _registeredUid;
  String? _pendingMatchId;

  Future<void> start() async {
    session.addListener(_onSession);
    _subs
      ..add(FirebaseMessaging.onMessage.listen(_onForeground))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_onTap))
      ..add(_fcm.onTokenRefresh.listen((t) => _saveToken(t)));
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onTap(initial);
    _onSession();
  }

  void _onSession() {
    final uid = session.uid;
    if (session.status != SessionStatus.ready || uid == null) return;
    if (_registeredUid != uid) {
      _registeredUid = uid;
      _register();
    }
    final pending = _pendingMatchId;
    if (pending != null) {
      _pendingMatchId = null;
      router.push('/chat/$pending');
    }
  }

  Future<void> _register() async {
    try {
      final settings = await _fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('push register failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final uid = session.uid;
    if (uid == null) return;
    await Backend.users.doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Call before signing out so this phone stops getting that user's pushes.
  Future<void> unregister() async {
    final uid = session.uid;
    _registeredUid = null;
    try {
      final token = await _fcm.getToken();
      if (uid != null && token != null) {
        await Backend.users.doc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('push unregister failed: $e');
    }
  }

  void _onTap(RemoteMessage m) {
    final matchId = m.data['matchId'] as String?;
    if (matchId == null) return;
    if (session.status == SessionStatus.ready) {
      router.push('/chat/$matchId');
    } else {
      _pendingMatchId = matchId; // opened from a cold start; go once signed in
    }
  }

  void _onForeground(RemoteMessage m) {
    final matchId = m.data['matchId'] as String?;
    final n = m.notification;
    if (matchId == null || n == null) return;
    final here = router.routerDelegate.currentConfiguration.uri.path;
    // Already looking at it: the chat itself / the match dialog shows it.
    if (here == '/chat/$matchId') return;
    if (m.data['type'] == 'match' && here == '/discover') return;

    messenger.currentState?.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        duration: const Duration(seconds: 4),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              n.title ?? 'Amore',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (n.body != null)
              Text(
                n.body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              ),
          ],
        ),
        action: SnackBarAction(
          label: 'Open',
          textColor: AppColors.rose,
          onPressed: () => router.push('/chat/$matchId'),
        ),
      ),
    );
  }

  void dispose() {
    session.removeListener(_onSession);
    for (final s in _subs) {
      s.cancel();
    }
  }
}
