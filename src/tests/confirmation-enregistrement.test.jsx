// ═══════════════════════════════════════════════════════════
// AnarBib — retours du catalogage (03-04/10/2026).
//   * useSaveConfirmation : message dans la barre d'état + toast temporaire ;
//     la page ne saute plus (décision du 04/10 : « barre collante + toast »).
//   * CatalogStatusBar : une apparence par type, l'erreur en role=alert, le
//     succès s'efface seul, le reste attend qu'on le ferme.
//   * ConfirmProvider / useConfirm : la fenêtre maison répond oui ou non.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { renderHook, act, render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';

const notify = vi.fn();
vi.mock('@/contexts/ToastContext', () => ({ useToast: () => ({ notify }) }));

const { useSaveConfirmation } = await import('@/hooks/useSaveConfirmation');
const { default: CatalogStatusBar } = await import('@/components/catalog/CatalogStatusBar');
const { ConfirmProvider, useConfirm } = await import('@/contexts/ConfirmContext');

const MESSAGES = { 'common.close': 'Fermer', 'common.cancel': 'Annuler', 'common.confirm': 'Confirmer' };
const intl = (ui) => <IntlProvider locale="fr" messages={MESSAGES}>{ui}</IntlProvider>;

afterEach(() => { cleanup(); vi.useRealTimers(); notify.mockClear(); });

describe('useSaveConfirmation', () => {
  it('pose le message et ouvre un toast de succès', () => {
    const setMsg = vi.fn();
    const { result } = renderHook(() => useSaveConfirmation(setMsg));
    act(() => result.current('Brouillon enregistré'));
    expect(setMsg).toHaveBeenCalledWith({ text: 'Brouillon enregistré', kind: 'ok' });
    expect(notify).toHaveBeenCalledWith({ kind: 'success', message: 'Brouillon enregistré' });
  });
  it('avec réserves : avertissement dans la barre, toast d’information', () => {
    const setMsg = vi.fn();
    const { result } = renderHook(() => useSaveConfirmation(setMsg));
    act(() => result.current('Enregistré, mais…', 'warn'));
    expect(setMsg).toHaveBeenCalledWith({ text: 'Enregistré, mais…', kind: 'warn' });
    expect(notify).toHaveBeenCalledWith({ kind: 'info', message: 'Enregistré, mais…' });
  });
  it('texte vide : rien', () => {
    const setMsg = vi.fn();
    const { result } = renderHook(() => useSaveConfirmation(setMsg));
    act(() => result.current(''));
    expect(setMsg).not.toHaveBeenCalled();
    expect(notify).not.toHaveBeenCalled();
  });
});

describe('CatalogStatusBar', () => {
  it('rien à dire : rien à l’écran', () => {
    const { container } = render(intl(<CatalogStatusBar msg={{ text: '', kind: 'ok' }} onClose={() => {}} />));
    expect(container.innerHTML).toBe('');
  });
  it('erreur : role=alert, reste affichée', () => {
    vi.useFakeTimers();
    const onClose = vi.fn();
    render(intl(<CatalogStatusBar msg={{ text: 'Échec', kind: 'error' }} onClose={onClose} />));
    expect(screen.getByRole('alert').className).toContain('cat-status--error');
    act(() => { vi.advanceTimersByTime(60000); });
    expect(onClose).not.toHaveBeenCalled();
  });
  it('succès : role=status, s’efface seul', () => {
    vi.useFakeTimers();
    const onClose = vi.fn();
    render(intl(<CatalogStatusBar msg={{ text: 'Enregistré', kind: 'ok' }} onClose={onClose} />));
    expect(screen.getByRole('status').className).toContain('cat-status--ok');
    act(() => { vi.advanceTimersByTime(10000); });
    expect(onClose).toHaveBeenCalledTimes(1);
  });
  it('type inconnu : information, jamais une fausse erreur ni un faux succès', () => {
    render(intl(<CatalogStatusBar msg={{ text: 'Recherche…', kind: 'loading' }} onClose={() => {}} />));
    expect(screen.getByRole('status').className).toContain('cat-status--info');
  });
  it('le bouton Fermer ferme', () => {
    const onClose = vi.fn();
    render(intl(<CatalogStatusBar msg={{ text: 'Attention', kind: 'warn' }} onClose={onClose} />));
    fireEvent.click(screen.getByRole('button', { name: 'Fermer' }));
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});

describe('useConfirm', () => {
  function Bouton({ onReponse, options }) {
    const confirmer = useConfirm();
    return <button type="button" onClick={async () => onReponse(await confirmer(options))}>agir</button>;
  }
  it('le bouton nommé répond oui, Annuler répond non', async () => {
    const reponses = [];
    render(intl(<ConfirmProvider><Bouton onReponse={(r) => reponses.push(r)}
      options={{ message: 'Supprimer ?', confirmLabel: 'Supprimer définitivement', tone: 'danger' }} /></ConfirmProvider>));
    fireEvent.click(screen.getByText('agir'));
    const supprimer = await screen.findByRole('button', { name: 'Supprimer définitivement' });
    expect(supprimer.className).toContain('ab-button--danger');
    await act(async () => { fireEvent.click(supprimer); });
    fireEvent.click(screen.getByText('agir'));
    await act(async () => { fireEvent.click(await screen.findByRole('button', { name: 'Annuler' })); });
    expect(reponses).toEqual([true, false]);
  });
});
