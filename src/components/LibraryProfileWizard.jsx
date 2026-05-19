import { useState, useMemo } from 'react';
import { useIntl } from 'react-intl';

// =============================================================================
// LibraryProfileWizard (paquet F.3, 20/05/2026)
// =============================================================================
// Composant autonome qui guide la creation d'une biblio par les 4 axes
// orthogonaux du chantier profils d'adoption.
//
// Props :
//   value : { catalog_mode, circulation_mode, network_mode, governance_mode, profile_template_chosen }
//   onChange : (newValue) => void  -- callback parent
//   disabled : boolean             -- pour figer pendant submit
//
// Etat interne :
//   internalStep : 0..5
//     0 = ecran d'accueil avec choix profil type (A/B/C/D) ou "Personalizar"
//     1 = catalog_mode
//     2 = circulation_mode
//     3 = network_mode
//     4 = governance_mode
//     5 = recap interne (visualisation des 4 axes choisis avant validation parent)
//
// Doctrine profile_template_chosen :
//   - 'A', 'B', 'C', 'D' : choisi via clic raccourci ET aucune modification ulterieure
//   - 'custom' : choisi via raccourci PUIS modifie
//   - null : utilisateur·rice a parcouru le wizard sans clic raccourci
// =============================================================================

const PROFILE_TEMPLATES = {
  A: { catalog_mode: 'local_only',         circulation_mode: 'off',        network_mode: 'isolated',  governance_mode: 'informal' },
  B: { catalog_mode: 'local_only',         circulation_mode: 'informal',   network_mode: 'isolated',  governance_mode: 'informal' },
  C: { catalog_mode: 'network_published',  circulation_mode: 'informal',   network_mode: 'observer',  governance_mode: 'staff_roles' },
  D: { catalog_mode: 'network_published',  circulation_mode: 'full_sigb',  network_mode: 'federated', governance_mode: 'full_governance' },
};

// Helper : un quadruplet (catalog, circulation, network, governance) correspond-il
// exactement a un profil-type, ou est-ce custom ?
function detectTemplate(axes) {
  for (const key of ['A', 'B', 'C', 'D']) {
    const t = PROFILE_TEMPLATES[key];
    if (axes.catalog_mode === t.catalog_mode
     && axes.circulation_mode === t.circulation_mode
     && axes.network_mode === t.network_mode
     && axes.governance_mode === t.governance_mode) {
      return key;
    }
  }
  return null; // pas un profil type pur
}

