// ============================================================
// Patch binaire safe — Frontend B6 modal annulation biblio
// VERSION 2 (15/05/2026 soir) : compteur de vérification corrigé
// ============================================================
// V1 attendait 3 occurrences de `openCancelModal` mais il n'y en a que 2 :
//   - 1 dans la déclaration `function openCancelModal(consulta) {`
//   - 1 dans le onClick `openCancelModal(c)`
// Le rendu JSX du modal utilise `cancelTarget`, `closeCancelModal`,
// `handleCancelSubmit` — pas `openCancelModal`.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE_PATH = path.join(REPO_ROOT, 'src', 'pages', 'painel', 'PanelPage.jsx');

console.log('===== Patch B6 frontend v2 =====');
console.log(`Cible : ${FILE_PATH}\n`);

if (!fs.existsSync(FILE_PATH)) {
  console.error(`[FATAL] Fichier introuvable : ${FILE_PATH}`);
  process.exit(1);
}

let buf = fs.readFileSync(FILE_PATH);
const originalSize = buf.length;
const originalMd5 = crypto.createHash('md5').update(buf).digest('hex');
console.log(`Taille initiale : ${originalSize} bytes`);
console.log(`MD5 initial : ${originalMd5}\n`);

// ============================================================
// IDEMPOTENCE : detecter si le patch est deja applique
// ============================================================
if (buf.toString('utf8').includes('openCancelModal')) {
  console.log('[INFO] Patch deja applique (openCancelModal deja present). Aucune modification.');
  process.exit(0);
}

// ============================================================
// MODIFICATION 1 — Ajouter le state du modal Cancel
// ============================================================
console.log('[1/3] Ajout du state cancelTarget/cancelForm/etc...');

const ANCHOR_1_BEFORE = `  function closeScheduleModal() {
    if (scheduling) return;
    setScheduleTarget(null);
    setScheduleError('');
  }

`;

const INSERT_1 = `  function closeScheduleModal() {
    if (scheduling) return;
    setScheduleTarget(null);
    setScheduleError('');
  }

  // \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
  // B6 (15/05/2026) : modal d'annulation biblio avec note obligatoire
  // Fix spec consultas v2.1 \xA76.2 / \xA78.1
  // \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
  const [cancelTarget, setCancelTarget] = useState(null);
  const [cancelForm, setCancelForm] = useState({ note: '' });
  const [cancelError, setCancelError] = useState('');
  const [cancelling, setCancelling] = useState(false);

  function openCancelModal(consulta) {
    setCancelTarget(consulta);
    setCancelForm({ note: '' });
    setCancelError('');
  }

  function closeCancelModal() {
    if (cancelling) return;
    setCancelTarget(null);
    setCancelError('');
  }

  async function handleCancelSubmit() {
    if (!cancelTarget) return;
    const note = cancelForm.note.trim();
    setCancelError('');
    if (note.length < 5) {
      setCancelError(t({ id: 'panel.consultation.cancel.errorNoteTooShort' }));
      return;
    }
    if (note.length > 300) {
      setCancelError(t({ id: 'panel.consultation.cancel.errorNoteTooLong' }));
      return;
    }
    setCancelling(true);
    try {
      await setConsultaWorkflow(
        cancelTarget.consulta_id,
        cancelTarget.line_no,
        'cancelada_biblioteca',
        note
      );
      setCancelTarget(null);
      setCancelForm({ note: '' });
    } catch (err) {
      const msg = err?.message || '';
      if (msg.includes('cancel_note_required')) {
        setCancelError(t({ id: 'panel.consultation.cancel.errorBackend' }));
      } else {
        setCancelError(msg || t({ id: 'panel.consultation.cancel.errorGeneric' }));
      }
    } finally {
      setCancelling(false);
    }
  }

`;

const anchor1Buf = Buffer.from(ANCHOR_1_BEFORE, 'utf8');
const insert1Buf = Buffer.from(INSERT_1, 'utf8');

const idx1 = buf.indexOf(anchor1Buf);
if (idx1 === -1) {
  console.error('[FATAL] Modification 1 : ancre introuvable (closeScheduleModal block)');
  process.exit(1);
}

