// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/relatar-problema-source.test.js
//
// CE QUE CE TEST PROTÈGE (E14, 24/09/2026). « Signaler un problème » tient à un
// fil de pièces qui doivent rester ensemble : la route publique et la file
// protégée dans App.jsx, le lien au pied de TOUTES les pages (avec la page
// d'origine), l'intention « Je veux… », la déclaration verify_jwt = false de la
// fonction, l'aiguillage bug_report.* dans notify-event, et — côté fonction —
// la preuve de travail en deux temps, le compteur bug_ip, l'anti-flood. Chaque
// pièce qui manquerait laisserait une porte sans couloir derrière.
// Un test de source n'est pas un test de rendu ; le comportement de la fonction
// et des courriels est éprouvé dans relatar-banc.test.js.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const racine = path.resolve(here, '..', '..');
const lire = (rel) => readFileSync(path.resolve(racine, rel), 'utf8');

describe('« Signaler un problème » — les pièces tiennent ensemble (E14)', () => {
  it('la page est publique, la file est protégée, les deux sont chargées à la demande', () => {
    const app = lire('src/App.jsx');
    expect(app).toContain("lazy(() => import('@/pages/public/RelatarProblemaPage'))");
    expect(app).toContain("lazy(() => import('@/pages/federacao/RelatosFilaPage'))");
    expect(app).toContain('<Route path="/relatar-problema" element={<RelatarProblemaPage />} />');
    expect(app).toContain('<Route path="/relatar-problema/fila" element={<ProtectedRoute><RelatosFilaPage /></ProtectedRoute>} />');
  });

  it('le pied de page mène à /relatar-problema depuis toute page, avec la page d\'origine', () => {
    const layout = lire('src/components/layout/index.jsx');
    const footer = layout.slice(layout.indexOf('export function Footer()'));
    expect(footer).toContain('/relatar-problema?de=${encodeURIComponent(location.pathname)}');
    expect(footer).toContain("t({ id: 'nav.report' })");
  });

  it("l'intention « signaler un problème » existe, pour tout compte, et mène à la page", () => {
    const intentions = lire('src/pages/inicio/intentions.js');
    expect(intentions).toMatch(/id: 'report',\s+group: 'reader',[^}]*to: '\/relatar-problema'/);
  });

  it('la fonction est déclarée publique, et la page ne demande jamais de mot de passe', () => {
    const toml = lire('supabase/config.toml');
    expect(toml).toMatch(/\[functions\.submit-bug-report\]\s*\nverify_jwt = false/);
    const page = lire('src/pages/public/RelatarProblemaPage.jsx');
    expect(page).not.toMatch(/type="password"/);
    expect(page).toContain('<AltchaWidget');
    expect(page).toContain("callEdgeFunction('submit-bug-report'");
    expect(page).toContain('name="website"'); // honeypot
    // sans session, pas de bibliothèque par défaut dans le signalement (premier signalement réel, 24/09)
    expect(page).toContain('library_hint: role ? (libraryName || null) : null');
  });

  it("la fonction : Altcha en deux temps (usage bug_report), compteur bug_ip, doublon ouvert rendu tel quel", () => {
    const ef = lire('supabase/functions/submit-bug-report/index.ts');
    expect(ef).toContain('verifierSolution(');
    expect(ef).toContain('p_purpose: "bug_report"');
    expect(ef).toContain('freiner(sb, "bug_ip"');
    expect(ef).toContain('.eq("status", "open").eq("dedup_key", cle)');
    expect(ef).toContain('duplicate: true');
    expect(ef).toContain('req.headers.get("user-agent")');
    expect(ef).not.toContain('SUPABASE_SERVICE_ROLE_KEY');
  });

  it('notify-event aiguille bug_report.* vers le handler ; le handler écrit le canal humain dans le corps, jamais en Reply-To', () => {
    const dispatch = lire('supabase/functions/_shared/core/dispatch.ts');
    expect(dispatch).toContain('if (event.startsWith("bug_report.")) return await handleBugReportEvent(recordId);');
    const handler = lire('supabase/functions/_shared/domain/bug-report.ts');
    expect(handler).toContain('/relatar-problema/fila');
    expect(handler).toContain('bugreport.ack.noreply');
    expect(handler).not.toMatch(/replyTo|reply_to/);
    expect(handler).toContain('verdictEnvois(');
    // aucun identifiant du backlog dans le texte du courriel
    expect(handler).not.toMatch(/`[^`]*\(E14\)[^`]*`/);
  });

  it('la migration : tables fermées, kind bug_ip, usage Altcha, aucune adresse cloud en dur ; suites et filet BG2 à jour', () => {
    const migs = readdirSync(path.resolve(racine, 'supabase/migrations')).filter((f) => /_e14_signaler_un_probleme\.sql$/.test(f));
    expect(migs).toHaveLength(1);
    const sql = lire('supabase/migrations/' + migs[0]);
    expect(sql).toContain('REVOKE ALL ON public.bug_reports FROM anon, authenticated;');
    expect(sql).toContain('ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;');
    expect(sql).toContain("'bug_ip'::text");
    expect(sql).toContain("('register', 'cartography', 'bug_report')");
    // la liste de la fonction ET la CHECK de la table (allowlist ≠ CHECK, B26)
    expect(sql).toContain("CHECK (purpose = ANY (ARRAY['register'::text, 'cartography'::text, 'bug_report'::text]))");
    expect(sql).toContain("private.fn_functions_base_url() || '/functions/v1/notify-event'");
    expect(sql).not.toContain('supabase.co');
    expect(lire('tests/sql/compteurs_d_abus_tests.sql')).toContain("'bug_ip'");
    expect(lire('tests/sql/ci-suites.txt')).toContain('tests/sql/signalements_tests.sql');
    const bg2 = lire('deploy/bg2-known-tables.txt').split(/\r?\n/);
    expect(bg2).toContain('bug_reports');
    expect(bg2).toContain('bug_report_notification_outbox');
  });

  it('les clés existent dans les dix locales (page, file, pied, intention, accusé de réception)', () => {
    const dirLocales = path.resolve(racine, 'src/i18n/locales');
    const locales = readdirSync(dirLocales).filter((f) => f.endsWith('.json'));
    expect(locales).toHaveLength(10);
    for (const f of locales) {
      const m = JSON.parse(readFileSync(path.join(dirLocales, f), 'utf8'));
      for (const k of ['relatar.title', 'relatar.what', 'relatar.duplicate', 'relatar.fila.title', 'nav.report', 'inicio.i.report', 'inicio.kw.report']) {
        expect(m[k], `${f} ${k}`).toBeTruthy();
      }
    }
    const mails = lire('supabase/functions/_shared/i18n/mail-strings.ts');
    for (const k of ['bugreport.ack.sub', 'bugreport.ack.intro', 'bugreport.ack.ref', 'bugreport.ack.noreply']) {
      const bloc = mails.slice(mails.indexOf(`"${k}"`), mails.indexOf('},', mails.indexOf(`"${k}"`)));
      for (const l of ['"pt-BR"', 'fr:', 'es:', 'en:', 'it:', 'de:', 'ca:', 'eo:', 'nl:', 'el:']) expect(bloc, `${k} ${l}`).toContain(l);
    }
  });
});
