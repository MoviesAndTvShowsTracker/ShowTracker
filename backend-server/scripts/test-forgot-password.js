/* Forgot password answers the same way, at the same speed, whether or not the account exists. No DB. */
const assert = require('assert');
const { requestPasswordReset, RESET_RESPONSE } = require('../services/passwordResetFlow');

(async () => {
  const sent = [];
  let release;
  const slowSend = new Promise((r) => { release = r; });
  const deps = {
    findUser: async (email) => (email === 'known@x.com' ? { email } : null),
    issueReset: async (user) => { await slowSend; sent.push(user.email); },
    log: () => {},
  };

  const known = await requestPasswordReset('Known@X.com', deps);
  const unknown = await requestPasswordReset('nobody@x.com', deps);
  assert.deepStrictEqual(known, unknown, 'identical answers');
  assert.deepStrictEqual(known, RESET_RESPONSE);
  assert.strictEqual(sent.length, 0, 'answers before the email work finishes (no timing signal)');
  release();
  await new Promise((r) => setTimeout(r, 10));
  assert.deepStrictEqual(sent, ['known@x.com'], 'the real account still gets its email');

  // A mail failure is logged, never shown.
  const logged = [];
  const failing = await requestPasswordReset('known@x.com', {
    ...deps, issueReset: async () => { throw new Error('mail down'); }, log: (m) => logged.push(m),
  });
  assert.deepStrictEqual(failing, RESET_RESPONSE);
  await new Promise((r) => setTimeout(r, 10));
  assert.strictEqual(logged.length, 1);

  // Missing email is still a client error.
  await assert.rejects(requestPasswordReset('  ', deps), (e) => e.status === 400);

  console.log('forgot password: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
