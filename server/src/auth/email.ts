import nodemailer, { type Transporter } from 'nodemailer';

import { env } from '../config.js';

let transporter: Transporter | null | undefined;

function mailer(): Transporter | null {
  if (transporter !== undefined) return transporter;
  if (!env.SMTP_HOST) {
    transporter = null;
    return null;
  }
  transporter = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_SECURE,
    auth:
      env.SMTP_USER || env.SMTP_PASS
        ? { user: env.SMTP_USER, pass: env.SMTP_PASS }
        : undefined,
    // One connection at most: recovery emails are rare and must not keep a
    // permanent SMTP pool open.
    pool: false,
  });
  return transporter;
}

export function isEmailConfigured(): boolean {
  return Boolean(env.SMTP_HOST);
}

/**
 * Sends a password-reset deep link. Returns false when SMTP is not configured;
 * the API then reports manual delivery only in development.
 */
export async function sendPasswordResetEmail(
  email: string,
  token: string,
): Promise<boolean> {
  const transport = mailer();
  if (!transport) return false;
  const resetUrl = env.PASSWORD_RESET_URL.replace(
    '{token}',
    encodeURIComponent(token),
  );
  await transport.sendMail({
    from: env.SMTP_FROM,
    to: email,
    subject: 'MediaCRM: восстановление доступа',
    text: [
      'Вы запросили восстановление доступа к MediaCRM.',
      '',
      `Ссылка действует 30 минут: ${resetUrl}`,
      '',
      'Если вы не запрашивали сброс, просто проигнорируйте письмо.',
    ].join('\n'),
    html: [
      '<p>Вы запросили восстановление доступа к MediaCRM.</p>',
      `<p><a href="${resetUrl}">Сменить пароль</a> (ссылка действует 30 минут).</p>`,
      '<p>Если вы не запрашивали сброс, просто проигнорируйте письмо.</p>',
    ].join(''),
  });
  return true;
}
