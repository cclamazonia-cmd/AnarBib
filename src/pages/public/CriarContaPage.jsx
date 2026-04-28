import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '@/lib/supabase';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { Button } from '@/components/ui';
import CountrySelect from '@/components/forms/CountrySelect';
import StateSelect from '@/components/forms/StateSelect';
import PhoneInput, { isValidPhoneNumber } from '@/components/forms/PhoneInput';
import { hasStatesList, getCountryMetadata, getStateName } from '@/components/forms/countryData';

const ANARBIB_LOGO = 'https://cclamazonia.noblogs.org/files/2026/03/AnarBib_logo.png';
const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';

// Pays par défaut au chargement initial. La détection plus fine
// (via locale ou IP géolocalisée) pourra être ajoutée ultérieurement.
const DEFAULT_COUNTRY = 'BR';

export default function CriarContaPage() {
  const navigate = useNavigate();
  const { formatMessage: t } = useIntl();
  const GENDERS = [
    { value: '',            label: t({id:'auth.create.genderNone'}) },
    { value: 'feminino',    label: t({id:'auth.create.genderF'}) },
    { value: 'masculino',   label: t({id:'auth.create.genderM'}) },
    { value: 'nao_binario', label: t({id:'auth.create.genderNB'}) },
    { value: 'outro',       label: t({id:'auth.create.genderOther'}) },
  ];
  const [libraries, setLibraries] = useState([]);
  const [currentLib, setCurrentLib] = useState(null);
  const [form, setForm] = useState({
    library_slug: '', first_name: '', last_name: '', email: '',
    // phone est désormais au format E.164 ('+5511999999999')
    phone: '',
    gender: '', addr1: '', addr2: '', unit: '', cep: '', bairro: '',
    city: '',
    state: '',
    country: DEFAULT_COUNTRY,
    acceptRules: false, consent: false,
  });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [loading, setLoading] = useState(false);
  const [publicId, setPublicId] = useState('');

  // Métadonnées de pays pour adapter labels et listes (CEP/PLZ/CP/ZIP, Estado/Bundesland/etc.)
  const countryMeta = getCountryMetadata(form.country);

  useEffect(() => {
    (async () => {
      try {
        const { data: libs } = await supabase.from('v_libraries_for_signup').select('id, slug, name, short_name, city');

        if (!libs?.length) return;
        const { data: commons } = await supabase.from('library_commons').select('library_id, logo_url, logo_file_key');
        const { data: regs } = await supabase.from('library_regulation_documents').select('library_id').eq('is_active', true);
        const regSet = new Set((regs || []).map(r => r.library_id));
        const commonsMap = {}; (commons || []).forEach(c => { commonsMap[c.library_id] = c; });
        setLibraries(libs.map(l => ({ ...l, logo_url: commonsMap[l.id]?.logo_url || null, logo_file_key: commonsMap[l.id]?.logo_file_key || null, has_regimento: regSet.has(l.id) })));
      } catch {}
    })();
  }, []);

  function set(k, v) { setForm(p => ({ ...p, [k]: v })); }
  function handleLibChange(slug) { set('library_slug', slug); set('acceptRules', false); setCurrentLib(libraries.find(l => l.slug === slug) || null); }
  function libLogo(lib) {
    if (!lib?.slug) return null;
    if (lib.logo_url?.startsWith('http')) return lib.logo_url;
    if (lib.logo_file_key && !lib.logo_file_key.startsWith('.')) {
      const key = lib.logo_file_key.includes('/') ? lib.logo_file_key : `themes/${lib.logo_file_key}/logo-${lib.logo_file_key}.png`;
      return `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/${key}`;
    }
    return `${PROJECT_URL}/storage/v1/object/public/library-ui-assets/themes/${lib.slug}/logo-${lib.slug}.png`;
  }

  /**
   * Quand l'utilisateur·rice change de pays, on remet à zéro l'état/province
   * (les codes diffèrent d'un pays à l'autre). Le code postal est conservé
   * — l'utilisateur·rice peut avoir saisi le bon avant de choisir le pays.
   */
  function handleCountryChange(newCountry) {
    setForm(p => ({ ...p, country: newCountry, state: '' }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.first_name.trim() || !form.last_name.trim() || !form.email.trim() || !form.phone.trim()) {
      setMsg({ text: t({id:'auth.create.fillRequired'}), kind: 'error' });
      return;
    }
    // Validation E.164 du numéro de téléphone
    if (!isValidPhoneNumber(form.phone)) {
      setMsg({ text: t({id:'address.phone.invalid'}), kind: 'error' });
      return;
    }
    if (!form.consent) { setMsg({ text: t({id:'auth.create.checkConsent'}), kind: 'error' }); return; }
    if (currentLib?.has_regimento && !form.acceptRules) { setMsg({ text: t({id:'auth.create.acceptRulesRequired'}), kind: 'error' }); return; }

    setLoading(true); setMsg({ text: '', kind: '' }); setPublicId('');
    try {
      const noLib = !form.library_slug;
      const addr2 = [
        form.bairro.trim() && `${t({id:'auth.create.bairro'})}: ${form.bairro.trim()}`,
        form.addr2.trim()  && `${t({id:'auth.create.addr2'})}: ${form.addr2.trim()}`,
      ].filter(Boolean).join(' | ');

      // Conversion du code d'état (ex: 'SP') vers son nom local (ex: 'São Paulo')
      // si on a une liste fermée, sinon on envoie tel quel.
      const stateValue = hasStatesList(form.country)
        ? getStateName(form.country, form.state)
        : form.state.trim();

      // Pour le pays, on envoie le nom traduit dans la langue active pour l'affichage
      // mais on conserve aussi le code ISO côté Edge Function pour traitement.
      const { data, error } = await supabase.functions.invoke('register', { body: {
        email: form.email.trim(),
        first_name: form.first_name.trim(),
        last_name: form.last_name.trim(),
        phone: form.phone.trim(), // au format E.164
        gender: form.gender,
        address_1: form.addr1.trim(),
        address_2: addr2,
        address_unit: form.unit.trim(),
        cep: form.cep.trim(), // garde le nom 'cep' côté API par compat
        city: form.city.trim(),
        state: stateValue,
        country: form.country,           // code ISO ('BR', 'FR', 'AR'…)
        country_code: form.country,      // alias explicite pour la nouvelle API
        consent_email: true,
        accept_rules: currentLib?.has_regimento ? form.acceptRules : true,
        library_slug: noLib ? '' : form.library_slug,
        library_name: currentLib?.name || '',
        signup_without_library: noLib,
        anarbib_logo_url: ANARBIB_LOGO,
        preferred_login_identifier: 'public_id',
      }});
      if (error) {
        const m = data?.error || error.message || t({id:'auth.networkError'});
        setMsg({
          text: (m.includes('already') || m.includes('já existe') || m.includes('exists'))
            ? t({id:'auth.create.emailAlreadyRegistered'})
            : m,
          kind: 'error'
        });
        return;
      }
      if (data?.public_id) setPublicId(data.public_id);

      // Messages de succès
      const okMsgKey = data?.email_usuaria_enviado === false
        ? (noLib ? 'auth.create.successNoLibEmailFailed' : 'auth.create.successEmailFailed')
        : (noLib ? 'auth.create.successNoLib'           : 'auth.create.success');
      setMsg({
        text: t({id: okMsgKey}),
        kind: data?.email_usuaria_enviado === false ? 'warn' : 'ok'
      });
    } catch {
      setMsg({ text: t({id:'auth.networkError'}), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }

  const fs = { width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };
  const ls = { display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 3, color: 'var(--brand-muted, #ccc)' };
  const hs = { fontSize: '.78rem', color: 'var(--brand-muted, #999)', marginTop: 4 };
  const req = <span style={{ color: '#f87171' }}>*</span>;
  const ll = libLogo(currentLib);

  return (
    <PageShell><Topbar />
      <div style={{ maxWidth: 720, margin: '0 auto', padding: '24px 16px' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 4, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({id:'auth.create.title'})}</h1>
        <p style={{ color: 'var(--brand-muted)', marginBottom: 20, fontSize: '.9rem' }}>{t({id:'auth.create.subtitle'})}</p>

        {/* Sélection de bibliothèque */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16 }}>
          <label style={ls}>{t({id:'auth.create.selectLibrary'})} {req}</label>
          <select value={form.library_slug} onChange={e => handleLibChange(e.target.value)} style={fs}>
            <option value="">{t({id:'auth.create.selectPh'})}</option>
            {libraries.map(l => (
              <option key={l.slug} value={l.slug}>
                {l.short_name ? `${l.short_name} — ` : ''}
                {l.name}
                {l.city ? ` (${l.city})` : ''}
              </option>
            ))}
            <option value="">{t({id:'auth.create.noLibrary'})}</option>
          </select>
          <div style={hs}>{t({id:'auth.create.libraryHint'})}</div>
        </div>

        {/* Logos */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 16, margin: '16px 0', padding: 16 }}>
          <img src={ANARBIB_LOGO} alt="AnarBib" style={{ height: 64, objectFit: 'contain', filter: 'drop-shadow(0 4px 12px rgba(0,0,0,.4))' }} />
          {ll && (<><span style={{ fontSize: '1.5rem', color: 'var(--brand-muted, #888)', fontWeight: 300 }}>+</span>
            <img src={ll} alt={currentLib?.name || ''} style={{ height: 64, objectFit: 'contain', filter: 'drop-shadow(0 4px 12px rgba(0,0,0,.4))' }} /></>)}
        </div>

        {/* Bloc sécurité */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(29,78,216,.08)', border: '1px solid rgba(29,78,216,.2)', marginBottom: 16, fontSize: '.82rem', color: 'var(--brand-muted, #ccc)', lineHeight: 1.6 }}>
          <strong>{t({id:'auth.create.securityTitle'})}</strong>
          <p style={{ margin: '4px 0' }}>{t({id:'auth.create.securityPw'})}</p>
          <p style={{ margin: '4px 0' }}>{t({id:'auth.create.securityId'})}</p>
          <p style={{ margin: '4px 0' }}>{t({id:'auth.create.securityForgot'}, {
            link: <Link to="/cadastro" style={{ textDecoration: 'underline' }}>{t({id:'auth.create.securityForgotLink'})}</Link>
          })}</p>
          <p style={{ margin: '4px 0' }}>{t({id:'auth.create.securitySpam'})}</p>
        </div>

        <p style={hs}>{req}{t({id:'auth.create.required'})}</p>

        {msg.text && <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'warn' ? 'rgba(180,83,9,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'warn' ? '#fbbf24' : '#f87171', border: `1px solid ${msg.kind === 'ok' ? 'rgba(21,128,61,.25)' : msg.kind === 'warn' ? 'rgba(180,83,9,.25)' : 'rgba(220,38,38,.25)'}` }}>{msg.text}</div>}

        {publicId && <div style={{ padding: 16, borderRadius: 10, background: 'rgba(21,128,61,.12)', border: '1px solid rgba(21,128,61,.3)', marginBottom: 16, textAlign: 'center' }}>
          <strong>{t({id:'auth.create.yourPublicId'})}</strong>
          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0' }}>{t({id:'auth.create.publicIdHint'})}</div>
          <div style={{ fontSize: '1.4rem', fontWeight: 900, letterSpacing: '.05em', color: '#4ade80' }}>{publicId}</div>
        </div>}

        <form onSubmit={handleSubmit}>
          {/* Nom + Prénom */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
            <div>
              <label style={ls}>{t({id:'auth.create.firstName'})} {req}</label>
              <input type="text" value={form.first_name} onChange={e => set('first_name', e.target.value)} required style={fs} autoComplete="given-name" />
            </div>
            <div>
              <label style={ls}>{t({id:'auth.create.lastName'})} {req}</label>
              <input type="text" value={form.last_name} onChange={e => set('last_name', e.target.value)} required style={fs} autoComplete="family-name" />
            </div>
          </div>

          {/* Email */}
          <div style={{ marginBottom: 12 }}>
            <label style={ls}>{t({id:'auth.create.email'})} {req}</label>
            <input type="email" value={form.email} onChange={e => set('email', e.target.value)} required style={fs} autoComplete="email" />
          </div>

          {/* Téléphone international (composant E.164) */}
          <div style={{ marginBottom: 12 }}>
            <label style={ls}>{t({id:'auth.create.phone'})} {req}</label>
            <PhoneInput
              value={form.phone}
              onChange={v => set('phone', v || '')}
              countryCode={form.country}
              required
              ariaLabel={t({id:'auth.create.phone'})}
            />
            <div style={hs}>{t({id:'address.phone.hint'})}</div>
          </div>

          {/* Genre */}
          <div style={{ marginBottom: 16 }}>
            <label style={ls}>{t({id:'auth.create.gender'})}</label>
            <select value={form.gender} onChange={e => set('gender', e.target.value)} style={fs}>
              {GENDERS.map(g => <option key={g.value} value={g.value}>{g.label}</option>)}
            </select>
            <div style={hs}>{t({id:'auth.create.genderOptional'})}</div>
          </div>

          {/* ─── Section Adresse ─── */}
          <h2 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: 10, fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({id:'auth.create.addressTitle'})}</h2>

          {/* Pays — placé EN PREMIER pour adapter dynamiquement les champs suivants */}
          <div style={{ marginBottom: 12 }}>
            <label style={ls}>{t({id:'auth.create.country'})} {req}</label>
            <CountrySelect value={form.country} onChange={handleCountryChange} required style={fs} />
          </div>

          {/* Adresse ligne 1 */}
          <div style={{ marginBottom: 12 }}>
            <label style={ls}>{t({id:'auth.create.addr1'})}</label>
            <input type="text" value={form.addr1} onChange={e => set('addr1', e.target.value)} style={fs} autoComplete="address-line1" />
          </div>

          {/* Adresse ligne 2 (complément) */}
          <div style={{ marginBottom: 12 }}>
            <label style={ls}>{t({id:'auth.create.addr2'})}</label>
            <input type="text" value={form.addr2} onChange={e => set('addr2', e.target.value)} style={fs} autoComplete="address-line2" />
          </div>

          {/* Numéro / Code postal / Quartier (le label "bairro/quartier" reste utile en BR/FR/ES) */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, marginBottom: 12 }}>
            <div>
              <label style={ls}>{t({id:'auth.create.unit'})}</label>
              <input type="text" value={form.unit} onChange={e => set('unit', e.target.value)} style={fs} />
            </div>
            <div>
              {/* Le label du code postal s'adapte selon le pays (CEP/CP/PLZ/ZIP/Postcode) */}
              <label style={ls}>{t({id: countryMeta.postalCodeLabel})}</label>
              <input type="text" value={form.cep} onChange={e => set('cep', e.target.value)} inputMode="numeric" style={fs} autoComplete="postal-code" />
            </div>
            <div>
              <label style={ls}>{t({id:'auth.create.bairro'})}</label>
              <input type="text" value={form.bairro} onChange={e => set('bairro', e.target.value)} style={fs} />
            </div>
          </div>

          {/* Ville */}
          <div style={{ marginBottom: 12 }}>
            <label style={ls}>{t({id:'auth.create.city'})}</label>
            <input type="text" value={form.city} onChange={e => set('city', e.target.value)} style={fs} autoComplete="address-level2" />
          </div>

          {/* État/Région — adaptatif au pays sélectionné */}
          <div style={{ marginBottom: 16 }}>
            <label style={ls}>{t({id: countryMeta.stateLabel})}</label>
            <StateSelect
              countryCode={form.country}
              value={form.state}
              onChange={v => set('state', v)}
              style={fs}
              ariaLabel={t({id: countryMeta.stateLabel})}
            />
          </div>

          <hr style={{ border: 'none', borderTop: '1px solid rgba(255,255,255,.1)', margin: '20px 0' }} />

          {/* Acceptation du règlement (uniquement si la bibliothèque en a un) */}
          {currentLib?.has_regimento && (
            <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 12, fontSize: '.85rem', cursor: 'pointer' }}>
              <input type="checkbox" checked={form.acceptRules} onChange={e => set('acceptRules', e.target.checked)} style={{ marginTop: 3 }} />
              <span>{t({id:'auth.create.acceptRules'})} {req}</span>
            </label>
          )}

          {/* Consentement email */}
          <label style={{ display: 'flex', gap: 8, alignItems: 'flex-start', marginBottom: 16, fontSize: '.85rem', cursor: 'pointer' }}>
            <input type="checkbox" checked={form.consent} onChange={e => set('consent', e.target.checked)} required style={{ marginTop: 3 }} />
            <span>{t({id:'auth.create.consentEmail'})}</span>
          </label>

          {/* Boutons d'action */}
          <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
            <Button variant="primary" type="submit" disabled={loading}>{loading ? t({id:'auth.create.submitting'}) : t({id:'auth.create.submit'})}</Button>
            <Button variant="secondary" onClick={() => navigate(-1)}>{t({id:'auth.create.back'})}</Button>
            <Link to="/cadastro" style={{ textDecoration: 'none' }}>
              <Button variant="secondary">{t({id:'auth.create.haveAccount'})}</Button>
            </Link>
          </div>
        </form>
      </div>
      <Footer />
    </PageShell>
  );
}
