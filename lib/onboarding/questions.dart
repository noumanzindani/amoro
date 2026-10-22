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
  const QuestionOption(this.value, this.label, [this.emoji]);

  String get display => emoji == null ? label : '$emoji $label';
}

/// One profile question. The same definition drives the one-per-screen
/// onboarding flow and the Profile → Edit screen. The answer is stored on
/// the user document under [id], or in the owner-only private doc if
/// [private].
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

  /// When set, the question is only asked (and only required) if this
  /// returns true for the answers given so far, e.g. [isWoman].
  final bool Function(Map<String, dynamic> answers)? showIf;

  /// For [QuestionType.video]: the exact length the recording must be.
  final Duration? videoLength;

  /// For [QuestionType.scale]: the slider's range, the words under each
  /// end, and how a value reads (e.g. "7 / 10").
  final int scaleMin;
  final int scaleMax;
  final String? lowLabel;
  final String? highLabel;
  final String Function(int value)? scaleFormat;

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
    this.videoLength,
    this.scaleMin = 0,
    this.scaleMax = 10,
    this.lowLabel,
    this.highLabel,
    this.scaleFormat,
    this.chipIcon,
  });

  bool appliesTo(Map<String, dynamic> answers) => showIf?.call(answers) ?? true;

  /// Human-readable answer for profile views and cards; null if unanswered.
  String? format(dynamic value) {
    if (value == null) return null;
    switch (type) {
      case QuestionType.text:
      case QuestionType.longText:
        final s = (value as String).trim();
        return s.isEmpty ? null : s;
      case QuestionType.date:
        final d = (value as Timestamp).toDate();
        return '${d.day}/${d.month}/${d.year}';
      case QuestionType.height:
        return formatHeight(value as int);
      case QuestionType.scale:
        final v = value as int;
        return scaleFormat?.call(v) ?? '$v';
      case QuestionType.single:
        return _option(value as String)?.display;
      case QuestionType.multi:
        final labels = (value as List)
            .map((v) => _option(v as String)?.display)
            .whereType<String>();
        return labels.isEmpty ? null : labels.join(', ');
      case QuestionType.photos:
        final n = (value as List).length;
        return n == 0 ? null : '$n photo${n == 1 ? '' : 's'}';
      case QuestionType.video:
        return 'Video recorded';
    }
  }

  QuestionOption? _option(String value) {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }
}

bool isWoman(Map<String, dynamic> answers) => answers['gender'] == 'woman';

String outOfTen(int v) => '$v / 10';
String ageYears(int v) => 'Age $v';

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
const List<ProfileQuestion> profileQuestions = [
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
    scaleFormat: outOfTen,
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
    scaleFormat: outOfTen,
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
    scaleFormat: ageYears,
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
    showIf: isWoman,
  ),
  ProfileQuestion(
    id: 'privateVideo',
    group: QuestionGroup.about,
    type: QuestionType.video,
    title: 'Record a 30-second video',
    subtitle: 'Only you can see this',
    required: true,
    private: true, // stored as a Storage path in the owner-only folder
    showIf: isWoman,
    videoLength: Duration(seconds: 30),
  ),
  ProfileQuestion(
    id: 'privateVideoLong',
    group: QuestionGroup.about,
    type: QuestionType.video,
    title: 'Record a 2-minute video',
    subtitle: 'Only you can see this',
    required: true,
    private: true, // everyone records this one
    videoLength: Duration(seconds: 120),
  ),
];