export default function LibraryProfileWizard({ value, onChange, disabled = false }) {
  const { formatMessage: t } = useIntl();
  const [internalStep, setInternalStep] = useState(0);

  const axes = useMemo(() => ({
    catalog_mode: value?.catalog_mode || null,
    circulation_mode: value?.circulation_mode || null,
    network_mode: value?.network_mode || null,
    governance_mode: value?.governance_mode || null,
  }), [value]);

  const allAxesChosen = axes.catalog_mode && axes.circulation_mode && axes.network_mode && axes.governance_mode;

  // Helper interne : met a jour les axes ET recalcule profile_template_chosen
  function updateAxes(patch, opts = {}) {
    const newAxes = { ...axes, ...patch };
    const detected = detectTemplate(newAxes);
    // Doctrine : si l'utilisateur·rice avait cliqué un template et modifie
    // un axe -> le tag devient 'custom' (sauf si modification revient pile sur
    // un autre profil-type, alors c'est ce nouveau profil)
    let newTemplate = null;
    if (opts.fromTemplateClick) {
      newTemplate = opts.fromTemplateClick;  // 'A', 'B', 'C' ou 'D'
    } else if (detected) {
      newTemplate = detected; // par hasard, le quadruplet correspond a un template
    } else if (value?.profile_template_chosen
            && ['A', 'B', 'C', 'D'].includes(value.profile_template_chosen)) {
      newTemplate = 'custom';
    } else {
      newTemplate = value?.profile_template_chosen || null;
    }
    onChange({ ...newAxes, profile_template_chosen: newTemplate });
  }

  function chooseTemplate(key) {
    const template = PROFILE_TEMPLATES[key];
    onChange({ ...template, profile_template_chosen: key });
    setInternalStep(5); // sauter directement au recap
  }

  function goCustom() {
    // Si pas encore de choix, on commence l'etape 1.
    // Si deja des choix (modification), on garde et on commence a l'etape 1.
    setInternalStep(1);
  }

  // -----------------------------------------------------------------
  // Sous-vues par etape
  // -----------------------------------------------------------------

  const cardStyle = {
    padding: '14px 16px', borderRadius: 8, marginBottom: 10,
    border: '1px solid rgba(255,255,255,.12)', background: 'rgba(255,255,255,.03)',
    cursor: disabled ? 'not-allowed' : 'pointer',
    transition: 'all .15s ease',
    opacity: disabled ? 0.6 : 1,
  };
  const cardSelectedStyle = {
    ...cardStyle,
    borderColor: 'var(--brand-accent, #f87171)',
    background: 'rgba(248,113,113,.08)',
  };

  function renderStep0() {
    return (
      <>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 6 }}>
          {t({ id: 'wizard.profile.intro.title' })}
        </h3>
        <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', marginBottom: 14 }}>
          {t({ id: 'wizard.profile.intro.subtitle' })}
        </p>

        {['A', 'B', 'C', 'D'].map(key => (
          <div key={key} style={cardStyle}
               onClick={() => !disabled && chooseTemplate(key)}
               role="button"
               aria-disabled={disabled}>
            <div style={{ fontWeight: 700, fontSize: '.95rem', marginBottom: 4 }}>
              {t({ id: `wizard.profile.template.${key}.title` })}
            </div>
            <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
              {t({ id: `wizard.profile.template.${key}.desc` })}
            </div>
          </div>
        ))}

        <div style={{ marginTop: 16, padding: '12px 14px', borderRadius: 8,
                      borderTop: '1px solid rgba(255,255,255,.1)', textAlign: 'center' }}>
          <button type="button" onClick={goCustom}
                  disabled={disabled}
                  style={{ background: 'none', border: 'none', color: 'var(--brand-accent, #f87171)',
                           fontSize: '.9rem', cursor: disabled ? 'not-allowed' : 'pointer',
                           textDecoration: 'underline', fontWeight: 600 }}>
            {t({ id: 'wizard.profile.intro.customize' })} →
          </button>
        </div>
      </>
    );
  }

  // Generateur de page-axe (etapes 1 a 4)
  function renderStepAxis({ axisKey, options, stepNumber }) {
    const currentValue = axes[axisKey];
    return (
      <>
        <div style={{ fontSize: '.75rem', color: 'var(--brand-muted)', marginBottom: 4, fontWeight: 600 }}>
          {t({ id: 'wizard.profile.step.counter' }, { step: stepNumber, total: 4 })}
        </div>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 6 }}>
          {t({ id: `wizard.profile.axis.${axisKey}.title` })}
        </h3>
        <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', marginBottom: 14 }}>
          {t({ id: `wizard.profile.axis.${axisKey}.subtitle` })}
        </p>

        {options.map(opt => (
          <div key={opt}
               style={currentValue === opt ? cardSelectedStyle : cardStyle}
               onClick={() => !disabled && updateAxes({ [axisKey]: opt })}
               role="radio"
               aria-checked={currentValue === opt}
               aria-disabled={disabled}>
            <div style={{ fontWeight: 700, fontSize: '.9rem', marginBottom: 3 }}>
              {t({ id: `wizard.profile.option.${axisKey}.${opt}.title` })}
            </div>
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>
              {t({ id: `wizard.profile.option.${axisKey}.${opt}.desc` })}
            </div>
          </div>
        ))}

        <div style={{ marginTop: 14, display: 'flex', justifyContent: 'space-between', gap: 8 }}>
          <button type="button" onClick={() => setInternalStep(stepNumber - 1)}
                  disabled={disabled}
                  style={{ padding: '8px 14px', borderRadius: 6, border: '1px solid rgba(255,255,255,.15)',
                           background: 'transparent', color: '#f4f4f4',
                           fontSize: '.85rem', cursor: disabled ? 'not-allowed' : 'pointer' }}>
            ← {t({ id: 'wizard.profile.nav.back' })}
          </button>
          <button type="button" onClick={() => setInternalStep(stepNumber + 1)}
                  disabled={disabled || !currentValue}
                  style={{ padding: '8px 14px', borderRadius: 6, border: 'none',
                           background: currentValue ? 'var(--brand-accent, #f87171)' : 'rgba(255,255,255,.08)',
                           color: currentValue ? '#fff' : 'var(--brand-muted)',
                           fontSize: '.85rem', fontWeight: 600,
                           cursor: (disabled || !currentValue) ? 'not-allowed' : 'pointer' }}>
            {t({ id: 'wizard.profile.nav.next' })} →
          </button>
        </div>
      </>
    );
  }

  function renderStep5Recap() {
    const incoherent = axes.catalog_mode === 'network_published'
                    && axes.network_mode === 'isolated';

    return (
      <>
        <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 6 }}>
          {t({ id: 'wizard.profile.recap.title' })}
        </h3>
        <p style={{ color: 'var(--brand-muted)', fontSize: '.88rem', marginBottom: 14 }}>
          {t({ id: 'wizard.profile.recap.subtitle' })}
        </p>

        {/* Resume des 4 axes avec lien "modifier" */}
        {['catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode'].map((axis, idx) => (
          <div key={axis}
               style={{ padding: '10px 12px', borderRadius: 6, marginBottom: 8,
                        background: 'rgba(255,255,255,.04)', display: 'flex',
                        justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: '.75rem', color: 'var(--brand-muted)', fontWeight: 600 }}>
                {t({ id: `wizard.profile.axis.${axis}.title` })}
              </div>
              <div style={{ fontSize: '.88rem', fontWeight: 600, marginTop: 2 }}>
                {t({ id: `wizard.profile.option.${axis}.${axes[axis]}.title` })}
              </div>
            </div>
            <button type="button" onClick={() => setInternalStep(idx + 1)}
                    disabled={disabled}
                    style={{ background: 'none', border: 'none',
                             color: 'var(--brand-accent, #f87171)',
                             fontSize: '.8rem', cursor: disabled ? 'not-allowed' : 'pointer',
                             textDecoration: 'underline' }}>
              {t({ id: 'wizard.profile.recap.modify' })}
            </button>
          </div>
        ))}

        {/* Bandeau d'avertissement si quadruplet incoherent */}
        {incoherent && (
          <div style={{ padding: '12px 14px', borderRadius: 8, marginTop: 8,
                        background: 'rgba(251,146,60,.1)', border: '1px solid rgba(251,146,60,.3)',
                        color: '#fdba74', fontSize: '.85rem' }}>
            ⚠ {t({ id: 'wizard.profile.recap.incoherenceCatalogNetwork' })}
          </div>
        )}

        <div style={{ marginTop: 16, padding: '10px 12px', borderRadius: 6,
                      background: 'rgba(34,197,94,.08)', border: '1px solid rgba(34,197,94,.2)',
                      color: '#86efac', fontSize: '.82rem' }}>
          ✓ {t({ id: 'wizard.profile.recap.confirmed' })}
        </div>
      </>
    );
  }

  // -----------------------------------------------------------------
  // Routage des etapes
  // -----------------------------------------------------------------
  let body;
  if (internalStep === 0) {
    body = renderStep0();
  } else if (internalStep === 1) {
    body = renderStepAxis({
      axisKey: 'catalog_mode',
      options: ['local_only', 'network_published'],
      stepNumber: 1,
    });
  } else if (internalStep === 2) {
    body = renderStepAxis({
      axisKey: 'circulation_mode',
      options: ['off', 'informal', 'full_sigb'],
      stepNumber: 2,
    });
  } else if (internalStep === 3) {
    body = renderStepAxis({
      axisKey: 'network_mode',
      options: ['isolated', 'observer', 'federated'],
      stepNumber: 3,
    });
  } else if (internalStep === 4) {
    body = renderStepAxis({
      axisKey: 'governance_mode',
      options: ['informal', 'staff_roles', 'full_governance'],
      stepNumber: 4,
    });
  } else {
    body = renderStep5Recap();
  }

  // -----------------------------------------------------------------
  // Container : barre de progression + body
  // -----------------------------------------------------------------
  return (
    <fieldset style={{ border: '1px solid rgba(255,255,255,.12)', borderRadius: 12,
                       padding: 18, marginBottom: 18 }}>
      <legend style={{ fontSize: '.85rem', fontWeight: 700, padding: '0 8px',
                        color: 'var(--brand-accent, #f87171)' }}>
        {t({ id: 'wizard.profile.legend' })}
      </legend>

      {/* Barre d'etapes (visible quand on est dans 1-5) */}
      {internalStep > 0 && (
        <div style={{ display: 'flex', gap: 4, marginBottom: 14 }}>
          {[1, 2, 3, 4, 5].map(s => (
            <div key={s} style={{
              flex: 1, height: 4, borderRadius: 2,
              background: s <= internalStep ? 'var(--brand-accent, #f87171)' : 'rgba(255,255,255,.1)',
            }} />
          ))}
        </div>
      )}

      {body}

      {/* Indicateur statut pour parent : tous les axes sont-ils choisis ? */}
      {!allAxesChosen && internalStep > 0 && (
        <div style={{ marginTop: 12, fontSize: '.75rem', color: 'var(--brand-muted)',
                      textAlign: 'center' }}>
          {t({ id: 'wizard.profile.statusHint.incomplete' })}
        </div>
      )}
    </fieldset>
  );
}
