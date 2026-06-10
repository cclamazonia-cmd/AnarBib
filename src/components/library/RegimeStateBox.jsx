import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

// =============================================================================
// RegimeStateBox (EA-06, chantier-cadre Biblioteca, 21/05/2026)
// =============================================================================
// Encart de lecture du régime, en tête de l'onglet regulation de
// BibliotecaPage. Restaure le `regimeStateBox` du HTML d'origine, absent
// du JSX. Cf. docs/journal/chantiers/CHANTIER_audit_biblioteca_...md
//
// Diagnostic de LECTURE : il calcule l'un des 5 états du régime selon le
// croisement (jeu actif) × (texte de régiment actif) × (lien entre les deux)
// et affiche titre + description + note + suggestions d'étapes.
//
// PAS de boutons d'action : dans le HTML, les boutons faisaient défiler vers
// les formulaires de la même page ; dans le JSX, PolicySetManager et l'upload
// de texte sont déjà visibles juste en dessous dans le même onglet.
//
// Composant autonome : reçoit libraryId + regulationDocs (déjà chargés par
// BibliotecaPage) et recharge lui-même le jeu actif (lecture simple .from(),
// doctrine RPC v3).
//
// Les 5 états (fidèles au HTML d'origine) :
//   1 ok   — jeu actif ET lié à un texte
//   2 warn — jeu actif MAIS non lié à un texte
//   3 warn — pas de jeu actif MAIS un texte actif
//   4 warn — pas de jeu actif, mais des jeux existent
//   5 warn — rien (ni jeu actif, ni texte actif, ni jeu du tout)
// =============================================================================

function docKindLabel(t, docKind) {
  if (!docKind) return t({ id: 'biblioteca.regime.docKindGeneric' });
  return t({ id: `biblioteca.regulation.docKind.${docKind}`, defaultMessage: docKind });
}

