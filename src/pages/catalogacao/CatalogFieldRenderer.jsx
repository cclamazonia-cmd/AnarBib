/* ──────────────────────────────────────────────────────────────────────────
 *  CatalogFieldRenderer.jsx — Rendu générique piloté par le registre
 *  Track A · Lot 4   (spec-catalogacao-fiche-et-paliers v0.3, §3.1 / §7)
 *
 *  RÔLE
 *  ────
 *  Transforme un descripteur de champ du registre (fieldRegistry.js) en JSX.
 *  Remplace les helpers ad-hoc `inp()` / `sel()` de BookDraftForm : le rendu
 *  d'un champ découle désormais de sa déclaration, pas d'une branche JSX.
 *
 *  STYLE (Lot 4)
 *  ─────────────
 *  Utilise les classes `.ab-*` de la maquette v3. Les styles inline sont
 *  supprimés ; tout passe par CatalogacaoPage.css.
 *  `type:'seg'` rend un vrai segmented control (boutons aria-pressed).
 *
 *  VISIBILITÉ
 *  ──────────
 *  Ce module ne décide PAS de la visibilité : l'appelant ne lui passe que des
 *  champs déjà filtrés par `visibleGroups(tier, material)` (§3.3).
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
 *    - type omis ⇒ 'text'
 *    - type 'seg' ⇒ segmented control (boutons mutuellement exclusifs)
 *    - ph = clé i18n du placeholder ; phEx = placeholder littéral
 * ────────────────────────────────────────────────────────────────────────── */

import { FIELD_BY_ID, isFieldVisible } from './fieldRegistry.js';

function placeholderOf(field, t) {
  if (field.ph) return t({ id: field.ph });
  if (field.phEx) return field.phEx;
  return undefined;
}

function spanClass(span) {
  if (span === 2) return 'ab-span2';
  if (span === 3) return 'ab-span3';
  return '';
}

// Rend un champ unique. À utiliser dans un .map() (la `key` est posée ici).
export function renderField(field, ctx) {
  const { f, set, t } = ctx;
  const label = t({ id: field.label });
  const className = `ab-field ${spanClass(field.span)}`.trim();
  const placeholder = placeholderOf(field, t);
  const type = field.type || 'text';

  if (type === 'textarea') {
    return (
      <div className={className} key={field.id}>
        <label className="ab-field__label">{label}</label>
        <textarea
          className="ab-textarea"
          value={f(field.id)}
          onChange={e => set(field.id, e.target.value)}
          placeholder={placeholder}
          rows={field.rows || 3}
        />
      </div>
    );
  }

  if (type === 'seg') {
    const options = (field.opts || []).map(o => ({ value: o.value, label: t({ id: o.label }) }));
    const current = f(field.id);
    return (
      <div className={className} key={field.id}>
        <label className="ab-field__label">{label}</label>
        <div className="ab-seg">
          {options.map(o => (
            <button
              key={o.value}
              type="button"
              aria-pressed={current === o.value ? 'true' : 'false'}
              onClick={() => set(field.id, o.value)}
            >
              {o.label}
            </button>
          ))}
        </div>
      </div>
    );
  }

  if (type === 'select') {
    const options = (field.opts || []).map(o => ({ value: o.value, label: t({ id: o.label }) }));
    return (
      <div className={className} key={field.id}>
        <label className="ab-field__label">{label}</label>
        <select
          className="ab-select"
          value={f(field.id)}
          onChange={e => set(field.id, e.target.value)}
        >
          {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </div>
    );
  }

  if (type === 'library_select') {
    // field.id is 'owner_library' or 'holder_library'; paired uuid column is '<id>_id'
    const idKey = field.id + '_id';
    const libs = ctx.networkLibraries || [];
    return (
      <div className={className} key={field.id}>
        <label className="ab-field__label">{label}</label>
        <select
          className="ab-select"
          value={f(idKey) || ''}
          onChange={e => {
            const lib = libs.find(l => l.id === e.target.value);
            set(idKey, e.target.value || '');
            set(field.id, lib ? lib.name : '');
          }}
        >
          <option value="">{placeholder || '—'}</option>
          {libs.map(l => <option key={l.id} value={l.id}>{l.name}{l.short_name ? ` (${l.short_name})` : ''}</option>)}
        </select>
      </div>
    );
  }

  // text | number | date
  return (
    <div className={className} key={field.id}>
      <label className="ab-field__label">{label}</label>
      <input
        className="ab-input"
        type={type}
        value={f(field.id)}
        onChange={e => set(field.id, e.target.value)}
        placeholder={placeholder}
        readOnly={field.readOnly}
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

// Rend une section « matériel » : en-tête avec tag + grille de champs.
// Utilise les classes .ab-group de la maquette v3.
// `group.fields` est déjà filtré par palier/matériel (visibleGroups).
//
// #périodiques P7 (27/08/2026) — `ctx.sectionExtras[group.id]` permet à une
// section d'accueillir un composant qui n'est pas un champ du registre,
// rendu EN TÊTE de la grille.
//
// ⚠ Ce point d'extension ne vaut que pour les groupes que BookDraftForm passe
// RÉELLEMENT à cette fonction (MATERIAL_SECTION_IDS + `aquisicao`). Le
// sélecteur de titre de revue y avait été déclaré sous la clé `periodico`, un
// groupe que le formulaire rend champ par champ dans sa grille principale :
// l'entrée n'a jamais été lue, le sélecteur n'a jamais été monté (constaté en
// prod le 02/09/2026). Il est désormais monté en ligne dans BookDraftForm ;
// src/tests/serial-picker-monte.test.js garde la règle « une clé de
// sectionExtras = un groupe effectivement rendu par renderMaterialSection ».
export function renderMaterialSection(group, ctx) {
  const { t } = ctx;
  const extra = ctx.sectionExtras ? ctx.sectionExtras[group.id] : null;
  return (
    <section className="ab-group ab-span3" key={group.id}>
      <div className="ab-group-head">
        <h3>{t({ id: group.title })}</h3>
        {group.tag && <span className="ab-tag">{t({ id: group.tag })}</span>}
      </div>
      <div className="cat-book-grid">
        {extra || null}
        {group.fields.map(field => renderField(field, ctx))}
      </div>
    </section>
  );
}
