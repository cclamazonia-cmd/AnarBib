// src/pages/biblioteca/ReportsSection.jsx — E6, BibliotecaPage lot 4 (12/10/2026)
// L'onglet « Relatórios e resumos » : les compteurs, les titres les plus
// empruntés, l'historique des PEB, le compte-rendu en texte (généré ici,
// copié ou envoyé par fn_send_weekly_report_now) et le suivi financier.
// Tout ce qu'il lit — stats, équipe, tâches, PEB et leurs exemplaires,
// échanges, bibliothèques, canal — reste chargé par le parent (loadCore /
// loadHeavy) et arrive en props ; onChanged remplace le rechargement complet du parent.
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import PebHistorySection from '@/components/library/PebHistorySection';
import FinanceReportsSection from '@/components/biblioteca/FinanceReportsSection';
import { fs, bx } from './styles';

export default function ReportsSection({ libraryId, libraryName, lib, stats, members, tasks, illLoans, illItemsByLoan, exchanges, allLibraries, mailChannel, taskStatus, taskPrio, setMsg, onChanged }) {
  const { formatMessage: t } = useIntl();
  // ── Generate report text ────────────────────────────────
  function generateReportText() {
    const now = new Date().toLocaleDateString();
    const libName = lib?.name || libraryName;
    const lines = [
      t({id:'biblioteca.report.headerLine'},{lib:libName}),
      t({id:'biblioteca.report.dateLine'},{date:now}),
      '',
      t({id:'biblioteca.report.docsInCatalog'},{count:stats.books}),
      t({id:'biblioteca.report.authorities'},{count:stats.authors}),
      t({id:'biblioteca.report.localExemplars'},{count:stats.exemplars}),
      t({id:'biblioteca.report.registeredReaders'},{count:stats.readers}),
      t({id:'biblioteca.report.openLoans'},{count:stats.loansOpen}),
      t({id:'biblioteca.report.reservationsActive'},{count:stats.reservationsActive}),
      t({id:'biblioteca.report.consultationsActive'},{count:stats.consultationsActive}),
      t({id:'biblioteca.report.librarians'},{count:members.filter(m => m.role === 'librarian').length}),
      '',
      t({id:'biblioteca.report.team'}) + ':',
      ...members.map(m => {
        const p = m.profiles || {};
        const personName = [p.first_name, p.last_name].filter(Boolean).join(' ') || p.email || '—';
        const roleLabel = (m.role === 'librarian' || m.role === 'reader' || m.role === 'coordenador' || m.role === 'administrador')
          ? t({id:`roles.${m.role}`})
          : m.role;
        return `  ${personName} — ${roleLabel}`;
      }),
      '',
      t({id:'biblioteca.report.tasks'}) + ':',
      ...(tasks.length ? tasks.map(tk => `  [${taskStatus[tk.status] || tk.status}] ${tk.title} (${taskPrio[tk.priority] || tk.priority})${tk.owner ? ` — ${tk.owner}` : ''}`) : ['  ' + t({id:'biblioteca.report.noTasksRegistered'})]),
      // #ILL-reports volet A : section PEB du compte-rendu. Chiffres dérivés
      // de illLoans (la file active exclut déjà les PEB archivés), puis liste
      // des PEB EN COURS uniquement (ni devolvido ni cancelado), avec le sens
      // du prêt, le partenaire et les titres des exemplaires.
      ...(() => {
        const ILL_TERMINAL = ['devolvido', 'cancelado'];
        const ongoing = illLoans.filter(l => !ILL_TERMINAL.includes(l.status_global));
        const overdue = illLoans.filter(l => l.status_global === 'atrasado');
        const terminalPending = illLoans.filter(l => ILL_TERMINAL.includes(l.status_global));
        const out = [
          '',
          t({id:'biblioteca.report.illSection'}) + ':',
          '  ' + t({id:'biblioteca.report.illOngoing'}, {count: ongoing.length}),
          '  ' + t({id:'biblioteca.report.illOverdue'}, {count: overdue.length}),
          '  ' + t({id:'biblioteca.report.illTerminalPending'}, {count: terminalPending.length}),
        ];
        if (ongoing.length) {
          out.push('  ' + t({id:'biblioteca.report.illOngoingList'}) + ':');
          for (const loan of ongoing) {
            const isLender = loan.lender_library_id === libraryId;
            const partnerId = isLender ? loan.borrower_library_id : loan.lender_library_id;
            const partnerLib = allLibraries.find(l => l.id === partnerId);
            const partnerName = partnerLib?.short_name || partnerLib?.name || '—';
            const sens = isLender
              ? t({id:'biblioteca.report.illLendTo'}, {partner: partnerName})
              : t({id:'biblioteca.report.illBorrowFrom'}, {partner: partnerName});
            const statusLabel = t({id:`ill.status.${loan.status_global}`});
            out.push(`    #${loan.id} — ${sens} — ${statusLabel}`);
            // titres des exemplaires : illItemsByLoan est chargé dans le meme
            // chargement que illLoans, donc toujours synchrone ici.
            const items = illItemsByLoan[loan.id] || [];
            if (items.length) {
              const titles = items
                .map(it => it.titulo_cache || it.bib_ref || '—')
                .join(' ; ');
              out.push(`      ${titles}`);
            }
          }
        }
        return out;
      })(),
      // #EA-11 : section Trocas du compte-rendu. Trois chiffres dérivés de
      // exchanges (trocas impliquant la bibliothèque, requérante ou cible) :
      // propostas (créées sur 7 jours), aceitas (acceptées sur 7 jours) et en
      // cours (acceptées dont la phase d'exécution n'est ni completed ni
      // cancelled — phase manquante/illisible = en cours).
      ...(() => {
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const proposed = exchanges.filter(e => new Date(e.created_at) >= sevenDaysAgo).length;
        const accepted = exchanges.filter(e => e.status === 'accepted' && e.decided_at && new Date(e.decided_at) >= sevenDaysAgo).length;
        const ongoing = exchanges.filter(e => e.status === 'accepted' && (() => {
          try {
            const o = JSON.parse(e.object_ref || 'null');
            const ph = o && o.execution_followup && o.execution_followup.phase;
            return !['completed', 'cancelled'].includes(ph);
          } catch {
            return true;
          }
        })()).length;
        return [
          '',
          t({id:'biblioteca.report.exchangesSection'}) + ':',
          '  ' + t({id:'biblioteca.report.exchangesProposed'}, {count: proposed}),
          '  ' + t({id:'biblioteca.report.exchangesAccepted'}, {count: accepted}),
          '  ' + t({id:'biblioteca.report.exchangesOngoing'}, {count: ongoing}),
        ];
      })(),
    ];
    return lines.join('\n');
  }

  async function sendReport() {
    // EA-13 (etape 8) : envoi SERVEUR du rapport hebdomadaire via l'Edge Function
    // notify-weekly-report (Resend), debloque par la cloture de #110. Remplace le
    // placeholder mailto: historique. Destinataire resolu cote EF sur
    // weekly_report_email ; autorisation gardee par la RPC (staff de la biblio).
    const email = mailChannel?.weekly_report_email?.trim();
    if (!email) { setMsg({ text: t({id:'biblioteca.report.noWeeklyEmail'}), kind: 'error' }); return; }
    try {
      const { error } = await supabase.rpc('fn_send_weekly_report_now', { p_library_id: libraryId });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.report.sent' }, { email }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  return (<div>
          <h3 style={{ marginBottom:12 }}>{t({ id: 'biblioteca.reports.title' })}</h3>
          <div style={bx}>
            <div className="cat-book-grid">
              {[{v:stats.books,l:t({id:'catalog.stats.documents'})},{v:stats.authors,l:t({id:'catalog.stats.authorities'})},{v:stats.exemplars,l:t({id:'catalog.stats.exemplars'})},{v:stats.readers,l:t({id:'biblioteca.stats.readersActive'})},{v:stats.loansOpen,l:t({id:'biblioteca.stats.loansOpen'})},{v:stats.loansOverdue,l:t({id:'biblioteca.stats.loansOverdue'}),warn:stats.loansOverdue>0},{v:stats.loansCreated7d,l:t({id:'biblioteca.stats.loansCreated7d'})},{v:stats.loansCreated30d,l:t({id:'biblioteca.stats.loansCreated30d'})},{v:stats.loansReturned7d,l:t({id:'biblioteca.stats.loansReturned7d'})},{v:stats.reservationsActive,l:t({id:'biblioteca.stats.reservationsActive'})},{v:stats.consultationsActive,l:t({id:'biblioteca.stats.consultationsActive'})},{v:stats.trocasActive,l:t({id:'biblioteca.stats.trocasActive'})},{v:stats.librariansActive,l:t({id:'biblioteca.stats.librariansActive'})}].map((s,i)=>(
                <div key={i} style={{ padding:14, borderRadius:8, background:s.warn?'rgba(220,38,38,.15)':'rgba(0,0,0,.15)', textAlign:'center', border:s.warn?'1px solid rgba(220,38,38,.4)':'none' }}>
                  <div style={{ fontSize:'1.5rem', fontWeight:800 }}>{s.v}</div><div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{s.l}</div>
                </div>
              ))}
            </div>
          </div>

          {stats.topBooks && stats.topBooks.length > 0 && (
            <div style={bx}>
              <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.reports.topBooks90d' })}</h4>
              <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:10 }}>
                {t({ id: 'biblioteca.reports.topBooks90dHint' })}
              </div>
              <div style={{ display:'flex', flexDirection:'column', gap:6 }}>
                {stats.topBooks.map((b, i) => (
                  <div key={i} style={{ display:'flex', justifyContent:'space-between', gap:12, padding:'8px 12px', borderRadius:6, background:'rgba(0,0,0,.12)' }}>
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ fontSize:'.92rem', fontWeight:600, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{b.titulo || t({ id: 'common.untitled' })}</div>
                      <div style={{ fontSize:'.78rem', color:'var(--brand-muted)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{b.autor || t({ id: 'common.unknownAuthor' })}</div>
                    </div>
                    <div style={{ fontSize:'.92rem', fontWeight:700, alignSelf:'center', whiteSpace:'nowrap' }}>{t({ id: 'biblioteca.reports.topBooks.loanCount' }, { count: b.cnt })}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
          {/* #ILL-archive (25/05/2026) : consultation des PEB archivés.
              Composant dédié, lit la vue api.peb_history_v1, permet de
              désarchiver. Réservé au staff (l'onglet Rapports l'est déjà).
              #ILL-reports volet B : onChange=onChanged pour que la file active
              se rafraîchisse quand un PEB est désarchivé. */}
          <PebHistorySection libraryId={libraryId} allLibraries={allLibraries} onChange={onChanged} />
          <div style={bx}>
            <h4 style={{ margin:'0 0 10px' }}>{t({ id: 'biblioteca.reports.generate' })}</h4>
            <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:10 }}>
              {t({ id: 'biblioteca.reports.generateHint' })}
            </div>
            <textarea value={generateReportText()} readOnly rows={12} style={{...fs, fontFamily:'monospace', fontSize:'.82rem', resize:'vertical', marginBottom:10}} />
            <div style={{ display:'flex', gap:8, flexWrap:'wrap' }}>
              <button className="cat-btn primary" onClick={()=>{ navigator.clipboard?.writeText(generateReportText()); setMsg({text:t({id:'biblioteca.report.copiedToast'}),kind:'ok'}); }} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.reports.copy' })}</button>
              <button className="cat-btn secondary" onClick={sendReport} style={{ fontSize:'.88rem' }}>{t({ id: 'biblioteca.reports.sendEmail' })}</button>
              <span style={{ fontSize:'.82rem', color:'var(--brand-muted)', alignSelf:'center' }}>{t({ id: 'biblioteca.tasks.recipient' })} {mailChannel?.weekly_report_email || t({ id: 'common.notConfigured' })}</span>
            </div>
          </div>

          {/* Suivi financier exportable (cotisations + dépôts de garantie, DEPOT-9).
              Chaque sous-section ne s'affiche que si le système est actif. */}
          <FinanceReportsSection
            libraryId={libraryId}
            membershipEnabled={!!lib?.membership_enabled}
            depositEnabled={!!lib?.deposit_enabled}
            members={members}
          />
  </div>);
}
