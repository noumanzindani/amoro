import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Amore shares the hbgapp-c3c88 project and its (default) database with
/// other apps, which already own a `users` collection. Every Amore
/// collection is prefixed with `amore_` — always go through these getters.
class Backend {
  static const bucket = 'gs://hbgapp-c3c88-amore-media';

  static FirebaseFirestore get db => FirebaseFirestore.instance;

  static FirebaseStorage get storage =>
      FirebaseStorage.instanceFor(app: Firebase.app(), bucket: bucket);

  static CollectionReference<Map<String, dynamic>> get users =>
      db.collection('amore_users');
  static CollectionReference<Map<String, dynamic>> get swipes =>
      db.collection('amore_swipes');
  static CollectionReference<Map<String, dynamic>> get blocks =>
      db.collection('amore_blocks');
  static CollectionReference<Map<String, dynamic>> get reports =>
      db.collection('amore_reports');
  static CollectionReference<Map<String, dynamic>> get matches =>
      db.collection('amore_matches');
  static CollectionReference<Map<String, dynamic>> get questions =>
      db.collection('amore_questions');
}
