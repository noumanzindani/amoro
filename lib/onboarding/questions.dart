import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

enum QuestionType {
  text,
  longText,
  date,
  height,
  scale,
  single,
  multi,
  photos,
  video,
}

enum QuestionGroup {
  basics('Basics'),
  intentions('Looking for'),
  interests('Interests'),
  lifestyle('Lifestyle'),
  personal('Private · only you'),
  about('About me');

  final String label;
  const QuestionGroup(this.label);
}

class QuestionOption {
  final String value;
  final String label;
  final String? emoji;

  /// Picture answers: an image the user taps instead of a chip.
  final String? imageUrl;
  const QuestionOption(this.value, this.label, [this.emoji, this.imageUrl]);

  String get display => emoji == null ? label : '$emoji $label';

  Map<String, dynamic> toMap() => {
    'value': value,
    'label': label,
    if (emoji != null) 'emoji': emoji,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  static QuestionOption? fromMap(Object? m) {
    if (m is! Map) return null;
    final value = m['value'], label = m['label'];
    if (value is! String || label is! String) return null;
    final emoji = m['emoji'], imageUrl = m['imageUrl'];
    return QuestionOption(
      value,
      label,
      emoji is String ? emoji : null,
      imageUrl is String ? imageUrl : null,
    );
  }
}

/// "Ask this only if [questionId]'s answer is one of [values]". For a
/// multi-choice answer, any overlap counts. No answer means no match.
class ShowIf {
  final String questionId;
  final List<String> values;
  const ShowIf(this.questionId, this.values);

  bool matches(Map<String, dynamic> answers) {
    final answer = answers[questionId];
    if (answer is String) return values.contains(answer);
    if (answer is List) return answer.any(values.contains);
    return false;
  }

  Map<String, dynamic> toMap() => {'questionId': questionId, 'values': values};

  static ShowIf? fromMap(Object? m) {
    if (m is! Map) return null;
    final id = m['questionId'], values = m['values'];
    if (id is! String || values is! List) return null;
    return ShowIf(id, values.whereType<String>().toList());
  }
}

/// Core questions the app's logic reads directly (matching, age, photo).
/// The admin panel can reword them but not delete them.
const systemQuestionIds = {
  'name',
  'birthDate',
  'gender',
  'interestedIn',
  'photoUrls',
};

/// Fields the app itself keeps on a profile; a question can't use them.
const reservedAnswerIds = {
  'fcmTokens',
  'onboardingAt',
  'onboardingComplete',
  'onboardingStep',
  'createdAt',
  'updatedAt',
  'seed',
};

/// The answer values that are still options of [q] (an admin may have
/// removed some since the person answered).
List<String> knownValues(ProfileQuestion q, Iterable<Object?> values) => [
  for (final v in values)
    if (v is String && q.options.any((o) => o.value == v)) v,
];

final _questionId = RegExp(r'^[A-Za-z][A-Za-z0-9]{0,29}$');
final _optionValue = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_]*$');

/// One profile question. The same definition drives the one-per-screen
/// onboarding flow and the Profile → Edit screen. The answer is stored on
/// the user document under [id], or in the owner-only private doc if
/// [private]. Questions live in `amore_questions/{id}` (managed in the admin
/// panel); [defaultQuestions] is the built-in set and offline fallback.
class ProfileQuestion {
  final String id;
  final QuestionGroup group;
  final String title;
  final String? subtitle;
  final QuestionType type;
  final List<QuestionOption> options;
  final bool required;
  final int? minSelect;
  final int? maxSelect;
  final int? maxLength;

  /// Stored at amore_users/{uid}/private/profile, which only the owner can
  /// read. Private photos are kept as Storage paths in an owner-only folder.
  final bool private;

  /// When set, the question is only asked (and only required) if it
  /// matches the answers given so far.
  final ShowIf? showIf;

  /// For [QuestionType.video]: the exact length the recording must be.
  final int? videoSeconds;

  /// Position in the flow (admin panel), and whether it's asked at all.
  final double order;
  final bool active;

  /// For [QuestionType.scale]: the slider's range, the words under each
  /// end, and how a value reads (e.g. "7 / 10").
  final int scaleMin;
  final int scaleMax;
  final String? lowLabel;
  final String? highLabel;

  /// How a value reads; `{v}` is replaced by the value, e.g. "{v} / 10".
  final String? scaleFormat;

