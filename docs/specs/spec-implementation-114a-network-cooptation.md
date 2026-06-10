# Spec d'implémentation — #114.A : notify-event routing `network.cooptation_*`

> ## ⚠️ Note de clôture — 31/05/2026
>
> **Statut actuel** : référence historique — chantier #114.A clos le 14/05/2026.
> Toutes les phases décrites au § 8 « Estimation totale révisée » (i18n l.deadline, network.ts, dispatch.ts, check + deploy, test) ont été exécutées dans la session du 14/05. La RPC `notify-event` route désormais correctement `network.cooptation_proposed` et `network.cooptation_voted`.
>
> Source : résumé `docs/journal/arbitrages/AnarBib_decisions_synthese_2026-05-29.docx`, section « Acquis » ; backlog v23 section E.
>
> Le bloc de métadonnées ci-dessous est celui de la rédaction d'origine, conservé pour traçabilité.

**Version :** 0.1 — 2026-05-14
**Périmètre :** sous-paquet #114.A (cooptation_proposed + cooptation_voted)
**Statut :** Inconnues à trancher avant implémentation

---

## 1. Contexte

### 1.1 Bug constaté

L'Edge Function `notify-event` ne route pas les events `network.*`. Le helper SQL `fn_network_notify_event` insère bien les events dans `team_notification_outbox`, le trigger `trg_team_outbox_dispatch` POST bien vers l'EF, mais le dispatch.ts retourne `null` (= ignored), donc aucun mail n'est envoyé. Détecté lors du test cooptation Patricia 2026-05-13.

### 1.2 Périmètre du sous-paquet A

Implémenter **uniquement** les 2 premiers events de la cooptation initiale :

- `network.cooptation_proposed` — un admin propose la cooptation d'un nouveau membre
- `network.cooptation_voted` — un admin vote (favorable / opposed / abstain) sur une proposition ouverte

Les events suivants (`_rejected`, `_completed`, `_reminder`, et toute la famille `collective_removal_*`) sont **hors périmètre** et traités dans #114.B, #114.C…

### 1.3 Doctrine destinataires (spec v0.3 Q1)

| Event | Destinataires | Target notifié ? |
|---|---|---|
| `cooptation_proposed` | Tous admins réseau actifs **sauf proposeur** | NON |
| `cooptation_voted` | Tous admins réseau actifs **sauf voteur et target** | NON |

Le target n'est notifié qu'à `cooptation_completed` (= unanimité atteinte) ou `cooptation_rejected` (= au moins un vote contre).

---

## 2. Payloads SQL observés

### 2.1 `network.cooptation_proposed`

Source : `public.fn_network_admin_propose_cooptation(p_user_id uuid, p_motivation text)`

```json
{
  "proposal_id": "uuid",
  "proposed_user_id": "uuid (target)",
  "proposed_by": "uuid (proposeur)",
  "motivation_preview": "200 premiers caractères de la motivation",
  "expires_at": "ISO 8601 — 60 jours après création"
}
```

### 2.2 `network.cooptation_voted`

Source : `public.fn_network_admin_vote_cooptation(p_proposal_id uuid, p_vote text, p_disclose_identity boolean, p_rationale text DEFAULT NULL)`

```json
{
  "proposal_id": "uuid",
  "proposed_user_id": "uuid (target)",
  "proposed_by": "uuid (proposeur initial)",
  "vote": "favorable | opposed | abstain",
  "voter_user_id": "uuid OU null (selon disclose_identity)",
  "disclose_identity": "true | false"
}
```

