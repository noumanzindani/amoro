# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**Amore** (`com.amore.amore`, repo `noumanzindani/amoro`): a Flutter + Firebase dating app.
Android is the primary target; iOS builds need Xcode signing set up first.

Features: email/Google sign-in → one-question-per-screen onboarding → Discover
(swipe; mutual like = match) · Community (browse everyone, message directly) ·
Chats (real-time 1:1 with timestamps, ✓/✓✓ receipts, typing, photos/videos,
view-once media) · Profile (edit answers, blocked people) · Block/Report.

## Commands

```bash
flutter pub get
flutter analyze                 # must stay at "No issues found!"
flutter test                    # unit tests in test/
flutter run                     # or: flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk

firebase deploy --only firestore,storage        # rules + indexes
firebase deploy --only functions:amore          # ONLY ever deploy the amore codebase
cd functions && npm run seed                    # 30 test profiles (+likes toward real users)
cd functions && npm run seed:clean              # remove all seed data

# Admin panel (Flutter web, separate entrypoint) → https://amore-admin.web.app
flutter build web -t lib/admin/main.dart --release && firebase deploy --only hosting:admin
cd functions && npm run admin:add -- someone@example.com   # needs a verified email
cd functions && npm run admin:list                         # admin:remove -- <email>
```

## ⚠️ Shared Firebase project — read before deploying

Amore runs on **`hbgapp-c3c88`**, shared with HabitBeGone, Pocket Change,
School Management and Luna.

- **Firestore:** Amore uses the `(default)` database but only `amore_*`
  collections. The other apps own `users`, `deletionRequests`, etc.
- **`firestore.rules` is the rules file for the whole database.** Its first
  block is the other apps' (currently allow-all) catch-all, narrowed with
  `!collection.matches('amore_.*')`. Never remove or tighten it without the
  owners' say — it would break their apps.
- **Storage:** Amore uses its own bucket `hbgapp-c3c88-amore-media`
  (`Backend.bucket`); `storage.rules` targets only that bucket.
- **Hosting:** the default site `hbgapp-c3c88.web.app` is **HabitBeGone's**.
  Amore's admin panel is the separate site `amore-admin` (hosting target
  `admin`); only ever deploy with `--only hosting:admin`.
- **Functions:** codebase `amore` in `functions/`. The project also hosts another
  app's `createPaymentIntent`; a plain `firebase deploy --only functions` could
  offer to delete it. Use `--only functions:amore`.
- **Auth is project-wide**: accounts are shared with the other apps.
- The CLI account is an **Editor**: it can't create databases or grant IAM roles.
  Firestore-triggered functions still need an Owner to grant three service-agent
  roles (see the deploy error output) before `functions:amore` deploys.
- Test rule changes with the Rules API before deploying
  (`POST https://firebaserules.googleapis.com/v1/projects/hbgapp-c3c88:test`).

## Architecture (`lib/`)

```
backend.dart          Firestore/Storage handles + amore_* collection getters (always use these)
theme.dart            AppColors + buildTheme(): IMIC-style dark theme, rose accent, Inter
models/               AppUser (answers keyed by question id), Match, Message
onboarding/           questions.dart (the question registry), question_input.dart
services/             auth, user, swipe, chat, block, storage, push, secure_screen
providers/            SessionProvider (router gate), DeckProvider, BlockProvider
router.dart           go_router; redirects on SessionStatus; 4-tab StatefulShellRoute
screens/              auth, onboarding, discover, community, matches (Chats), chat, profile, home
widgets/              ui.dart (AppButton, AppLoader, FloatingNavBar…), profile_card.dart
```

- **State:** `provider` + `ChangeNotifier`. Repositories are plain classes provided in `main.dart`.
- **Questions:** live in Firestore `amore_questions/{id}`, edited in the admin
  panel (`lib/admin/`); `QuestionsProvider` streams them and falls back to
  `defaultQuestions` (`lib/onboarding/questions.dart`) when the collection is
  empty or unreadable. Each `ProfileQuestion` drives onboarding and Edit
  Profile; its answer is stored under its `id`. Onboarding resumes by question
  id (`onboardingAt`). Admins carry the auth claim `amoreAdmin` (plus a
  verified email); rules check it for `amore_questions` and
  `amore_question_media/` (option pictures). Question `type`, `private`, ids
  and option values are fixed once created; core ids are `systemQuestionIds`.
  `showIf` (`ShowIf('gender', ['woman'])`) makes a question conditional;
  onboarding skips it and Edit Profile hides it when it doesn't apply.
  `validateAnswer` / `normalizeAnswer` are shared by both flows.
- **Chats:** `amore_matches/{uidA}_{uidB}` (sorted ids) for both swipe matches and
  Community chats (`source: 'community'`), with `messages` subcollection.
  Unread counts, read marks and typing live as per-uid maps on the match doc.
  **User ids must never contain `_`** (ids are split on it; seed ids are `seedUserNN`).
- **Media:** chat media is referenced by Storage *path* and downloaded via the
  SDK — never store download URLs for chat media (they bypass rules).
  View-once files are deleted by the receiver after viewing.
- **Private answers:** questions with `private: true` (`privatePhotos`, `privateVideo`, `privateVideoLong`, and the `personal` group: `attractionWomen`, `attractionMen`, `firstSexualAwarenessAge` — kept for future AI matching, never displayed) are
  saved to owner-only `amore_users/{uid}/private/profile` via
  `SessionProvider.saveAnswer`; private photos and videos live at `users/{uid}/private/`
  (owner-only Storage rule) and are stored as paths, never download URLs.
- **Push tokens:** stored in owner-only `amore_users/{uid}/private/devices`,
  never on the public profile (rules reject `fcmTokens` there).
- **Blocks:** `amore_blocks/{blocker}_{blocked}`; `BlockProvider.isHidden` filters
  Discover, Community and Chats; rules refuse chats/messages across a block.

## Conventions

- Match surrounding code; keep `flutter analyze` clean and add tests for logic.
- Conventional Commits (`feat:`, `fix:`, `chore:` …).
- Firestore list queries need rules provable from the query (split `get`/`list`).
- New composite queries need an entry in `firestore.indexes.json`; indexes take
  a few minutes to build after deploy.