  /// Shown before the answer on profile chips so "No" reads as "🚬 No".
  final String? chipIcon;

  const ProfileQuestion({
    required this.id,
    required this.group,
    required this.title,
    required this.type,
    this.subtitle,
    this.options = const [],
    this.required = false,
    this.minSelect,
    this.maxSelect,
    this.maxLength,
    this.private = false,
    this.showIf,
    this.videoSeconds,
    this.order = 0,
    this.active = true,
    this.scaleMin = 0,
    this.scaleMax = 10,
    this.lowLabel,
    this.highLabel,
    this.scaleFormat,
    this.chipIcon,
  });

  bool appliesTo(Map<String, dynamic> answers) =>
      showIf?.matches(answers) ?? true;

  Duration? get videoLength =>
      videoSeconds == null ? null : Duration(seconds: videoSeconds!);

  bool get system => systemQuestionIds.contains(id);

  bool get hasImageOptions => options.any((o) => o.imageUrl != null);

  /// Firestore shape for `amore_questions/{id}` (the id is the doc id).
  Map<String, dynamic> toMap() => {
    'group': group.name,
    'type': type.name,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (options.isNotEmpty) 'options': [for (final o in options) o.toMap()],
    'required': required,
    'private': private,
    'active': active,
    'order': order,
    if (minSelect != null) 'minSelect': minSelect,
    if (maxSelect != null) 'maxSelect': maxSelect,
    if (maxLength != null) 'maxLength': maxLength,
    if (showIf != null) 'showIf': showIf!.toMap(),
    if (videoSeconds != null) 'videoSeconds': videoSeconds,
    if (type == QuestionType.scale) ...{
      'scaleMin': scaleMin,
      'scaleMax': scaleMax,
    },
    if (lowLabel != null) 'lowLabel': lowLabel,
    if (highLabel != null) 'highLabel': highLabel,
    if (scaleFormat != null) 'scaleFormat': scaleFormat,
    if (chipIcon != null) 'chipIcon': chipIcon,
  };

  /// Null when the document can't be understood (unknown type or section,
  /// no title), so a bad document is skipped instead of crashing the app.
  static ProfileQuestion? fromMap(String id, Map<String, dynamic> m) {
    final type = _byName(QuestionType.values, m['type']);
    final group = _byName(QuestionGroup.values, m['group']);
    final title = m['title'];
    if (type == null || group == null || title is! String || title.isEmpty) {
      return null;
    }
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    String? asString(Object? v) => v is String ? v : null;
    return ProfileQuestion(
      id: id,
      group: group,
      type: type,
      title: title,
      subtitle: asString(m['subtitle']),
      options: [
        if (m['options'] case final List options)
          for (final o in options) ?QuestionOption.fromMap(o),
      ],
      required: m['required'] == true,
      private: m['private'] == true,
      active: m['active'] != false,
      order: m['order'] is num ? (m['order'] as num).toDouble() : 0,
      minSelect: asInt(m['minSelect']),
      maxSelect: asInt(m['maxSelect']),
      maxLength: asInt(m['maxLength']),
      showIf: ShowIf.fromMap(m['showIf']),
      videoSeconds: asInt(m['videoSeconds']),
      scaleMin: asInt(m['scaleMin']) ?? 0,
      scaleMax: asInt(m['scaleMax']) ?? 10,
      lowLabel: asString(m['lowLabel']),
      highLabel: asString(m['highLabel']),
      scaleFormat: asString(m['scaleFormat']),
      chipIcon: asString(m['chipIcon']),
    );
  }

  /// Human-readable answer for profile views and cards; null if unanswered.
  /// Answers are user-written data, so a value of the wrong type (another
  /// user's bad write, or a question whose type changed) reads as null.
  String? format(dynamic value) {
    switch (type) {
      case QuestionType.text:
      case QuestionType.longText:
        if (value is! String) return null;
        final s = value.trim();
        return s.isEmpty ? null : s;
      case QuestionType.date:
        if (value is! Timestamp) return null;
        final d = value.toDate();
        return '${d.day}/${d.month}/${d.year}';
      case QuestionType.height:
        return value is int ? formatHeight(value) : null;
      case QuestionType.scale:
        if (value is! int) return null;
        return scaleFormat?.replaceAll('{v}', '$value') ?? '$value';
      case QuestionType.single:
        return value is String ? _option(value)?.display : null;
      case QuestionType.multi:
        if (value is! List) return null;
        final labels = value
            .whereType<String>()
            .map((v) => _option(v)?.display)
            .whereType<String>();
        return labels.isEmpty ? null : labels.join(', ');
      case QuestionType.photos:
        if (value is! List || value.isEmpty) return null;
        return '${value.length} photo${value.length == 1 ? '' : 's'}';
      case QuestionType.video:
        return value is String ? 'Video recorded' : null;
    }
  }

