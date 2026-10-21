import 'package:cloud_firestore/cloud_firestore.dart';

import '../backend.dart';

/// Blocks are stored as amore_blocks/{blocker}_{blocked}. Either side can
/// see the block (so both hide each other); only the blocker can remove it.
class BlockRepository {
  CollectionReference<Map<String, dynamic>> get _blocks => Backend.blocks;

  Stream<Set<String>> watchBlockedByMe(String me) => _blocks
      .where('blocker', isEqualTo: me)
      .snapshots()
      .map((s) => s.docs.map((d) => d['blocked'] as String).toSet());

  Stream<Set<String>> watchBlockingMe(String me) => _blocks
      .where('blocked', isEqualTo: me)
      .snapshots()
      .map((s) => s.docs.map((d) => d['blocker'] as String).toSet());

  Future<void> block(String me, String other) =>
      _blocks.doc('${me}_$other').set({
        'blocker': me,
        'blocked': other,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> unblock(String me, String other) =>
      _blocks.doc('${me}_$other').delete();

  Future<void> report({
    required String me,
    required String other,
    required String reason,
    String? details,
    String? matchId,
  }) => Backend.reports.add({
    'reporter': me,
    'reported': other,
    'reason': reason,
    if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    'matchId': ?matchId,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
