// =====================================================================
// NUMDIF D16 (15/10/2026, REGISTRE §47 NUMDIF-4) — deposit-digital-candidate
// verse des candidats validés côté serveur, par lots, avec reprise.
// Session : File de candidats PDF.
//
// La base revérifie tout (tests/sql/numdif_versement_tests.sql) ; ici, l'ordre
// des gestes dans la fonction, qui fait la promesse de NUMDIF-4 — « un fichier
// versé qui est exactement celui qu'on a regardé » —, et la boucle de lot de
// l'écran : paquets, reprise de ce qui reste, arrêt, un refus n'arrête rien.
// =====================================================================
import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/lib/supabase', () => ({ supabase: { rpc: vi.fn() }, SUPABASE_URL: 'https://exemple.invalid' }));
const { versementParLots } = await import('@/pages/importacoes/CandidatsPdfPanel.jsx');

const SRC = readFileSync(path.resolve(__dirname, '../../supabase/functions/deposit-digital-candidate/index.ts'), 'utf8');
const PANNEAU = readFileSync(path.resolve(__dirname, '../pages/importacoes/CandidatsPdfPanel.jsx'), 'utf8');
const i = (s) => { const n = SRC.indexOf(s); expect(n, s).toBeGreaterThan(-1); return n; };

describe('deposit-digital-candidate — l’ordre des gestes', () => {
  it('garde → téléchargement → zone privée (empreintes au passage) → vérification → seau du cas → enregistrement', () => {
    const garde = i("userClient.rpc('fn_digital_candidate_deposit_garde'");
    const telechargement = i('await fetch(g.file_url');
    const passage = i('h256.update(value); h1.update(value);');
    const zone = i('service.storage.from(ZONE_PRIVEE).upload(zone, flux');
    const verification = i('if (attendue.obtenue !== attendue.valeur)');
    const seau = i('service.storage.from(ZONE_PRIVEE).move(zone, chemin');
    const enregistrement = i("service.schema('ingest').rpc('fn_digital_candidate_deposit_record'");
    expect(garde).toBeLessThan(telechargement);
    expect(telechargement).toBeLessThan(zone);
    expect(passage).toBeLessThan(zone);
    expect(zone).toBeLessThan(verification);
    expect(verification).toBeLessThan(seau);
    expect(seau).toBeLessThan(enregistrement);
  });

  it('la zone avant vérification est privée : un fichier non vérifié n’est jamais public', () => {
    expect(SRC).toContain("const ZONE_PRIVEE = 'pdf-restrito';");
    expect(SRC).toContain('const zone = `numdif-staging/${id}/${horodatage}.pdf`;');
  });

  it('SHA-256 s’il est connu, sinon le SHA-1 de la source (MediaWiki), et le SHA-256 calculé est transmis', () => {
    expect(SRC).toContain("g.sha256 ? { alg: 'SHA-256', valeur: g.sha256, obtenue: sha256 } : { alg: 'SHA-1', valeur: g.sha1, obtenue: sha1 }");
    expect(SRC).toContain('p_sha256: sha256, p_sha1: sha1');
  });

  it('le refus d’empreinte efface la zone, se dit et se garde sur le candidat', () => {
    const bloc = SRC.slice(SRC.indexOf('if (attendue.obtenue !== attendue.valeur)'), SRC.indexOf("echec(id, 'fingerprint_mismatch'"));
    expect(bloc).toContain('service.storage.from(ZONE_PRIVEE).remove([zone])');
    expect(bloc).toContain('await noterEchec(');
  });

  it('le chemin est books/<notice>/<horodatage ms>_<nom>.pdf, dans le seau que fixe le cas', () => {
    expect(SRC).toContain('const chemin = `books/${g.book_id}/${horodatage}_${nom}`;');
    expect(SRC).toContain('const bucket: string = g.destination.storage_bucket;');
  });

  it('par lots : un budget de temps, et la liste de ce qui reste', () => {
    expect(SRC).toMatch(/if \(issues\.length > 0 && Date\.now\(\) - debut > BUDGET_MS\) \{ remaining\.push\(id\); continue; \}/);
    expect(SRC).toContain('results: issues, remaining');
  });

  it('aucun contournement : un refus de la source arrête ce candidat', () => {
    expect(SRC).toMatch(/\[401, 403, 429, 503\]\.includes\(reponse\.status\)/);
  });

  it('l’écran appelle la fonction avec le jeton de la session, et relaie son refus', () => {
    expect(PANNEAU).toContain('/functions/v1/deposit-digital-candidate');
    expect(PANNEAU).toContain('Authorization: `Bearer ${session?.access_token}`');
    expect(PANNEAU).toContain('throw erreurDeFonction(out, res.status)');
  });
});

describe('le lot de l’écran : paquets, reprise, arrêt', () => {
  it('ce que la fonction n’a pas eu le temps de commencer repart en tête, et chaque candidat passe une fois', async () => {
    const vus = [];
    const appeler = vi.fn(async (paquet) => {
      // la fonction ne traite que les deux premiers, rend le reste
      const faits = paquet.slice(0, 2);
      vus.push(...faits);
      return { ok: true, results: faits.map((id) => ({ id, ok: id !== 3 })), remaining: paquet.slice(2) };
    });
    const bilan = await versementParLots([1, 2, 3, 4, 5, 6, 7], appeler);
    expect(vus).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(bilan).toMatchObject({ total: 7, done: 6, failed: 1, arrete: false });
  });

  it('« arrêter » laisse le reste pour la reprise', async () => {
    let n = 0;
    const appeler = vi.fn(async (paquet) => ({ ok: true, results: paquet.map((id) => ({ id, ok: true })), remaining: [] }));
    const bilan = await versementParLots([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], appeler, { arrete: () => n++ >= 1 });
    expect(appeler).toHaveBeenCalledTimes(1);
    expect(bilan).toMatchObject({ total: 11, done: 5, arrete: true });
  });
});
