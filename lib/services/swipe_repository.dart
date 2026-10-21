import 'package:cloud_firestore/cloud_firestore.dart';

import '../backend.dart';
import '../models/match.dart';

class SwipeRepository {
  CollectionReference<Map<String, dynamic>> get _swipes => Backend.swipes;
  CollectionReference<Map<String, dynamic>> get _matches => Backend.matches;

  /// Ids of everyone [me] has already liked or passed.
  Future<Set<String>> swipedIds(String me) async {
    final snap = await _swipes.where('from', isEqualTo: me).get();
    return snap.docs.map((d) => d['to'] as String).toSet();
  }

  Future<void> pass(String me, String other) =>
      _record(me, other, liked: false);

  /// Records a like. Returns true if it created a match.
  Future<bool> like(String me, String other) async {
    await _record(me, other, liked: true);

    final theirs = await _swipes.doc('${other}_$me').get();
    if (!theirs.exists || theirs['liked'] != true) return false;

    final ref = _matches.doc(Match.idFor(me, other));
    // Both people can hit this at once; the second one finds it already there.
    if ((await ref.get()).exists) return true;
    await ref.set({
      'users': [me, other]..sort(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageAt': null,
    });
    return true;
  }

  Future<void> _record(String me, String other, {required bool liked}) =>
      _swipes.doc('${me}_$other').set({
        'from': me,
        'to': other,
        'liked': liked,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Match>> watchMatches(String me) => _matches
      .where('users', arrayContains: me)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(Match.fromDoc).toList()
              ..sort((a, b) => b.activityAt.compareTo(a.activityAt)),
      );
}