  QuestionOption? _option(String value) {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }
}

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// A camelCase id from free text ("Do you smoke?" → "doYouSmoke"), starting
/// with a letter, at most 30 characters, and not already in [taken].
String slugId(String text, Set<String> taken) {
  final words = text
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.toLowerCase())
      .toList();
  var base = [
    for (var i = 0; i < words.length; i++)
      i == 0 ? words[i] : words[i][0].toUpperCase() + words[i].substring(1),
  ].join();
  if (base.isEmpty) base = 'question';
  if (!RegExp('^[a-z]').hasMatch(base)) {
    base = 'q${base[0].toUpperCase()}${base.substring(1)}';
  }
  if (base.length > 28) base = base.substring(0, 28); // room for a suffix
  if (!taken.contains(base)) return base;
  for (var n = 2; ; n++) {
    if (!taken.contains('$base$n')) return '$base$n';
  }
}

/// Problems with an admin's question [draft] (the `toMap` shape); empty when
/// it can be saved.
List<String> validateQuestionDefinition(
  Map<String, dynamic> draft, {
  required String id,
  required bool isNew,
  required Set<String> existingIds,
  List<ProfileQuestion> others = const [],
}) {
  final errors = <String>[];
  if (reservedAnswerIds.contains(id)) {
    errors.add('"$id" is used by the app itself; choose another ID.');
  }
  if (!_questionId.hasMatch(id)) {
    errors.add(
      'ID must start with a letter and use only letters and numbers '
      '(max 30).',
    );
  }
  if (isNew && existingIds.contains(id)) {
    errors.add('A question with ID "$id" already exists.');
  }
  final title = draft['title'];
  if (title is! String || title.trim().isEmpty) errors.add('Add a title.');
  final type = _byName(QuestionType.values, draft['type']);
  if (type == null) errors.add('Choose a question type.');
  if (_byName(QuestionGroup.values, draft['group']) == null) {
    errors.add('Choose a section.');
  }
  int? asInt(Object? v) => v is num ? v.toInt() : null;
  final min = asInt(draft['minSelect']), max = asInt(draft['maxSelect']);
  if (min != null && max != null && min > max) {
    errors.add('Minimum can\'t be more than maximum.');
  }

  if (type == QuestionType.single || type == QuestionType.multi) {
    final options = draft['options'] as List? ?? const [];
    if (options.isEmpty) errors.add('Add at least one option.');
    final seen = <String>{};
    for (final o in options) {
      final value = o is Map ? o['value'] : null;
      final label = o is Map ? o['label'] : null;
      if (label is! String || label.trim().isEmpty) {
        errors.add('Every option needs a label.');
      }
      if (value is! String || !_optionValue.hasMatch(value)) {
        errors.add('Option value "$value" is not valid.');
      } else if (!seen.add(value)) {
        errors.add('Two options share the value "$value".');
      }
    }
  }
  if (type == QuestionType.photos && (max == null || max < 1 || max > 10)) {
    errors.add('Photo questions allow 1 to 10 photos.');
  }
  if (type == QuestionType.scale &&
      (asInt(draft['scaleMin']) ?? 0) >= (asInt(draft['scaleMax']) ?? 10)) {
    errors.add('The slider\'s minimum must be below its maximum.');
  }
  if (type == QuestionType.video) {
    final seconds = asInt(draft['videoSeconds']);
    if (seconds == null || seconds < 5 || seconds > 180) {
      errors.add('Video length must be 5 to 180 seconds.');
    }
    if (draft['private'] != true) errors.add('Videos are always private.');
  }
  final showIf = ShowIf.fromMap(draft['showIf']);
  if (showIf != null) {
    final source = others
        .where((q) => q.id == showIf.questionId && q.id != id)
        .firstOrNull;
    final order = draft['order'] is num ? (draft['order'] as num) : 0;
    if (showIf.questionId == id) {
      errors.add('A question can\'t depend on itself.');
    } else if (source == null) {
      errors.add('The "show only if" question no longer exists.');
    } else if (!source.active) {
      errors.add(
        'The "show only if" question is hidden, so this would never show.',
      );
    } else if (source.order >= order) {
      errors.add(
        'Move this question below "${source.title}", which it depends on.',
      );
    }
    if (showIf.values.isEmpty) {
      errors.add('Pick at least one answer for "show only if".');
    }
  }
  return errors;
}

