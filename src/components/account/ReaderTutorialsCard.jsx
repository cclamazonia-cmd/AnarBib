// src/components/account/ReaderTutorialsCard.jsx
//
// Carte « Tutoriais em vídeo » sur la page compte (/conta). Tutos lecteur·rices
// publiés sur Kolektiva.media (instance PeerTube). Les sous-titres des 10 locales
// sont embarqués SUR les vidéos → accessibles via le menu « CC » du lecteur. On
// pré-sélectionne la piste qui correspond à la langue de l'UI via ?subtitle=.
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

export default function ReaderTutorialsCard() {
  const { formatMessage: t, locale } = useIntl();
  const { documents } = useEffectiveScope();
  const [open, setOpen] = useState(false);

  if (!documents?.showReaderManual) return null;

  const sub = SUBTITLE_LANG[locale];
  const embedUrl = (vid) =>
    `https://kolektiva.media/videos/embed/${vid}${sub ? `?subtitle=${sub}` : ''}`;

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
            {TUTORIALS.map((tut) => {
              const title = t({ id: tut.titleKey });
              return (
                <figure key={tut.id} style={{ margin: 0 }}>
                  <div style={{ position: 'relative', width: '100%', paddingTop: '56.25%', borderRadius: 8, overflow: 'hidden', background: '#000' }}>
                    <iframe
                      title={title}
                      src={embedUrl(tut.id)}
                      loading="lazy"
                      allow="fullscreen; picture-in-picture"
                      allowFullScreen
                      sandbox="allow-same-origin allow-scripts allow-popups allow-forms"
                      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', border: 0 }}
                    />
                  </div>
                  <figcaption style={{ marginTop: 8, fontSize: '.92rem', fontWeight: 600 }}>{title}</figcaption>
                </figure>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}
