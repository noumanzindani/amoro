import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../backend.dart';

class StorageService {
  Future<String> uploadPhoto(String uid, File file) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final ref = Backend.storage.ref('users/$uid/photos/$id.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<void> deletePhoto(String url) async {
    try {
      await Backend.storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