const before1 = buf.slice(0, idx1);
const after1 = buf.slice(idx1 + anchor1Buf.length);
buf = Buffer.concat([before1, insert1Buf, after1]);
console.log(`  OK : ancre trouvee \xE0 offset ${idx1}, ${insert1Buf.length - anchor1Buf.length} bytes ajoutes`);

// ============================================================
// MODIFICATION 2 — Remplacer le onClick du bouton Anular
// ============================================================
console.log('\n[2/3] Remplacement du onClick du bouton Anular...');

const ANCHOR_2 = `<button className="ab-button ab-button--mini ab-button--danger" onClick={() => setConsultaWorkflow(c.consulta_id, c.line_no, 'cancelada_biblioteca', t({id:'panel.consultation.cancelledByPanel'}))}>{t({ id: 'common.cancel' })}</button>`;

const REPLACE_2 = `<button className="ab-button ab-button--mini ab-button--danger" onClick={() => openCancelModal(c)}>{t({ id: 'common.cancel' })}</button>`;

const anchor2Buf = Buffer.from(ANCHOR_2, 'utf8');
const replace2Buf = Buffer.from(REPLACE_2, 'utf8');

const idx2 = buf.indexOf(anchor2Buf);
if (idx2 === -1) {
  console.error('[FATAL] Modification 2 : ancre introuvable (bouton Anular consulta)');
  process.exit(1);
}

const idx2Bis = buf.indexOf(anchor2Buf, idx2 + 1);
if (idx2Bis !== -1) {
  console.error(`[FATAL] Modification 2 : ancre trouvee 2 fois (offset ${idx2} et ${idx2Bis})`);
  process.exit(1);
}

const before2 = buf.slice(0, idx2);
const after2 = buf.slice(idx2 + anchor2Buf.length);
buf = Buffer.concat([before2, replace2Buf, after2]);
console.log(`  OK : ancre trouvee \xE0 offset ${idx2}, remplacement effectue`);

// ============================================================
// MODIFICATION 3 — Ajouter le rendu JSX du modal Cancel
// ============================================================
console.log('\n[3/3] Ajout du rendu JSX du modal Cancel...');

const ANCHOR_3 = `          <Button onClick={handleScheduleSubmit} disabled={scheduling}>
            {scheduling ? t({ id: 'panel.consultation.schedule.submitting' }) : t({ id: 'panel.consultation.schedule.submitButton' })}
          </Button>
        </div>
      </Modal>
    </PageShell>
  );
}`;

const REPLACE_3 = `          <Button onClick={handleScheduleSubmit} disabled={scheduling}>
            {scheduling ? t({ id: 'panel.consultation.schedule.submitting' }) : t({ id: 'panel.consultation.schedule.submitButton' })}
          </Button>
        </div>
      </Modal>

      {/* B6 (15/05/2026) : modal d'annulation biblio avec note obligatoire */}
      <Modal
        isOpen={!!cancelTarget}
        onClose={closeCancelModal}
        title={t({ id: 'panel.consultation.cancel.title' })}
        size="medium"
      >
        <div className="ab-modal__body">
          {cancelTarget && (
            <>
              <p style={{ marginBottom: 8 }}>
                <strong>{t({ id: 'panel.consultation.cancel.subtitle' })} :</strong>{' '}
                {cancelTarget.user_name || cancelTarget.user_email || cancelTarget.user_public_id || '?'}
              </p>
              <p style={{ marginBottom: 16, fontStyle: 'italic', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.book' })} : {cancelTarget.titulo || cancelTarget.bib_ref || '?'}
              </p>
            </>
          )}
          <p style={{ marginBottom: 12, fontSize: '.9rem' }}>
            {t({ id: 'panel.consultation.cancel.description' })}
          </p>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              <span style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.noteLabel' })}
              </span>
              <textarea
                value={cancelForm.note}
                onChange={(e) => setCancelForm({ note: e.target.value })}
                placeholder={t({ id: 'panel.consultation.cancel.notePlaceholder' })}
                className="ab-input"
                rows={4}
                maxLength={300}
                disabled={cancelling}
              />
              <span style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>
                {t({ id: 'panel.consultation.cancel.noteHint' })} ({cancelForm.note.length}/300, min 5)
              </span>
            </label>
            {cancelError && (
              <p style={{ color: 'var(--brand-danger, #c62828)', fontSize: '.9rem', margin: 0 }}>{cancelError}</p>
            )}
          </div>
        </div>
        <div className="ab-modal__actions">
          <Button variant="secondary" onClick={closeCancelModal} disabled={cancelling}>
            {t({ id: 'panel.consultation.cancel.backButton' })}
          </Button>
          <Button onClick={handleCancelSubmit} disabled={cancelling || cancelForm.note.trim().length < 5}>
            {cancelling ? t({ id: 'panel.consultation.cancel.submitting' }) : t({ id: 'panel.consultation.cancel.confirmButton' })}
          </Button>
        </div>
      </Modal>
    </PageShell>
  );
}`;

