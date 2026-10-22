import 'package:cloud_firestore/cloud_firestore.dart';

import '../backend.dart';
import '../onboarding/questions.dart';

/// `amore_questions/{id}`: the onboarding questions, edited in the admin
/// panel. Everyone signed in can read them; only admins can write (rules).
class QuestionRepository {
  CollectionReference<Map<String, dynamic>> get _col => Backend.questions;

  /// Every question (active or not) in order. Documents the app can't
  /// understand are skipped.
  Stream<List<ProfileQuestion>> watchAll() => _col
      .orderBy('order')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => ProfileQuestion.fromMap(d.id, d.data()))
            .whereType<ProfileQuestion>()
            .toList(),
      );

  Future<void> upsert(String id, Map<String, dynamic> data) =>
      _col.doc(id).set({...data, 'updatedAt': FieldValue.serverTimestamp()});

  /// Users' saved answers are not touched.
  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> reorder(List<String> idsInOrder) {
    final batch = Backend.db.batch();
    for (var i = 0; i < idsInOrder.length; i++) {
      batch.update(_col.doc(idsInOrder[i]), {'order': i * 10});
    }
    return batch.commit();
  }

  /// Copies [defaultQuestions] in, only when the collection is empty.
  /// Returns how many were written.
  Future<int> importDefaults() async {
    if ((await _col.limit(1).get()).docs.isNotEmpty) return 0;
    final batch = Backend.db.batch();
    for (var i = 0; i < defaultQuestions.length; i++) {
      final q = defaultQuestions[i];
      batch.set(_col.doc(q.id), {
        ...q.toMap(),
        'order': i * 10,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return defaultQuestions.length;
  }
}
