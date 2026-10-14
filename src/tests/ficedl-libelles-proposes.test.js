// THES-FIC6 — les traductions qu'AnarBib propose à la FICEDL (labels_proposes)
// vivent à côté des libellés aspirés (labels, THES-FIC1), sans jamais s'y mêler.
import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { toRow } from '../../scripts/ficedl_thesaurus_sync.mjs';
import { libellesFicedl, pickLabel } from '@/lib/i18nLabel';

const ROOT = resolve(__dirname, '../..');

describe('THES-FIC6 : la proposition ne se mêle pas à la source', () => {
  it('le sync ne connaît pas labels_proposes : un upsert ne peut pas l’écraser', () => {
    const ligne = toRow({ id: 'mot1', labels: { fr: 'action directe', en: 'direct action' }, url: 'u' }, 't');
    expect(Object.keys(ligne)).not.toContain('labels_proposes');
    expect(ligne.labels).not.toHaveProperty('ro');
  });

  it('la source l’emporte ; la proposition comble une langue absente', () => {
    const term = { labels: { fr: 'grève', en: 'strike' }, labels_proposes: { ro: 'grevă', en: 'FAUX' } };
    expect(libellesFicedl(term)).toEqual({ fr: 'grève', en: 'strike', ro: 'grevă' });
    expect(pickLabel(libellesFicedl(term), 'ro')).toBe('grevă');
    expect(pickLabel(libellesFicedl(term), 'en')).toBe('strike');
    expect(libellesFicedl({ labels: { fr: 'x' } })).toEqual({ fr: 'x' });
    expect(libellesFicedl(null)).toEqual({});
  });

  it('aucune migration n’écrit le roumain dans labels', () => {
    const dir = resolve(ROOT, 'supabase/migrations');
    for (const f of readdirSync(dir).filter((n) => n.endsWith('.sql'))) {
      const sql = readFileSync(resolve(dir, f), 'utf8');
      expect(sql, f).not.toMatch(/SET\s+labels\s*=\s*[^;]*'ro'/i);
    }
  });

  it('les trois lecteurs du front passent par libellesFicedl', () => {
    for (const f of ['src/pages/public/FicedlThesaurusPage.jsx', 'src/pages/public/FicedlTermPage.jsx', 'src/pages/catalogacao/SubjectLabelEditor.jsx']) {
      const src = readFileSync(resolve(ROOT, f), 'utf8');
      expect(src, f).toContain('labels_proposes');
      expect(src, f).toContain('libellesFicedl(');
    }
  });
});
