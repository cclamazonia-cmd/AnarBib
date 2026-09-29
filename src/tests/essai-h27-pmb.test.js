// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/essai-h27-pmb.test.js
//
// ESSAI H27 (28/09/2026), critère 2 : réimporter dans PMB l'export TIRÉ DE LA
// BASE. Sauté par défaut ; il écrit les fichiers du réimport à partir de
// l'export que la suite tests/sql/aller_retour_pmb_tests.sql émet sous
// anarbib.h27_export = on (les 64 notices des fixtures PMB importées,
// publiées, puis exportées par fn_export_catalog_lote et
// fn_export_authorities_lote) :
//   ESSAI_H27_EXPORT=export.json ESSAI_H27_DIR=dossier npx vitest run src/tests/essai-h27-pmb.test.js
// par le chemin de l'écran Importations (serializeCatalog, autorites) :
//   catalogue-h27.iso : UNIMARC ISO 2709, comme « UNIMARC — ISO 2709 » ;
//   autorites-h27.iso : UNIMARC Autorités, s'il y en a (une notice importée
//                       n'est liée à une autorité qu'après la révision) ;
//   essai-h27.json    : ce que le fichier porte (notices, exemplaires 995, …),
//                       pour comparer aux nombres de PMB ;
//   catalogue-sans-tri.iso, sous ESSAI_H27_SANS_TRI=1 : le CONTRE-ESSAI — le
//                       même export dans l'ordre reçu (celui de la RPC de
//                       l'écran, par id), sans ranger les périodiques avant
//                       les articles : ce que l'écran écrivait avant la revue
//                       du 28/09 (mesuré : 7 articles rattachés sur 15).
// Tout le reste (sauvegarde, vidage, import, comptes, restauration) :
// tests/pmb/banc/essai-reimport-pmb.sh.
import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { serializeCatalog } from '../../supabase/functions/export-catalog-lote/serialize.ts';
import { enregistrement } from '../../supabase/functions/_shared/marc/ecriture.ts';
import { autorites } from '../../supabase/functions/_shared/marc/autorites.ts';
import { ecrireIso2709 } from '../../supabase/functions/_shared/marc/iso2709.ts';
import { parseMarcIso2709 } from '../../supabase/functions/process-partner-catalog-import/marc.ts';

const EXPORT = process.env.ESSAI_H27_EXPORT;
const SORTIE = process.env.ESSAI_H27_DIR;

describe.skipIf(!EXPORT || !SORTIE)('essai H27 : le fichier du réimport dans PMB, tiré de la base', () => {
  it('écrit catalogue-h27.iso (et autorites-h27.iso) par le chemin de l\'écran', () => {
    const exp = JSON.parse(readFileSync(EXPORT, 'utf8'));
    const lib = exp.library ?? {};
    // Les options de l'écran (ImportacoesPage.jsx, handleExportLote).
    const bibliotheque = { nom: lib.short_name || lib.name || null, pays: lib.country ?? null, langue: lib.default_locale ?? null };
    const cat = serializeCatalog(exp.records, 'unimarc_iso2709', { bibliotheque });
    expect(cat.avertissements).toEqual([]);
    mkdirSync(SORTIE, { recursive: true });
    writeFileSync(path.join(SORTIE, 'catalogue-h27.iso'), cat.content);
    // Le contre-essai : par l'écrivain, notice par notice — serializeCatalog, lui, range toujours.
    if (process.env.ESSAI_H27_SANS_TRI === '1') {
      const brut = ecrireIso2709(exp.records.map((r) => enregistrement(r, { dialecte: 'unimarc', bibliotheque })));
      expect(brut.avertissements).toEqual([]);
      writeFileSync(path.join(SORTIE, 'catalogue-sans-tri.iso'), brut.octets);
    }
    const aut = exp.authorities ?? {};
    const nAut = (aut.authors?.length ?? 0) + (aut.subjects?.length ?? 0);
    if (nAut) {
      const a = ecrireIso2709(autorites(aut, { bibliotheque: { pays: lib.country ?? null, langue: lib.default_locale ?? null } }));
      expect(a.avertissements).toEqual([]);
      writeFileSync(path.join(SORTIE, 'autorites-h27.iso'), a.octets);
    }
    const relues = parseMarcIso2709(cat.content).records;
    const zones = (tag) => relues.reduce((n, r) => n + r.fields.filter((f) => f.tag === tag).length, 0);
    const bilan = {
      notices: relues.length,
      exemplaires_995: zones('995'),
      notices_sans_995: relues.filter((r) => !r.fields.some((f) => f.tag === '995')).length,
      responsabilites_7xx: ['700', '701', '702', '710', '711', '712'].reduce((n, t) => n + zones(t), 0),
      vedettes_606: zones('606'),
      mots_cles_610: zones('610'),
      exemplaires_de_l_export: exp.records.reduce((n, r) => n + (r.items?.length ?? 0), 0),
      exemplaires_sans_code_d_origine: exp.records.reduce((n, r) => n + (r.items ?? []).filter((it) => !it.code).length, 0),
      autorites: { noms: aut.authors?.length ?? 0, sujets: aut.subjects?.length ?? 0 },
    };
    writeFileSync(path.join(SORTIE, 'essai-h27.json'), JSON.stringify(bilan, null, 2));
    console.log(`essai H27 : ${JSON.stringify(bilan)}`);
    expect(relues.length).toBe(exp.records.length);
  });
});
