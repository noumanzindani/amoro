# Admin Question Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Amore's onboarding questions into Firestore and build an admin website where questions, their options (incl. option images), required/public/private, upload questions and "show only if" conditions are managed without an app release.

**Architecture:** `ProfileQuestion` becomes serializable (`fromMap`/`toMap`); the const list becomes `defaultQuestions` (import source + fallback). The phone app streams `amore_questions` through a `QuestionsProvider`. The admin panel is a Flutter web entrypoint (`lib/admin/main.dart`) in the same package, deployed to its own hosting site `amore-admin`. Admins are identified by the custom claim `amoreAdmin: true`, enforced by Firestore and Storage rules.

**Tech Stack:** Flutter 3.41 (Android/iOS + web), cloud_firestore, firebase_storage, firebase_auth, provider, image_picker (web: bytes); Node firebase-admin scripts; Firebase Hosting target.

**Spec:** `docs/superpowers/specs/2026-10-22-admin-question-panel-design.md`

## Global Constraints

- Project `hbgapp-c3c88` is shared. Never deploy hosting to site `hbgapp-c3c88` (HabitBeGone). Hosting deploys use `--only hosting:admin` only.
- `firestore.rules`: keep the other apps' catch-all block byte-for-byte; add Amore rules only inside the Amore section.
- Admin claim name is exactly `amoreAdmin` (boolean `true`). Granting/removing must merge with existing custom claims.
- Question ids and option values: `^[A-Za-z][A-Za-z0-9]*$`, ≤ 30 chars, unique; immutable after creation.
- Question `type` and `private` are immutable after creation. `video` questions are always private.
- System question ids: `name`, `birthDate`, `gender`, `interestedIn`, `photoUrls` — cannot be deleted, panel warns before hiding or making optional.
- Video length 5–180 s. Option images < 5 MB, stored at `amore_question_media/{questionId}/{file}`.
- No new pub/npm dependencies.
- `flutter analyze` must report "No issues found!" and `flutter test` must pass after every task.
- Branch `feat/admin-question-panel`; Conventional Commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. A question doc that is malformed or has an unknown `type`/`group` (hand-edited in console, or written by a newer panel) → the app skips it, never crashes. *(Task 1 test `fromMap returns null for unknown type`.)*
2. `amore_questions` empty, unreadable, or not yet loaded (first launch offline) → app uses `defaultQuestions` and behaves exactly as today. *(Task 2 test `effectiveQuestions falls back to defaults`.)*
3. `showIf` pointing at a deleted/hidden question or a removed option value → the dependent question is simply not asked; the panel lists such dependents before deleting. *(Task 1 tests `ShowIf with missing answer is false`, `dependentsOf`.)*
4. A user's stored answer is an option value that no longer exists → profile chips/format skip it, no "null" text. *(Task 1 test `format ignores unknown option values`.)*
5. Admin reorders/inserts/hides questions while a user is mid-onboarding → resume lands on a sensible question by id, and the screen works from a snapshot taken when it opened. *(Task 2 tests for `resumeQuestionId`.)*

---

### Task 1: Serializable question schema + admin helpers

**Files:**
- Modify: `lib/onboarding/questions.dart`
- Modify: `test/validation_test.dart` (use `defaultQuestions`)
- Create: `test/question_schema_test.dart`

