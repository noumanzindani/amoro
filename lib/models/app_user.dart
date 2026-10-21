import 'package:cloud_firestore/cloud_firestore.dart';

/// A user profile. Answers to onboarding questions are stored as top-level
/// fields keyed by question id, so [data] is the source of truth.
class AppUser {
  final String uid;
  final Map<String, dynamic> data;

  const AppUser(this.uid, this.data);

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser(doc.id, doc.data() ?? const {});

  dynamic operator [](String key) => data[key];

  String get name => (data['name'] as String? ?? '').trim();
  String? get gender => data['gender'] as String?;
  List<String> get interestedIn =>
      List<String>.from(data['interestedIn'] ?? const []);
  List<String> get photoUrls =>
      List<String>.from(data['photoUrls'] ?? const []);
  int get onboardingStep => data['onboardingStep'] as int? ?? 0;
  bool get onboardingComplete => data['onboardingComplete'] == true;

  DateTime? get birthDate => (data['birthDate'] as Timestamp?)?.toDate();

  int? get age {
    final b = birthDate;
    if (b == null) return null;
    return ageOn(b, DateTime.now());
  }

  static int ageOn(DateTime birth, DateTime today) {
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age;
  }
}
