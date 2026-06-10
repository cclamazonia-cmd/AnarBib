import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import './ImportacoesPage.css';

// =============================================================================
// ImportWizard — assistant « Novo import » (IMP-8).
// =============================================================================
// Route dediee /importacoes/novo, coordenador-only (aligne IMP-14). Stepper
// lineaire qui RE-DERIVE le flux de la page v7 (IMP-15) : il ne fait que cabler
// les RPC fn_import_* deja existants. Ecriture book_drafts UNIQUEMENT a l'etape
// finale (promotion).
//
// v1 (cet increment) : coquille + etape Circuit. Le cablage des etapes Source /
// Pre-visualizacao / Promocao suit (increments 2-3). Etape Mapping differee
// (IMP-10 a venir) -> on reste a 4 etapes.
// =============================================================================

const CIRCUITS = ['migracao', 'arquivo', 'fontes'];

const STEPS = [
  { n: 1, key: 'circuit' },
  { n: 2, key: 'source' },
  { n: 3, key: 'preview' },
  { n: 4, key: 'promote' },
];

export default function ImportWizard() {
  const { role, isNetworkAdmin } = useLibrary();
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'importacoes.wizard.title' }));

  // IMP-14 : coordenador-only (aligne sur les wrappers fn_import_* + la nav).
  const canImport = role === 'coordenador' || role === 'administrador' || isNetworkAdmin;

  const [step, setStep] = useState(1);
  const [circuit, setCircuit] = useState(null);

  if (!canImport) {
    return (
      <PageShell>
        <Topbar />
        <Hero title={t({ id: 'importacoes.wizard.title' })} subtitle={t({ id: 'importacoes.restricted' })} />
        <Footer />
      </PageShell>
    );
  }

  const canNext = step === 1 ? !!circuit : step < 4;

  // ── Stepper ───────────────────────────────────────────────
  function renderStepper() {
    return (
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', margin: '18px 0 22px' }}>
        {STEPS.map((s) => {
          const active = step === s.n;
          const done = step > s.n;
          return (
            <div
              key={s.n}
              style={{
                display: 'flex', alignItems: 'center', gap: 8,
                padding: '7px 14px', borderRadius: 999, fontSize: '.85rem',
                fontWeight: active ? 700 : 500,
                background: active ? 'var(--brand-accent, #f87171)' : 'rgba(255,255,255,.06)',
                color: active ? '#fff' : (done ? 'var(--brand-fg, #e8e2d6)' : 'var(--brand-muted, #9a948a)'),
                border: '1px solid ' + (active ? 'transparent' : 'rgba(255,255,255,.10)'),
              }}
            >
              <span
                style={{
                  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                  width: 22, height: 22, borderRadius: '50%', fontSize: '.78rem', fontWeight: 700,
                  background: active ? 'rgba(0,0,0,.25)' : 'rgba(255,255,255,.10)',
                }}
              >
                {done ? '✓' : s.n}
              </span>
              {t({ id: `importacoes.wizard.step.${s.key}` })}
            </div>
          );
        })}
      </div>
    );
  }

  // ── Étape 1 : Circuit ─────────────────────────────────────
  function renderCircuit() {
    return (
      <div className="imp-sheet">
        <div className="imp-sheet__head">
          <span className="imp-sheet__title">{t({ id: 'importacoes.wizard.step.circuit' })}</span>
        </div>
        <div className="imp-sheet__body" style={{ display: 'grid', gap: 10 }}>
          {CIRCUITS.map((c) => {
            const selected = circuit === c;
            return (
              <button
                key={c}
                type="button"
                onClick={() => setCircuit(c)}
                style={{
                  textAlign: 'left', cursor: 'pointer',
                  padding: '14px 16px', borderRadius: 10,
                  background: selected ? 'rgba(248,113,113,.08)' : 'rgba(255,255,255,.03)',
                  border: '1px solid ' + (selected ? 'var(--brand-accent, #f87171)' : 'rgba(255,255,255,.12)'),
                  color: 'inherit', transition: 'all .15s ease',
                }}
              >
                <strong style={{ display: 'block', marginBottom: 4 }}>
                  {t({ id: `importacoes.wizard.circuit.${c}` })}
                </strong>
                <span className="imp-note">{t({ id: `importacoes.circuit.${c}.hint` })}</span>
              </button>
            );
          })}
        </div>
      </div>
    );
  }

  // ── Étapes 2-4 : placeholders (cablage : increments suivants) ──
  function renderWip(stepKey) {
    return (
      <div className="imp-sheet">
        <div className="imp-sheet__head">
          <span className="imp-sheet__title">{t({ id: `importacoes.wizard.step.${stepKey}` })}</span>
        </div>
        <div className="imp-sheet__body">
          <p className="imp-note">{t({ id: 'importacoes.wizard.wip' })}</p>
        </div>
      </div>
    );
  }

  return (
    <PageShell>
      <Topbar />
      <div className="imp-shell" style={{ maxWidth: 880, margin: '0 auto', padding: '0 16px 40px' }}>
        {/* Fil d'Ariane */}
        <nav style={{ fontSize: '.85rem', color: 'var(--brand-muted, #9a948a)', margin: '20px 0 0' }}>
          <Link to="/importacoes" style={{ color: 'inherit' }}>{t({ id: 'importacoes.title' })}</Link>
          <span style={{ margin: '0 8px' }}>›</span>
          <span style={{ color: 'var(--brand-fg, #e8e2d6)' }}>{t({ id: 'importacoes.wizard.title' })}</span>
        </nav>

        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, margin: '8px 0 0', fontFamily: 'var(--brand-font-body)' }}>
          {t({ id: 'importacoes.wizard.title' })}
        </h1>
        <p style={{ color: 'var(--brand-muted)', margin: '4px 0 0', fontSize: '.9rem' }}>
          {t({ id: 'importacoes.wizard.subtitle' })}
        </p>

        {renderStepper()}

        {step === 1 && renderCircuit()}
        {step === 2 && renderWip('source')}
        {step === 3 && renderWip('preview')}
        {step === 4 && renderWip('promote')}

        {/* Navigation */}
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 22 }}>
          <button
            className="cat-btn secondary"
            type="button"
            disabled={step === 1}
            onClick={() => setStep((s) => Math.max(1, s - 1))}
          >
            {t({ id: 'importacoes.wizard.back' })}
          </button>
          <button
            className="cat-btn primary"
            type="button"
            disabled={!canNext}
            onClick={() => setStep((s) => Math.min(4, s + 1))}
          >
            {t({ id: 'importacoes.wizard.next' })}
          </button>
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
