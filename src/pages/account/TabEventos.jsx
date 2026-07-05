import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

/**
 * TabEventos — agenda des événements des bibliothèques de la lectrice.
 *
 * Onglet « Événements » du compte lecteur /conta. Lecture seule : présente les
 * lectures publiques, débats, ateliers… à venir, organisés par les
 * bibliothèques où la personne est membre actif. Aucune inscription (v1).
 *
 * Consomme la RPC api.fn_my_library_events (SECURITY DEFINER) : filtre déjà par
 * auth.uid() + statut d'adhésion 'active' + is_public + non annulé + à venir.
 */

const TYPE_KEY = {
  lecture_publique: 'account.events.type.lecture_publique',
  debat: 'account.events.type.debat',
  atelier: 'account.events.type.atelier',
  rencontre: 'account.events.type.rencontre',
  projection: 'account.events.type.projection',
  autre: 'account.events.type.autre',
};

export default function TabEventos() {
  const { formatMessage: t, locale } = useIntl();
  const [rows, setRows] = useState(null);

  const dateFmt = new Intl.DateTimeFormat(locale, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  const timeFmt = new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit' });

  const load = useCallback(async () => {
    try {
      const { data } = await supabase.schema('api').rpc('fn_my_library_events');
      setRows(Array.isArray(data) ? data : []);
    } catch {
      setRows([]);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    (async () => { if (!cancelled) await load(); })();
    return () => { cancelled = true; };
  }, [load]);

  if (rows === null) {
    return <p className="ab-conta-hint">{t({ id: 'common.loading' })}</p>;
  }

  return (
    <div>
      <h2 className="ab-conta-section-title">{t({ id: 'account.events.title' })}</h2>
      <p className="ab-conta-hint">{t({ id: 'account.tab.events.hint' })}</p>

      {rows.length === 0 ? (
        <p className="ab-conta-empty">{t({ id: 'account.events.empty' })}</p>
      ) : (
        <div className="ab-conta-items">
          {rows.map((ev) => {
            const start = new Date(ev.starts_at);
            const end = ev.ends_at ? new Date(ev.ends_at) : null;
            const sameDayEnd = end && end.toDateString() === start.toDateString();
            return (
              <div key={ev.id} className="ab-conta-item" style={{ display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'flex-start' }}>
                <div style={{ flex: 1, minWidth: 220 }}>
                  <span className="ab-conta-item__title">{ev.title}</span>
                  <span className="ab-conta-item__meta" style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 4 }}>
                    <span style={{ padding: '1px 8px', borderRadius: 999, background: 'rgba(255,255,255,.08)', fontSize: '.72rem' }}>
                      {t({ id: TYPE_KEY[ev.event_type] || TYPE_KEY.autre })}
                    </span>
                    <span style={{ color: 'var(--brand-muted)' }}>{ev.library_name}</span>
                  </span>
                  <span className="ab-conta-item__meta" style={{ marginTop: 4, display: 'block' }}>
                    {dateFmt.format(start)} · {timeFmt.format(start)}
                    {end && (sameDayEnd ? `–${timeFmt.format(end)}` : ` → ${dateFmt.format(end)} ${timeFmt.format(end)}`)}
                  </span>
                  {ev.location && (
                    <span className="ab-conta-item__meta" style={{ marginTop: 2, display: 'block' }}>
                      📍 {ev.location}
                    </span>
                  )}
                  {ev.description && (
                    <p style={{ margin: '8px 0 0', fontSize: '.85rem', whiteSpace: 'pre-wrap', color: 'var(--brand-text, inherit)' }}>
                      {ev.description}
                    </p>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
