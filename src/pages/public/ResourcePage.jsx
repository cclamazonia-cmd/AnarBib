import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { useSearchParams, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import './ResourcePage.css';

const SUPABASE_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
const EDGE_URL = `${SUPABASE_URL}/functions/v1/read-digital-asset`;

function fmt(v, fallback = '—') { return String(v ?? '').trim() || fallback; }

export default function ResourcePage() {
  const { formatMessage: t } = useIntl();
  const [params] = useSearchParams();
  const { user } = useAuth();

  const assetId = params.get('asset_id') || params.get('assetId') || params.get('id');

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [payload, setPayload] = useState(null);

  async function loadResource() {
    setLoading(true);
    setError('');
    setPayload(null);

    if (!assetId) {
      setError(t({id:'resource.noId'}));
      setLoading(false);
      return;
    }

    try {
      const { data: sessionData } = await supabase.auth.getSession();
      const token = sessionData?.session?.access_token;

      const headers = { 'Content-Type': 'application/json' };
      if (token) headers['Authorization'] = `Bearer ${token}`;
      else headers['Authorization'] = `Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmbHdtaWtpeWpmbmlraXBodGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzIyNDUsImV4cCI6MjA4OTQwODI0NX0.kCs7nPg08ofjb9CWwRH9xVN6BjanrAC5pj418line1o'}`;
      headers['apikey'] = headers['Authorization'].replace('Bearer ', '');

      const res = await fetch(EDGE_URL, {
        method: 'POST',
        headers,
        body: JSON.stringify({ asset_id: Number(assetId) }),
      });

      if (!res.ok) {
        const text = await res.text();
        throw new Error(t({id:'resource.errorStatus'},{status:res.status}) + ': ' + text);
      }

      const contentType = res.headers.get('content-type') || '';
      if (contentType.includes('application/json')) {
        const data = await res.json();
        setPayload(data);
      } else {
        // Binary response (PDF, etc.) — create blob URL
        const blob = await res.blob();
        setPayload({
          access_url: URL.createObjectURL(blob),
          viewer_kind: contentType.includes('pdf') ? 'pdf' : 'generic',
          asset: { mime_type: contentType, label: t({id:'resource.title'}) },
        });
      }
    } catch (err) {
      setError(err.message || t({id:'resource.errorLoading'}));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { loadResource(); }, [assetId, user]);

  useDocumentTitle(payload?.asset?.label || t({ id: 'pageTitle.resource' }));

  const asset = payload?.asset || {};
  const accessUrl = payload?.access_url || '';
  const viewerKind = payload?.viewer_kind || 'generic';

  return (
    <PageShell>
      <Topbar />

      {/* Hero */}
      <Hero title={t({ id: 'resource.heroTitle' })} subtitle={t({ id: 'resource.heroSubtitle' })}>
        <div className="ab-recurso-hero-actions">
          <Link to="/" className="ab-button ab-button--secondary">{t({ id: 'resource.backToCatalog' })}</Link>
          {user
            ? <Link to="/conta" className="ab-button ab-button--secondary">{t({ id: 'nav.account' })}</Link>
            : <Link to="/cadastro" className="ab-button ab-button--secondary">{t({ id: 'resource.signInOrAccount' })}</Link>}
          {accessUrl && !accessUrl.startsWith('blob:') && (
            <a href={accessUrl} target="_blank" rel="noopener noreferrer" className="ab-button">{t({ id: 'resource.open' })}</a>
          )}
        </div>
      </Hero>

      {/* Toolbar pills */}
      <div className="ab-recurso-toolbar">
        <Pill>{user?.email || t({ id: 'resource.noSession' })}</Pill>
        <Pill variant={loading ? 'warn' : error ? 'bad' : 'ok'}>
          {loading ? t({id:'resource.checking'}) : error ? t({id:'resource.error'}) : t({id:'resource.authorized'})}
        </Pill>
        {viewerKind && !loading && !error && <Pill>{t({ id: 'resource.viewer' }, { kind: t({ id: `resource.viewerKind.${viewerKind}`, defaultMessage: viewerKind }) })}</Pill>}
        <button className="ab-button ab-button--secondary ab-button--mini" onClick={loadResource}>{t({ id: 'common.update' })}</button>
        <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => {
          navigator.clipboard.writeText(window.location.href).catch(() => {});
        }}>{t({ id: 'resource.copyLink' })}</button>
      </div>

      {/* Contenu */}
      {loading ? (
        <div className="ab-recurso-loading"><Spinner size={32} /><p>{t({ id: 'resource.loadingMessage' })}</p></div>
      ) : error ? (
        <div className="ab-recurso-error">
          <EmptyState message={error}>
            {!user && <Link to="/cadastro"><Button>{t({ id: 'resource.signInToAccess' })}</Button></Link>}
            <Button variant="secondary" onClick={loadResource}>{t({ id: 'common.retry' })}</Button>
          </EmptyState>
        </div>
      ) : (
        <div className="ab-recurso-grid">
          {/* Carte métadonnées */}
          <div className="ab-recurso-card">
            <h2 className="ab-recurso-section-title">{t({ id: 'resource.readingTitle' })}</h2>
            <p className="ab-recurso-summary">
              {accessUrl ? t({id:'resource.loaded'}) : t({id:'resource.noUrl'})}
            </p>
            <div className="ab-recurso-meta-list">
              <MetaItem label={t({ id: 'resource.meta.focus' })} value={fmt(asset.label)} />
              <MetaItem label={t({ id: 'resource.meta.typeUse' })} value={`${fmt(asset.resource_type)} · ${fmt(asset.usage_type)}`} />
              <MetaItem label={t({ id: 'resource.meta.access' })} value={fmt(asset.access_scope)} />
              <MetaItem label={t({ id: 'resource.meta.sourceAttribution' })} value={fmt(asset.attribution_text || asset.source_name)} />
              <MetaItem label={t({ id: 'resource.meta.rightsLanguage' })} value={`${fmt(asset.rights_status)} · ${fmt(asset.language_code)}`} />
              <MetaItem label={t({ id: 'resource.meta.technicalIds' })} value={`asset_id: ${assetId || '—'} · mime: ${fmt(asset.mime_type)} · bucket: ${fmt(asset.storage_bucket)}`} />
            </div>
          </div>

          {/* Viewer */}
          <div className="ab-recurso-viewer-shell">
            <div className="ab-recurso-viewer-head">
              <h2>{fmt(asset.label, t({ id: 'pageTitle.resource' }))}</h2>
              <p>{t({ id: 'resource.viewerTypeLine' }, { type: fmt(asset.resource_type), use: fmt(asset.usage_type), access: fmt(asset.access_scope) })}</p>
            </div>
            <div className="ab-recurso-viewer-body">
              {!accessUrl ? (
                <div className="ab-recurso-viewer-empty">
                  <strong>{t({ id: 'resource.viewer.empty' })}</strong>
                  <p>{t({ id: 'resource.viewer.emptyDetail' })}</p>
                </div>
              ) : viewerKind === 'pdf' ? (
                <iframe src={accessUrl} title="PDF" className="ab-recurso-iframe" />
              ) : viewerKind === 'audio' ? (
                <audio controls preload="metadata" src={accessUrl} className="ab-recurso-audio" />
              ) : viewerKind === 'video' ? (
                <video controls preload="metadata" src={accessUrl} className="ab-recurso-video" />
              ) : viewerKind === 'image' ? (
                <img src={accessUrl} alt={t({ id: 'resource.viewer.imageAlt' })} className="ab-recurso-image" />
              ) : viewerKind === 'external_link' ? (
                <div className="ab-recurso-viewer-notice">
                  <strong>{t({ id: 'resource.viewer.externalTitle' })}</strong>
                  <p dangerouslySetInnerHTML={{ __html: t({ id: 'resource.viewer.externalNotice' }) }} />
                  <a href={accessUrl} target="_blank" rel="noopener noreferrer" className="ab-button">{t({ id: 'resource.viewer.openExternal' })}</a>
                </div>
              ) : (
                <div className="ab-recurso-viewer-notice">
                  <strong>{t({ id: 'resource.viewer.unsupportedTitle' })}</strong>
                  <p>{t({ id: 'resource.viewer.unsupportedDetail' })}</p>
                  {accessUrl && <a href={accessUrl} target="_blank" rel="noopener noreferrer" className="ab-button ab-button--secondary">{t({ id: 'resource.viewer.openNewTab' })}</a>}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      <Footer />
    </PageShell>
  );
}

function MetaItem({ label, value }) {
  return (
    <div className="ab-recurso-meta-item">
      <strong>{label}</strong>
      <div>{value}</div>
    </div>
  );
}
