// =====================================================================
// NUMDIF (19/10/2026, REGISTRE §47 NUMDIF-2 et NUMDIF-4) —
// realign-digital-resource met une ressource déjà versée au seau que fixe
// aujourd'hui le cas de son candidat (premier usage : le lot « Overige
// bestanden » d'Anarchief.org, de pdf-restrito vers anarbib-pdf-public).
// Session : Anarchief — ouvrir le lot Overige.
//
// La base revérifie tout (tests/sql/numdif_realignement_tests.sql) ; ici,
// l'ordre des gestes qui tient la promesse : la ressource désigne toujours un
// objet présent, sa portée ne contredit jamais son seau, et le fichier déplacé
// est exactement celui qui a été versé (SHA-256 avant ET après la copie).
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const SRC = readFileSync(path.resolve(__dirname, '../../supabase/functions/realign-digital-resource/index.ts'), 'utf8');
const i = (s, depuis = 0) => { const n = SRC.indexOf(s, depuis); expect(n, s).toBeGreaterThan(-1); return n; };

describe('realign-digital-resource — l’ordre des gestes', () => {
  it('garde → empreinte avant → copie → empreinte après → enregistrement → effacement de l’original', () => {
    const serve = i('Deno.serve(');
    const garde = i("userClient.rpc('fn_digital_resource_realign_garde'", serve);
    const avant = i('const avant = await empreinte(service, de, chemin);', serve);
    const copie = i('.copy(chemin, chemin, { destinationBucket: vers })', serve);
    const apres = i('const apres = await empreinte(service, vers, chemin);', serve);
    const enregistrement = i("service.schema('ingest').rpc('fn_digital_resource_realign_record'", serve);
    const effacement = i('await service.storage.from(de).remove([chemin])', serve);
    expect(garde).toBeLessThan(avant);
    expect(avant).toBeLessThan(copie);
    expect(copie).toBeLessThan(apres);
    expect(apres).toBeLessThan(enregistrement);
    expect(enregistrement).toBeLessThan(effacement);
  });

  it('le fichier en place et la copie sont comparés au SHA-256 versé', () => {
    expect(SRC).toContain('if (avant.sha256 !== g.sha256)');
    expect(SRC).toContain("if ('erreur' in apres || apres.sha256 !== g.sha256)");
    expect(SRC).toContain('p_sha256: apres.sha256');
  });

  it('une copie refusée par l’empreinte ou par la base est effacée ; l’original ne l’est qu’après l’enregistrement', () => {
    const apresBloc = SRC.slice(SRC.indexOf("if ('erreur' in apres"), SRC.indexOf('// 5.'));
    expect(apresBloc).toContain('await effacerCopie();');
    const recBloc = SRC.slice(SRC.indexOf('if (recErr)'), SRC.indexOf('// 6.'));
    expect(recBloc).toContain('await effacerCopie();');
    expect(SRC.indexOf('.remove([chemin])', SRC.indexOf('// 6.'))).toBeGreaterThan(SRC.indexOf('if (recErr)'));
  });

  it('le chemin ne change pas, seul le seau change ; une ressource alignée n’est pas touchée', () => {
    expect(SRC).toContain('p_from_bucket: de, p_from_path: chemin, p_bucket: vers, p_path: chemin');
    const aligne = i('if (g.aligned)');
    expect(aligne).toBeLessThan(i('createClient(supabaseUrl, serviceKey'));
  });

  // J13 (22/10/2026) : une ressource sans candidat (administration du réseau,
  // vers le restreint seulement — la base en décide) n'a pas toujours
  // d'empreinte enregistrée : le fichier en place devient la référence AVANT la
  // copie, jamais après, et seulement dans ce cas.
  it('sans candidat : l’empreinte du fichier en place sert de référence, avant la copie', () => {
    expect(SRC).toContain('(!g.sha256 && !g.sans_candidat)');
    const reference = i('if (g.sans_candidat && !g.sha256) g.sha256 = avant.sha256;');
    expect(reference).toBeGreaterThan(i('const avant = await empreinte(service, de, chemin);'));
    expect(reference).toBeLessThan(i('if (avant.sha256 !== g.sha256)'));
    expect(reference).toBeLessThan(i('.copy(chemin, chemin, { destinationBucket: vers })'));
  });

  it('empreintes natives (node:crypto), pas de JavaScript pur', () => {
    expect(SRC).toContain("import { createHash } from 'node:crypto';");
  });

  it('par lots : un budget de temps et la liste de ce qui reste', () => {
    expect(SRC).toMatch(/if \(issues\.length > 0 && Date\.now\(\) - debut > BUDGET_MS\) \{ remaining\.push\(id\); continue; \}/);
    expect(SRC).toContain('const MAX_PAR_APPEL = 10;');
  });
});