/// Questions whose "show only if" points at [questionId] (and [value]).
List<ProfileQuestion> dependentsOf(
  String questionId,
  List<ProfileQuestion> all, {
  String? value,
}) => [
  for (final q in all)
    if (q.showIf?.questionId == questionId &&
        (value == null || q.showIf!.values.contains(value)))
      q,
];

/// Values offered in only one of gender / interested-in. Matching compares
/// them, so they should list the same values.
Set<String> genderValueMismatch(List<ProfileQuestion> all) {
  Set<String>? valuesOf(String id) {
    for (final q in all) {
      if (q.id == id) return {for (final o in q.options) o.value};
    }
    return null;
  }

  final gender = valuesOf('gender'), wanted = valuesOf('interestedIn');
  if (gender == null || wanted == null) return {};
  return gender.difference(wanted).union(wanted.difference(gender));
}

/// "30 seconds", "2 minutes", "1 min 30 s".
String formatVideoLength(Duration d) {
  final m = d.inMinutes, s = d.inSeconds % 60;
  if (m == 0) return '$s seconds';
  if (s == 0) return '$m minute${m == 1 ? '' : 's'}';
  return '$m min $s s';
}

String formatHeight(int cm) {
  final totalInches = (cm / 2.54).round();
  return '$cm cm (${totalInches ~/ 12}\'${totalInches % 12}")';
}

/// Returns an error message if [value] can't be accepted for [question],
/// or null if the user may continue. Used by both onboarding and editing.
/// Cleans an answer before saving: trims text, and stores blank text or an
/// empty selection as null.
dynamic normalizeAnswer(dynamic value) {
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
  if (value is List && value.isEmpty) return null;
  return value;
}

String? validateAnswer(ProfileQuestion question, dynamic value) {
  if (question.type == QuestionType.multi && value is List) {
    value = knownValues(question, value);
  } else if (question.type == QuestionType.single && value is String) {
    value = knownValues(question, [value]).firstOrNull;
  }
  final empty =
      value == null ||
      (value is String && value.trim().isEmpty) ||
      (value is List && value.isEmpty);
  if (empty) {
    return question.required ? 'Please answer this to continue.' : null;
  }

  if (value is List) {
    final min = question.minSelect, max = question.maxSelect;
    final noun = question.type == QuestionType.photos ? 'photo' : 'option';
    if (question.type == QuestionType.photos &&
        min != null &&
        value.length < min) {
      final left = min - value.length;
      return 'Add $left more photo${left == 1 ? '' : 's'}.';
    }
    if (min != null && value.length < min) {
      return 'Add at least $min $noun${min == 1 ? '' : 's'}.';
    }
    if (max != null && value.length > max) {
      return 'You can choose up to $max $noun${max == 1 ? '' : 's'}.';
    }
  }

  if (question.type == QuestionType.date && question.id == 'birthDate') {
    final age = AppUser.ageOn((value as Timestamp).toDate(), DateTime.now());
    if (age < 18) return 'You must be 18 or older to use Amore.';
    if (age > 100) return 'Please check your birthday.';
  }
  return null;
}

const _genders = [
  QuestionOption('woman', 'Woman'),
  QuestionOption('man', 'Man'),
  QuestionOption('nonbinary', 'Non-binary'),
];

const _yesSometimesNo = [
  QuestionOption('yes', 'Yes'),
  QuestionOption('sometimes', 'Sometimes'),
  QuestionOption('no', 'No'),
  QuestionOption('prefer_not', 'Prefer not to say'),
];

