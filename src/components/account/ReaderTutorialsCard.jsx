// src/components/account/ReaderTutorialsCard.jsx
//
// Carte « Tutoriais em vídeo » sur la page compte (/conta). Tutos lecteur·rices
// publiés sur Kolektiva.media (instance PeerTube). Les sous-titres des 10 locales
// sont embarqués SUR les vidéos → accessibles via le menu « CC » du lecteur. On
// pré-sélectionne la piste qui correspond à la langue de l'UI via ?subtitle=.
//
// CONFIDENTIALITÉ (INV-3) : les vidéos ne sont PAS chargées automatiquement.
// Tant que la lectrice n'a pas cliqué sur la façade, aucune iframe n'est montée,
// donc aucune requête n'atteint kolektiva.media (pas de fuite d'IP, pas de
// stockage tiers). Au clic, l'iframe est montée avec ?p2p=0 → WebTorrent/WebRTC
// désactivé, l'IP n'est plus exposée aux pairs ni aux serveurs STUN.
// Voir la clause « Vídeos tutoriais » de la page /privacidade.
//
// Gating : même périmètre que le « Manual do leitor » (scope.documents.showReaderManual,
// toujours vrai sur /conta). Repliable, replié par défaut pour rester discret.

import { useState } from 'react';
import { useIntl } from 'react-intl';
import useEffectiveScope from '@/hooks/useEffectiveScope';

// Vidéos publiées (id court PeerTube = segment /w/<id> de l'URL Kolektiva).
const TUTORIALS = [
  { id: '4pLFefK4fB5SBpDidAkcJa', titleKey: 'account.tutorials.video1' },
  { id: 'isFwwRa9AqzbvyjgyzLro8', titleKey: 'account.tutorials.video2' },
];

// Locale de l'app → code de piste de sous-titres PeerTube (cf. captions Kolektiva :
// pt-BR exporté en « pt », es en « es-419 », les 8 autres identiques).
const SUBTITLE_LANG = {
  'pt-BR': 'pt', en: 'en', fr: 'fr', es: 'es-419', de: 'de',
  it: 'it', ca: 'ca', el: 'el', eo: 'eo', nl: 'nl',
};

// Construit l'URL d'embed Kolektiva.
//   p2p=0        → coupe WebTorrent/WebRTC (INV-3) : l'IP n'est pas exposée
//                  aux autres pairs ni aux serveurs STUN.
//   warningTitle=0 → masque l'avertissement P2P de PeerTube (sans objet, P2P coupé).
//   subtitle     → pré-sélectionne la piste de la langue courante.
// URLSearchParams gère proprement le « ? » / « & » et l'encodage.
function buildEmbedUrl(vid, sub) {
  const params = new URLSearchParams();
  if (sub) params.set('subtitle', sub);
  params.set('p2p', '0');
  params.set('warningTitle', '0');
  return `https://kolektiva.media/videos/embed/${vid}?${params.toString()}`;
}

// Façade « click-to-load ». Rien n'est chargé depuis kolektiva.media tant que la
// lectrice n'a pas cliqué. Pas de miniature tierce (elle serait servie par
// kolektiva → recontacterait le tiers avant le clic) : cadre neutre, icône + notice.
function TutorialVideo({ vid, sub, title, loadLabel, loadNotice }) {
  const [loaded, setLoaded] = useState(false);

  return (
    <figure style={{ margin: 0 }}>
      <div style={{ position: 'relative', width: '100%', paddingTop: '56.25%', borderRadius: 8, overflow: 'hidden', background: '#000' }}>
        {loaded ? (
          <iframe
            title={title}
            src={buildEmbedUrl(vid, sub)}
            loading="lazy"
            allow="fullscreen; picture-in-picture"
            allowFullScreen
            sandbox="allow-same-origin allow-scripts allow-popups allow-forms"
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', border: 0 }}
          />
        ) : (
          <button
            type="button"
            onClick={() => setLoaded(true)}
            aria-label={`${loadLabel} : ${title}. ${loadNotice}`}
            style={{
              position: 'absolute', inset: 0, width: '100%', height: '100%',
              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
              gap: 10, padding: 16, border: 0, cursor: 'pointer',
              background: '#000', color: '#fff', textAlign: 'center', font: 'inherit',
            }}
          >
            <span aria-hidden="true" style={{ fontSize: '2.75rem', lineHeight: 1 }}>▶</span>
            <span style={{ fontWeight: 700, fontSize: '.95rem' }}>{loadLabel}</span>
            <span style={{ fontSize: '.78rem', opacity: 0.75, maxWidth: 320, lineHeight: 1.45 }}>{loadNotice}</span>
          </button>
        )}
      </div>
      <figcaption style={{ marginTop: 8, fontSize: '.92rem', fontWeight: 600 }}>{title}</figcaption>
    </figure>
  );
}

export default function ReaderTutorialsCard() {
  const { formatMessage: t, locale } = useIntl();
  const { documents } = useEffectiveScope();
  const [open, setOpen] = useState(false);

  if (!documents?.showReaderManual) return null;

  const sub = SUBTITLE_LANG[locale];
  const loadLabel = t({ id: 'account.tutorials.loadButton' });
  const loadNotice = t({ id: 'account.tutorials.loadNotice' });

  return (
    <div className="ab-conta-card" style={{ marginTop: 16 }}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', background: 'none', border: 0, cursor: 'pointer', padding: 0, color: 'inherit', textAlign: 'left' }}
      >
        <span aria-hidden="true" style={{ fontSize: '1.25rem' }}>🎬</span>
        <span style={{ fontWeight: 700, fontSize: '1.05rem', flex: 1 }}>{t({ id: 'account.tutorials.title' })}</span>
        <span aria-hidden="true" style={{ transform: open ? 'rotate(90deg)' : 'none', transition: 'transform .15s', opacity: 0.7 }}>▶</span>
      </button>

      {open && (
        <>
          <p className="ab-conta-hint" style={{ margin: '8px 0 16px' }}>{t({ id: 'account.tutorials.hint' })}</p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 16 }}>
            {TUTORIALS.map((tut) => (
              <TutorialVideo
                key={tut.id}
                vid={tut.id}
                sub={sub}
                title={t({ id: tut.titleKey })}
                loadLabel={loadLabel}
                loadNotice={loadNotice}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
}
