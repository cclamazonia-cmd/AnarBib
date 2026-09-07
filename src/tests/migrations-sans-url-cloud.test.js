// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/migrations-sans-url-cloud.test.js
//
// CE QUE CE TEST PROTÈGE (I20, 07/09/2026). Douze fonctions et un job cron
// portaient l'URL des Edge Functions du projet cloud du mainteneur en dur :
// une instance auto-hébergée aurait envoyé ses dépêches à la production
// d'AnarBib. La migration 20260907123000 a remplacé le littéral par
// `private.fn_functions_base_url()`. Ce test empêche qu'un nouveau littéral
// `…supabase.co/functions/v1/…` n'entre dans une migration : l'adresse d'une
// fonction se construit TOUJOURS depuis le helper.
//
// LISTE FERMÉE. Les huit migrations historiques gardent leur texte (une
// migration appliquée ne se réécrit pas) et la migration I20 porte le repli
// cloud du helper : ce sont les seules exceptions, nommées une à une. Une
// migration nouvelle qui aurait besoin d'une adresse de fonction appelle le
// helper ; si elle a une raison de figurer ici, la dire dans le commit.

import { describe, it, expect } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const MIG_DIR = path.join(ROOT, 'supabase', 'migrations');

const LITTERAL = /supabase\.co\/functions\/v1\//;

// Fichiers autorisés à porter le littéral (liste fermée, ne s'allonge pas).
const EXCEPTIONS = new Set([
  '20260510000000_baseline_live.sql',
  '20260618234207_cartography_notify_wiring.sql',
  '20260619001819_onbo_111_lot2b_mail_wiring.sql',
  '20260702205148_gazette_automation_jobs.sql',
  '20260702205149_gazette_submission_translate_cron.sql',
  '20260817142739_service_health_probes.sql',
  '20260828190000_lot3b_moisson_oai_pmh.sql',
  '20260904130100_les_oeuvres_ont_un_titre_par_langue.sql',
  '20260907123000_l_adresse_des_fonctions_n_est_plus_codee_en_dur.sql',
]);

describe('I20 — aucune migration nouvelle ne code en dur l’adresse des fonctions', () => {
  const files = readdirSync(MIG_DIR).filter((f) => /^\d{14}_.*\.sql$/.test(f)).sort();

  it('le dossier des migrations est lu', () => {
    expect(files.length).toBeGreaterThan(200);
  });

  it('les exceptions nommées existent toutes (sinon la liste ment)', () => {
    const manquantes = [...EXCEPTIONS].filter((f) => !files.includes(f));
    expect(manquantes).toEqual([]);
  });

  it('hors exceptions, aucune migration ne porte «supabase.co/functions/v1/»', () => {
    const fautives = files
      .filter((f) => !EXCEPTIONS.has(f))
      .filter((f) => LITTERAL.test(readFileSync(path.join(MIG_DIR, f), 'utf8')));
    expect(fautives, 'construire l’URL avec private.fn_functions_base_url() || \'/functions/v1/<nom>\'').toEqual([]);
  });

  it('la migration I20 définit bien le helper et son repli', () => {
    const src = readFileSync(
      path.join(MIG_DIR, '20260907123000_l_adresse_des_fonctions_n_est_plus_codee_en_dur.sql'),
      'utf8'
    );
    expect(src).toMatch(/CREATE OR REPLACE FUNCTION private\.fn_functions_base_url\(\)/);
    expect(src).toMatch(/current_setting\('anarbib\.functions_base_url', true\)/);
  });
});