**⚠️ Le payload ne contient PAS le `rationale`** (présent en DB mais non émis dans l'event pour préserver la vie privée du votant si non-disclose). Cf. inconnue § 4.4.

---

## 3. Helpers TS confirmés

### 3.1 mail-strings.ts (i18n)

```typescript
// tMail(locale, key, params?) avec fallback : locale → pt-BR → key
export function tMail(
  locale: string | null | undefined,
  key: string,
  params?: Record<string, string | number>
): string

// label(locale, key) = wrapper sur tMail(locale, `l.${key}`)
// Les "labels" sont stockés sous le préfixe `l.` (pas `label.`)
export function label(locale: string | null | undefined, key: string): string

// greeting(locale, name?) — prend un STRING name, pas un profil
export function greeting(
  locale: string | null | undefined,
  name?: string | null
): string

// formatDateLocale(d, locale?) — formate date selon locale
export function formatDateLocale(
  d: string | Date | null | undefined,
  locale?: string | null
): string
```

### 3.2 email.ts (transport)

```typescript
export async function safeSendEmail(target, subject, html, text, label = "email", context)
export function userTargetFromProfile(p)  // construit target email depuis profil
export function adminTarget(ctx)          // construit target email biblio
export function skippedEmailResult(label, reason, email)  // résultat NOOP propre
```

### 3.3 layout.ts (mail/)

```typescript
export function renderEmail(opts)
// opts : { preheader, title, introHtml, details, actionBox?, greeting?, footerHtml, context }
// details : [{ label, value }]
// actionBox : { kind: 'action' | 'info', label, url }
```

### 3.4 Convention team.ts (à calquer)

```typescript
// greeting est passé EN PARAMÈTRE de renderEmail, pas dans introHtml
const { html, text } = renderEmail({
  preheader: subject,
  title: subject,
  greeting: greeting(locale, target.first_name || undefined),
  introHtml: `<p>${introTpl}</p>`,
  details: [{ label: label(locale, "contact"), value: ... }],
  footerHtml: footerPadrao(ctx),
  context: ctx
});
```

---

## 4. Inconnues à trancher (4 points)

### 4.1 Locale du destinataire

**Question :** chaque admin réseau a un `profiles.preferred_language`. On envoie chaque mail dans la locale du destinataire individuellement. ✅ Pas de débat.

**Décision proposée :** OK, chaque admin reçoit dans sa locale. Fallback `pt-BR` si vide.

### 4.2 Contexte de branding (ctx)

**Question :** pour les events `team.*` (locaux à une biblio), `ctx = resolveLibraryNotificationContext(library_id)` donne le branding bibliothèque. Pour `network.*`, **il n'y a pas de library_id** : la gouvernance réseau est transverse.

**Options :**
- **A. ctx = null/neutre** : mail sans branding de biblio spécifique, subject `[AnarBib]` ou `[Rede]`
- **B. ctx du destinataire** : mail prend le branding de la biblio principale du destinataire (`profiles.default_library_id`)
- **C. ctx hardcodé "Rede AnarBib"** : on définit un ctx générique réseau

**Décision proposée :** **Option A** (ctx neutre, subject `[Rede]`). C'est cohérent avec le caractère transverse de l'admin réseau. La biblio locale n'a rien à voir avec un vote de cooptation.

**Action si validé :** modifier `subjectTag(null)` ou ajouter un cas spécial dans `applyBrandingText`. Ou plus simple, hardcoder `bt = "Rede"` dans le handler.

### 4.3 Labels manquants

**Question :** je veux afficher dans les `details` :
- Motivation (= déjà clé i18n existante `network.cooptation_proposed.motivation_label`)
- Deadline (60j) → **pas de label existant**
- Type de vote (favorable / opposed / abstain) → **pas de clés i18n**
- Identité du voteur si disclose → **pas de label existant**

**Options :**
- **A. Ajouter des clés `l.deadline`, `l.vote`, `l.voter`** + `network.vote.favorable/opposed/abstain` × 6 locales
- **B. Inline string dans le code** (avec dictionnaire local TS dans network.ts)
- **C. Minimaliste** : ne pas afficher voter ni type de vote dans cooptation_voted, juste le fait qu'un vote a eu lieu (info déjà dans intro)

**Décision proposée :** **Option A pour les labels** (cohérence i18n maintenance) + **Option C minimaliste pour le contenu du mail voted** (l'`intro` dit déjà "un admin a voté", ça suffit ; le vote détaillé est consultable dans `/painel/admin-rede`). Le destinataire ouvrira la page pour voir détails.

Concrètement, ajouter :
- `l.deadline` × 6 locales (= "Délai pour voter", "Voting deadline", etc.)

Et c'est tout pour #114.A. Les labels `vote`, `voter`, etc. seront ajoutés au moment de #114.B/C si nécessaire.

### 4.4 Rationale dans `cooptation_voted`

**Question :** le payload ne contient pas le `rationale` (le motif d'un vote contre). Pour l'afficher dans le mail aux autres admins (= transparence Q1), il faut soit :
- **A.** Charger depuis DB dans le handler (SELECT rationale FROM `network_administrator_cooptation_votes`)
- **B.** Modifier `fn_network_admin_vote_cooptation` pour inclure `rationale` dans payload (avec respect disclose_identity)
- **C.** Ne pas afficher le rationale dans cooptation_voted, seulement dans `cooptation_rejected` (qui devra alors charger DB ou avoir un payload enrichi)

**Décision proposée :** **Option C** pour ce sous-paquet (minimaliste). Le rationale (qui peut être lourd politiquement) sera traité quand on implémentera `cooptation_rejected` (#114.B). Pour `voted`, on dit juste "un admin a voté", sans détails.

---

## 5. Clés i18n à ajouter

Selon les décisions ci-dessus (option C minimaliste partout) :

### 5.1 Ajout obligatoire

```json
"l.deadline": {
  "pt-BR": "Prazo para votar",
  "fr": "Date limite pour voter",
  "es": "Plazo para votar",
  "en": "Voting deadline",
  "it": "Termine per votare",
  "de": "Abstimmungsfrist"
}
```

**1 clé × 6 locales = 6 entrées.**

### 5.2 Ajout reporté à #114.B/C

Aucune autre clé i18n nécessaire pour #114.A.

Quand on implémentera `cooptation_rejected` (#114.B), il faudra :
- `network.vote.favorable / opposed / abstain` × 6 locales
- `l.voter` × 6 locales (peut-être)

---

## 6. Plan d'implémentation #114.A

### Phase 1 — i18n : ajouter `l.deadline` (5 min)

Script PowerShell qui ajoute la clé × 6 locales dans `_shared/i18n/mail-strings.ts` (= fichier TS, pas JSON). Test deno check + JSON-equivalent.

### Phase 2 — Création `_shared/domain/network.ts` (45 min)

Calque structurel sur `team.ts` (mais sans library_id, ctx neutre) :

```typescript
// Helpers privés
async function markOutboxSent(outboxId)
async function markOutboxFailed(outboxId, errorMsg)
async function loadProfile(userId)
async function loadActiveNetworkAdmins()
function displayName(p)
function resolveLocale(p)
function cooptationProposalUrl(proposalId)

// Handler principal (export)
export async function handleNetworkEvent(recordId)
  → Lit team_notification_outbox(recordId)
  → Dispatch interne :
    if event === "network.cooptation_proposed" → handleCooptationProposed(payload)
    if event === "network.cooptation_voted"    → handleCooptationVoted(payload)
    else → markOutboxFailed("unhandled_event"), return { ignored }

// Handlers événementiels
async function handleCooptationProposed(payload)
  → recipients = loadActiveNetworkAdmins() - [proposed_by]
  → ctx = null (neutre, subject "[Rede]")
  → Pour chaque destinataire (locale individuelle) :
    - subject = tMail(locale, "network.cooptation_proposed.sub", { proposedName })
    - greeting = greeting(locale, r.first_name)
    - intro = tMail(locale, "network.cooptation_proposed.intro", { proposerName, proposedName })
    - details : [
        { label: tMail(locale, "network.cooptation_proposed.motivation_label"), value: motivation_preview },
        { label: label(locale, "deadline"), value: formatDateLocale(expires_at, locale) }
      ]
    - actionBox : { kind: "action", label: cta, url: proposalUrl }
    - safeSendEmail(...)
  → return { recipients_count, results }

async function handleCooptationVoted(payload)
  → recipients = loadActiveNetworkAdmins() - [voter_user_id, proposed_user_id]
  → ctx = null (neutre)
  → Pour chaque destinataire :
    - subject = tMail(locale, "network.cooptation_voted.sub", { proposedName })
    - greeting = greeting(locale, r.first_name)
    - intro = tMail(locale, "network.cooptation_voted.intro", { proposedName })
    - details : [] (minimaliste, voir § 4.3)
    - PAS d'actionBox (l'intro indique déjà l'action)
    - safeSendEmail(...)
  → return { recipients_count, results }
```

### Phase 3 — Routing dans `_shared/core/dispatch.ts` (1 min)

Ajouter UNE ligne en haut de dispatch.ts :

```typescript
import { handleNetworkEvent } from "../domain/network.ts";

// Au début du dispatch, juste après team :
if (event.startsWith("network.")) return await handleNetworkEvent(recordId);
```

### Phase 4 — `deno check` strict (3 min)

```powershell
deno check supabase/functions/notify-event/index.ts
```

Exit 0 attendu. Si TS errors, fixer typings (cast `as Record<string, unknown>` si besoin).

### Phase 5 — Deploy (3 min)

```powershell
supabase functions deploy notify-event --no-verify-jwt --project-ref uflwmikiyjfnikiphtcp
```

### Phase 6 — Test scénario cooptation (15 min)

⚠️ **Problème** : aujourd'hui Xavier est seul admin réseau actif. Le quorum minimum de 3 n'est pas atteint. Donc en théorie une proposition de cooptation devrait être bloquée par la garde "quorum < 3".

**À vérifier en SQL** : la fonction `fn_network_admin_propose_cooptation` a-t-elle un check de quorum ? D'après le code lu (§ 2.1), **non** : les gardes 1 à 6 ne checkent pas le quorum. Donc on peut tester.

Stratégie de test :
1. Créer un user fictif test (ou utiliser Lívia) comme target
2. SQL : `SELECT api.fn_network_admin_propose_cooptation('<livia_uuid>', 'Test cooptation paquet 114A — motivation de test plus de 20 chars')`
3. **Attendre** : 1 mail à Xavier (lui-même proposant, NON destinataire car exclu) → 0 mail. Pas concluant.

**Stratégie alternative** : créer un 2ème admin de test temporaire pour avoir 2 admins actifs.

```sql
-- Promouvoir Lívia comme admin réseau temporairement
INSERT INTO network_administrators (user_id, status, coopted_at)
VALUES ('366cdc4e-10e0-44ad-8554-a444bcf9607a', 'active', now());

-- Maintenant Xavier (proposeur) propose un 3e user (target fictif)
-- → mail attendu à Lívia (seule autre admin active, hors proposeur)

-- Cleanup après test :
DELETE FROM network_administrators 
WHERE user_id = '366cdc4e-10e0-44ad-8554-a444bcf9607a' 
  AND status = 'active';
```

⚠️ Cela contredit la doctrine "Lívia n'est pas admin réseau". Acceptable temporairement pour test, à nettoyer immédiatement après.

### Phase 7 — Commit + push (3 min)

```
paquet 114.A : routing notify-event events network.cooptation_proposed + voted

- Création _shared/domain/network.ts (handler handleNetworkEvent)
- Ajout route network.* dans dispatch.ts (= une ligne)
- Ajout clé i18n l.deadline × 6 locales dans mail-strings.ts
- Doctrine v0.3 Q1 : target non notifié à proposed/voted

Reste à implémenter (sous-paquets B/C) :
- network.cooptation_rejected, _completed, _reminder
- network.collective_removal_* (5 events)
```

---

## 7. Décisions à confirmer

Avant de coder, valider ces 4 points :

1. **§ 4.2 ctx neutre** ([Rede] dans subject, pas de branding biblio) — OUI/NON
2. **§ 4.3 minimaliste pour `voted`** (juste intro, pas de détails type vote / voter / rationale) — OUI/NON
3. **§ 4.4 rationale absent dans #114.A** (reporté à `rejected` dans #114.B) — OUI/NON
4. **§ Phase 6 test** : créer Lívia admin temporaire pour tester — OUI / je préfère autre stratégie / on skip le test

---

## 8. Estimation totale révisée

- Phase 1 : i18n l.deadline → 5 min
- Phase 2 : network.ts → 45 min
- Phase 3 : dispatch.ts → 1 min
- Phase 4-5 : check + deploy → 6 min
- Phase 6 : test → 15 min
- Phase 7 : commit/push → 3 min

**Total : ~1h15 sans imprévu, 2h avec.**
