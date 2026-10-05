// ═══════════════════════════════════════════════════════════
// AnarBib — « Publié — et maintenant ? » (04/10/2026).
// Un seul encadré remplace, après une publication, le message, le toast, le
// bandeau « Ajouter un exemplaire ? » et la fenêtre œuvre/édition qui revenait
// à chaque publication.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import AfterPublishPanel from '@/pages/catalogacao/AfterPublishPanel';

afterEach(cleanup);
const intl = (ui) => <IntlProvider locale="fr" messages={{ 'common.close': 'Fermer' }}>{ui}</IntlProvider>;
const src = (f) => readFileSync(path.resolve(__dirname, '../pages/catalogacao', f), 'utf8');

describe('AfterPublishPanel', () => {
  it('dit ce qui est publié et propose les suites, sans les actions absentes', () => {
    const ajouter = vi.fn();
    render(intl(<AfterPublishPanel title="« Anarchie » est publié. Et maintenant ?" onClose={() => {}}
      actions={[
        { id: 'a', primary: true, label: 'Ajouter un exemplaire', hint: 'Pour ta bibliothèque.', onClick: ajouter },
        false,
        null,
        { id: 'b', label: 'Nouveau document', onClick: () => {} },
      ]} />));
    expect(screen.getByRole('heading').textContent).toContain('Anarchie');
    expect(screen.getAllByRole('button').map((b) => b.textContent)).toEqual([
      '×', 'Ajouter un exemplairePour ta bibliothèque.', 'Nouveau document',
    ]);
    fireEvent.click(screen.getByText('Ajouter un exemplaire'));
    expect(ajouter).toHaveBeenCalledTimes(1);
  });
  it('se ferme', () => {
    const fermer = vi.fn();
    render(intl(<AfterPublishPanel title="x" onClose={fermer} actions={[]} />));
    fireEvent.click(screen.getByRole('button', { name: 'Fermer' }));
    expect(fermer).toHaveBeenCalledTimes(1);
  });
});

describe('les trois éditeurs', () => {
  it('Document : l’encadré remplace le bandeau, la fenêtre de création n’est plus rouverte d’office', () => {
    const s = src('BookDraftForm.jsx');
    expect(s).not.toContain("'catalogacao.postPublish.body'");
    expect(s).toContain("title={t({ id: 'catalogacao.next.title' }, { title: lastPublished.title })}");
    // Après publication, creationChoice reste non nul : la fenêtre œuvre/édition
    // ne s'ouvre plus que sur « Nouveau document ».
    expect(s).toMatch(/resetForm\(\);[\s\S]{0,900}setCreationChoice\('work'\);[\s\S]{0,600}setLastPublished\(publishedId \?/);
    expect(s).toContain("onClick: () => { setLastPublished(null); setCreationChoice(null); }");
    expect(s).toContain('selectEditionAsWork({ work_id: lastPublished.workId');
  });
  it('Autorité et exemplaire : un encadré, la navigation passée par la page', () => {
    for (const [f, cle] of [['AuthorDraftForm.jsx', 'catalogacao.next.titleAuthor'], ['ExemplarDraftForm.jsx', 'catalogacao.next.titleExemplar']]) {
      const s = src(f);
      expect(s).toContain(`t({ id: '${cle}' }`);
      expect(s).toMatch(/onNavigateTab \}\) \{/);
    }
    const page = src('CatalogacaoPage.jsx');
    expect(page.match(/onChanged=\{refreshAll\} onNavigateTab=\{switchTab\} \/>/g)).toHaveLength(2);
  });
});
