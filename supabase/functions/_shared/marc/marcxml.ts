// Écrivain MARCXML (H23, 28/09/2026) — l'inverse de parseMarcXml (marc.ts).
//
// MARC21 : la collection porte l'espace de noms MARC21 slim. UNIMARC : la
// forme que PMB appelle « XML MARC » (sans espace de noms), celle qu'il sait
// relire et que notre import lit à l'identique de l'ISO 2709.
import type { NoticeMarc } from './ecriture.ts';

// Échappement, et retrait des caractères interdits en XML 1.0 (les
// séparateurs ISO 2709 compris) : un seul de trop rend tout le fichier illisible.
// H26 : un seul test pour le cas courant (rien à échapper).
const A_ECHAPPER = /[&<>"\x00-\x08\x0b\x0c\x0e-\x1f\ud800-\udfff￾￿]/;
function x(v: unknown): string {
  const s = String(v ?? '');
  if (!A_ECHAPPER.test(s)) return s;
  return s
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f￾￿]/g, ' ')
    .replace(/[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/g, '�')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function guide(leader: string): string {
  const g = (leader || '').padEnd(24, ' ').slice(0, 24).split('');
  g[10] = '2'; g[11] = '2';
  return g.join('');
}

export function ecrireMarcXml(notices: NoticeMarc[], opts: { espaceDeNoms?: boolean } = {}): string {
  const ns = opts.espaceDeNoms ? ' xmlns="http://www.loc.gov/MARC21/slim"' : '';
  const recs = notices.map((n) => {
    const lignes = [`  <record>`, `    <leader>${x(guide(n.leader))}</leader>`];
    for (const f of n.fields) {
      if (typeof f.value === 'string') {
        lignes.push(`    <controlfield tag="${x(f.tag)}">${x(f.value)}</controlfield>`);
        continue;
      }
      const subs = (f.subfields ?? []).filter((s) => s && String(s.value ?? '') !== '');
      if (!subs.length) continue;
      lignes.push(`    <datafield tag="${x(f.tag)}" ind1="${x((f.ind1 || ' ')[0])}" ind2="${x((f.ind2 || ' ')[0])}">`);
      for (const s of subs) lignes.push(`      <subfield code="${x(s.code[0])}">${x(s.value)}</subfield>`);
      lignes.push('    </datafield>');
    }
    lignes.push('  </record>');
    return lignes.join('\n');
  });
  return `<?xml version="1.0" encoding="UTF-8"?>\n<collection${ns}>\n${recs.join('\n')}\n</collection>\n`;
}
