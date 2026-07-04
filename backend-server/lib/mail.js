const { Resend } = require('resend');

const BRAND = 'Marquee';

function getFromAddress() {
  const configured = process.env.MAIL_FROM?.trim();
  if (configured) return configured;
  return 'onboarding@resend.dev';
}

async function sendPasswordResetEmail({ to, resetUrl }) {
  const apiKey = process.env.RESEND_API_KEY;
  const from = getFromAddress();

  const subject = `Reset your ${BRAND} password`;
  const text = [
    `We received a request to reset your ${BRAND} password.`,
    '',
    `Reset your password (link expires in 1 hour):`,
    resetUrl,
    '',
    `If you did not request this, you can ignore this email.`,
  ].join('\n');

  const html = `
    <p>We received a request to reset your ${BRAND} password.</p>
    <p><a href="${resetUrl}">Reset your password</a> — this link expires in 1 hour.</p>
    <p>If you did not request this, you can ignore this email.</p>
  `.trim();

  if (!apiKey) {
    console.warn('[mail] RESEND_API_KEY not set — password reset link for', to, ':', resetUrl);
    return { devMode: true };
  }

  const resend = new Resend(apiKey);
  const result = await resend.emails.send({
    from,
    to,
    subject,
    html,
    text,
  });

  if (result.error) {
    console.error('[mail] Resend error:', result.error);
    const err = new Error(result.error.message || 'Failed to send email.');
    err.status = 502;
    throw err;
  }

  console.log('[mail] Password reset sent to', to, 'id:', result.data?.id);
  return result.data;
}

module.exports = { sendPasswordResetEmail };
