# Admin question panel — design

Date: 2026-10-22 · Status: draft for approval

## Intent

The owner wants to change Amore's onboarding without shipping a new app
build: add questions, write their options, decide whether each is required,
and decide whether answers are public (shown on the profile) or private
(only the user, and later the AI). Some questions are answered by uploading
images, and some offer picture options to choose from.

Today every question is a `const` entry in `lib/onboarding/questions.dart`
(`profileQuestions`), so any change needs a code change and a new app build.

## Goals

- A **website** admin panel (opened in a desktop browser) where an admin can:
  - list all questions in order, drag to reorder, show/hide (active) each;
  - create, edit, duplicate and delete questions;
  - per question set: section, type, title, subtitle, required, public/private,
    type-specific settings (options, min/max, slider range and labels, photo
    count, video length), and an optional "show only if" condition;
  - upload an image per option ("picture answers");
  - create "upload as the answer" questions (photos, with min/max count; video
    with exact length), public or private.
- **Everything is editable**, including the core questions (name, birthday,
  gender, interested in, profile photo) — with guardrails (below).
- The phone app reads questions live from Firestore. Changes apply on the next
  app start / screen open, with no new build.
- All of today's questions are carried over unchanged (including women-only
  private photos and 30 s video, the 2-minute video, the private sliders).

## Non-goals (this version)

- Forcing existing, already-onboarded users through newly added required
  questions (they see them as "Required" in Edit Profile, as today).
- Translations, A/B tests, scheduled publishing, edit history/undo.
- An admin view of users' answers (answers stay in Firestore/console).
- Multiple admin roles/permissions (one level: admin).

## Anti-goals (would be a failure even if it "works")

- Any other app in the shared `hbgapp-c3c88` project is affected (their rules,
  hosting site, auth claims, data).
- A non-admin can change questions or upload option images.
- An admin edit silently breaks matching or crashes the app for existing users.
- Private answers become visible to other users.

## Constraints

- Shared Firebase project `hbgapp-c3c88`. The **default hosting site
  `hbgapp-c3c88.web.app` belongs to HabitBeGone** — never deploy to it.
- Storage rules cannot read Firestore in this project (missing service-agent
  role), so admin checks in Storage must come from the auth token.
- Auth is shared project-wide; other apps may already use custom claims.
- CLI account is Editor (can create hosting sites, web apps, set custom claims
  via Admin SDK; cannot grant IAM).
- User ids/question ids are used as Firestore field names; question ids must be
  `[A-Za-z][A-Za-z0-9]*` (no `_`, no dots), unique, and immutable once created.

## Decisions (made with the owner)

- Admin panel is a website (not inside the phone app).
- Everything editable, including core questions.
- "Answer-based" means: picture answers (option images) and upload-as-answer.
- Each question has a public/private switch.

## Design

### Data: `amore_questions/{id}`

One document per question; the doc id is the question id and the answer key.

| field | meaning |
|---|---|
| `order` | number; list order (fractional allowed for drag-reorder) |
| `active` | bool; inactive questions are not asked or shown |
| `system` | bool; core question (see guardrails) |
| `group` | section key: basics, intentions, interests, lifestyle, personal, about |
| `type` | text, longText, date, height, scale, single, multi, photos, video |
| `title`, `subtitle` | strings |
| `required`, `private` | bools |
| `options` | list of `{value, label, emoji?, imageUrl?}` (single/multi) |
| `minSelect`, `maxSelect` | ints (multi, photos) |
| `maxLength` | int (text) |
| `scaleMin`, `scaleMax`, `lowLabel`, `highLabel`, `scaleFormat` | slider; format is a template such as `{v} / 10` or `Age {v}` |
| `videoSeconds` | int (video) |
| `showIf` | optional `{questionId, values: [..]}` — asked only if that answer is one of `values` (for multi answers: any overlap) |
| `chipIcon` | optional emoji prefix for profile chips |
| `updatedAt` | server timestamp |

`ProfileQuestion` gains `fromMap`/`toMap`; the function-typed fields used today
(`showIf`, `scaleFormat`) become data (`ShowIf` value class, template string).
The current const list becomes `defaultQuestions` — used as the import source,
the offline/empty fallback, and in tests.

### Admin identity

