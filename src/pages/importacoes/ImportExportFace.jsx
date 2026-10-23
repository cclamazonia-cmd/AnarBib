// Face « Export » de la page Importations — export de lot, export de fonds
// (notices + fichiers), envoi direct à une companheira, curation des fichiers
// publics, attache des fonds reçus, dé-vérification : sortie d'ImportacoesPage.jsx
// telle quelle (E6, 23/10/2026), avec l'état et les actions qu'elle est seule à
// lire. La page lui passe la bibliothèque et son bandeau de messages.
// Garde : src/tests/importacoes-face-export-montee.test.jsx.
import { useIntl } from 'react-intl';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase, SUPABASE_URL } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { erreurDeFonction } from '@/lib/edgeError';
import { assertRpcOk } from '../../lib/rpcStatus.js';

// La pastille d'état, la même que celle de la page.
function Pill({ children, variant = 'muted' }) {
  return <span className={`cat-pill ${variant}`}>{children}</span>;
}

export default function ImportExportFace(p) {
  const { formatMessage: t } = useIntl();
  const {
    libraryId, setMsg,
  } = p;

  // ── Export de lote (Lot 5, IMP-13) ─────────────────────
  const [exportFormat, setExportFormat] = useState('csv');
  const [exportLoading, setExportLoading] = useState(false);

  // ── Export de fonds (EX-5, IMP-16 — niveau 2 : notices + fichiers) ───
  const [fondsFormat, setFondsFormat] = useState('json');
  const [fondsCount, setFondsCount] = useState(null);
  const [fondsCounting, setFondsCounting] = useState(false);
  const [fondsLoading, setFondsLoading] = useState(false);

  // ── EX-4 : envoi direct à une companheira (droit mutualisation) ──
  const [fondsTarget, setFondsTarget] = useState('');
  const [fondsPartners, setFondsPartners] = useState([]);
  const [fondsPartnersLoaded, setFondsPartnersLoaded] = useState(false);
  const [fondsSending, setFondsSending] = useState(false);

  // ── Curation des fichiers pour l'export (Solution 1, entrée a) ──
  const [pubResources, setPubResources] = useState([]);
  const [pubLoaded, setPubLoaded] = useState(false);
  const [pubLoading, setPubLoading] = useState(false);
  const [pubPromotingId, setPubPromotingId] = useState(null);
  const [selectedPub, setSelectedPub] = useState(() => new Set()); // multi-sélection promotion (point 5)
  const [bulkPromoting, setBulkPromoting] = useState(false);

  // ── Attache des fonds reçus (Solution 1, entrée b) ──
  const [recvAssets, setRecvAssets] = useState([]);
  const [recvLoaded, setRecvLoaded] = useState(false);
  const [recvLoading, setRecvLoading] = useState(false);
  const [attachTarget, setAttachTarget] = useState(null);
  const [bookQuery, setBookQuery] = useState('');
  const [bookResults, setBookResults] = useState([]);
  const [bookSearching, setBookSearching] = useState(false);
  const [attaching, setAttaching] = useState(false);
  const [attachMode, setAttachMode] = useState({}); // received_asset_id → 'export'|'read'|'both' (point 6)

  // ── Dé-vérification des digital_assets (entrée c) ──
  const [verifiedAssets, setVerifiedAssets] = useState([]);
  const [verifiedLoaded, setVerifiedLoaded] = useState(false);
  const [verifiedLoading, setVerifiedLoading] = useState(false);
  const [revokingId, setRevokingId] = useState(null);
  const [confirmingId, setConfirmingId] = useState(null);

  // ── Export de lote : le catalogue par pages, le fichier assemblé ici ──
  // L'accès (coordenador de la biblio, IMP-14) est re-validé par la RPC ; un rôle
  // insuffisant renvoie son erreur, affichée.
  // H26 (28/09/2026) : plus d'edge function entre la base et le fichier. Mesuré :
  // sérialiser 2 200 notices en ISO 2709 coûtait déjà 2 s de CPU à une edge
  // function (sa limite), 50 000 bien au-delà. La RPC rend le catalogue par
  // pages de 1 000 (≈ 0,14 ms par notice en production, loin des 8 s du rôle),
  // et le fichier est écrit ici avec le MÊME module que l'import relit
  // (supabase/functions/_shared/marc, chargé à la demande).
  async function handleExportLote() {
    if (!libraryId) {
      setMsg({ text: t({ id: 'importacoes.export.lote.error' }, { message: 'library_id' }), kind: 'error' });
      return;
    }
    setExportLoading(true);
    setMsg({ text: t({ id: 'importacoes.export.lote.exporting' }), kind: 'info' });
    try {
      // H25 : les autorités liées aux notices de la bibliothèque (UNIMARC
      // Autorités) ; leur 001 est le $3 que portent les notices exportées.
      if (exportFormat === 'unimarc_autorites') {
        const { data, error } = await supabase.rpc('fn_export_authorities_lote', { p_library_id: libraryId });
        if (error) throw error;
        const [{ autorites }, { ecrireIso2709 }] = await Promise.all([
          import('../../../supabase/functions/_shared/marc/autorites.ts'),
          import('../../../supabase/functions/_shared/marc/iso2709.ts'),
        ]);
        const lib = data?.library ?? null;
        const r = ecrireIso2709(autorites(data ?? {}, { bibliotheque: lib ? { pays: lib.country ?? null, langue: lib.default_locale ?? null } : null }));
        const url = URL.createObjectURL(new Blob([r.octets], { type: 'application/marc' }));
        const link = document.createElement('a');
        link.href = url;
        link.download = `autoridades-${lib?.slug || libraryId}-${new Date().toISOString().slice(0, 10)}.mrc`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
        setMsg(r.avertissements.length
          ? { text: t({ id: 'importacoes.export.lote.warnings' }, { n: r.avertissements.length }), kind: 'info' }
          : { text: t({ id: 'importacoes.export.lote.success' }), kind: 'ok' });
        return;
      }
      const records = [];
      let apres = null;
      let total = null;
      let library = null;
      do {
        const { data, error } = await supabase.rpc('fn_export_catalog_lote', { p_library_id: libraryId, p_apres: apres, p_limite: 1000 });
        if (error) throw error;
        if (total === null && data?.total != null) total = Number(data.total);
        library = data?.library ?? library;
        if (Array.isArray(data?.records)) records.push(...data.records);
        apres = data?.next ?? null;
        setMsg({ text: t({ id: 'importacoes.export.lote.progress' }, { n: records.length, total: total ?? records.length }), kind: 'info' });
      } while (apres);
      const { serializeCatalog } = await import('../../../supabase/functions/export-catalog-lote/serialize.ts');
      const r = serializeCatalog(records, exportFormat, {
        bibliotheque: library ? { nom: library.short_name || library.name || null, pays: library.country ?? null, langue: library.default_locale ?? null } : null,
      });
      // UTF-8 BOM pour le CSV (compat Excel / accents).
      const blob = new Blob([r.ext === 'csv' ? '\uFEFF' + r.content : r.content], { type: r.mime });
      const jour = new Date().toISOString().slice(0, 10);
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `catalogo-${library?.slug || libraryId}-${jour}.${r.ext}`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
      // H23 : ce que le format n'a pas pu porter en entier (zone raccourcie,
      // notice écartée).
      const remarques = r.avertissements?.length || 0;
      setMsg(remarques > 0
        ? { text: t({ id: 'importacoes.export.lote.warnings' }, { n: remarques }), kind: 'info' }
        : { text: t({ id: 'importacoes.export.lote.success' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.lote.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setExportLoading(false);
    }
  }

  // ── Export de fonds (EX-5, IMP-16) : aperçu éligibles + ZIP notices+fichiers ──
  // Niveau 2 — remise d'un lot à une biblioteca companheira. Miroir de
  // handleExportLote, mais via l'EF export-fonds-bundle (EX-2) : le ZIP embarque
  // les notices sérialisées + un manifeste + les fichiers « domaine public
  // confirmé » (P3 strict). Le gate coordenador (IMP-14) est re-validé côté RPC.
  async function loadFondsEligibleCount() {
    if (!libraryId) {
      setMsg({ text: t({ id: 'importacoes.export.fonds.error' }, { message: 'library_id' }), kind: 'error' });
      return;
    }
    setFondsCounting(true);
    try {
      const { data, error } = await supabase.rpc('fn_export_fonds_eligible_count', { p_library_id: libraryId });
      if (error) throw error;
      setFondsCount(Number(data) || 0);
    } catch (err) {
      setFondsCount(null);
      setMsg({ text: t({ id: 'importacoes.export.fonds.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setFondsCounting(false);
    }
  }

  async function handleExportFonds() {
    if (!libraryId) {
      setMsg({ text: t({ id: 'importacoes.export.fonds.error' }, { message: 'library_id' }), kind: 'error' });
      return;
    }
    setFondsLoading(true);
    setMsg({ text: t({ id: 'importacoes.export.fonds.preparing' }), kind: 'info' });
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(
        `${SUPABASE_URL}/functions/v1/export-fonds-bundle`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${session?.access_token}`,
            apikey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ library_id: libraryId, format: fondsFormat }),
        }
      );
      if (!res.ok) {
        let m = `HTTP ${res.status}`;
        try { const j = await res.json(); if (j?.error) m = j.error; } catch { /* corps non-JSON */ }
        throw new Error(m);
      }
      const blob = await res.blob();
      const cd = res.headers.get('Content-Disposition') || '';
      const match = cd.match(/filename="?([^"]+)"?/);
      const filename = match ? match[1] : `fonds-${libraryId}.zip`;
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
      const truncated = (res.headers.get('X-Truncated') || '') === 'true';
      const fileCount = res.headers.get('X-File-Count') || '0';
      if (truncated) {
        setMsg({ text: t({ id: 'importacoes.export.fonds.truncated' }, { count: fileCount }), kind: 'info' });
      } else {
        setMsg({ text: t({ id: 'importacoes.export.fonds.success' }), kind: 'ok' });
      }
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.fonds.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setFondsLoading(false);
    }
  }

  // ── Envoi direct d'un lot de fonds à une companheira (EX-4) ──────────────────
  // Charge les partenariats actifs portant le droit `mutualisation` (miroir
  // digishare : fn_partnership_list_mine). Le transfert lui-même est gaté côté SQL.
  async function loadFondsPartners() {
    if (!libraryId) return;
    try {
      const { data, error } = await supabase.rpc('fn_partnership_list_mine', { p_library_id: libraryId });
      if (error) throw error;
      const muta = (data || []).filter(
        (r) => r.direction === 'active' && Array.isArray(r.rights) && r.rights.includes('mutualisation'),
      );
      setFondsPartners(muta);
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.fonds.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setFondsPartnersLoaded(true);
    }
  }

  async function handleDepositFondsDirect() {
    if (!libraryId || !fondsTarget) {
      setMsg({ text: t({ id: 'importacoes.export.fonds.error' }, { message: 'companheira' }), kind: 'error' });
      return;
    }
    setFondsSending(true);
    setMsg({ text: t({ id: 'importacoes.export.fonds.directSending' }), kind: 'info' });
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(
        `${SUPABASE_URL}/functions/v1/deposit-fonds-direct`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${session?.access_token}`,
            apikey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ source_library_id: libraryId, target_library_id: fondsTarget }),
        }
      );
      const out = await res.json().catch(() => ({}));
      if (!res.ok) throw erreurDeFonction(out, res.status);   // E24 : le code, traduit
      setMsg({
        text: t({ id: 'importacoes.export.fonds.directSent' }, { count: out?.inserted_rows ?? 0, files: out?.received_files_deposited ?? 0 }),
        kind: 'ok',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.fonds.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setFondsSending(false);
    }
  }

  // ── Curation : promouvoir un fichier public en digital_asset vérifié (Sol. 1a) ──
  // Rend une fiche éligible à l'export de fonds (EX-1 exige un digital_asset
  // public_domain_confirmed, distinct du « libre de droits » coché au catalogage).
  async function loadPublishableResources() {
    if (!libraryId) return;
    setPubLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_export_publishable_resources', { p_library_id: libraryId });
      if (error) throw error;
      setPubResources(Array.isArray(data) ? data : []);
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.curate.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setPubLoaded(true);
      setPubLoading(false);
    }
  }

  async function handlePublishResource(res) {
    setPubPromotingId(res.resource_id);
    try {
      const { data: rpcData, error } = await supabase.rpc('fn_publish_digital_asset_from_resource', { p_resource_id: res.resource_id });
      if (error) throw error;
      assertRpcOk(rpcData);
      setPubResources((prev) => prev.filter((r) => r.resource_id !== res.resource_id));
      setMsg({ text: t({ id: 'importacoes.export.curate.validated' }, { title: res.book_title || res.label || '—' }), kind: 'ok' });
      if (fondsCount != null) await loadFondsEligibleCount();
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.curate.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setPubPromotingId(null);
    }
  }

  // Multi-sélection : valider plusieurs fichiers d'un coup (point 5). Boucle sur la RPC par-item
  // (jamais un « tout valider » : tout fichier public n'est pas forcément domaine public).
  function togglePub(id) {
    setSelectedPub((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }

  async function handleBulkPublish() {
    const ids = pubResources.filter((r) => selectedPub.has(r.resource_id)).map((r) => r.resource_id);
    if (ids.length === 0) return;
    setBulkPromoting(true);
    setMsg({ text: t({ id: 'importacoes.export.curate.bulkValidating' }, { n: ids.length }), kind: 'info' });
    let ok = 0, fail = 0;
    for (const id of ids) {
      try {
        const { data: rpcData, error } = await supabase.rpc('fn_publish_digital_asset_from_resource', { p_resource_id: id });
        if (error) throw error;
        assertRpcOk(rpcData);
        ok += 1;
      } catch { fail += 1; }
    }
    setSelectedPub(new Set());
    if (fondsCount != null) await loadFondsEligibleCount();
    await loadPublishableResources();
    setMsg({ text: t({ id: 'importacoes.export.curate.bulkDone' }, { ok, fail }), kind: fail ? 'error' : 'ok' });
    setBulkPromoting(false);
  }

  // ── Attache d'un fichier de fonds reçu à un livre (Solution 1b) ──────────────
  async function loadReceivedAssets() {
    if (!libraryId) return;
    setRecvLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_list_received_assets_to_attach', { p_library_id: libraryId });
      if (error) throw error;
      setRecvAssets(Array.isArray(data) ? data : []);
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.attach.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setRecvLoaded(true);
      setRecvLoading(false);
    }
  }

  function startAttach(asset) {
    setAttachTarget(asset);
    setBookQuery('');
    setBookResults([]);
  }

  async function searchBooks() {
    if (!libraryId || !bookQuery.trim()) return;
    setBookSearching(true);
    try {
      const { data, error } = await supabase.rpc('fn_search_library_books', { p_library_id: libraryId, p_query: bookQuery.trim() });
      if (error) throw error;
      setBookResults(Array.isArray(data) ? data : []);
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.attach.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setBookSearching(false);
    }
  }

  async function handleAttach(asset, book) {
    if (!asset || !book?.book_id) return;
    const mode = attachMode[asset.received_asset_id] || 'both';
    setAttaching(true);
    setMsg({ text: t({ id: 'importacoes.export.attach.attaching' }), kind: 'info' });
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(
        `${SUPABASE_URL}/functions/v1/attach-received-asset`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${session?.access_token}`,
            apikey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ received_asset_id: asset.received_asset_id, book_id: book.book_id, mode }),
        }
      );
      const out = await res.json().catch(() => ({}));
      if (!res.ok) throw erreurDeFonction(out, res.status);   // E24 : le code, traduit
      setRecvAssets((prev) => prev.filter((a) => a.received_asset_id !== asset.received_asset_id));
      setAttachTarget(null);
      setBookResults([]);
      setBookQuery('');
      setMsg({ text: t({ id: 'importacoes.export.attach.attached' }, { title: book.title || '—' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.attach.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setAttaching(false);
    }
  }

  // ── Dé-vérifier un digital_asset (annuler une revendication domaine public, entrée c) ──
  async function loadVerifiedAssets() {
    if (!libraryId) return;
    setVerifiedLoading(true);
    try {
      const { data, error } = await supabase.rpc('fn_list_verified_digital_assets', { p_library_id: libraryId });
      if (error) throw error;
      setVerifiedAssets(Array.isArray(data) ? data : []);
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.verified.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setVerifiedLoaded(true);
      setVerifiedLoading(false);
    }
  }

  async function handleRevoke(asset) {
    if (!window.confirm(t({ id: 'importacoes.export.verified.confirm' }, { title: asset.book_title || '—' }))) return;
    setRevokingId(asset.asset_id);
    setMsg({ text: t({ id: 'importacoes.export.verified.revoking' }), kind: 'info' });
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(
        `${SUPABASE_URL}/functions/v1/revoke-digital-asset`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${session?.access_token}`,
            apikey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ asset_id: asset.asset_id }),
        }
      );
      const out = await res.json().catch(() => ({}));
      if (!res.ok) throw erreurDeFonction(out, res.status);   // E24 : le code, traduit
      setVerifiedAssets((prev) => prev.filter((a) => a.asset_id !== asset.asset_id));
      setMsg({
        text: t({ id: out?.file_removed ? 'importacoes.export.verified.revokedFile' : 'importacoes.export.verified.revoked' }, { title: asset.book_title || '—' }),
        kind: 'ok',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.verified.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setRevokingId(null);
    }
  }

  // ── Confirmer « domaine public » un asset to_review (acte explicite, point 1) ──
  async function handleConfirm(asset) {
    if (!window.confirm(t({ id: 'importacoes.export.verified.confirmAsk' }, { title: asset.book_title || '—', source: asset.source_name || '—' }))) return;
    setConfirmingId(asset.asset_id);
    setMsg({ text: t({ id: 'importacoes.export.verified.confirming' }), kind: 'info' });
    try {
      const { data: rpcData, error } = await supabase.rpc('fn_confirm_digital_asset_rights', { p_asset_id: asset.asset_id });
      if (error) throw error;
      assertRpcOk(rpcData);
      setVerifiedAssets((prev) => prev.map((a) => (a.asset_id === asset.asset_id ? { ...a, review_state: 'public_domain_confirmed' } : a)));
      setMsg({ text: t({ id: 'importacoes.export.verified.confirmedDP' }, { title: asset.book_title || '—' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'importacoes.export.verified.error' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setConfirmingId(null);
    }
  }

  return (
    <>
            <div className="imp-frontier imp-frontier--export">
              <span aria-hidden="true">⇄</span>
              <div>
                <b>{t({ id: 'importacoes.export.frontier.title' })}</b>{' '}
                {t({ id: 'importacoes.export.frontier.desc' })}
              </div>
            </div>

            {/* E12 lot C : le bloc « Partage ILL » (circuit en développement) ne
                s'affiche plus — un chantier ne se montre pas aux usagères. Les
                clés importacoes.export.partilha.* restent pour le jour où il
                sera livré. */}

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.lote.title' })}<Pill variant="ok">UNIMARC · MARC21 · CSV · JSON</Pill></span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.lote.desc' })}</p>
                <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
                  <select
                    className="ab-select"
                    aria-label={t({ id: 'importacoes.export.lote.format' })}
                    value={exportFormat}
                    onChange={(e) => setExportFormat(e.target.value)}
                    disabled={exportLoading}
                    style={{ maxWidth: 240 }}
                  >
                    {/* H23 (28/09/2026) : UNIMARC, le format de PMB, en ISO 2709 et en
                        XML (« XML MARC ») ; MARC21 en ISO 2709 et en MARCXML. */}
                    <option value="unimarc_iso2709">UNIMARC — ISO 2709</option>
                    <option value="unimarc_xml">UNIMARC — XML</option>
                    <option value="unimarc_autorites">{t({ id: 'importacoes.export.lote.formatAutorites' })}</option>
                    <option value="marc21_iso2709">MARC21 — ISO 2709</option>
                    <option value="marcxml">MARC21 — MARCXML</option>
                    <option value="csv">CSV</option>
                    <option value="json">JSON</option>
                  </select>
                  <button
                    className="cat-btn primary"
                    onClick={handleExportLote}
                    disabled={exportLoading || !libraryId}
                  >
                    {exportLoading ? t({ id: 'importacoes.export.lote.exporting' }) : t({ id: 'importacoes.export.lote.download' })}
                  </button>
                </div>
                {/* H25, H27 : la marche à suivre dans PMB (tests/pmb/README.md,
                    docs/interop/couverture-pmb.md § 3). Sous le catalogue : l'onglet
                    d'import de PMB et « Générer les liens entre notices ? », sans
                    lesquels ni les exemplaires ni les articles n'entrent ; sous les
                    autorités : l'ordre des deux fichiers. */}
                {exportFormat === 'unimarc_iso2709' && (
                  <p className="imp-note" data-testid="export-pmb-hint" style={{ marginTop: 8 }}>{t({ id: 'importacoes.export.lote.pmbHint' })}</p>
                )}
                {exportFormat === 'unimarc_autorites' && (
                  <p className="imp-note" data-testid="export-autorites-hint" style={{ marginTop: 8 }}>{t({ id: 'importacoes.export.lote.autoritesHint' })}</p>
                )}
              </div>
            </div>

            {/* E12 lot C : « être source » est un export — il monte à côté de
                l'export par lot, avec le flux OPDS, et ne dit plus « en
                développement » : le circuit a été éprouvé le 02/09 (H5). */}
            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.serFonte.title' })}<Pill variant="ok">OAI-PMH · OPDS</Pill></span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.serFonte.desc' })}</p>
                <p className="imp-note">{t({ id: 'importacoes.export.serFonte.who' })}</p>
                {/* La porte vers le circuit : la barre de navigation n'offre
                    « Réseau » qu'aux admins réseau (canSeeRede), alors que
                    RedePage accueille une coordination directement sur l'onglet
                    « Être source » (OAI-O3). Sans ce lien, une coordination
                    devait taper /rede à la main — constat de Xavier, 02/09. */}
                <Link to="/rede" className="cat-btn secondary" style={{ display: 'inline-block', marginTop: 6 }}>
                  {t({ id: 'importacoes.export.serFonte.go' })}
                </Link>
                <p className="imp-note">{t({ id: 'importacoes.export.serFonte.opds' })}</p>
              </div>
            </div>

            {/* E12 lot C : les gestes de coordination sur le fonds numérique
                (éligibilité, export de fonds, fichiers reçus, domaine public)
                sont de même nature et s'ouvrent ensemble, repliés par défaut —
                la bibliothécaire qui veut « exporter le catalogue » les voit
                sans les subir. */}
            <details className="imp-sheet imp-coord">
              <summary className="imp-sheet__head imp-coord__summary">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.coord.title' })}</span>
                <span className="imp-coord__hint">{t({ id: 'importacoes.export.coord.hint' })}</span>
              </summary>

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.curate.title' })}</span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.curate.desc' })}</p>
                <div style={{ marginTop: 8 }}>
                  <button className="cat-btn secondary" type="button" onClick={loadPublishableResources} disabled={pubLoading || !libraryId}>
                    {pubLoading ? t({ id: 'importacoes.export.curate.loading' }) : t({ id: 'importacoes.export.curate.load' })}
                  </button>
                </div>
                {pubLoaded && pubResources.length === 0 && (
                  <p className="imp-note" style={{ opacity: 0.8, marginTop: 8 }}>{t({ id: 'importacoes.export.curate.empty' })}</p>
                )}
                {pubResources.length > 0 && (
                  <>
                    <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', margin: '10px 0 0' }}>
                      <button className="cat-btn secondary" type="button" disabled={bulkPromoting}
                        onClick={() => setSelectedPub((prev) => (prev.size === pubResources.length ? new Set() : new Set(pubResources.map((r) => r.resource_id))))}>
                        {selectedPub.size === pubResources.length ? t({ id: 'importacoes.export.curate.selectNone' }) : t({ id: 'importacoes.export.curate.selectAll' })}
                      </button>
                      <button className="cat-btn primary" type="button" disabled={bulkPromoting || selectedPub.size === 0} onClick={handleBulkPublish}>
                        {bulkPromoting
                          ? t({ id: 'importacoes.export.curate.bulkValidating' }, { n: selectedPub.size })
                          : t({ id: 'importacoes.export.curate.bulkValidate' }, { n: selectedPub.size })}
                      </button>
                    </div>
                    <ul style={{ listStyle: 'none', padding: 0, margin: '10px 0 0' }}>
                      {pubResources.map((res) => (
                        <li key={res.resource_id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', padding: '8px 10px', borderRadius: 6, marginBottom: 4, background: 'rgba(127,127,127,0.08)' }}>
                          <span style={{ minWidth: 0, fontSize: '.85rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                            <input type="checkbox" checked={selectedPub.has(res.resource_id)} onChange={() => togglePub(res.resource_id)} disabled={bulkPromoting} />
                            <span><b>{res.book_title || '—'}</b>{res.label ? ` · ${res.label}` : ''}{res.is_primary && <Pill variant="ok">★</Pill>}</span>
                          </span>
                          <button className="cat-btn primary" type="button" onClick={() => handlePublishResource(res)} disabled={pubPromotingId === res.resource_id || bulkPromoting}>
                            {pubPromotingId === res.resource_id ? t({ id: 'importacoes.export.curate.validating' }) : t({ id: 'importacoes.export.curate.validate' })}
                          </button>
                        </li>
                      ))}
                    </ul>
                  </>
                )}
              </div>
            </div>

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.fonds.title' })}<Pill variant="ok">ZIP</Pill></span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.fonds.desc' })}</p>
                <p className="imp-note" style={{ opacity: 0.8 }}>{t({ id: 'importacoes.export.fonds.gated' })}</p>
                {fondsCount != null && (
                  <p className="imp-note">
                    {fondsCount > 0
                      ? t({ id: 'importacoes.export.fonds.eligible' }, { count: fondsCount })
                      : t({ id: 'importacoes.export.fonds.eligibleZero' })}
                  </p>
                )}
                <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
                  <select
                    className="ab-select"
                    aria-label={t({ id: 'importacoes.export.fonds.format' })}
                    value={fondsFormat}
                    onChange={(e) => setFondsFormat(e.target.value)}
                    disabled={fondsLoading}
                    style={{ maxWidth: 240 }}
                  >
                    <option value="json">JSON</option>
                    <option value="csv">CSV</option>
                    <option value="marcxml">MARCXML (MARC21)</option>
                  </select>
                  <button
                    className="cat-btn secondary"
                    type="button"
                    onClick={loadFondsEligibleCount}
                    disabled={fondsCounting || !libraryId}
                  >
                    {fondsCounting ? t({ id: 'importacoes.export.fonds.previewing' }) : t({ id: 'importacoes.export.fonds.preview' })}
                  </button>
                  <button
                    className="cat-btn primary"
                    type="button"
                    onClick={handleExportFonds}
                    disabled={fondsLoading || !libraryId}
                  >
                    {fondsLoading ? t({ id: 'importacoes.export.fonds.preparing' }) : t({ id: 'importacoes.export.fonds.download' })}
                  </button>
                </div>

                <div style={{ marginTop: 14, paddingTop: 12, borderTop: '1px solid rgba(127,127,127,0.25)' }}>
                  <p className="imp-note"><b>{t({ id: 'importacoes.export.fonds.directTitle' })}</b></p>
                  <p className="imp-note" style={{ opacity: 0.8 }}>{t({ id: 'importacoes.export.fonds.directDesc' })}</p>
                  <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
                    <select
                      className="ab-select"
                      aria-label={t({ id: 'importacoes.export.fonds.directPartner' })}
                      value={fondsTarget}
                      onChange={(e) => setFondsTarget(e.target.value)}
                      onFocus={() => { if (!fondsPartnersLoaded) loadFondsPartners(); }}
                      disabled={fondsSending}
                      style={{ maxWidth: 320 }}
                    >
                      <option value="">{t({ id: 'importacoes.export.fonds.directPartnerPlaceholder' })}</option>
                      {fondsPartners.map((p) => (
                        <option key={p.partnership_id} value={p.partner_library_id}>{p.partner_name}</option>
                      ))}
                    </select>
                    <button
                      className="cat-btn primary"
                      type="button"
                      onClick={handleDepositFondsDirect}
                      disabled={fondsSending || !libraryId || !fondsTarget}
                    >
                      {fondsSending ? t({ id: 'importacoes.export.fonds.directSending' }) : t({ id: 'importacoes.export.fonds.directSend' })}
                    </button>
                  </div>
                  {fondsPartnersLoaded && fondsPartners.length === 0 && (
                    <p className="imp-note" style={{ opacity: 0.8 }}>{t({ id: 'importacoes.export.fonds.directNoPartner' })}</p>
                  )}
                </div>
              </div>
            </div>

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.attach.title' })}</span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.attach.desc' })}</p>
                <div style={{ marginTop: 8 }}>
                  <button className="cat-btn secondary" type="button" onClick={loadReceivedAssets} disabled={recvLoading || !libraryId}>
                    {recvLoading ? t({ id: 'importacoes.export.attach.loading' }) : t({ id: 'importacoes.export.attach.load' })}
                  </button>
                </div>
                {recvLoaded && recvAssets.length === 0 && (
                  <p className="imp-note" style={{ opacity: 0.8, marginTop: 8 }}>{t({ id: 'importacoes.export.attach.empty' })}</p>
                )}
                {recvAssets.length > 0 && (
                  <ul style={{ listStyle: 'none', padding: 0, margin: '10px 0 0' }}>
                    {recvAssets.map((a) => (
                      <li key={a.received_asset_id} style={{ padding: '8px 10px', borderRadius: 6, marginBottom: 6, background: 'rgba(127,127,127,0.08)' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                          <span style={{ minWidth: 0, fontSize: '.85rem' }}>
                            <b>{a.title || '—'}</b>{a.source_name ? ` · ${a.source_name}` : ''}{a.asset_kind ? ` · ${a.asset_kind}` : ''}
                          </span>
                          <div style={{ display: 'flex', gap: 8, flexShrink: 0, alignItems: 'center' }}>
                            <select className="ab-select" style={{ fontSize: '.76rem', padding: '2px 6px', width: 'auto' }}
                              value={attachMode[a.received_asset_id] || 'both'} disabled={attaching}
                              onChange={(e) => setAttachMode((prev) => ({ ...prev, [a.received_asset_id]: e.target.value }))}
                              title={t({ id: 'importacoes.export.attach.modeLabel' })}>
                              <option value="both">{t({ id: 'importacoes.export.attach.modeBoth' })}</option>
                              <option value="read">{t({ id: 'importacoes.export.attach.modeRead' })}</option>
                              <option value="export">{t({ id: 'importacoes.export.attach.modeExport' })}</option>
                            </select>
                            {a.suggested_book_id && (
                              <button className="cat-btn primary" type="button"
                                onClick={() => handleAttach(a, { book_id: a.suggested_book_id, title: a.suggested_book_title })} disabled={attaching}>
                                {t({ id: 'importacoes.export.attach.attachSuggested' }, { title: a.suggested_book_title || '—' })}
                              </button>
                            )}
                            <button className="cat-btn secondary" type="button" onClick={() => startAttach(a)} disabled={attaching}>
                              {t({ id: 'importacoes.export.attach.choose' })}
                            </button>
                          </div>
                        </div>
                        {attachTarget && attachTarget.received_asset_id === a.received_asset_id && (
                          <div style={{ marginTop: 8, paddingTop: 8, borderTop: '1px solid rgba(127,127,127,0.2)' }}>
                            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                              <input className="ab-input" value={bookQuery} onChange={(e) => setBookQuery(e.target.value)}
                                placeholder={t({ id: 'importacoes.export.attach.searchPh' })} style={{ flex: 1, minWidth: 'min(160px, 100%)' }} />
                              <button className="cat-btn secondary" type="button" onClick={searchBooks} disabled={bookSearching || !bookQuery.trim()}>
                                {bookSearching ? t({ id: 'importacoes.export.attach.searching' }) : t({ id: 'importacoes.export.attach.search' })}
                              </button>
                            </div>
                            {bookResults.length > 0 && (
                              <ul style={{ listStyle: 'none', padding: 0, margin: '8px 0 0' }}>
                                {bookResults.map((b) => (
                                  <li key={b.book_id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', padding: '6px 8px' }}>
                                    <span style={{ fontSize: '.82rem' }}>{b.title || '—'}{b.isbn ? ` · ${b.isbn}` : ''}</span>
                                    <button className="cat-btn primary" type="button" onClick={() => handleAttach(a, b)} disabled={attaching}>
                                      {attaching ? t({ id: 'importacoes.export.attach.attaching' }) : t({ id: 'importacoes.export.attach.attachHere' })}
                                    </button>
                                  </li>
                                ))}
                              </ul>
                            )}
                          </div>
                        )}
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>

            <div className="imp-sheet">
              <div className="imp-sheet__head">
                <span className="imp-sheet__title">{t({ id: 'importacoes.export.verified.title' })}</span>
              </div>
              <div className="imp-sheet__body">
                <p className="imp-note">{t({ id: 'importacoes.export.verified.desc' })}</p>
                <div style={{ marginTop: 8 }}>
                  <button className="cat-btn secondary" type="button" onClick={loadVerifiedAssets} disabled={verifiedLoading || !libraryId}>
                    {verifiedLoading ? t({ id: 'importacoes.export.verified.loading' }) : t({ id: 'importacoes.export.verified.load' })}
                  </button>
                </div>
                {verifiedLoaded && verifiedAssets.length === 0 && (
                  <p className="imp-note" style={{ opacity: 0.8, marginTop: 8 }}>{t({ id: 'importacoes.export.verified.empty' })}</p>
                )}
                {verifiedAssets.length > 0 && (
                  <ul style={{ listStyle: 'none', padding: 0, margin: '10px 0 0' }}>
                    {verifiedAssets.map((a) => (
                      <li key={a.asset_id} style={{ padding: '8px 10px', borderRadius: 6, marginBottom: 6, background: 'rgba(127,127,127,0.08)' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                          <span style={{ minWidth: 0, fontSize: '.85rem' }}>
                            <b>{a.book_title || '—'}</b>
                            {a.asset_kind ? ` · ${a.asset_kind}` : ''}
                            {a.source_name ? ` · ${a.source_name}` : ''}
                            {a.from_received ? ` · ${t({ id: 'importacoes.export.verified.fromReceived' })}` : ''}
                            {' · '}
                            <span style={{ fontWeight: 700, color: a.review_state === 'to_review' ? 'var(--brand-warning, #b45309)' : 'var(--brand-ok, #15803d)' }}>
                              {a.review_state === 'to_review' ? t({ id: 'importacoes.export.verified.statusToReview' }) : t({ id: 'importacoes.export.verified.statusConfirmed' })}
                            </span>
                          </span>
                          <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                            {a.review_state === 'to_review' && (
                              <button className="cat-btn primary" type="button" onClick={() => handleConfirm(a)} disabled={confirmingId === a.asset_id || revokingId === a.asset_id}>
                                {confirmingId === a.asset_id ? t({ id: 'importacoes.export.verified.confirming' }) : t({ id: 'importacoes.export.verified.confirmDP' })}
                              </button>
                            )}
                            <button className="cat-btn secondary" type="button" onClick={() => handleRevoke(a)} disabled={revokingId === a.asset_id || confirmingId === a.asset_id}
                              style={{ borderColor: 'var(--brand-danger, #b42318)', color: 'var(--brand-danger, #b42318)' }}>
                              {revokingId === a.asset_id ? t({ id: 'importacoes.export.verified.revoking' }) : t({ id: 'importacoes.export.verified.revoke' })}
                            </button>
                          </div>
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </div>
            </div>

            </details>
          </>

  );
}
