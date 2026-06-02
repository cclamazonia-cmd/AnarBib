---
Genre : référence
Statut : 🟢 référence (chantier #NOTIFY-prorrogacao livré 30/05)
Décisions : incarne NPRO-D1..D7 ; cite DOC-I18N-1, DOC-DEPLOY-1
Supersédé par : —
---

# Spec — Notification de prorrogação granulaire

**Fichier :** `docs/specs/spec-notify-prorrogacao-granulaire.md`
**Version :** 0.1 (cadrage) — 2026-05-29
**Origine :** constat QA Phase 5 (chantier granularité). Le backend/UI granulaires sont en prod (1a/1b/2/3a + front conta/painel), mais la couche notification est restée header-centrée et aveugle à la granularité.
**Score / priorité :** lié à `#NOTIFY-Painel-acts`. À inscrire backlog v18.

---

## 1. Constat (diagnostiqué, preuves à l'appui)

Deux défauts confirmés par la trace `net._http_response` et la lecture du code :

1. **Émission « une fois par lot ».** Le trigger `trg_notify_emprestimo_prorrogacao` (AFTER UPDATE OF `renewals_used` ON `emprestimos_v2`) dispatche quand `NEW.renewals_used > OLD.renewals_used`. Or `emprestimos_v2.renewals_used = MAX(items ouverts)` (trigger `trg_sync_header_renewals`, paquet 1a). Donc :
   - 1er item d'un lot renouvelé → header 0→1 → **un** dispatch ;
   - items suivants du même lot → header reste à 1 → `1 > 1` faux → **silence**.
   - Preuve : 4 renouvellements sur #50 → **1 seul** `emprestimo_v2_prorrogado` (record_id 50) dans pg_net.

2. **Mail daté sur l'ancienne échéance.** Dans `_shared/domain/emprestimos.ts`, branche `emprestimo_v2_prorrogado` (l.63 mail lecteur, l.189 mail admin) :
   - `da = String(emprestimo.due_at)` (l.26) = échéance **header**, jamais mise à jour par le renouvellement → « Nova data de devolução » affiche l'ancienne date.
   - `ea = String(emprestimo.extended_at)` (l.28) = un **timestamp** (instant du renouvellement), pas une date d'échéance.
   - La bonne source — `items[].extended_until` — est **déjà chargée** par `getEmprestimoV2Bundle` (cf. `_shared/data/emprestimos.ts`, le select inclut `extended_until`) mais **non utilisée** dans cette branche.
   - L'EF ne reçoit que `record_id` (le header) : il ne peut pas cibler l'item renouvelé.

**Cause profonde :** le modèle d'événement est header-centré (`record_id` = emprunt), conçu avant la granularité par item.

---

## 2. Comportement cible

- **Une action de renouvellement = une notification**, qu'elle porte 1 item ou N (« tout renouveler »).
  - Renouvellement par item (lecteur `renew_my_loan_item`, staff `extend_loan_item_as_library`) → 1 mail nommant **l'item** et sa **nouvelle échéance**.
  - Renouvellement de lot (`renew_my_loan`, `extend_loan_as_library`) → 1 mail listant **les items effectivement renouvelés** et leur(s) échéance(s).
  - Renouveler un 2e item d'un lot après le 1er → un **second** mail (plus de silence).
- **Échéance affichée = `extended_until`** des items renouvelés (source de vérité), jamais `due_at` header ni `extended_at`.
- Mail lecteur en `preferred_language` ; copie admin en `pt-BR` (`libLocale`). Inchangé.
- Aucun item ignoré (`skipped`) ne génère de mail (ni lecteur ni biblio).

---

## 3. Décisions (reco + points ouverts)

| # | Décision | Reco | Alternative écartée |
|---|----------|------|----------------------|
| D1 | **Lieu d'émission** | Depuis `fn_v2_extend_core` (il connaît `v_renewed[]` = `{line_no,new_due_date}` et couvre **tous** les wrappers item/lot × lecteur/staff de façon uniforme). | Trigger sur `emprestimo_itens_v2` : possible, mais l'émission métier est plus claire dans le cœur. |
| D2 | **Granularité de l'événement** | **Un** événement par action, portant `line_nos[]` des items renouvelés. | Un événement **par item** → 4 mails pour un « tout renouveler » = spam. Rejeté. |
| D3 | **Payload** | `{ event:'emprestimo_v2_prorrogado', record_id:<emprestimo_id>, line_nos:[…] }`. L'EF relit `extended_until` en DB (pas de date dans le payload → zéro divergence payload/DB). | Passer les dates dans le payload → risque de divergence. Rejeté. |
| D4 | **Retrait du trigger header** | `DROP TRIGGER trg_notify_emprestimo_prorrogacao` + `DROP FUNCTION` associée (sinon double notification). | Garder le trigger + dédup côté EF → fragile. Rejeté. |
| D5 | **Texte `loan.renewed.once`** | Reformuler « par exemplaire/document » (le quota est désormais par item, pas par emprunt) × 8 locales dans `mail-strings.ts`. | Laisser « par emprunt » → faux sémantiquement. **✅ Acté : formulation « par exemplaire » livrée × 8 locales (chantier clos 30/05).** |
| D6 | **Dates divergentes dans un même mail** | Si tous les items renouvelés ont la même `extended_until` → une date (`loan.newDue`). Sinon → liste « titre — date » par item. | Date unique forcée → imprécis si divergence. |
| D7 | **Retour global d'un lot partiellement renouvelé** | **Hors périmètre.** Le mail de retour total liste les items rendus, ce qui est correct. | — |

---

## 4. Changements — Backend (migration)

Fichier : `supabase/migrations/<timestamp futur>_notify_prorrogacao_granulaire.sql` (timestamp postérieur, push, Woodpecker applique — **jamais** `apply_migration` MCP, **jamais** SQL Editor avant push).

1. **`CREATE OR REPLACE FUNCTION public.fn_v2_extend_core(...)`** — ajouter, juste avant le `RETURN` final et conditionné par `v_any_renewed`, l'émission :
   ```sql
   IF v_any_renewed THEN
     PERFORM public.fn_dispatch_circulation_notify_event(
       'emprestimo_v2_prorrogado',
       p_emprestimo_id,
       jsonb_build_object(
         'line_nos',
         (SELECT array_agg((e->>'line_no')::int)
            FROM jsonb_array_elements(v_renewed) e)
       )
     );
   END IF;
   ```
   - Conserver `SECURITY DEFINER` + `SET search_path` existants ; `CREATE OR REPLACE` préserve les GRANT. `fn_dispatch_circulation_notify_event` est en `public` (appel qualifié), elle pose son propre `search_path` (public, net, vault) et **n'échoue jamais** (EXCEPTION WHEN OTHERS → NULL) : l'émission est best-effort, le renouvellement reste atomique.
   - Ne PAS toucher la logique de renouvellement (prouvée par S1–S6).

2. **Retrait du trigger header :**
   ```sql
   DROP TRIGGER IF EXISTS trg_notify_emprestimo_prorrogacao ON public.emprestimos_v2;
   DROP FUNCTION IF EXISTS public.trg_notify_emprestimo_prorrogacao();
   ```
   (Vérifier d'abord qu'aucun autre objet ne dépend de la fonction.)

3. **DO-block de vérification** en fin de transaction (RAISE EXCEPTION = rollback) :
   ```sql
   DO $$
   BEGIN
     IF EXISTS (SELECT 1 FROM pg_trigger
                WHERE tgname = 'trg_notify_emprestimo_prorrogacao') THEN
       RAISE EXCEPTION 'trigger header prorrogacao non retiré';
     END IF;
   END $$;
   ```

> `trg_sync_header_renewals` (synchro `header.renewals_used = MAX`) **reste** : il sert l'affichage et la cohérence, il ne déclenche plus de notification (le trigger notif est retiré).

---

## 5. Changements — Edge Function (`notify-event`)

Fichier : `functions/_shared/domain/emprestimos.ts`, branche `emprestimo_v2_prorrogado`.

**Mail lecteur (l. ~63–90) :**
- Lire les items ciblés :
  ```ts
  const pln = normalizeLineNos(getPayloadValue(payload, "line_nos"));
  const ti = pln.length ? items.filter(i => pln.includes(i.line_no)) : oi; // fallback rétro-compat
  ```
- Titres : `joinTitles(ti.map(i => i.titulo || `[${i.bib_ref}]`))`.
- Nouvelle échéance depuis `extended_until` des items ciblés :
  ```ts
  const dues = [...new Set(ti.map(i => String(i.extended_until || i.due_at || "").trim()).filter(Boolean))];
  const newDue = dues.length === 1 ? dues[0] : dues.sort().at(-1); // unique, sinon la plus lointaine
  ```
- Remplacer dans `intro` et `detKeys` les usages de `da`/`ea` par `newDue` (et les titres ciblés). Si `dues.length > 1`, lister « titre — date » par item (D6).

**Mail admin (l. ~189–192) :** mêmes titres/dates ciblés ; reste `pt-BR`.

**Déploiement :** par **CLI** (`notify-event` ~150 Ko bundlé > limite MCP) :
```bash
supabase functions deploy notify-event --no-verify-jwt
```
(garder `--no-verify-jwt` : l'EF s'authentifie par `x-webhook-secret`).

**Ordre de déploiement recommandé :** EF **d'abord** (elle lit `line_nos` si présent, sinon retombe sur `oi` = comportement actuel), **puis** la migration (émission par item + retrait trigger). Évite toute fenêtre de double/mauvais mail.

---

## 6. i18n (dans `_shared/i18n/mail-strings.ts`, 8 locales par clé)

- Clés existantes réutilisées : `loan.renewed.sub`, `loan.renewed.intro`, `loan.newDue`, `loan.renewed.once`, `admin.renewalDone`, labels `items` / `newDueDate`.
- **D5** : reformuler `loan.renewed.once` (« par exemplaire » plutôt que « par emprunt ») × 8 locales — passage unique.
- Éventuelle nouvelle clé si D6 impose un rendu « titre — date » par item (à trancher).
- Conventions militantes : ces chaînes ne portent pas de terme genré personnel ; rien à adapter (point médian / Genderstern / formes triples non sollicités). *Nit repéré au passage : `es` « solo une vez » → « una vez » (le neutre argentin ne s'applique pas à ce compte féminin) — cleanup hors périmètre.*

---

## 7. Plan de QA (re-run Phase 5, volet notifications)

Données : rouvrir #50/#51 via `-- RESET`, ou utiliser #52.
1. Renouveler **un** item (lecteur) → **un** mail lecteur + copie admin, nommant **l'item** et `extended_until` (date correcte, p.ex. 13/07), pas l'ancienne.
2. Renouveler un **2e** item du même lot → **un second** mail (plus de silence). Vérifier 2 dispatches distincts dans `net._http_response`.
3. « Tout renouveler » sur un lot frais → **un** mail listant tous les items renouvelés + date(s).
4. Lot mixte (1 item échu) → mail ne listant que les items renouvelés ; aucun mail pour l'item ignoré.
5. Vérifier **absence de double mail** (trigger header retiré).
6. Contrôle pg_net : 1 dispatch par action, payload `line_nos` correct.

---

## 8. Risques & vigilance

- **Best-effort dispatch :** `fn_dispatch_circulation_notify_event` n'échoue jamais → un souci pg_net/secret ne casse pas le renouvellement (warning seulement). Comportement déjà en place.
- **Tous les chemins notifient désormais** (item/lot, lecteur/staff) via le cœur — c'est voulu, mais vérifier qu'aucun appelant interne de `fn_v2_extend_core` ne doit rester silencieux. (La conversion réserva→emprunt n'appelle pas le cœur d'extension.)
- **Transition de déploiement** : respecter l'ordre EF → migration (§5).

## 9. Dépendances & séquencement

- **#110 (Resend)** : la trace pg_net montre des ids de réponse de type Resend → le transport de `notify-event` semble **déjà** Resend. B est donc **fonctionnellement indépendant** de #110 (à confirmer).
- **#NOTIFY-Painel-acts** : même pattern (dispatch + handler EF + i18n mail) pour paiements/restrictions/gels. B en est le précurseur côté circulation.

## 10. Hors périmètre

- Refonte du mail de retour (total/partiel) — correct en l'état.
- Rappels d'échéance, autres familles de notifications.
- Migration Resend elle-même (#110).
