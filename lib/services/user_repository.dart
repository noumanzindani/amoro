import 'package:cloud_firestore/cloud_firestore.dart';

import '../backend.dart';
import '../models/app_user.dart';

class UserRepository {
  CollectionReference<Map<String, dynamic>> get _users => Backend.users;

  Stream<AppUser?> watch(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? AppUser.fromDoc(d) : null);

  Future<AppUser?> get(String uid) async {
    final d = await _users.doc(uid).get();
    return d.exists ? AppUser.fromDoc(d) : null;
  }

  /// Creates the empty profile document on first sign-in.
  Future<void> ensureExists(String uid) async {
    final ref = _users.doc(uid);
    if ((await ref.get()).exists) return;
    await ref.set({
      'onboardingStep': 0,
      'onboardingComplete': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(String uid, Map<String, dynamic> fields) => _users
      .doc(uid)
      .update({...fields, 'updatedAt': FieldValue.serverTimestamp()});

  /// Answers to private questions; readable only by the owner (rules).
  DocumentReference<Map<String, dynamic>> _private(String uid) =>
      _users.doc(uid).collection('private').doc('profile');

  Stream<Map<String, dynamic>> watchPrivate(String uid) =>
      _private(uid).snapshots().map((d) => d.data() ?? const {});

  Future<void> updatePrivate(String uid, Map<String, dynamic> fields) =>
      _private(uid).set(fields, SetOptions(merge: true));

  /// Profiles whose gender is one I'm interested in. Further filtering
  /// happens client-side in DeckProvider.
  /// Everyone who finished onboarding, newest first (Community tab).
  Future<List<AppUser>> community({int limit = 200}) async {
    final snap = await _users
        .where('onboardingComplete', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(AppUser.fromDoc).toList();
  }

  Future<List<AppUser>> getMany(Iterable<String> uids) async =>
      (await Future.wait(uids.map(get))).whereType<AppUser>().toList();

  Future<List<AppUser>> candidates(
    List<String> genders, {
    int limit = 100,
  }) async {
    if (genders.isEmpty) return const [];
    final snap = await _users
        .where('onboardingComplete', isEqualTo: true)
        .where('gender', whereIn: genders)
        .limit(limit)
        .get();
    return snap.docs.map(AppUser.fromDoc).toList();
  }
}