export default function RegimeStateBox({ libraryId, regulationDocs = [] }) {
  const { formatMessage: t } = useIntl();

  const [loading, setLoading] = useState(true);
  const [policySets, setPolicySets] = useState([]);

  // ── Chargement de TOUS les jeux (lecture simple .from(), doctrine RPC v3) ──
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('library_circulation_policy_sets')
        .select('id, label, status, is_active, regulation_document_id')
        .eq('library_id', libraryId);
      if (error) throw error;
      setPolicySets(data || []);
    } catch {
      // En cas d'erreur de lecture, on retombe sur l'état "rien défini"
      // plutôt que de bloquer l'onglet : l'encart est un confort de lecture.
      setPolicySets([]);
    } finally {
      setLoading(false);
    }
  }, [libraryId]);

  useEffect(() => { load(); }, [load]);

  // ── Calcul de l'état du régime ────────────────────────────────────────────
  const regime = useMemo(() => {
    const activeDoc = regulationDocs.find(d => d?.is_active === true) || null;
    const activeSet = policySets.find(s => s?.is_active === true)
      || policySets.find(s => String(s?.status || '').trim() === 'active')
      || null;
    const linkedDocId = activeSet?.regulation_document_id != null
      ? String(activeSet.regulation_document_id) : '';
    const linkedDoc = linkedDocId
      ? regulationDocs.find(d => String(d?.id || '') === linkedDocId) || null
      : null;

    const setLabel = activeSet?.label || (activeSet?.id != null ? `#${activeSet.id}` : '—');
    const docVersion = (doc) => doc?.version_label
      ? t({ id: 'biblioteca.regime.versionSuffix' }, { version: doc.version_label })
      : '';

    // État 1 — jeu actif ET lié à un texte
    if (activeSet && linkedDoc) {
      return {
        tone: 'ok',
        title: linkedDoc.doc_kind === 'regimento'
          ? t({ id: 'biblioteca.regime.state1.titleRegimento' })
          : t({ id: 'biblioteca.regime.state1.titleGeneric' }),
        text: t({ id: 'biblioteca.regime.state1.text' }, {
          set: setLabel,
          docKind: docKindLabel(t, linkedDoc.doc_kind),
          version: docVersion(linkedDoc),
        }),
        note: t({ id: 'biblioteca.regime.state1.note' }),
        stepsTitle: t({ id: 'biblioteca.regime.state1.stepsTitle' }),
        steps: [
          t({ id: 'biblioteca.regime.state1.step1' }),
          t({ id: 'biblioteca.regime.state1.step2' }),
          t({ id: 'biblioteca.regime.state1.step3' }),
        ],
      };
    }
    // État 2 — jeu actif MAIS non lié à un texte
    if (activeSet && !linkedDoc) {
      return {
        tone: 'warn',
        title: t({ id: 'biblioteca.regime.state2.title' }),
        text: t({ id: 'biblioteca.regime.state2.text' }, { set: setLabel }),
        note: t({ id: 'biblioteca.regime.state2.note' }),
        stepsTitle: t({ id: 'biblioteca.regime.stepsTitleNext' }),
        steps: [
          t({ id: 'biblioteca.regime.state2.step1' }),
          t({ id: 'biblioteca.regime.state2.step2' }),
          t({ id: 'biblioteca.regime.state2.step3' }),
        ],
      };
    }
    // État 3 — pas de jeu actif MAIS un texte actif
    if (!activeSet && activeDoc) {
      return {
        tone: 'warn',
        title: t({ id: 'biblioteca.regime.state3.title' }),
        text: t({ id: 'biblioteca.regime.state3.text' }, {
          docKind: docKindLabel(t, activeDoc.doc_kind),
          version: docVersion(activeDoc),
        }),
        note: t({ id: 'biblioteca.regime.state3.note' }),
        stepsTitle: t({ id: 'biblioteca.regime.stepsTitleNext' }),
        steps: [
          t({ id: 'biblioteca.regime.state3.step1' }),
          t({ id: 'biblioteca.regime.state3.step2' }),
          t({ id: 'biblioteca.regime.state3.step3' }),
        ],
      };
    }
    // État 4 — pas de jeu actif, mais des jeux existent
    if (!activeSet && policySets.length > 0) {
      return {
        tone: 'warn',
        title: t({ id: 'biblioteca.regime.state4.title' }),
        text: t({ id: 'biblioteca.regime.state4.text' }),
        note: t({ id: 'biblioteca.regime.state4.note' }),
        stepsTitle: t({ id: 'biblioteca.regime.stepsTitleNext' }),
        steps: [
          t({ id: 'biblioteca.regime.state4.step1' }),
          t({ id: 'biblioteca.regime.state4.step2' }),
          t({ id: 'biblioteca.regime.state4.step3' }),
        ],
      };
    }
    // État 5 — rien défini
    return {
      tone: 'warn',
      title: t({ id: 'biblioteca.regime.state5.title' }),
      text: t({ id: 'biblioteca.regime.state5.text' }),
      note: t({ id: 'biblioteca.regime.state5.note' }),
      stepsTitle: t({ id: 'biblioteca.regime.stepsTitleNext' }),
      steps: [
        t({ id: 'biblioteca.regime.state5.step1' }),
        t({ id: 'biblioteca.regime.state5.step2' }),
        t({ id: 'biblioteca.regime.state5.step3' }),
        t({ id: 'biblioteca.regime.state5.step4' }),
      ],
    };
  }, [policySets, regulationDocs, t]);

  // ── Styles (ton ok / warn) ────────────────────────────────────────────────
  const palette = regime.tone === 'ok'
    ? { bg: 'rgba(126,224,168,.10)', border: '#7ee0a8', text: '#7ee0a8', icon: '✓' }
    : { bg: 'rgba(245,200,120,.10)', border: '#f5c878', text: '#f5c878', icon: '!' };

  if (loading) {
    return (
      <div style={{
        padding: '12px 14px', borderRadius: 8, marginBottom: 16,
        background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)',
        fontSize: '.85rem', color: 'var(--brand-muted)',
      }}>
        {t({ id: 'common.loading' })}
      </div>
    );
  }

  return (
    <div style={{
      background: palette.bg,
      borderLeft: `3px solid ${palette.border}`,
      borderRadius: 8,
      padding: '12px 16px',
      marginBottom: 16,
    }}>
      <div style={{ fontSize: '.92rem', fontWeight: 600, color: palette.text, marginBottom: 5 }}>
        <span aria-hidden="true" style={{
          display: 'inline-block', width: 16, marginRight: 6, textAlign: 'center',
        }}>{palette.icon}</span>
        {regime.title}
      </div>
      <div style={{ fontSize: '.86rem', color: palette.text, marginBottom: 6 }}>
        {regime.text}
      </div>
      <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)', marginBottom: 8 }}>
        {regime.note}
      </div>
      <div style={{ fontSize: '.78rem', fontWeight: 600, color: 'var(--brand-muted)', marginBottom: 4 }}>
        {regime.stepsTitle}
      </div>
      <ol style={{ margin: 0, paddingLeft: 20, fontSize: '.8rem', color: 'var(--brand-muted)' }}>
        {regime.steps.map((step, i) => (
          <li key={i} style={{ marginBottom: 2 }}>{step}</li>
        ))}
      </ol>
    </div>
  );
}
