// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/smtp-transport.test.js
//
// Teste les mécanismes critiques de supabase/functions/_shared/mail/smtp.ts :
// - RFC 2047 : encodage exclusif du display-name (From, To, Reply-To)
// - RFC 2045 : pliage base64 à 76 colonnes (logos volumineux, immunité dot-stuffing)
// - Protection STARTTLS et validation SMTP_HOST (DOC-SILENCE-1)

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SMTP_SRC = new URL('../../supabase/functions/_shared/mail/smtp.ts', import.meta.url);
const SMTP_CODE = transformSync(readFileSync(SMTP_SRC, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

// Évaluation du module transpiler en CommonJS
function loadSmtpModule() {
  const mod = { exports: {} };
  const fn = new Function('module', 'exports', 'Deno', SMTP_CODE);
  fn(mod, mod.exports, { env: { get: () => '' } });
  return mod.exports;
}

const { encodeAddress, encodeUtf8Header, toBase64Wrapped, extractEmail } = loadSmtpModule();

describe('smtp.ts — conformité RFC 2047 (encodage display-name)', () => {
  it('n’encode que le display-name avec accents et laisse l’adresse en clair', () => {
    const raw = 'Biblioteca Libertária Maxwell Ferreira <contact@blmf.org>';
    const encoded = encodeAddress(raw);
    expect(encoded).toBe('=?UTF-8?B?QmlibGlvdGVjYSBMaWJlcnTDoXJpYSBNYXh3ZWxsIEZlcnJlaXJh?= <contact@blmf.org>');
    expect(encoded).toContain('<contact@blmf.org>');
    expect(encoded.endsWith('<contact@blmf.org>')).toBe(true);
  });

  it('gère les bibliothèques françaises avec accents et parenthèses', () => {
    const raw = 'Bibliothèque Solidaires (Paris, France) <contact@solidaires.org>';
    const encoded = encodeAddress(raw);
    expect(encoded).toBe('=?UTF-8?B?QmlibGlvdGjDqHF1ZSBTb2xpZGFpcmVzIChQYXJpcywgRnJhbmNlKQ==?= <contact@solidaires.org>');
    expect(encoded).toContain('<contact@solidaires.org>');
  });

  it('laisse intacte une adresse ASCII pure sans encoder', () => {
    const raw = 'Admin AnarBib <admin@anarbib.local>';
    const encoded = encodeAddress(raw);
    expect(encoded).toBe('Admin AnarBib <admin@anarbib.local>');
  });

  it('gère une adresse seule sans display-name', () => {
    expect(encodeAddress('simple@anarbib.local')).toBe('simple@anarbib.local');
    expect(encodeAddress('<simple@anarbib.local>')).toBe('<simple@anarbib.local>');
  });
});

describe('smtp.ts — conformité RFC 2045 (pliage base64 à 76 caractères)', () => {
  it('plie le contenu base64 à 76 colonnes max par ligne pour les gros contenus', () => {
    // Simule un long contenu HTML avec un logo base64
    const longHtml = '<img src="data:image/png;base64,' + 'A'.repeat(5000) + '">';
    const wrapped = toBase64Wrapped(longHtml);
    const lines = wrapped.split('\r\n');

    expect(lines.length).toBeGreaterThan(1);
    for (const line of lines) {
      expect(line.length).toBeLessThanOrEqual(76);
    }
  });

  it('immunise contre le dot-stuffing (aucun point en début de ligne SMTP)', () => {
    const textWithLeadingDots = '.Ligne avec un point\r\n..Deux points\r\n.';
    const wrapped = toBase64Wrapped(textWithLeadingDots);
    // En base64, l'alphabet ne contient que [A-Za-z0-9+/=], JAMAIS de point en début de ligne
    const lines = wrapped.split('\r\n');
    for (const line of lines) {
      expect(line.startsWith('.')).toBe(false);
    }
  });
});

describe('email.ts — aiguillage strict DOC-SILENCE-1', () => {
  it('lève une erreur lisible si MAIL_TRANSPORT=smtp est défini sans SMTP_HOST', async () => {
    const EMAIL_SRC = new URL('../../supabase/functions/_shared/transport/email.ts', import.meta.url);
    const EMAIL_CODE = transformSync(readFileSync(EMAIL_SRC, 'utf8'), {
      loader: 'ts', format: 'cjs', target: 'es2022',
    }).code;

    const mod = { exports: {} };
    const fakeEnv = {
      MAIL_TRANSPORT: 'smtp',
      SMTP_HOST: '',
    };
    const fn = new Function('require', 'module', 'exports', 'Deno', EMAIL_CODE);
    const customRequire = (id) => {
      if (id.includes('smtp')) return loadSmtpModule();
      return {};
    };
    fn(customRequire, mod, mod.exports, {
      env: { get: (k) => fakeEnv[k] || '' },
    });

    await expect(mod.exports.sendEmail({
      toEmail: 'dest@example.org',
      subject: 'Test',
      html: '<p>Test</p>',
    })).rejects.toThrow('MAIL_TRANSPORT=smtp configuré mais SMTP_HOST est vide');
  });
});
