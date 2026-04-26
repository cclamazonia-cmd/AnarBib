import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
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

  useEffect(() => {
    const label = payload?.asset?.label || 'Recurso digital';
    document.title = `${label} — AnarBib`;
  }, [payload]);

  const asset = payload?.asset || {};
  const accessUrl = payload?.access_url || '';
  const viewerKind = payload?.viewer_kind || 'generic';

  return (
    <PageShell>
      <Topbar />

      {/* Hero */}
      <Hero title="Ler recurso digital" subtitle="Abertura genérica de recurso digital do AnarBib para PDF, áudio, vídeo, imagem e links externos.">
        <div className="ab-recurso-hero-actions">
          <Link to="/" className="ab-button ab-button--secondary">Voltar ao catálogo</Link>
          {user
            ? <Link to="/conta" className="ab-button ab-button--secondary">Minha conta</Link>
            : <Link to="/cadastro" className="ab-button ab-button--secondary">Entrar / minha conta</Link>}
          {accessUrl && !accessUrl.startsWith('blob:') && (
            <a href={accessUrl} target="_blank" rel="noopener noreferrer" className="ab-button">Abrir recurso</a>
          )}
        </div>
      </Hero>

      {/* Toolbar pills */}
      <div className="ab-recurso-toolbar">
        <Pill>{user?.email || 'Sem sessão'}</Pill>
        <Pill variant={loading ? 'warn' : error ? 'bad' : 'ok'}>
          {loading ? t({id:'resource.checking'}) : error ? t({id:'resource.error'}) : t({id:'resource.authorized'})}
        </Pill>
        {viewerKind && !loading && !error && <Pill>Leitor: {viewerKind}</Pill>}
        <button className="ab-button ab-button--secondary ab-button--mini" onClick={loadResource}>Atualizar</button>
        <button className="ab-button ab-button--secondary ab-button--mini" onClick={() => {
          navigator.clipboard.writeText(window.location.href).catch(() => {});
        }}>Copiar link</button>
      </div>

      {/* Contenu */}
      {loading ? (
        <div className="ab-recurso-loading"><Spinner size={32} /><p>Carregando metadados e acesso do recurso digital.</p></div>
      ) : error ? (
        <div className="ab-recurso-error">
          <EmptyState message={error}>
            {!user && <Link to="/cadastro"><Button>Entrar para acessar</Button></Link>}
            <Button variant="secondary" onClick={loadResource}>Tentar de novo</Button>
          </EmptyState>
        </div>
      ) : (
        <div className="ab-recurso-grid">
          {/* Carte métadonnées */}
          <div className="ab-recurso-card">
            <h2 className="ab-recurso-section-title">Leitura do recurso</h2>
            <p className="ab-recurso-summary">
              {accessUrl ? t({id:'resource.loaded'}) : t({id:'resource.noUrl'})}
            </p>
            <div className="ab-recurso-meta-list">
              <MetaItem label="Recurso em foco" value={fmt(asset.label)} />
              <MetaItem label="Tipo / uso" value={`${fmt(asset.resource_type)} · ${fmt(asset.usage_type)}`} />
              <MetaItem label="Acesso" value={fmt(asset.access_scope)} />
              <MetaItem label="Fonte / atribuição" value={fmt(asset.attribution_text || asset.source_name)} />
              <MetaItem label="Direitos / idioma" value={`${fmt(asset.rights_status)} · ${fmt(asset.language_code)}`} />
              <MetaItem label="Identificadores técnicos" value={`asset_id: ${assetId || '—'} · mime: ${fmt(asset.mime_type)} · bucket: ${fmt(asset.storage_bucket)}`} />
            </div>
          </div>

          {/* Viewer */}
          <div className="ab-recurso-viewer-shell">
            <div className="ab-recurso-viewer-head">
              <h2>{fmt(asset.label, 'Recurso digital')}</h2>
              <p>Tipo {fmt(asset.resource_type)} · uso {fmt(asset.usage_type)} · acesso {fmt(asset.access_scope)}</p>
            </div>
            <div className="ab-recurso-viewer-body">
              {!accessUrl ? (
                <div className="ab-recurso-viewer-empty">
                  <strong>Sem conteúdo para mostrar</strong>
                  <p>Este recurso não retornou URL de acesso.</p>
                </div>
              ) : viewerKind === 'pdf' ? (
                <iframe src={accessUrl} title="PDF" className="ab-recurso-iframe" />
              ) : viewerKind === 'audio' ? (
                <audio controls preload="metadata" src={accessUrl} className="ab-recurso-audio" />
              ) : viewerKind === 'video' ? (
                <video controls preload="metadata" src={accessUrl} className="ab-recurso-video" />
              ) : viewerKind === 'image' ? (
                <img src={accessUrl} alt="Imagem do recurso digital" className="ab-recurso-image" />
              ) : viewerKind === 'external_link' ? (
                <div className="ab-recurso-viewer-notice">
                  <strong>Link externo</strong>
                  <p>Este recurso abre fora do AnarBib. Usa o botão <em>Abrir recurso</em> para continuar.</p>
                  <a href={accessUrl} target="_blank" rel="noopener noreferrer" className="ab-button">Abrir recurso externo</a>
                </div>
              ) : (
                <div className="ab-recurso-viewer-notice">
                  <strong>Formato sem renderização local segura</strong>
                  <p>O recurso está acessível, mas este formato abre melhor numa nova aba.</p>
                  {accessUrl && <a href={accessUrl} target="_blank" rel="noopener noreferrer" className="ab-button ab-button--secondary">Abrir em nova aba</a>}
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
