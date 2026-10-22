#!/usr/bin/env node
/**
 * Grants or removes Amore admin access (custom auth claim `amoreAdmin`).
 *
 *   npm run admin:add -- someone@example.com
 *   ADMIN_PASSWORD=... npm run admin:add -- admin@amore.com --create
 *   npm run admin:remove -- someone@example.com
 *   npm run admin:list
 *
 * Auth accounts are shared with the other apps in hbgapp-c3c88, so claims
 * are merged: other apps' claims on the same account are kept as they are.
 * `--create` makes an email/password account first if none exists; the
 * password comes from ADMIN_PASSWORD and is never printed.
 */
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const PROJECT_ID = 'hbgapp-c3c88';
process.env.GOOGLE_CLOUD_QUOTA_PROJECT ??= PROJECT_ID;
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
const auth = getAuth();

const [command, email, ...flags] = process.argv.slice(2);

async function findOrCreate(address) {
  try {
    return await auth.getUserByEmail(address);
  } catch (e) {
    if (e.code !== 'auth/user-not-found' || !flags.includes('--create')) throw e;
    const password = process.env.ADMIN_PASSWORD;
    if (!password) throw new Error('set ADMIN_PASSWORD to create the account');
    console.log(`creating account ${address}`);
    return auth.createUser({ email: address, password, emailVerified: true });
  }
}

async function add() {
  const user = await findOrCreate(email);
  await auth.setCustomUserClaims(user.uid, { ...(user.customClaims ?? {}), amoreAdmin: true });
  console.log(`✔ ${email} is now an Amore admin. Sign out and back in to the admin panel.`);
}

async function remove() {
  const user = await auth.getUserByEmail(email);
  const claims = { ...(user.customClaims ?? {}) };
  delete claims.amoreAdmin;
  await auth.setCustomUserClaims(user.uid, Object.keys(claims).length ? claims : null);
  console.log(`✔ ${email} is no longer an Amore admin.`);
}

async function list() {
  let token;
  do {
    const page = await auth.listUsers(1000, token);
    for (const u of page.users) {
      if (u.customClaims?.amoreAdmin === true) console.log(u.email ?? u.uid);
    }
    token = page.pageToken;
  } while (token);
}

const run = { add, remove, list }[command];
if (!run || (command !== 'list' && !email)) {
  console.error('usage: admin.js add|remove <email> [--create] | list');
  process.exit(1);
}
run().then(() => process.exit(0)).catch((e) => {
  console.error('✖', e.message);
  process.exit(1);
});
