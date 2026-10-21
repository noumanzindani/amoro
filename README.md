# amoro

Amore — a Flutter + Firebase dating app (Android first).

- Sign-in: email/password and Google
- One-question-per-screen onboarding; every answer is editable in Profile
- Discover (swipe, mutual like = match), Community (browse everyone, message directly)
- Chats: real-time 1:1 with timestamps, read receipts, typing indicator, photos/videos and view-once media
- Block and report

## Run

```bash
flutter pub get
flutter run
flutter test
```

## Firebase

Uses the shared `hbgapp-c3c88` project. Amore's data lives only in `amore_*`
collections and the `hbgapp-c3c88-amore-media` bucket. `firestore.rules` is the
rules file for the **whole** default database — keep the other apps' section
intact when deploying.

```bash
firebase deploy --only firestore,storage      # rules + indexes
firebase deploy --only functions:amore         # push notifications (own codebase)
cd functions && npm run seed                   # 30 test profiles; npm run seed:clean removes them
```
