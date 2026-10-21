/**
 * Amore push notifications. Deployed as the `amore` codebase inside the
 * shared hbgapp-c3c88 project, so deploys never touch other apps' functions:
 *   firebase deploy --only functions:amore
 */
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { logger } = require('firebase-functions');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

const REGION = 'us-central1';
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** Never reveal media, and never preview view-once content. */
function bodyFor(msg) {
  switch (msg.type) {
    case 'photo':
      return msg.viewOnce ? '🔥 Sent a view-once photo' : '📷 Sent a photo';
    case 'video':
      return msg.viewOnce ? '🔥 Sent a view-once video' : '🎥 Sent a video';
    default: {
      const text = String(msg.text || '');
      return text.length > 120 ? `${text.slice(0, 117)}…` : text;
    }
  }
}

/** Sends to every device of `uid` and prunes tokens FCM reports as dead. */
async function notifyUser(uid, { title, body, data }) {
  // Tokens live in a private doc only the owner (and admin) can read.
  const userRef = db.collection('amore_users').doc(uid).collection('private').doc('devices');
  const snap = await userRef.get();
  const tokens = snap.get('fcmTokens') || [];
  if (tokens.length === 0) return;

  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: { channelId: 'amore_messages', color: '#E5395C', tag: data.matchId },
    },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  const dead = res.responses
    .map((r, i) => (!r.success && DEAD_TOKEN_CODES.has(r.error?.code) ? tokens[i] : null))
    .filter(Boolean);
  if (dead.length) {
    await userRef.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
    logger.info('Removed dead tokens', { uid, count: dead.length });
  }
}

exports.amoreOnMessage = onDocumentCreated(
  { document: 'amore_matches/{matchId}/messages/{messageId}', region: REGION },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const { matchId } = event.params;
    const users = matchId.split('_');
    const recipient = users.find((u) => u !== msg.senderId);
    if (!recipient || !users.includes(msg.senderId)) return;

    const sender = await db.collection('amore_users').doc(msg.senderId).get();
    const name = (sender.get('name') || 'Someone').trim();
    await notifyUser(recipient, {
      title: name,
      body: bodyFor(msg),
      data: { type: 'message', matchId },
    });
  },
);

exports.amoreOnMatch = onDocumentCreated(
  { document: 'amore_matches/{matchId}', region: REGION },
  async (event) => {
    const match = event.data?.data();
    if (!match?.users?.length) return;
    // Chats started from Community aren't matches; their first message notifies.
    if (match.source === 'community') return;
    const { matchId } = event.params;
    // Both get notified: the person who swiped last also sees the in-app
    // dialog, but the app hides pushes for screens already showing them.
    await Promise.all(
      match.users.map(async (uid) => {
        const otherId = match.users.find((u) => u !== uid);
        const other = await db.collection('amore_users').doc(otherId).get();
        const name = (other.get('name') || 'Someone').trim();
        await notifyUser(uid, {
          title: "It's a match! 💘",
          body: `You and ${name} liked each other. Say hi!`,
          data: { type: 'match', matchId },
        });
      }),
    );
  },
);