const anchor3Buf = Buffer.from(ANCHOR_3, 'utf8');
const replace3Buf = Buffer.from(REPLACE_3, 'utf8');

const idx3 = buf.indexOf(anchor3Buf);
if (idx3 === -1) {
  console.error('[FATAL] Modification 3 : ancre introuvable (fin du modal Schedule)');
  process.exit(1);
}

const before3 = buf.slice(0, idx3);
const after3 = buf.slice(idx3 + anchor3Buf.length);
buf = Buffer.concat([before3, replace3Buf, after3]);
console.log(`  OK : ancre trouvee \xE0 offset ${idx3}, ${replace3Buf.length - anchor3Buf.length} bytes ajoutes`);

// ============================================================
// Verifications finales
// ============================================================
const finalSize = buf.length;
const finalMd5 = crypto.createHash('md5').update(buf).digest('hex');
const sizeDelta = finalSize - originalSize;
const finalContent = buf.toString('utf8');

console.log('\n===== Verifications finales =====');
console.log(`Taille initiale : ${originalSize} bytes`);
console.log(`Taille finale   : ${finalSize} bytes`);
console.log(`Delta           : +${sizeDelta} bytes`);
console.log(`MD5 final       : ${finalMd5}`);

// CORRECTION v2 : openCancelModal n'apparait que 2 fois dans le fichier final
//   1. function openCancelModal(consulta) {  (declaration)
//   2. onClick={() => openCancelModal(c)}    (usage dans le bouton Anular)
// Le rendu JSX du modal n'utilise pas openCancelModal mais cancelTarget,
// closeCancelModal et handleCancelSubmit.
const openCancelCount = (finalContent.match(/openCancelModal/g) || []).length;
console.log(`\nOccurrences de openCancelModal : ${openCancelCount} (attendu : 2)`);

if (openCancelCount !== 2) {
  console.error(`[FATAL] Nombre d'occurrences inattendu (attendu 2, trouve ${openCancelCount})`);
  process.exit(1);
}

// Verification supplementaire : les autres identifiants critiques
const closeCancelCount = (finalContent.match(/closeCancelModal/g) || []).length;
const handleCancelCount = (finalContent.match(/handleCancelSubmit/g) || []).length;
const cancelTargetCount = (finalContent.match(/cancelTarget/g) || []).length;

console.log(`Occurrences de closeCancelModal : ${closeCancelCount} (attendu : 3 = declaration + 2 onClick)`);
console.log(`Occurrences de handleCancelSubmit : ${handleCancelCount} (attendu : 2 = declaration + 1 onClick)`);
console.log(`Occurrences de cancelTarget : ${cancelTargetCount} (attendu : >= 7)`);

if (closeCancelCount !== 3 || handleCancelCount !== 2 || cancelTargetCount < 7) {
  console.error('[FATAL] Identifiants critiques manquants ou en nombre insuffisant');
  process.exit(1);
}

// Verification : 0 occurrence de panel.consultation.cancelledByPanel (cle i18n obsolete)
const obsoleteCount = (finalContent.match(/panel\.consultation\.cancelledByPanel/g) || []).length;
console.log(`Occurrences de cle obsolete panel.consultation.cancelledByPanel : ${obsoleteCount} (attendu : 0)`);

if (obsoleteCount !== 0) {
  console.error(`[FATAL] Cle i18n obsolete encore presente`);
  process.exit(1);
}

// ============================================================
// Ecriture
// ============================================================
console.log('\n===== Ecriture =====');
fs.writeFileSync(FILE_PATH, buf);
console.log(`OK : fichier ecrit (${finalSize} bytes)`);
console.log('\nProchaine etape : npm run build pour valider la syntaxe');
