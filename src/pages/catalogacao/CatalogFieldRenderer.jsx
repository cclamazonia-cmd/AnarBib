/* ──────────────────────────────────────────────────────────────────────────
 *  CatalogFieldRenderer.jsx — Rendu générique piloté par le registre
 *  Track A · Lot 2   (spec-catalogacao-fiche-et-paliers v0.3, §3.1)
 *
 *  RÔLE
 *  ────
 *  Transforme un descripteur de champ du registre (fieldRegistry.js) en JSX.
 *  Remplace les helpers ad-hoc `inp()` / `sel()` de BookDraftForm : le rendu
 *  d'un champ découle désormais de sa déclaration, pas d'une branche JSX.
 *
 *  FIDÉLITÉ (Lot 2 = refactor de mécanisme, pas de style)
 *  ──────────────────────────────────────────────────────
 *  Le markup reproduit EXACTEMENT `inp`/`sel` actuels : même `.cat-field`,
 *  mêmes styles inline, même structure label + contrôle. L'adoption des
 *  classes `.ab-*` et le vrai segmented control relèvent du Lot 4 (lisibilité).
 *
 *  VISIBILITÉ
 *  ──────────
 *  Ce module ne décide PAS de la visibilité : l'appelant ne lui passe que des
 *  champs déjà filtrés par `visibleGroups(tier, material)` (§3.3). Donc plus de
 *  `mode-complete-only` ici — un champ non visible n'est tout simplement pas rendu.
 *
 *  CONTRAT
 *  ───────
 *  ctx = { f, set, t }
 *    f(key)        → valeur courante (string)
 *    set(key, val) → maj d'état
 *    t({id})       → formatMessage (react-intl)
 *
 *  Descripteur (cf. fieldRegistry.js) :
 *    { id, label, type?, span?, ph?, phEx?, rows?, opts?, readOnly? }
 *    - type omis ⇒ 'text' ; 'seg' rendu comme <select> en Lot 2
 *    - ph = clé i18n du placeholder ; phEx = placeholder littéral
 * ────────────────────────────────────────────────────────────────────────── */

import { FIELD_BY_ID, isFieldVisible } from './fieldRegistry.js';

const CONTROL_STYLE = {
  width: '100%', padding: '7px 10px', borderRadius: 6,
  border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)',
  color: '#f4f4f4', fontSize: '.85rem',
};
const READONLY_STYLE = { ...CONTROL_STYLE, background: 'rgba(0,0,0,.15)' };
const TEXTAREA_STYLE = { ...CONTROL_STYLE, resize: 'vertical', fontFamily: 'inherit' };

function placeholderOf(field, t) {
  if (field.ph) return t({ id: field.ph });
  if (field.phEx) return field.phEx;
  return undefined;
}

// Rend un champ unique. À utiliser dans un .map() (la `key` est posée ici).
export function renderField(field, ctx) {
  const { f, set, t } = ctx;
  const label = t({ id: field.label });
  const style = field.span ? { gridColumn: `span ${field.span}` } : {};
  const placeholder = placeholderOf(field, t);
  const type = field.type || 'text';

  if (type === 'textarea') {
    return (
      <div className="cat-field" style={style} key={field.id}>
        <label>{label}</label>
        <textarea
          value={f(field.id)}
          onChange={e => set(field.id, e.target.value)}
          placeholder={placeholder}
          rows={field.rows || 3}
          style={TEXTAREA_STYLE}
        />
      </div>
    );
  }

  if (type === 'select' || type === 'seg') {
    const options = (field.opts || []).map(o => ({ value: o.value, label: t({ id: o.label }) }));
    return (
      <div className="cat-field" style={style} key={field.id}>
        <label>{label}</label>
        <select
          value={f(field.id)}
          onChange={e => set(field.id, e.target.value)}
          style={CONTROL_STYLE}
        >
          {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </div>
    );
  }

  // text | number | date
  return (
    <div className="cat-field" style={style} key={field.id}>
      <label>{label}</label>
      <input
        type={type}
        value={f(field.id)}
        onChange={e => set(field.id, e.target.value)}
        placeholder={placeholder}
        readOnly={field.readOnly}
        style={field.readOnly ? READONLY_STYLE : CONTROL_STYLE}
      />
    </div>
  );
}

// Rend un champ du registre par son id, gardé par (tier, material).
// Renvoie null (donc rien) si le champ n'est pas visible — c'est ce qui applique
// le filtrage matériel au cœur de la fiche (ex. editora masquée pour áudio).
export function renderRegistryField(id, ctx, tier, material) {
  const field = FIELD_BY_ID[id];
  if (!field || !isFieldVisible(field, tier, material)) return null;
  return renderField(field, ctx);
}

// Rend une section « matériel » : en-tête + grille de champs.
// Reproduit le pattern `.cat-material-section` › h4 › `.cat-book-grid` du legacy.
// `group.fields` est déjà filtré par palier/matériel (visibleGroups).
export function renderMaterialSection(group, ctx) {
  const { t } = ctx;
  return (
    <div className="cat-material-section" style={{ gridColumn: 'span 3' }} key={group.id}>
      <h4>{t({ id: group.title })}</h4>
      <div className="cat-book-grid">
        {group.fields.map(field => renderField(field, ctx))}
      </div>
    </div>
  );
}
