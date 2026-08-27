// =============================================================================
// SerialPage.jsx — fiche PUBLIQUE d'un titre de périodique.
// =============================================================================
// Route /periodico/:slug — arbitrage de la spec §13 TODO 5 : une page à part
// entière, pas une facette du catalogue. C'est ce qui rend l'état de collection
// LISIBLE : « nous avons 1896-1914, sauf le n°23 et 1902 » n'a pas de place
// dans une liste de résultats, et c'est pourtant l'information qui décide d'une
// demande de prêt entre bibliothèques.
//
// Surface anon, lecture seule. Un titre encore `proposto` n'est pas visible du
// public : ce n'est pas filtré ici mais par la RLS de public.serials, et la
// page rend simplement « introuvable ». Le staff, lui, la voit — même URL,
// même code, deux résultats, sans seconde page à maintenir.
//
// Trois blocs, dans l'ordre où ils servent :
//   1. l'identité du titre (formes parallèles, dates, ISSN, éditrice) ;
//   2. l'ÉTAT DE COLLECTION par bibliothèque — déclaré s'il existe, calculé
//      sinon, et jamais l'un maquillé en l'autre ;
//   3. les fascicules catalogués, triés (ano, issue_key, titulo) — garde G6.
// Plus la filiation (titre précédent / suivant), qui est la raison d'être du
// modèle sur un fonds courant de 1860 à aujourd'hui.
// =============================================================================

import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { Link, useParams } from 'react-router-dom';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { supabase } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

// Désignation lisible d'un fascicule. On n'affiche PAS issue_key : c'est une
// clé de distinction (« 12|maio de 1997|1997 »), pas un libellé.
function issueLabel(it, t) {
  const bits = [];
  if (it.volume) bits.push(t({ id: 'serial.issue.volume' }, { v: it.volume }));
  if (it.numero) bits.push(t({ id: 'serial.issue.number' }, { n: it.numero }));
  if (it.fasciculo) bits.push(it.fasciculo);
  if (it.data_edicao) bits.push(it.data_edicao);
  if (bits.length === 0 && it.ano) bits.push(it.ano);
  return bits.join(' · ');
}

