#!/usr/bin/env node
/**
 * Seeds Amore with test profiles (and likes toward real users, so swiping
 * right on them produces matches). Every seeded document has `seed: true`.
 *
 *   node functions/scripts/seed.js            # add/refresh 30 seed profiles
 *   node functions/scripts/seed.js --count 50
 *   node functions/scripts/seed.js --clean    # remove all seed data
 *
 * Auth: Application Default Credentials (`gcloud auth application-default login`).
 * Writes only to amore_* collections in the shared hbgapp-c3c88 project.
 *
 * Seed ids contain no '_' — chat ids are `{uidA}_{uidB}` and are split on it.
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

const PROJECT_ID = 'hbgapp-c3c88';
process.env.GOOGLE_CLOUD_QUOTA_PROJECT ??= PROJECT_ID;
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const db = getFirestore();

const args = process.argv.slice(2);
const CLEAN = args.includes('--clean');
const COUNT = Number(args[args.indexOf('--count') + 1]) || 30;

// Deterministic PRNG so re-running produces the same people (idempotent).
let state = 20261021;
const rand = () => ((state = (state * 1664525 + 1013904223) >>> 0) / 2 ** 32);
const pick = (list) => list[Math.floor(rand() * list.length)];
const pickSome = (list, min, max) => {
  const n = min + Math.floor(rand() * (max - min + 1));
  return [...list].sort(() => rand() - 0.5).slice(0, n);
};
const maybe = (p, value) => (rand() < p ? value : null);

// Option values must match lib/onboarding/questions.dart.
const WOMEN = ['Sara', 'Ayesha', 'Emma', 'Olivia', 'Zara', 'Mia', 'Hana', 'Sophia', 'Isabella', 'Amelia',
  'Fatima', 'Chloe', 'Layla', 'Ava', 'Grace', 'Noor', 'Lily', 'Maya', 'Ella', 'Aria'];
const MEN = ['Ali', 'James', 'Omar', 'Liam', 'Noah', 'Hamza', 'Ethan', 'Lucas', 'Daniel', 'Adam',
  'Bilal', 'Ryan', 'Zain', 'Leo', 'Owen', 'Yusuf', 'Jack', 'Henry', 'Samuel', 'Elijah'];
const CITIES = ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Austin', 'Miami', 'Seattle', 'Boston',
  'San Francisco', 'Atlanta', 'Denver', 'Dallas', 'Lahore', 'Karachi', 'Islamabad', 'Toronto', 'London', 'Dubai'];
const INTERESTS = ['travel', 'music', 'movies', 'reading', 'cooking', 'foodie', 'coffee', 'fitness', 'hiking',
  'yoga', 'football', 'cricket', 'gaming', 'art', 'photography', 'dancing', 'pets', 'tech', 'fashion', 'nature'];
const LOOKING_FOR = ['long_term', 'long_term', 'short_term', 'casual', 'friends', 'unsure'];
const YSN = ['yes', 'sometimes', 'sometimes', 'no', 'no', 'prefer_not'];
const EXERCISE = ['daily', 'often', 'sometimes', 'never'];
const PETS = ['dog', 'cat', 'other', 'none_want', 'none'];
const RELIGION = ['muslim', 'christian', 'hindu', 'sikh', 'buddhist', 'jewish', 'spiritual', 'agnostic',
  'atheist', 'other', 'prefer_not'];
const KIDS_HAVE = ['no', 'no', 'no', 'yes', 'prefer_not'];
const KIDS_WANT = ['want', 'open', 'dont_want', 'unsure'];
const BIOS = [
  'Coffee first, adventures second. Looking for someone to explore new places with.',
  'Weekend hiker, weekday software person. Tell me your favourite trail.',
  'Big on family, bigger on biryani. Let\'s find the best spot in town.',
  'Bookworm with a passport. Currently reading three books at once.',
  'Gym in the morning, Netflix at night. Balance is everything.',
  'Amateur chef. I will absolutely cook for you if you bring dessert.',
  'Dog parent. Yes, he comes first. Sorry in advance.',
  'Into live music, late-night chai and long conversations.',
  'Trying every coffee shop in the city. Halfway there.',
  'Photographer by hobby. Let me take your next profile pic.',
  'Love a good debate about movies. Strong opinions, loosely held.',
  'Cricket on weekends, football on weekdays.',
  'Here for something real. Kindness is attractive.',
  'Sunsets, road trips, and playlists for every mood.',
];

function profile(i) {
  const gender = i % 9 === 8 ? 'nonbinary' : i % 2 === 0 ? 'woman' : 'man';
  const names = gender === 'man' ? MEN : gender === 'woman' ? WOMEN : [...WOMEN, ...MEN];
  const photoGender = gender === 'man' ? 'men' : 'women';
  const photoIndex = (i * 7) % 99;
  const age = 21 + Math.floor(rand() * 18);
  const birth = new Date(Date.UTC(2026 - age, Math.floor(rand() * 12), 1 + Math.floor(rand() * 27)));
  const interestedIn = gender === 'woman' ? pick([['man'], ['man'], ['man', 'nonbinary'], ['woman', 'man']])
    : gender === 'man' ? pick([['woman'], ['woman'], ['woman', 'nonbinary']])
    : ['woman', 'man', 'nonbinary'];
  const createdAt = Timestamp.fromMillis(Date.now() - Math.floor(rand() * 30 * 24 * 3600 * 1000));
  return {
    name: pick(names),
    birthDate: Timestamp.fromDate(birth),
    gender,
    interestedIn,
    heightCm: maybe(0.85, gender === 'man' ? 168 + Math.floor(rand() * 22) : 155 + Math.floor(rand() * 20)),
    city: maybe(0.9, pick(CITIES)),
    lookingFor: pick(LOOKING_FOR),
    interests: pickSome(INTERESTS, 3, 8),
    drinking: maybe(0.8, pick(YSN)),
    smoking: maybe(0.8, pick(YSN)),
    exercise: maybe(0.8, pick(EXERCISE)),
    pets: maybe(0.6, pickSome(PETS, 1, 2)),
    religion: maybe(0.7, pick(RELIGION)),
    kidsHave: maybe(0.7, pick(KIDS_HAVE)),
    kidsWant: maybe(0.7, pick(KIDS_WANT)),
    bio: maybe(0.85, pick(BIOS)),
    photoUrls: [`https://randomuser.me/api/portraits/${photoGender}/${photoIndex}.jpg`],
    onboardingStep: 17,
    onboardingComplete: true,
    createdAt,
    updatedAt: createdAt,
    seed: true,
  };
}

const seedId = (i) => `seedUser${String(i + 1).padStart(2, '0')}`;

async function commitAll(writes) {
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    writes.slice(i, i + 400).forEach((w) => w(batch));
    await batch.commit();
  }
}

async function seed() {
  const people = Array.from({ length: COUNT }, (_, i) => [seedId(i), profile(i)]);
  await commitAll(people.map(([id, data]) => (b) => b.set(db.collection('amore_users').doc(id), data)));
  console.log(`✔ ${people.length} seed profiles written to amore_users`);

  // Each compatible seed person likes ~half of the real users, so swiping
  // right on them in Discover creates a match.
  const real = (await db.collection('amore_users').where('onboardingComplete', '==', true).get())
    .docs.filter((d) => !d.get('seed'));
  const likes = [];
  for (const user of real) {
    const g = user.get('gender');
    const wants = user.get('interestedIn') || [];
    for (const [id, p] of people) {
      if (!g || !p.interestedIn.includes(g) || !wants.includes(p.gender) || rand() < 0.5) continue;
      likes.push((b) => b.set(db.collection('amore_swipes').doc(`${id}_${user.id}`), {
        from: id, to: user.id, liked: true, createdAt: FieldValue.serverTimestamp(), seed: true,
      }));
    }
  }
  await commitAll(likes);
  console.log(`✔ ${likes.length} seed likes toward ${real.length} real user(s)`);
}

async function clean() {
  const users = await db.collection('amore_users').where('seed', '==', true).get();
  const ids = new Set(users.docs.map((d) => d.id));
  const swipes = await db.collection('amore_swipes').where('seed', '==', true).get();
  // Swipes/matches/blocks that real users made toward seed people.
  const toSeed = (await db.collection('amore_swipes').get()).docs.filter((d) => ids.has(d.get('to')));
  const matches = (await db.collection('amore_matches').get()).docs
    .filter((d) => (d.get('users') || []).some((u) => ids.has(u)));
  const blocks = (await db.collection('amore_blocks').get()).docs
    .filter((d) => ids.has(d.get('blocked')) || ids.has(d.get('blocker')));

  for (const m of matches) await db.recursiveDelete(m.ref); // includes messages
  await commitAll([...users.docs, ...swipes.docs, ...toSeed, ...blocks].map((d) => (b) => b.delete(d.ref)));
  console.log(`✔ removed ${users.size} profiles, ${swipes.size + toSeed.length} swipes, `
    + `${matches.length} chats, ${blocks.length} blocks`);
}

(CLEAN ? clean() : seed()).then(() => process.exit(0)).catch((e) => {
  console.error('✖', e.message);
  process.exit(1);
});
