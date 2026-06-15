import { useState } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';
import { localizeError } from '@/lib/localizeError';
import { Button } from '@/components/ui';

// ── Carte-lecteur (chantier mobile, 28/05/2026) ─────────────────────────────
// Extrait d'AccountPage en composant LAZY (refactor 08/06/2026) : c'est la seule
// consommatrice de `qrcode` + `jspdf` (~200 ko+). Isolée ici, ces dépendances
// quittent le chunk d'AccountPage et ne sont chargées qu'au rendu de la section
// (uniquement pour les biblios `reader_cards_enabled`, sur l'onglet profil).
//
// Le QR encode UNIQUEMENT le token opaque (pas d'URL, pas de user_id).
// Génération locale (qrcode + canvas), aucun appel réseau (anti-tracking).

async function composeCardCanvas(token, slug) {
  // qrcode chargé à la demande (defer ~50 ko hors du chunk de la section)
  const QRCode = (await import('qrcode')).default;
  // Canvas carte : fond clair, slug en haut, QR compact centré.
  // QR ~240px sur canvas 400px ≈ 40-45 mm imprimé sur A6.
  const W = 400, H = 380;
  const QR_SIZE = 240;
  const canvas = document.createElement('canvas');
  canvas.width = W; canvas.height = H;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = '#1f1f1f';
  ctx.font = 'bold 32px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText(slug, W / 2, 50);
  const qrDataUrl = await QRCode.toDataURL(token, { width: QR_SIZE, margin: 1, errorCorrectionLevel: 'M' });
  const qrImg = new Image();
  await new Promise((res, rej) => { qrImg.onload = res; qrImg.onerror = rej; qrImg.src = qrDataUrl; });
  ctx.drawImage(qrImg, (W - QR_SIZE) / 2, 80, QR_SIZE, QR_SIZE);
  return canvas;
}

export default function ReaderCardSection() {
  const { formatMessage: t } = useIntl();
  const { libraryId, librarySlug, libraryName } = useLibrary();
  const [cardBusy, setCardBusy] = useState(false);
  const [cardMsg, setCardMsg] = useState('');
  const [cardMsgIsError, setCardMsgIsError] = useState(false);

  async function generateReaderCard() {
    if (cardBusy) return;
    setCardBusy(true); setCardMsg(''); setCardMsgIsError(false);
    try {
      const { data, error } = await supabase.schema('api').rpc('generate_my_reader_card', { p_library_id: libraryId });
      if (error) throw error;
      if (!data?.ok) {
        const reason = data?.reason || 'unknown';
        setCardMsg(t({ id: `account.readerCard.error.${reason}`, defaultMessage: t({ id: 'account.readerCard.error.unknown' }) }));
        setCardMsgIsError(true);
        return;
      }
      const token = data.token;
      const slug = data.library_slug || librarySlug;
      const canvas = await composeCardCanvas(token, slug);
      // Export PNG (galerie)
      await new Promise((resolve) => {
        canvas.toBlob((blob) => {
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url; a.download = `carte-lecteur-${slug}.png`;
          document.body.appendChild(a); a.click(); document.body.removeChild(a);
          URL.revokeObjectURL(url); resolve();
        }, 'image/png');
      });
      // Export PDF (impression) : carte centrée sur une page A6
      const pngDataUrl = canvas.toDataURL('image/png');
      const { jsPDF } = await import('jspdf');
      const pdf = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a6' });
      const pw = pdf.internal.pageSize.getWidth();
      const imgW = pw - 20;
      const imgH = imgW * (canvas.height / canvas.width);
      pdf.addImage(pngDataUrl, 'PNG', 10, 10, imgW, imgH);
      pdf.save(`carte-lecteur-${slug}.pdf`);
      setCardMsg(t({ id: 'account.readerCard.generated' }));
      setCardMsgIsError(false);
    } catch (e) {
      setCardMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t, 'account.readerCard.error.unknown') }));
      setCardMsgIsError(true);
    } finally {
      setCardBusy(false);
    }
  }

  return (
    <div style={{ marginTop: 40, padding: 22, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' }}>
      <h3 style={{ margin: '0 0 4px', fontSize: '1.05rem', color: 'var(--brand-fg, #f4f4f4)', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>
        {t({ id: 'account.readerCard.title' })}
      </h3>
      <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 14px' }}>
        {t({ id: 'account.readerCard.subtitle' }, { library: libraryName })}
      </p>
      <p style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 16px', lineHeight: 1.5 }}>
        {t({ id: 'account.readerCard.securityNote' }, { library: libraryName })}
      </p>
      <Button onClick={generateReaderCard} disabled={cardBusy}>
        {cardBusy ? '…' : t({ id: 'account.readerCard.generate' })}
      </Button>
      {cardMsg && (
        <p style={{ marginTop: 12, fontSize: '.85rem', color: cardMsgIsError ? '#f87171' : '#4ade80' }}>{cardMsg}</p>
      )}
    </div>
  );
}