export default function SerialPage() {
  const { slug } = useParams();
  const { formatMessage: t, locale } = useIntl();

  const [serial, setSerial] = useState(undefined); // undefined = chargement, null = absent
  const [issues, setIssues] = useState([]);
  const [holdings, setHoldings] = useState([]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const api = supabase.schema('api');
      const { data: det } = await api.rpc('serial_detail_v1', { p_slug: slug });
      const s = Array.isArray(det) ? det[0] : det;
      if (cancelled) return;
      if (!s) { setSerial(null); return; }
      setSerial(s);

      const [iss, hold] = await Promise.all([
        api.rpc('serial_issues_v1', { p_serial_id: s.id }),
        api.from('serial_holdings_public_v1').select('*').eq('serial_id', s.id),
      ]);
      if (cancelled) return;
      setIssues(Array.isArray(iss.data) ? iss.data : []);
      setHoldings(Array.isArray(hold.data) ? hold.data : []);
    })();
    return () => { cancelled = true; };
  }, [slug]);

  const title = serial ? serial.uniform_title : '';
  useDocumentTitle(title || t({ id: 'serial.pageTitle' }));

  // Formes parallèles dans la langue de lecture, avec repli sur la langue base.
  const altList = serial
    ? ((serial.alt_i18n && (serial.alt_i18n[locale] || serial.alt_i18n[(locale || '').split('-')[0]])) || [])
    : [];

  // Dates de parution. Le tiret ouvert (« 1896– ») dit « paraît toujours » ;
  // sans is_continuing on n'ajoute rien plutôt que de laisser croire à une fin.
  let span = '';
  if (serial) {
    const a = serial.start_year;
    const b = serial.end_year;
    if (a && b) span = `${a}–${b}`;
    else if (a && serial.is_continuing) span = `${a}–`;
    else if (a) span = a;
    else if (b) span = `–${b}`;
  }

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)',
    borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)', padding: '24px 24px 32px',
  };
  const sectionTitle = {
    fontSize: '.78rem', textTransform: 'uppercase', letterSpacing: '.05em',
    color: 'var(--brand-muted)', margin: '24px 0 8px', fontWeight: 700,
  };
  const linkBlue = { color: '#93c5fd', textDecoration: 'none' };
  const chip = {
    display: 'inline-flex', alignItems: 'center', gap: 6, padding: '4px 10px', borderRadius: 999,
    fontSize: '.84rem', background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.12)',
  };
  const meta = { color: 'var(--brand-muted)', fontSize: '.88rem', margin: '0 0 4px' };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 860, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          {serial === undefined ? (
            <p style={{ color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</p>
          ) : serial === null ? (
            <p style={{ color: 'var(--brand-muted)', fontStyle: 'italic' }}>{t({ id: 'serial.notFound' })}</p>
          ) : (
            <>
              {/* Filiation amont — un titre de 1890 renommé en 1905 se lit d'ici. */}
              {serial.predecessor_slug && (
                <div style={{ fontSize: '.82rem', marginBottom: 6 }}>
                  <span style={{ color: 'var(--brand-muted)' }}>{t({ id: 'serial.continues' })} </span>
                  <Link to={`/periodico/${serial.predecessor_slug}`} style={linkBlue}>
                    {serial.predecessor_title}
                  </Link>
                </div>
              )}

              <h1 style={{ fontSize: '1.7rem', fontWeight: 800, margin: '0 0 6px', fontFamily: 'var(--brand-font-body)' }}>
                {title}
              </h1>

              {span && <p style={meta}>{span}</p>}
              {altList.length > 0 && (
                <p style={meta}>{t({ id: 'serial.altTitles' })} : {altList.join(', ')}</p>
              )}
              {serial.emitter_org && (
                <p style={meta}>{t({ id: 'serial.emitter' })} : {serial.emitter_org}</p>
              )}
              {(serial.publisher_name || serial.place_publication) && (
                <p style={meta}>
                  {[serial.publisher_name, serial.place_publication].filter(Boolean).join(' · ')}
                </p>
              )}
              {serial.periodicidade && (
                <p style={meta}>{t({ id: 'serial.frequency' })} : {serial.periodicidade}</p>
              )}
              {(serial.issn || serial.issn_l) && (
                <p style={meta}>
                  {serial.issn && <>ISSN {serial.issn}</>}
                  {serial.issn && serial.issn_l && ' · '}
                  {serial.issn_l && <>ISSN-L {serial.issn_l}</>}
                </p>
              )}
              {serial.scope_note && (
                <p style={{ color: '#d4d4d4', fontSize: '.92rem', margin: '10px 0 0' }}>{serial.scope_note}</p>
              )}

              {serial.successor_slug && (
                <p style={{ fontSize: '.82rem', marginTop: 10 }}>
                  <span style={{ color: 'var(--brand-muted)' }}>{t({ id: 'serial.continuedBy' })} </span>
                  <Link to={`/periodico/${serial.successor_slug}`} style={linkBlue}>
                    {serial.successor_title}
                  </Link>
                </p>
              )}

              {/* ── État de collection ─────────────────────────────────────
                  Le DÉCLARÉ fait foi et s'affiche seul quand il existe. Le
                  calculé n'apparaît qu'à défaut, et il est alors annoncé comme
                  tel : « d'après les numéros catalogués ». Ne jamais laisser
                  croire qu'un intervalle calculé est une déclaration de la
                  bibliothèque — c'est ce qui ferait demander un prêt à
                  l'aveugle. */}
              {holdings.length > 0 && (
                <>
                  <div style={sectionTitle}>{t({ id: 'serial.holdings' })}</div>
                  <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 10 }}>
                    {holdings.map((h) => (
                      <li key={h.library_id} style={{ borderLeft: '2px solid rgba(255,255,255,.14)', paddingLeft: 10 }}>
                        <Link to={`/bibliotecas/${h.library_slug}`} style={{ ...linkBlue, fontWeight: 600, fontSize: '.92rem' }}>
                          {h.library_name || h.library_slug}
                        </Link>
                        {h.has_statement ? (
                          <div style={{ fontSize: '.9rem', color: '#d4d4d4', whiteSpace: 'pre-line', marginTop: 2 }}>
                            {h.statement}
                          </div>
                        ) : (
                          <div style={{ fontSize: '.86rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                            {t({ id: 'serial.holdings.computed' }, {
                              count: h.computed_count,
                              first: h.computed_first || '?',
                              last: h.computed_last || '?',
                            })}
                          </div>
                        )}
                        {h.gaps_note && (
                          <div style={{ fontSize: '.84rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                            {t({ id: 'serial.holdings.gaps' })} : {h.gaps_note}
                          </div>
                        )}
                        {h.completeness && h.completeness !== 'desconhecida' && (
                          <span style={{ ...chip, marginTop: 4, fontSize: '.74rem' }}>
                            {t({ id: `serial.completeness.${h.completeness}` })}
                          </span>
                        )}
                      </li>
                    ))}
                  </ul>
                </>
              )}

              {/* ── Fascicules catalogués ─────────────────────────────────── */}
              <div style={sectionTitle}>
                {t({ id: 'serial.issues' }, { count: issues.length })}
              </div>
              {issues.length === 0 ? (
                <p style={{ color: 'var(--brand-muted)', fontStyle: 'italic', fontSize: '.9rem' }}>
                  {t({ id: 'serial.issues.none' })}
                </p>
              ) : (
                <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
                  {issues.map((it) => (
                    <li key={`${it.book_id}-${it.library_id || 'na'}`} style={{ fontSize: '.9rem' }}>
                      <Link to={`/livro/${it.book_id}`} style={linkBlue}>
                        {issueLabel(it, t) || it.titulo}
                      </Link>
                      {it.library_name && (
                        <span style={{ color: 'var(--brand-muted)', fontSize: '.82rem' }}> · {it.library_name}</span>
                      )}
                      {/* La forme TRANSCRITE, quand elle diffère de la forme
                          retenue : ce n'est pas une erreur, c'est ce qui est
                          imprimé sur le fascicule. */}
                      {it.titulo_periodico && it.titulo_periodico !== title && (
                        <span style={{ color: 'var(--brand-muted)', fontSize: '.78rem', fontStyle: 'italic' }}>
                          {' '}({it.titulo_periodico})
                        </span>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