- Custom auth claim **`amoreAdmin: true`** (namespaced so it cannot collide with
  other apps' claims). Checked by Firestore and Storage rules and by the panel.
- Granted by a script `npm run admin:add -- <email>` (Admin SDK via ADC). It
  **merges** with the user's existing claims (`setCustomUserClaims` replaces the
  whole set, which could otherwise wipe another app's claims). `admin:remove`
  likewise. The admin signs out/in (or token refresh) to pick it up.

### Rules

- Firestore `amore_questions/{id}`: read if signed in; write only if
  `request.auth.token.amoreAdmin == true`, with basic shape checks (type in the
  allowed list, `title` string, id format).
- Storage `amore_question_media/{questionId}/{file}`: read if signed in; write
  only with the `amoreAdmin` claim, images < 5 MB.
- Option images use download URLs (public content by design).
- Existing user rules already allow arbitrary answer keys on `amore_users/{uid}`
  (owner) and `private/profile` (owner) — no change needed.

### Phone app

- `QuestionsProvider` streams `amore_questions` ordered by `order`, keeps
  `active` ones, falls back to `defaultQuestions` if the collection is empty or
  unreachable on first load. Onboarding, Edit Profile, profile chips and
  ProfileDetails read questions from it (replacing the global const list).
- **Old builds**: only test devices run the app today, so there is no
  forced-update gate. The new app still writes `onboardingStep` (index) next to
  `onboardingAt` so an older build mid-onboarding is not stranded. *(Builder's
  call.)*
- **Resume by id, not index**: onboarding saves `onboardingAt` (next question
  id). On resume: that question if it still exists and applies; otherwise the
  first applicable question with no answer; otherwise the last applicable one.
  (Index-based `onboardingStep` breaks when the admin reorders or inserts.)
- **Picture answers**: single/multi questions whose options have images render
  as an image grid (tap to select) instead of chips.
- **Upload answers**: existing photos/video inputs, driven by data; public photos
  go to `users/{uid}/photos/` (download URL on the public doc), private ones to
  `users/{uid}/private/` (path on the private doc) — unchanged mechanisms.
- **Public custom answers on the profile**: short answers as chips (as today);
  `longText` as a titled paragraph; public `photos` questions other than
  `photoUrls` as a titled photo strip in ProfileDetails. Private: never shown.
- Code that reads specific ids keeps working: `name`, `birthDate` (18+ check),
  `gender`/`interestedIn` (matching), `photoUrls`, `interests`, `bio`, `city`.
  Each must tolerate the question being missing/hidden.

### Guardrails for "everything editable"

- `system` questions: name, birthDate, gender, interestedIn, photoUrls. They
  cannot be deleted or change id/type; the panel warns before making them
  optional or hiding them. Labels, titles, subtitles, emoji, order are free.
- gender / interestedIn options: values cannot be renamed; removing a value
  shows a warning (existing users have it). The panel warns if the two lists'
  values differ (matching compares them).
- Deleting a question never deletes users' stored answers.
- Changing a question's **type or public/private** after creation is blocked;
  duplicate it instead. *(Builder's call.)* Flipping private→public would expose
  nothing new, but public→private would leave existing answers on the public
  doc / behind download URLs, and moving them needs an Admin SDK migration.
- **Option values are immutable for every choice question**, not only
  gender/interestedIn: the panel generates a value from the label once, and
  later edits change only the label/emoji/image. Removing an option warns that
  existing answers keep the old value, and lists any `showIf` conditions that
  depend on it. Orphaned values are not shown on profiles. *(Builder's call.)*
- Live validation in the form (unique ids/values, min ≤ max, choice questions
  need ≥ 1 option, video seconds 5–180 (a 2-minute clip is ~250 MB and the
  private-video Storage cap is 400 MB) *(builder's call)*, slider min < max).

### Admin website

- Flutter web, same repo, separate entrypoint `lib/admin/main.dart`, sharing the
  question model/validation with the app. Built with
  `flutter build web -t lib/admin/main.dart`.
- Registered as a new Firebase **web app** "Amore Admin"; deployed to a new
  hosting site **`amore-admin`** (`amore-admin.web.app`) via a hosting target —
  `firebase deploy --only hosting:admin`. The site's domain is added to Auth
  authorized domains if not automatic.
- Sign-in with Google (popup) or email/password; non-admins see "No access".
- Screens: question list (drag reorder, active toggle, badges for type /
  required / private / conditional / system) → editor form with type-specific
  sections and a small phone-style preview; "Import built-in questions" button
  shown when the collection is empty (writes `defaultQuestions`).

## Verification

- Unit tests: `toMap`/`fromMap` round-trip for every default question; ShowIf
  evaluation (single and multi); resume-by-id logic; validation unchanged.
- Rules tests via the Rules API: admin vs non-admin writes on
  `amore_questions` and `amore_question_media`; signed-out reads denied.
- Manual: import defaults → app behaves exactly as before; add a public
  single-choice question with picture options → appears in onboarding and as a
  chip; add a private photos question → owner-only; reorder → app follows.

## Left to the builder

- Exact panel layout and styling (match the app's dark rose theme).
- Fractional vs integer reordering scheme.
- Shape-check depth in Firestore rules beyond the ones listed.
