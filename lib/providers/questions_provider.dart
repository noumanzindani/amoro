import 'dart:async';

import 'package:flutter/foundation.dart';

import '../onboarding/questions.dart';
import '../services/question_repository.dart';
import 'session_provider.dart';

/// The questions to ask: the admin-managed ones when there are any,
/// otherwise the built-in [defaultQuestions]. Inactive ones are left out.
List<ProfileQuestion> effectiveQuestions(List<ProfileQuestion>? remote) {
  if (remote == null || remote.isEmpty) return defaultQuestions;
  return remote.where((q) => q.active).toList();
}

bool _answered(Object? v) =>
    v != null &&
    !(v is String && v.trim().isEmpty) &&
    !(v is List && v.isEmpty);

/// Where onboarding continues: the saved question if it still exists and
/// applies, else the first applicable unanswered one, else the last
/// applicable one. Null when no question applies.
String? resumeQuestionId({
  required List<ProfileQuestion> questions,
  required Map<String, dynamic> answers,
  String? onboardingAt,
}) {
  final applicable = questions.where((q) => q.appliesTo(answers)).toList();
  if (applicable.isEmpty) return null;
  if (applicable.any((q) => q.id == onboardingAt)) return onboardingAt;
  for (final q in applicable) {
    if (!_answered(answers[q.id])) return q.id;
  }
  return applicable.last.id;
}

/// Live onboarding questions for the signed-in user (rules require sign-in).
class QuestionsProvider extends ChangeNotifier {
  final QuestionRepository repo;
  final SessionProvider session;

  StreamSubscription<List<ProfileQuestion>>? _sub;
  String? _uid;
  List<ProfileQuestion>? _remote;
  bool _loaded = false;

  QuestionsProvider(this.repo, this.session) {
    session.addListener(_onSession);
    _onSession();
  }

  List<ProfileQuestion> get questions => effectiveQuestions(_remote);

  /// True once the first snapshot (or an error) arrived for this user.
  bool get loaded => _loaded;

  ProfileQuestion? byId(String id) {
    for (final q in questions) {
      if (q.id == id) return q;
    }
    return null;
  }

  void _onSession() {
    final uid = session.uid;
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    _remote = null;
    _loaded = false;
    if (uid != null) {
      _sub = repo.watchAll().listen(
        (qs) {
          _remote = qs;
          _loaded = true;
          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('questions stream error: $e'); // use built-in questions
          _loaded = true;
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    _sub?.cancel();
    super.dispose();
  }
}