/// Display order is onboarding order.
const List<ProfileQuestion> defaultQuestions = [
  ProfileQuestion(
    id: 'name',
    group: QuestionGroup.basics,
    type: QuestionType.text,
    title: "What's your first name?",
    required: true,
    maxLength: 30,
  ),
  ProfileQuestion(
    id: 'birthDate',
    group: QuestionGroup.basics,
    type: QuestionType.date,
    title: "When's your birthday?",
    subtitle: 'Only your age is shown. You must be 18+.',
    required: true,
  ),
  ProfileQuestion(
    id: 'gender',
    group: QuestionGroup.basics,
    type: QuestionType.single,
    title: 'Which best describes you?',
    options: _genders,
    required: true,
  ),
  ProfileQuestion(
    id: 'interestedIn',
    group: QuestionGroup.basics,
    type: QuestionType.multi,
    title: 'Who would you like to meet?',
    options: _genders,
    required: true,
    minSelect: 1,
  ),
  ProfileQuestion(
    id: 'heightCm',
    chipIcon: '📏',
    group: QuestionGroup.basics,
    type: QuestionType.height,
    title: 'How tall are you?',
  ),
  ProfileQuestion(
    id: 'city',
    chipIcon: '📍',
    group: QuestionGroup.basics,
    type: QuestionType.text,
    title: 'Where do you live?',
    subtitle: 'Your city or neighbourhood',
    maxLength: 40,
  ),
  ProfileQuestion(
    id: 'lookingFor',
    group: QuestionGroup.intentions,
    type: QuestionType.single,
    title: 'What are you looking for?',
    required: true,
    options: [
      QuestionOption('long_term', 'Long-term relationship', '💍'),
      QuestionOption('short_term', 'Short-term, open to long', '🥂'),
      QuestionOption('casual', 'Something casual', '😉'),
      QuestionOption('friends', 'New friends', '👋'),
      QuestionOption('unsure', 'Still figuring it out', '🤔'),
    ],
  ),
  ProfileQuestion(
    id: 'interests',
    group: QuestionGroup.interests,
    type: QuestionType.multi,
    title: 'What are you into?',
    subtitle: 'Pick 3 to 10',
    required: true,
    minSelect: 3,
    maxSelect: 10,
    options: [
      QuestionOption('travel', 'Travel', '✈️'),
      QuestionOption('music', 'Music', '🎵'),
      QuestionOption('movies', 'Movies', '🎬'),
      QuestionOption('reading', 'Reading', '📚'),
      QuestionOption('cooking', 'Cooking', '🍳'),
      QuestionOption('foodie', 'Foodie', '🍜'),
      QuestionOption('coffee', 'Coffee', '☕'),
      QuestionOption('fitness', 'Fitness', '🏋️'),
      QuestionOption('hiking', 'Hiking', '🥾'),
      QuestionOption('yoga', 'Yoga', '🧘'),
      QuestionOption('football', 'Football', '⚽'),
      QuestionOption('cricket', 'Cricket', '🏏'),
      QuestionOption('gaming', 'Gaming', '🎮'),
      QuestionOption('art', 'Art', '🎨'),
      QuestionOption('photography', 'Photography', '📷'),
      QuestionOption('dancing', 'Dancing', '💃'),
      QuestionOption('pets', 'Animals', '🐾'),
      QuestionOption('tech', 'Tech', '💻'),
      QuestionOption('fashion', 'Fashion', '👗'),
      QuestionOption('nature', 'Nature', '🌿'),
    ],
  ),
  ProfileQuestion(
    id: 'drinking',
    chipIcon: '🍷',
    group: QuestionGroup.lifestyle,
    type: QuestionType.single,
    title: 'Do you drink?',
    options: _yesSometimesNo,
  ),
  ProfileQuestion(
    id: 'smoking',
    chipIcon: '🚬',
    group: QuestionGroup.lifestyle,
    type: QuestionType.single,
    title: 'Do you smoke?',
    options: _yesSometimesNo,
  ),
  ProfileQuestion(
    id: 'exercise',
    chipIcon: '💪',
    group: QuestionGroup.lifestyle,
    type: QuestionType.single,
    title: 'How often do you work out?',
    options: [
      QuestionOption('daily', 'Every day'),
      QuestionOption('often', 'Often'),
      QuestionOption('sometimes', 'Sometimes'),
      QuestionOption('never', 'Never'),
    ],
  ),
  ProfileQuestion(
    id: 'pets',
    group: QuestionGroup.lifestyle,
    type: QuestionType.multi,
    title: 'Any pets?',
    options: [
      QuestionOption('dog', 'Dog', '🐶'),
      QuestionOption('cat', 'Cat', '🐱'),
      QuestionOption('other', 'Other', '🐠'),
      QuestionOption('none_want', 'None, but I want one'),
      QuestionOption('none', 'No pets'),
    ],
  ),
  ProfileQuestion(
    id: 'religion',
    chipIcon: '🙏',
    group: QuestionGroup.lifestyle,
    type: QuestionType.single,
    title: 'What are your religious beliefs?',
    options: [
      QuestionOption('muslim', 'Muslim'),
      QuestionOption('christian', 'Christian'),
      QuestionOption('hindu', 'Hindu'),
      QuestionOption('sikh', 'Sikh'),
      QuestionOption('buddhist', 'Buddhist'),
      QuestionOption('jewish', 'Jewish'),
      QuestionOption('spiritual', 'Spiritual'),
      QuestionOption('agnostic', 'Agnostic'),
      QuestionOption('atheist', 'Atheist'),
      QuestionOption('other', 'Other'),
      QuestionOption('prefer_not', 'Prefer not to say'),
    ],
  ),
  ProfileQuestion(
    id: 'kidsHave',
    chipIcon: '👶',
    group: QuestionGroup.lifestyle,
    type: QuestionType.single,
    title: 'Do you have children?',
    options: [
      QuestionOption('no', "Don't have kids"),
      QuestionOption('yes', 'Have kids'),
      QuestionOption('prefer_not', 'Prefer not to say'),
    ],
  ),
  ProfileQuestion(
    id: 'kidsWant',
    chipIcon: '🍼',
    group: QuestionGroup.lifestyle,
    type: QuestionType.single,
    title: 'Do you want children?',
    options: [
      QuestionOption('want', 'Want kids'),
      QuestionOption('open', 'Open to it'),
      QuestionOption('dont_want', "Don't want kids"),
      QuestionOption('unsure', 'Not sure'),
    ],
  ),
  // Private: never shown in the app, kept for future AI matching. Asked as
  // "women"/"men" rather than opposite/same so it works for every gender;
  // opposite/same is derivable from `gender`. Optional (sensitive data).
  ProfileQuestion(
    id: 'attractionWomen',
    group: QuestionGroup.personal,
    type: QuestionType.scale,
    title: 'How attracted are you to women?',
    subtitle: 'Private: only you can see this',
    private: true,
    lowLabel: 'Not at all',
    highLabel: 'Very',
    scaleFormat: '{v} / 10',
  ),
  ProfileQuestion(
    id: 'attractionMen',
    group: QuestionGroup.personal,
    type: QuestionType.scale,
    title: 'How attracted are you to men?',
    subtitle: 'Private: only you can see this',
    private: true,
    lowLabel: 'Not at all',
    highLabel: 'Very',
    scaleFormat: '{v} / 10',
  ),
  ProfileQuestion(
    id: 'firstSexualAwarenessAge',
    group: QuestionGroup.personal,
    type: QuestionType.scale,
    title: 'How old were you when you first discovered sex?',
    subtitle: 'Private: only you can see this',
    private: true,
    scaleMin: 5,
    scaleMax: 30,
    lowLabel: '5 or younger',
    highLabel: '30+',
    scaleFormat: 'Age {v}',
  ),
  ProfileQuestion(
    id: 'bio',
    group: QuestionGroup.about,
    type: QuestionType.longText,
    title: 'Tell people a bit about you',
    subtitle: 'A few lines is plenty',
    maxLength: 300,
  ),
  ProfileQuestion(
    id: 'photoUrls',
    group: QuestionGroup.about,
    type: QuestionType.photos,
    title: 'Add your profile photo',
    subtitle: 'This is the photo people see',
    required: true,
    minSelect: 1,
    maxSelect: 1,
  ),
  ProfileQuestion(
    id: 'privatePhotos',
    group: QuestionGroup.about,
    type: QuestionType.photos,
    title: 'Add 3 more photos',
    subtitle: 'Only you can see these',
    required: true,
    minSelect: 3,
    maxSelect: 3,
    private: true,
    showIf: ShowIf('gender', ['woman']),
  ),
  ProfileQuestion(
    id: 'privateVideo',
    group: QuestionGroup.about,
    type: QuestionType.video,
    title: 'Record a 30-second video',
    subtitle: 'Only you can see this',
    required: true,
    private: true, // stored as a Storage path in the owner-only folder
    showIf: ShowIf('gender', ['woman']),
    videoSeconds: 30,
  ),
  ProfileQuestion(
    id: 'privateVideoLong',
    group: QuestionGroup.about,
    type: QuestionType.video,
    title: 'Record a 2-minute video',
    subtitle: 'Only you can see this',
    required: true,
    private: true, // everyone records this one
    videoSeconds: 120,
  ),
];
