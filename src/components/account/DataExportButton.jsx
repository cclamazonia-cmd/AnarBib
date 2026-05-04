import { useState } from 'react';
import { useIntl } from 'react-intl';
import JSZip from 'jszip';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

// ─── Helpers ────────────────────────────────────────────────────────────────

/**
 * Convertit un tableau d'objets plats en CSV (RFC 4180).
 * Gère : valeurs null, virgules, guillemets, retours ligne, objets imbriqués
 * (sérialisés en JSON dans la cellule).
 */
function arrayToCsv(rows) {
  if (!rows || rows.length === 0) return '';

  // Collecte de toutes les clés (union de toutes les lignes)
  const allKeys = new Set();
  for (const row of rows) {
    if (row && typeof row === 'object') {
      Object.keys(row).forEach(k => allKeys.add(k));
    }
  }
  const headers = Array.from(allKeys);

  const escapeCell = (val) => {
    if (val === null || val === undefined) return '';
    let s;
    if (typeof val === 'object') {
      s = JSON.stringify(val);
    } else {
      s = String(val);
    }
    // Échappement RFC 4180 : si la valeur contient virgule, guillemet ou \n,
    // on entoure de guillemets et on double les guillemets internes.
    if (/[",\n\r]/.test(s)) {
      s = '"' + s.replace(/"/g, '""') + '"';
    }
    return s;
  };

  const lines = [headers.join(',')];
  for (const row of rows) {
    lines.push(headers.map(h => escapeCell(row?.[h])).join(','));
  }
  return lines.join('\r\n') + '\r\n';
}

/**
 * Aplatit les emprunts (avec items imbriqués) en lignes plates pour CSV.
 * Une ligne par item, avec les infos du loan parent répétées.
 */
function flattenLoansForCsv(loans) {
  const rows = [];
  for (const loan of loans || []) {
    if (!loan.items || loan.items.length === 0) {
      rows.push({
        loan_id: loan.loan_id,
        library_id: loan.library_id,
        loan_status: loan.status_global,
        loan_due_at: loan.due_at,
        loan_extended_once: loan.extended_once,
        loan_created_at: loan.created_at,
        loan_notes: loan.notes,
      });
    } else {
      for (const item of loan.items) {
        rows.push({
          loan_id: loan.loan_id,
          library_id: loan.library_id,
          loan_status: loan.status_global,
          loan_due_at: loan.due_at,
          loan_extended_once: loan.extended_once,
          loan_created_at: loan.created_at,
          loan_notes: loan.notes,
          item_line_no: item.line_no,
          item_status: item.item_status,
          bib_ref: item.bib_ref,
          rotulo: item.rotulo,
          titulo: item.titulo,
          autor: item.autor,
          editora: item.editora,
          ano: item.ano,
          item_due_at: item.due_at,
          item_extended_until: item.extended_until,
          item_extension_note: item.extension_note,
          item_returned_at: item.returned_at,
          item_return_completed_at: item.return_completed_at,
          item_return_scheduled_for: item.return_scheduled_for,
          item_notes: item.notes,
        });
      }
    }
  }
  return rows;
}

/**
 * Idem pour les réservations.
 */
function flattenReservationsForCsv(reservations) {
  const rows = [];
  for (const r of reservations || []) {
    if (!r.lines || r.lines.length === 0) {
      rows.push({
        reservation_id: r.reservation_id,
        library_id: r.library_id,
        reservation_status: r.status_global,
        reservation_created_at: r.created_at,
        reservation_notes: r.notes,
      });
    } else {
      for (const line of r.lines) {
        rows.push({
          reservation_id: r.reservation_id,
          library_id: r.library_id,
          reservation_status: r.status_global,
          reservation_created_at: r.created_at,
          reservation_notes: r.notes,
          line_no: line.line_no,
          line_status: line.item_status,
          bib_ref: line.bib_ref,
          rotulo: line.rotulo,
          titulo: line.titulo,
          autor: line.autor,
          editora: line.editora,
          ano: line.ano,
          line_expires_at: line.expires_at,
          line_cancelled_at: line.cancelled_at,
          line_converted_at: line.converted_at,
          line_expired_at: line.expired_at,
          line_notes: line.notes,
          workflow_stage: line.workflow?.workflow_stage,
          workflow_note: line.workflow?.workflow_note,
          pickup_scheduled_for: line.workflow?.pickup_scheduled_for,
          pickup_reply_status: line.workflow?.pickup_reply_status,
          pickup_reply_at: line.workflow?.pickup_reply_at,
        });
      }
    }
  }
  return rows;
}

/**
 * Idem pour les consultations.
 */
function flattenConsultationsForCsv(consultations) {
  const rows = [];
  for (const c of consultations || []) {
    if (!c.lines || c.lines.length === 0) {
      rows.push({
        consultation_id: c.consultation_id,
        library_id: c.library_id,
        consultation_status: c.status_global,
        consultation_created_at: c.created_at,
        consultation_notes: c.notes,
      });
    } else {
      for (const line of c.lines) {
        rows.push({
          consultation_id: c.consultation_id,
          library_id: c.library_id,
          consultation_status: c.status_global,
          consultation_created_at: c.created_at,
          consultation_notes: c.notes,
          line_no: line.line_no,
          line_status: line.item_status,
          bib_ref: line.bib_ref,
          titulo: line.titulo,
          autor: line.autor,
          editora: line.editora,
          ano: line.ano,
          line_expires_at: line.expires_at,
          line_cancelled_at: line.cancelled_at,
          line_consulted_at: line.consulted_at,
          line_expired_at: line.expired_at,
          line_dismissed_at: line.dismissed_by_reader_at,
          line_notes: line.notes,
        });
      }
    }
  }
  return rows;
}

/**
 * Aplatit les memberships pour CSV.
 */
function flattenMembershipsForCsv(memberships) {
  return (memberships || []).map(m => ({
    membership_id: m.membership_id,
    library_id: m.library?.id,
    library_slug: m.library?.slug,
    library_name: m.library?.name,
    library_short_name: m.library?.short_name,
    library_city: m.library?.city,
    library_country: m.library?.country,
    role: m.role,
    is_primary: m.is_primary,
    status: m.status,
    is_restricted: m.is_restricted,
    restricted_reason: m.restricted_reason,
    history_enabled: m.history_enabled,
    created_at: m.created_at,
    updated_at: m.updated_at,
  }));
}

/**
 * Génère un README explicatif inclus dans le zip.
 */
function buildReadme(data, locale) {
  const exportedAt = data.exported_at;
  const userEmail = data.user?.email || '(unknown)';
  const counts = {
    memberships: data.memberships?.length || 0,
    payments: data.membership_payments?.length || 0,
    loans: data.loans?.length || 0,
    reservations: data.reservations?.length || 0,
    consultations: data.consultations?.length || 0,
    notifications: data.notifications?.length || 0,
    wishlist: data.wishlist?.length || 0,
  };

  return `AnarBib — Export de donnees personnelles (RGPD article 20 / LGPD article 18)
===============================================================================

Date de l'export : ${exportedAt}
Compte concerne : ${userEmail}
Version du format : ${data.export_format_version}

Resume du contenu :
  - ${counts.memberships} membership(s) dans des bibliotheques
  - ${counts.payments} paiement(s) de cotisation
  - ${counts.loans} emprunt(s)
  - ${counts.reservations} reservation(s)
  - ${counts.consultations} consultation(s) sur place
  - ${counts.notifications} notification(s) recue(s)
  - ${counts.wishlist} element(s) en liste de souhaits

Contenu du dossier :
  data.json
    Export complet structure, avec relations entre objets preservees.
    Format adapte aux outils techniques (programmes, scripts d'analyse).

  csv/profile.csv
    Vos donnees personnelles (nom, email, langue, adresse, etc.)
  csv/memberships.csv
    Vos appartenances aux bibliotheques de la rete AnarBib
  csv/membership_payments.csv
    Historique des paiements de cotisation
  csv/loans.csv
    Tous vos emprunts (en cours et passes), une ligne par item
  csv/reservations.csv
    Toutes vos reservations, une ligne par item reserve
  csv/consultations.csv
    Toutes vos consultations sur place
  csv/notifications.csv
    Notifications recues dans l'application
  csv/wishlist.csv
    Liste de souhaits

Le format CSV s'ouvre directement dans Excel, LibreOffice Calc, Numbers,
et la plupart des tableurs.

Vos droits :
Cet export implemente l'article 20 du RGPD (droit a la portabilite) et
l'article 18 de la LGPD bresilienne. Si une donnee est incomplete ou
incorrecte, vous pouvez la rectifier depuis votre page "Mon compte"
ou contacter contato@anarbib.org.

Pour toute question : contato@anarbib.org
`;
}

// ─── Composant principal ────────────────────────────────────────────────────

const buttonStyle = {
  fontSize: '.88rem',
  padding: '8px 14px',
  borderRadius: 6,
  border: '1px solid var(--brand-accent, #c44)',
  background: 'transparent',
  color: 'var(--brand-fg, #f4f4f4)',
  cursor: 'pointer',
  fontFamily: 'inherit',
};

const messageStyle = (type) => ({
  fontSize: '.82rem',
  marginTop: 8,
  color: type === 'error' ? '#f88' : 'var(--brand-muted, #999)',
});

export default function DataExportButton() {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState({ type: null, text: '' });

  async function handleExport() {
    setLoading(true);
    setMessage({ type: null, text: '' });

    try {
      // 1. Récupérer toutes les données depuis la RPC
      const { data, error } = await supabase.rpc('fn_export_my_data');
      if (error) throw error;
      if (!data) throw new Error('No data returned');

      // 2. Construire le zip
      const zip = new JSZip();

      // README explicatif
      zip.file('README.txt', buildReadme(data, locale));

      // JSON complet
      zip.file('data.json', JSON.stringify(data, null, 2));

      // Dossier csv/
      const csvFolder = zip.folder('csv');

      // Profil — un seul objet, on le met en tableau d'un élément
      if (data.profile) {
        csvFolder.file('profile.csv', arrayToCsv([data.profile]));
      }

      // Memberships
      csvFolder.file('memberships.csv', arrayToCsv(flattenMembershipsForCsv(data.memberships)));

      // Paiements
      csvFolder.file('membership_payments.csv', arrayToCsv(data.membership_payments || []));

      // Emprunts (avec items aplatis)
      csvFolder.file('loans.csv', arrayToCsv(flattenLoansForCsv(data.loans)));

      // Réservations (avec lignes aplaties)
      csvFolder.file('reservations.csv', arrayToCsv(flattenReservationsForCsv(data.reservations)));

      // Consultations (avec lignes aplaties)
      csvFolder.file('consultations.csv', arrayToCsv(flattenConsultationsForCsv(data.consultations)));

      // Notifications
      csvFolder.file('notifications.csv', arrayToCsv(data.notifications || []));

      // Wishlist
      csvFolder.file('wishlist.csv', arrayToCsv(data.wishlist || []));

      // 3. Générer et déclencher le download
      const blob = await zip.generateAsync({
        type: 'blob',
        compression: 'DEFLATE',
        compressionOptions: { level: 6 },
      });

      const date = new Date().toISOString().slice(0, 10);
      const username = user?.email?.split('@')[0] || 'export';
      const safeUsername = username.replace(/[^a-z0-9-_]/gi, '_');
      const filename = `anarbib-export-${safeUsername}-${date}.zip`;

      // Création d'un lien temporaire pour le download
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      setMessage({ type: 'success', text: t({ id: 'account.export.success' }) });
    } catch (err) {
      console.error('Export error:', err);
      setMessage({
        type: 'error',
        text: t({ id: 'account.export.error' }, { message: err.message || 'unknown' }),
      });
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <button
        type="button"
        onClick={handleExport}
        disabled={loading}
        style={{ ...buttonStyle, opacity: loading ? 0.6 : 1 }}
      >
        {loading
          ? t({ id: 'account.export.loading' })
          : t({ id: 'account.export.button' })}
      </button>
      <p style={{ ...messageStyle(message.type), minHeight: '1.2em' }}>
        {message.text || t({ id: 'account.export.hint' })}
      </p>
    </div>
  );
}