**Interfaces:**
- Produces:
  - `class ShowIf { const ShowIf(this.questionId, this.values); final String questionId; final List<String> values; bool matches(Map<String, dynamic> answers); Map<String, dynamic> toMap(); static ShowIf? fromMap(Object? m); }` — `matches`: answer is a String in `values`, or a List overlapping `values`; missing answer → false.
  - `QuestionOption(value, label, [emoji, imageUrl])` + `Map<String,dynamic> toMap()`, `static QuestionOption? fromMap(Object? m)`.
  - `ProfileQuestion` new fields: `double order` (default 0), `bool active` (default true), `ShowIf? showIf` (replaces the function), `String? scaleFormat` (template with `{v}`, replaces the function), `int? videoSeconds` (replaces `videoLength`; keep getter `Duration? get videoLength`). Getter `bool get system => systemQuestionIds.contains(id)`. Getter `bool get hasImageOptions`.
  - `ProfileQuestion.appliesTo(answers)` → `showIf?.matches(answers) ?? true`.
  - `static ProfileQuestion? ProfileQuestion.fromMap(String id, Map<String, dynamic> m)` (null if `type`/`group` unknown or `title` not a non-empty string); `Map<String, dynamic> toMap()` (no `id`; omits nulls/defaults-free fields as it likes, must round-trip).
  - `const systemQuestionIds = {'name','birthDate','gender','interestedIn','photoUrls'};`
  - `final List<ProfileQuestion> defaultQuestions` (today's list, renamed; women-only ones use `ShowIf('gender', ['woman'])`; sliders use `'{v} / 10'` and `'Age {v}'`; videos `videoSeconds: 30` / `120`).
  - `String slugId(String text, Set<String> taken)` → camelCase alnum from words, starts with a letter (prefix `q` if needed), ≤ 30 chars, `'question'` if empty, de-duplicated with `2`, `3`…
  - `List<String> validateQuestionDefinition(Map<String, dynamic> draft, {required String id, required bool isNew, required Set<String> existingIds})` → human-readable errors (empty = valid).
  - `List<ProfileQuestion> dependentsOf(String questionId, List<ProfileQuestion> all, {String? value})` — questions whose `showIf` targets that question (and that value, if given).
  - `Set<String> genderValueMismatch(List<ProfileQuestion> all)` — values present in only one of `gender`/`interestedIn` options.

- [ ] **Step 1: Write the failing tests** in `test/question_schema_test.dart`:

```dart
test('every default question round-trips through toMap/fromMap', () {
  for (final q in defaultQuestions) {
    final back = ProfileQuestion.fromMap(q.id, q.toMap())!;
    expect(back.toMap(), q.toMap(), reason: q.id);
    expect(back.type, q.type);
    expect(back.private, q.private);
    expect(back.showIf?.questionId, q.showIf?.questionId);
  }
});
test('fromMap returns null for unknown type or missing title', () {
  expect(ProfileQuestion.fromMap('x', {'type': 'hologram', 'group': 'about', 'title': 'T'}), isNull);
  expect(ProfileQuestion.fromMap('x', {'type': 'text', 'group': 'about'}), isNull);
  expect(ProfileQuestion.fromMap('x', {'type': 'text', 'group': 'nowhere', 'title': 'T'}), isNull);
});
test('ShowIf matches single and multi answers; missing answer is false', () {
  const s = ShowIf('gender', ['woman']);
  expect(s.matches({'gender': 'woman'}), isTrue);
  expect(s.matches({'gender': 'man'}), isFalse);
  expect(s.matches({}), isFalse);
  expect(const ShowIf('pets', ['dog']).matches({'pets': ['cat', 'dog']}), isTrue);
});
test('women-only defaults still apply only to women', () {
  final q = defaultQuestions.firstWhere((q) => q.id == 'privatePhotos');
  expect(q.appliesTo({'gender': 'woman'}), isTrue);
  expect(q.appliesTo({'gender': 'nonbinary'}), isFalse);
});
test('scale template formats values', () {
  final q = defaultQuestions.firstWhere((q) => q.id == 'attractionMen');
  expect(q.format(7), '7 / 10');
  expect(defaultQuestions.firstWhere((q) => q.id == 'firstSexualAwarenessAge').format(12), 'Age 12');
});
test('format ignores unknown option values', () {
  final q = defaultQuestions.firstWhere((q) => q.id == 'pets');
  expect(q.format(['dog', 'unicorn']), isNot(contains('unicorn')));
  expect(defaultQuestions.firstWhere((q) => q.id == 'religion').format('gone'), isNull);
});
test('slugId makes unique camelCase ids', () {
  expect(slugId('Do you smoke weed?', {}), 'doYouSmokeWeed');
  expect(slugId('Pets', {'pets'}), 'pets2');
  expect(slugId('123 go', {}), 'q123Go');
  expect(slugId('!!!', {}), 'question');
  expect(slugId('a' * 50, {}).length, lessThanOrEqualTo(30));
});
test('validateQuestionDefinition catches broken drafts', () {
  Map<String, dynamic> d(Map<String, dynamic> m) => {'group': 'about', 'title': 'T', ...m};
  expect(validateQuestionDefinition(d({'type': 'single', 'options': []}), id: 'abc', isNew: true, existingIds: {}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'text'}), id: 'abc', isNew: true, existingIds: {'abc'}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'text'}), id: 'a_b', isNew: true, existingIds: {}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'multi', 'minSelect': 3, 'maxSelect': 2, 'options': [{'value': 'a', 'label': 'A'}]}), id: 'abc', isNew: true, existingIds: {}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'video', 'videoSeconds': 300, 'private': true}), id: 'abc', isNew: true, existingIds: {}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'video', 'videoSeconds': 60, 'private': false}), id: 'abc', isNew: true, existingIds: {}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'scale', 'scaleMin': 5, 'scaleMax': 5}), id: 'abc', isNew: true, existingIds: {}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'single', 'options': [{'value': 'a', 'label': 'A'}, {'value': 'a', 'label': 'B'}]}), id: 'abc', isNew: true, existingIds: {}), isNotEmpty);
  expect(validateQuestionDefinition(d({'type': 'single', 'options': [{'value': 'a', 'label': 'A'}]}), id: 'abc', isNew: true, existingIds: {}), isEmpty);
});
test('dependentsOf and genderValueMismatch', () {
  expect(dependentsOf('gender', defaultQuestions, value: 'woman').map((q) => q.id), containsAll(['privatePhotos', 'privateVideo']));
  expect(dependentsOf('gender', defaultQuestions, value: 'man'), isEmpty);
  expect(genderValueMismatch(defaultQuestions), isEmpty);
});
```

- [ ] **Step 2: Run** `flutter test test/question_schema_test.dart` — Expected: FAIL (undefined `defaultQuestions`, `ShowIf`, …).
- [ ] **Step 3: Implement** the interfaces above in `lib/onboarding/questions.dart`. Rename `profileQuestions` → `defaultQuestions` and update its callers *temporarily* (they move to the provider in Task 2). `validateQuestionDefinition` rules: id regex + uniqueness when new; non-empty title; known type/group; single/multi need ≥ 1 option with unique valid values and non-empty labels; `minSelect ≤ maxSelect` when both set; photos `maxSelect` 1–10; scale `scaleMin < scaleMax`; video `videoSeconds` 5–180 and `private == true`; `showIf.questionId != id`.
- [ ] **Step 4: Run** `flutter analyze && flutter test` — Expected: No issues; all pass (validation tests switched to `defaultQuestions`).
- [ ] **Step 5: Commit** `feat(questions): serializable question schema with admin helpers`.

### Task 2: Questions from Firestore in the phone app

**Files:**
- Create: `lib/services/question_repository.dart`, `lib/providers/questions_provider.dart`, `test/question_flow_test.dart`
- Modify: `lib/backend.dart` (add `questions` getter → `amore_questions`), `lib/main.dart` (provide repo + provider), `lib/screens/onboarding/onboarding_screen.dart`, `lib/screens/profile/edit_profile_screen.dart`, `lib/widgets/profile_card.dart`, `lib/models/app_user.dart` (`String? get onboardingAt`)

**Interfaces:**
- Consumes: Task 1 `ProfileQuestion.fromMap/toMap`, `defaultQuestions`.
- Produces:
  - `class QuestionRepository { Stream<List<ProfileQuestion>> watchAll(); Future<void> upsert(String id, Map<String, dynamic> data); Future<void> delete(String id); Future<void> reorder(List<String> idsInOrder); Future<int> importDefaults(); }` — `watchAll` orders by `order`, drops docs where `fromMap` is null; `upsert` merges and sets `updatedAt`; `reorder` batch-writes `order = index * 10`; `importDefaults` writes each default with `order = index * 10` **only if the collection is empty**, returns count written (0 if not empty).
  - `List<ProfileQuestion> effectiveQuestions(List<ProfileQuestion>? remote)` (top-level in `questions_provider.dart`): null/empty → `defaultQuestions`; else `remote.where((q) => q.active)`.
  - `class QuestionsProvider extends ChangeNotifier { QuestionsProvider(QuestionRepository repo, SessionProvider session); List<ProfileQuestion> get questions; bool get loaded; ProfileQuestion? byId(String id); }` — subscribes when `session.uid` becomes non-null, cancels on sign-out; on stream error logs and keeps/uses defaults with `loaded = true`.
  - `String? resumeQuestionId({required List<ProfileQuestion> questions, required Map<String, dynamic> answers, String? onboardingAt})` (top-level in `questions_provider.dart`): `onboardingAt` if it exists in `questions` and applies; else first applicable question whose answer is null/empty; else last applicable; null if none apply.
  - `profileChips(AppUser user, List<ProfileQuestion> questions)`, `interestChips(AppUser user, List<ProfileQuestion> questions)` (empty if no `interests` question).

- [ ] **Step 1: Write failing tests** in `test/question_flow_test.dart`:

```dart
test('effectiveQuestions falls back to defaults and drops inactive', () {
  expect(effectiveQuestions(null), defaultQuestions);
  expect(effectiveQuestions(const []), defaultQuestions);
  final a = ProfileQuestion.fromMap('a', {'type': 'text', 'group': 'about', 'title': 'A'})!;
  final b = ProfileQuestion.fromMap('b', {'type': 'text', 'group': 'about', 'title': 'B', 'active': false})!;
  expect(effectiveQuestions([a, b]).map((q) => q.id), ['a']);
});
group('resumeQuestionId', () {
  final qs = defaultQuestions;
  test('uses onboardingAt when it still applies', () {
    expect(resumeQuestionId(questions: qs, answers: {'gender': 'woman'}, onboardingAt: 'privatePhotos'), 'privatePhotos');
  });
  test('skips onboardingAt that no longer applies', () {
    expect(resumeQuestionId(questions: qs, answers: {'name': 'A', 'gender': 'man'}, onboardingAt: 'privatePhotos'), isNot('privatePhotos'));
  });
  test('falls back to first unanswered applicable question', () {
    expect(resumeQuestionId(questions: qs, answers: {'name': 'Sara'}, onboardingAt: 'deletedQuestion'), 'birthDate');
  });
  test('all answered → last applicable', () {
    final all = {for (final q in qs) q.id: 'x', 'gender': 'man'};
    expect(resumeQuestionId(questions: qs, answers: all), qs.lastWhere((q) => q.appliesTo(all)).id);
  });
  test('no questions → null', () {
    expect(resumeQuestionId(questions: const [], answers: const {}), isNull);
  });
});
```

- [ ] **Step 2: Run** `flutter test test/question_flow_test.dart` — Expected: FAIL (undefined symbols).
- [ ] **Step 3: Implement** repository, provider and the two pure functions; register `Provider.value(QuestionRepository)` and `ChangeNotifierProvider(QuestionsProvider)` in `main.dart`.
- [ ] **Step 4: Rewire screens.** Onboarding: show `AppLoader` until `loaded`; take a snapshot `List<ProfileQuestion>` of `questions` in `initState`/first build and index into it; initial step from `resumeQuestionId(... onboardingAt: profile.onboardingAt)`; on Next save `onboardingAt: nextId` **and** `onboardingStep: snapshotIndexOfNext` (old builds); finish when no next applicable question. Edit Profile and `ProfileCard`/`ProfileDetails` read `context.watch<QuestionsProvider>().questions`.
- [ ] **Step 5: Run** `flutter analyze && flutter test` — Expected: clean, all pass. Build & install on the connected Android device; with `amore_questions` still empty, sign-up flow looks exactly as before.
- [ ] **Step 6: Commit** `feat(questions): load onboarding questions from Firestore with local fallback`.

### Task 3: Picture answers and public custom answers on profiles

**Files:**
- Modify: `lib/onboarding/question_input.dart` (`_ChoiceAnswer`), `lib/widgets/profile_card.dart` (`ProfileDetails`, chip filter)
- Test: `test/question_schema_test.dart` (chip/section selection helpers)

**Interfaces:**
- Consumes: Task 1 `hasImageOptions`, Task 2 `profileChips(user, questions)`.
- Produces: `bool showsAsChip(ProfileQuestion q)` (public, not in the "shown elsewhere" set, type in text/height/scale/single/multi, value formats non-null); `List<ProfileQuestion> profileSections(List<ProfileQuestion> qs)` → public `longText` questions except `bio`, and public `photos` questions except `photoUrls`, in order.

- [ ] **Step 1: Write failing tests**: `showsAsChip` is false for private questions, `longText`, `photos`, `video`, and for `name`/`birthDate`/`gender`/`interestedIn`/`bio`/`photoUrls`/`interests`; true for `lookingFor`. `profileSections` of a list containing a public `photos` question `pics` and a public `longText` `story` returns `['story','pics']` in list order, never `bio`/`photoUrls`/private ones.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement.** `_ChoiceAnswer`: when `question.hasImageOptions`, render a 2-column grid of square image tiles (`CachedNetworkImage`, label under, rose 3px border + check badge when selected; options without an image show the emoji/label on `AppColors.surface`), same single/multi selection semantics as chips. `ProfileDetails`: after interests, for each `profileSections` entry with an answer: section title + paragraph (longText) or horizontal 3:4 photo strip (photos).
- [ ] **Step 4: Run** `flutter analyze && flutter test` — Expected: clean, all pass.
- [ ] **Step 5: Commit** `feat(questions): picture options and public custom answers on profiles`.

### Task 4: Admin claim, rules and their tests

**Files:**
- Create: `functions/scripts/admin.js`
- Modify: `functions/package.json` (scripts `admin:add`, `admin:remove`, `admin:list`), `firestore.rules` (Amore section), `storage.rules`

**Interfaces:**
- Produces: claim `amoreAdmin: true`; `npm run admin:add -- <email>`, `npm run admin:remove -- <email>`, `npm run admin:list` (lists users with the claim via `listUsers` pagination).

- [ ] **Step 1: Write the script.** Same ADC/quota-project setup as `seed.js`. `add`: `getUserByEmail`, `setCustomUserClaims(uid, {...(user.customClaims ?? {}), amoreAdmin: true})`. `remove`: copy claims, delete `amoreAdmin`, set (null if empty). Print "sign out and back in to the admin panel". Never print other claims' values.
- [ ] **Step 2: Rules.** Firestore, in the Amore section:
  - `function isAdmin() { return signedIn() && request.auth.token.get('amoreAdmin', false) == true; }`
  - `match /amore_questions/{qid} { allow read: if signedIn(); allow delete: if isAdmin(); allow create, update: if isAdmin() && qid.matches('^[A-Za-z][A-Za-z0-9]{0,29}$') && request.resource.data.type in ['text','longText','date','height','scale','single','multi','photos','video'] && request.resource.data.title is string && request.resource.data.title.size() > 0; }`
  - Storage: `match /amore_question_media/{questionId}/{fileName} { allow read: if request.auth != null; allow write: if request.auth != null && request.auth.token.get('amoreAdmin', false) == true && (request.resource == null || (request.resource.size < 5 * 1024 * 1024 && request.resource.contentType.matches('image/.*'))); }`
- [ ] **Step 3: Rules API tests** (script in scratchpad, same pattern as earlier runs, `token: {amoreAdmin: true}` in `auth`). Expected all SUCCESS:
  - questions: signed-in get ALLOW; signed-out get DENY; admin create valid ALLOW; non-admin create DENY; admin create `type: 'hologram'` DENY; admin create id `bad_id` DENY; admin delete ALLOW; non-admin delete DENY.
  - other apps unaffected: `users/x` write by anyone ALLOW (catch-all unchanged).
  - media: admin create 1 MB image ALLOW; admin 6 MB DENY; admin PDF DENY; non-admin create DENY; signed-in get ALLOW; signed-out get DENY.
- [ ] **Step 4: Deploy** `firebase deploy --only firestore:rules,storage` — Expected: "Deploy complete!". Run `flutter test` (unchanged, pass).
- [ ] **Step 5: Commit** `feat(admin): amoreAdmin claim scripts and question rules`.

### Task 5: Admin website shell (web target, hosting site, sign-in gate)

**Files:**
- Create: `web/` (via `flutter create --platforms=web .`; delete any generated `test/widget_test.dart`), `lib/admin/main.dart`, `lib/admin/admin_gate.dart`
- Modify: `lib/firebase_options.dart` (regenerated incl. web), `firebase.json` (flutter web config + `hosting: [{target: 'admin', public: 'build/web', ignore: [...], rewrites: [{source: '**', destination: '/index.html'}]}]`), `.firebaserc` (target `admin` → `amore-admin`)

**Interfaces:**
- Produces: `AdminGate` widget → signed out: sign-in page (Google via `FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider())`, plus email/password); signed in without claim (`getIdTokenResult(true).claims?['amoreAdmin'] == true` false): "No access" + Sign out; admin: `QuestionListScreen` (Task 6; placeholder text until then).
- Admin code must not import `dart:io`, `google_sign_in`, `services/auth_service.dart`, `onboarding/question_input.dart` or anything using `SessionProvider`.

- [ ] **Step 1:** `firebase apps:create WEB "Amore Admin"`; `flutterfire configure --project=hbgapp-c3c88 --platforms=android,ios,web` selecting the existing Amore Android/iOS apps and the new web app. Verify `DefaultFirebaseOptions.web` exists and Android/iOS ids are unchanged.
- [ ] **Step 2:** `firebase hosting:sites:create amore-admin`; `firebase target:apply hosting admin amore-admin`.
- [ ] **Step 3:** Implement `lib/admin/main.dart` (init Firebase with `DefaultFirebaseOptions.web`, `MaterialApp` titled "Amore Admin", `buildTheme()`, home `AdminGate`) and `admin_gate.dart`.
- [ ] **Step 4:** `flutter build web -t lib/admin/main.dart --release` — Expected: "✓ Built build/web". `flutter analyze && flutter test` clean.
- [ ] **Step 5:** `firebase deploy --only hosting:admin` — Expected URL `https://amore-admin.web.app`. Check Auth authorized domains via `GET https://identitytoolkit.googleapis.com/admin/v2/projects/hbgapp-c3c88/config`; if `amore-admin.web.app` is missing, `PATCH ...config?updateMask=authorizedDomains` with the **existing list plus** `amore-admin.web.app` and `amore-admin.firebaseapp.com`.
- [ ] **Step 6: Commit** `feat(admin): web admin shell with admin-only sign-in`.

### Task 6: Question list (import, reorder, show/hide, duplicate, delete)

**Files:**
- Create: `lib/admin/question_list_screen.dart`

**Interfaces:**
- Consumes: Task 2 `QuestionRepository` (`watchAll`, `reorder`, `upsert`, `delete`, `importDefaults`), Task 1 `system`, `dependentsOf`, `slugId`.
- Produces: `QuestionListScreen`; navigates to `QuestionEditorScreen(existing: ProfileQuestion?, all: List<ProfileQuestion>)` (Task 7).

- [ ] **Step 1: Implement.** Top bar: "Questions", signed-in email, Sign out. Empty collection → centered "Import built-in questions" button (calls `importDefaults`, snackbar with count). Otherwise `ReorderableListView` (drag handle) of tiles: title, id in muted text, badges (type, Required, Private, Conditional "if gender = woman", System lock, Hidden), active `Switch` (system → confirm dialog "Hiding a core question can break sign-up/matching"), menu: Edit, Duplicate (`id = slugId('${q.id}Copy', ids)`, `active: false`), Delete (disabled for system; confirm dialog listing `dependentsOf(q.id, all)`; note "users' saved answers are kept"). FAB "New question". A banner when `genderValueMismatch` is non-empty.
- [ ] **Step 2: Verify** `flutter analyze` clean; `flutter build web -t lib/admin/main.dart` builds.
- [ ] **Step 3: Commit** `feat(admin): question list with import, reorder, hide and delete`.

### Task 7: Question editor form

**Files:**
- Create: `lib/admin/question_editor_screen.dart`, `lib/admin/option_editor.dart`, `lib/admin/question_preview.dart`

**Interfaces:**
- Consumes: Task 1 `validateQuestionDefinition`, `slugId`, `dependentsOf`, `ProfileQuestion.fromMap`; Task 2 `QuestionRepository.upsert`; `Backend.storage`.
- Produces: `QuestionEditorScreen({ProfileQuestion? existing, required List<ProfileQuestion> all})`.

- [ ] **Step 1: Implement the form** on a `Map<String, dynamic>` draft (seeded from `existing.toMap()` or defaults `{type: 'single', group: 'about', required: false, private: false, active: true, order: max+10}`):
  - Common: Title, Subtitle, Section (group dropdown), Type (dropdown; disabled when editing), ID (auto `slugId(title)` while new, editable while new, read-only after), Required switch, Public/Private segmented control (disabled when editing; forced Private for video), Profile chip emoji (`chipIcon`).
  - single/multi: `OptionEditor` rows — label, emoji, image (upload via `ImagePicker().pickImage` → `readAsBytes` → `Backend.storage.ref('amore_question_media/$id/${ts}.jpg').putData(bytes, SettableMetadata(contentType: 'image/jpeg'))` → `getDownloadURL()`), remove (warn if editing and `dependentsOf(id, all, value:)` non-empty or value existed before), drag reorder; value = `slugId(label, takenValues)` generated once at row creation, shown muted, read-only. multi: min/max select.
  - text/longText: max length. scale: min, max, low/high labels, format template (default `{v}`). photos: min/max count (1–10). video: seconds (5–180).
  - "Show only if": off / question dropdown (other single/multi questions) + value chips.
  - System question: banner "Core question — matching depends on it" and confirm dialog on save if `required` turned off.
  - Save: `validateQuestionDefinition(...)` → errors listed inline, else `repo.upsert(id, draft)` and pop. `QuestionPreview` (right column on wide screens) renders title, subtitle and options as chips or image tiles from `ProfileQuestion.fromMap(id, draft)`.
- [ ] **Step 2: Verify** `flutter analyze && flutter test` clean; `flutter build web -t lib/admin/main.dart` builds.
- [ ] **Step 3: Commit** `feat(admin): question editor with options, images, conditions and validation`.

### Task 8: Ship and verify end to end

**Files:**
- Modify: `CLAUDE.md` (admin panel section: URL, build/deploy commands, claim scripts, never deploy to default hosting site), `README.md` (short admin section)

- [ ] **Step 1:** `flutter build web -t lib/admin/main.dart --release && firebase deploy --only hosting:admin`.
- [ ] **Step 2:** Grant the owner's admin email: `cd functions && npm run admin:add -- <email>` (email supplied by the user).
- [ ] **Step 3: Manual checks** (owner in browser, app on Android):
  - non-admin Google account → "No access";
  - admin → Import built-in questions → app sign-up identical to before;
  - add public single-choice question with 2 image options → appears in onboarding as image grid and as a chip on the profile;
  - add private photos question (min 1, max 2) → asked, never shown to others;
  - reorder two questions → app follows after reopening onboarding/Edit Profile;
  - hide a question → disappears from app.
- [ ] **Step 4:** `flutter analyze && flutter test` — clean, pass.
- [ ] **Step 5: Commit** `docs: admin question panel usage`.
