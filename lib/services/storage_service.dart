import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../backend.dart';

/// Reports 0.0–1.0 as a Storage upload or download moves along.
typedef OnProgress = void Function(double fraction);

class StorageService {
  Future<String> uploadPhoto(String uid, File file) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final ref = Backend.storage.ref('users/$uid/photos/$id.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Uploads to the owner-only folder and returns the Storage *path*: a
  /// download URL would let anyone holding it bypass the rules.
  Future<String> uploadPrivatePhoto(String uid, File file) =>
      _uploadPrivate(uid, file, 'jpg', 'image/jpeg');

  Future<String> uploadPrivateVideo(
    String uid,
    File file, {
    OnProgress? onProgress,
  }) => _uploadPrivate(uid, file, 'mp4', 'video/mp4', onProgress);

  Future<String> _uploadPrivate(
    String uid,
    File file,
    String ext,
    String contentType, [
    OnProgress? onProgress,
  ]) async {
    final id = DateTime.now().microsecondsSinceEpoch;
    final ref = Backend.storage.ref('users/$uid/private/$id.$ext');
    await _track(
      ref.putFile(file, SettableMetadata(contentType: contentType)),
      onProgress,
    );
    return ref.fullPath;
  }

  /// Downloads a private file to a temp file (cached per path) for playback.
  /// It downloads to a `.part` file first, so an interrupted download is
  /// never mistaken for a cached one.
  Future<File> downloadPrivate(String path, {OnProgress? onProgress}) async {
    final file = File(
      '${Directory.systemTemp.path}/${path.replaceAll('/', '_')}',
    );
    if (await file.exists() && await file.length() > 0) return file;
    final part = File('${file.path}.part');
    await _track(Backend.storage.ref(path).writeToFile(part), onProgress);
    return part.rename(file.path);
  }

  /// Awaits [task], forwarding its byte progress to [onProgress].
  Future<void> _track(Task task, OnProgress? onProgress) async {
    final StreamSubscription<TaskSnapshot>? sub = onProgress == null
        ? null
        : task.snapshotEvents.listen((s) {
            if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
          }, onError: (_) {}); // the awaited task reports the error
    try {
      await task;
    } finally {
      await sub?.cancel();
    }
  }

  Future<void> deletePhoto(String url) async {
    try {
      await Backend.storage.refFromURL(url).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
