// ── Rapprochements d'autorité proposés en révision de lot (H18, 27/09/2026) ──
// L'import crée les contributeurs d'une notice sans jamais les rattacher
// d'office à une autorité. Ici, à la demande, la recherche par nom du
// catalogage (fn_conv_autorite_homonyme, via fn_batch_contributor_candidates)
// propose une fiche pour chaque contributeur sans autorité des brouillons en
// cours du lot ; la personne qui catalogue rattache, ou non. Le rattachement
// passe par les politiques de book_draft_contributors (staff de la
// bibliothèque du brouillon) : rien de plus que ce que le formulaire permet.
import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

const cell = { padding: '3px 8px', borderBottom: '1px solid var(--brand-border, rgba(0,0,0,.08))', textAlign: 'left', verticalAlign: 'top' };
const muted = { color: 'var(--brand-muted, #999)' };

// Le lien proposé : la nature de la fiche vient avec elle quand le
// contributeur n'en avait pas (même vocabulaire : person, collective, congress).
export function patchRattachement(ligne) {
  const patch = { author_id: ligne.author_id };
  if (!ligne.nature && ligne.author_type) patch.nature = ligne.author_type;
  return patch;
}

export default function ContributorCandidates({ batchId }) {
  const { formatMessage: t } = useIntl();
  const [etat, setEtat] = useState({ lignes: null, chargement: false, erreur: null });
  const [lies, setLies] = useState({});

  async function chercher() {
    setEtat({ lignes: null, chargement: true, erreur: null });
    const { data, error } = await supabase.rpc('fn_batch_contributor_candidates', { p_batch_id: Number(batchId) });
    if (error) setEtat({ lignes: null, chargement: false, erreur: localizeError(error, t) });
    else setEtat({ lignes: Array.isArray(data) ? data : [], chargement: false, erreur: null });
  }

  async function rattacher(ligne) {
    setLies((l) => ({ ...l, [ligne.contributor_id]: 'encours' }));
    const patch = patchRattachement(ligne);
    const { data, error } = await supabase.from('book_draft_contributors')
      .update(patch).eq('id', ligne.contributor_id).select('id');
    const ok = !error && data?.length > 0;
    setLies((l) => ({ ...l, [ligne.contributor_id]: ok ? 'ok' : 'erreur' }));
    // Le formulaire du brouillon, s'il est ouvert, reprend le rattachement.
    if (ok) {
      window.dispatchEvent(new CustomEvent('anarbib:draft-contributor-linked', { detail: {
        draftId: ligne.draft_id, name: ligne.name, authorId: ligne.author_id,
        authorLabel: ligne.author_name, nature: patch.nature ?? null,
      } }));
    }
  }

  return (
    <section data-testid="contributor-candidates" style={{ marginTop: 12 }}>
      <h5 style={{ margin: '0 0 4px', fontSize: '.85rem' }}>{t({ id: 'review.report.contributors.title' })}</h5>
      <p style={{ ...muted, margin: '0 0 6px', fontSize: '.78rem' }}>{t({ id: 'review.report.contributors.intro' })}</p>
      <button type="button" className="ab-button ab-button--ghost" style={{ fontSize: '.75rem', padding: '4px 10px' }}
        disabled={etat.chargement} onClick={chercher}>
        {etat.chargement ? t({ id: 'review.report.contributors.searching' }) : t({ id: 'review.report.contributors.search' })}
      </button>
      {etat.erreur && <p role="alert" style={{ color: 'var(--brand-danger, #b42318)', fontSize: '.78rem' }}>{etat.erreur}</p>}
      {etat.lignes && etat.lignes.length === 0 && (
        <p style={{ ...muted, fontSize: '.78rem' }}>{t({ id: 'review.report.contributors.none' })}</p>
      )}
      {etat.lignes && etat.lignes.length > 0 && (
        <>
          <p style={{ fontSize: '.78rem', margin: '6px 0 0' }}>{t({ id: 'review.report.contributors.count' }, { n: etat.lignes.length })}</p>
          <div style={{ overflowX: 'auto', maxWidth: '100%' }}>
            <table style={{ borderCollapse: 'collapse', fontSize: '.78rem', marginTop: 4, width: '100%' }}>
              <tbody>
                {etat.lignes.map((l) => (
                  <tr key={l.contributor_id} data-contributor={l.contributor_id}>
                    <td style={{ ...cell, ...muted, wordBreak: 'break-word' }}>{l.titulo || '—'}</td>
                    <td style={{ ...cell, wordBreak: 'break-word' }}>
                      {l.name} <span style={muted}>({t({ id: `catalogacao.role.${l.role || 'outro'}` })})</span>
                    </td>
                    <td style={{ ...cell, wordBreak: 'break-word' }}>→ {l.author_name}</td>
                    <td style={{ ...cell, whiteSpace: 'nowrap' }}>
                      {lies[l.contributor_id] === 'ok'
                        ? <span>{t({ id: 'review.report.contributors.linked' })}</span>
                        : (
                          <button type="button" className="ab-button ab-button--ghost" style={{ fontSize: '.72rem', padding: '2px 8px' }}
                            disabled={lies[l.contributor_id] === 'encours'} onClick={() => rattacher(l)}>
                            {t({ id: 'review.report.contributors.link' })}
                          </button>
                        )}
                      {lies[l.contributor_id] === 'erreur' && (
                        <span role="alert" style={{ color: 'var(--brand-danger, #b42318)', marginLeft: 6 }}>{t({ id: 'review.report.contributors.linkFailed' })}</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </section>
  );
}
