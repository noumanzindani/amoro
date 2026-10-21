import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

enum QuestionType { text, longText, date, height, single, multi, photos }

enum QuestionGroup {
  basics('Basics'),
  intentions('Looking for'),
  interests('Interests'),
  lifestyle('Lifestyle'),
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
/// the user document under [id].
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
    this.chipIcon,
  });

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
    }
  }

  QuestionOption? _option(String value) {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }
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
    if (min != null && value.length < min) {
      return 'Add at least $min $noun${min == 1 ? '' : 's'}.';
    }
    if (max != null && value.length > max) {
      return 'You can choose up to $max ${noun}s.';
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
    title: 'Add your photos',
    subtitle: 'At least 1, up to 6',
    required: true,
    minSelect: 1,
    maxSelect: 6,
  ),
];
