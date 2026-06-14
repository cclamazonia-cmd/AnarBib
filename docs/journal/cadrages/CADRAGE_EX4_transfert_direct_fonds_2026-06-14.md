# CADRAGE — EX-4 : Transfert direct fédéré d'un lot de fonds (mode a)

| | |
|---|---|
| **Genre** | cadrage (framing — non normatif tant que non ratifié au REGISTRE) |
| **Date** | 14 juin 2026 |
| **Statut** | 🟢 v0.2 — **modèle VALIDÉ (Xavier 14/06)** : dépôt semi-auto gaté `mutualisation` (le droit suffit, pas d'accusé préalable — D1 reco retenue) + **EF sœur `deposit-fonds-direct`** (D2). Dépend d'EX-3 (réutilise sa réception) → à coder après. D3/D4 : reco retenues par défaut. |
| **Chantier** | Importações/Exportações — transfert direct (P1.a), niveau 2 |
| **Réfère à** | `CADRAGE_export_fonds_numeriques_2026-06-12.md` (P1.a, P4 « dépôt semi-auto en ingest ») ; `CADRAGE_EX3_reception_fonds_2026-06-14.md` (la réception est mutualisée) ; `fn_partnership_has_active_right` ; table `fonds_export_runs` ; pipeline `ingest`. |

## 1. Le reframing décisif — ce n'est PAS « cross-projet »
Le cadrage initial qualifiait EX-4 d'« inconnue technique : storage cross-projet ». **C'est une
fausse piste.** AnarBib est **mono-projet multi-tenant** : toutes les biblioteca fédérées vivent dans
**une seule** base / un seul projet Supabase (`uflwmikiyjfnikiphtcp`), les biblios sont des **lignes**
`public.libraries`, le cloisonnement est **RLS par `library_id`**, et `fn_partnership_has_active_right
(lib_a, lib_b, right)` interroge **deux biblios de la même base**. Donc :

> **EX-4 = copie storage INTRA-projet (service_role) + création de lignes `ingest` pour le
> `library_id` de la réceptrice.** Pas de fédération de storage entre projets, pas d'API cross-cloud.

C'est un ordre de grandeur plus simple que ce que le mot « fédéré » laissait craindre.

## 2. Le schéma a déjà anticipé ce mode (signaux)
- `public.fonds_export_runs` : `mode IN ('zip','direct')`, `target_kind IN ('download','companheira')`,
  `target_library_id REFERENCES libraries` — **les colonnes du mode direct existent déjà**.
- L'EF `export-fonds-bundle` **accepte déjà** `target_library_id` dans son body (aujourd'hui : sert
  juste à taguer le run `target_kind='companheira'`).
- `ingest.partner_catalog_sources` : `source_kind` inclut **`'partner_deposit'`** et `relation_status`
  inclut **`'mutualizacao_autorizada'`** — la voie « dépôt mutualisé » est **déjà prévue** côté staging.
- `fn_partnership_has_active_right(..., 'mutualisation')` : le gate P2 est **prêt** (cf. ILL réutilise
  le même helper pour `digital_share`).

## 3. Modèle proposé (miroir de l'export, livraison directe)
1. **Déclenchement** (source) : un·e coordenador de la biblio source lance un **run d'export `mode=direct`**
   vers une **companheira** (`target_library_id`), gaté `fn_partnership_has_active_right(source, cible,
   'mutualisation')` + gate coordenador (IMP-14, déjà dans `fn_export_fonds_records`).
2. **Sélection** : `fn_export_fonds_records` (EX-1) — inchangé (notices + assets `public_domain_confirmed`).
3. **Livraison directe** (au lieu du ZIP) : une EF (extension `mode=direct` de `export-fonds-bundle`,
   **ou** EF sœur `deposit-fonds-direct`) en service_role :
   - **copie** chaque fichier `digital_assets` (bucket→`partner-catalog-deposits`, **même projet**,
     `storage.copy`/download+upload) sous un chemin scoping la réceptrice ;
   - **crée le run d'import** côté réceptrice : `partner_catalog_sources` (source `partner_deposit` /
     `mutualizacao_autorizada` représentant la donatrice) + `partner_catalog_import_runs` +
     `staging_rows` à partir des notices du manifeste + **matching** (réutilise `fn_match_*`) ;
   - laisse le lot en **revue** (`ready_for_review`) chez la réceptrice = **dépôt semi-auto** (P4) :
     elle promeut les drafts + attache les fichiers reçus quand elle veut.
4. **Réception** = **exactement la plomberie d'EX-3** (staging + fichiers déposés + création d'asset).
   ⇒ **EX-4 DÉPEND d'EX-3** : il faut d'abord trancher/livrer la réception (volet fichiers) en EX-3,
   puis EX-4 = « la même réception, mais alimentée par un push serveur au lieu d'un upload ZIP manuel ».

## 4. Décisions à trancher (Xavier)
- **D1 — Consentement.** Le droit `mutualisation` actif suffit-il à **auto-déposer** chez la réceptrice
  (dépôt arrive en `ready_for_review`, jamais publié sans sa revue) — **ou** faut-il un **accusé /
  acceptation** préalable de la réceptrice (miroir ILL `demande→accepte`) avant la copie des fichiers ?
  *(Reco : le droit `mutualisation` suffit pour DÉPOSER en staging ; rien n'est publié sans la revue de
  la réceptrice → consentement déjà encapsulé par P4.)*
- **D2 — EF : extension ou sœur ?** Ajouter `mode=direct` à `export-fonds-bundle` (cohésion) **ou** EF
  dédiée `deposit-fonds-direct` (isolation ; l'export ZIP reste pur). *(Reco : EF sœur — responsabilités
  distinctes, storage service_role + écriture ingest cross-tenant = surface sensible à isoler.)*
- **D3 — Notification.** Prévenir la réceptrice (système mail maison, `from @notifications.anarbib.org`)
  qu'un dépôt mutualisé l'attend en file de revue ? *(Reco : oui, non bloquant, miroir des notifs PEB.)*
- **D4 — Volumétrie.** Même borne que le ZIP (80 Mo/150 fichiers) ou asynchrone d'emblée (la copie
  intra-projet est moins coûteuse que le ZIP en mémoire) ? *(Reco : borne identique pour le MVP.)*

## 5. Effort / séquencement
- **Dépend d'EX-3** (réception fichiers). À construire **après** EX-3.
- **Effort** : moyen une fois EX-3 fait (copie storage intra-projet + écriture ingest pour autre
  `library_id` + gate `mutualisation` + run `mode=direct`). **Risque** : moyen (écriture ingest
  cross-tenant en service_role → bien scoper le `library_id` cible et la RLS).
- **Doctrine** : REGISTRE §17 (`IMP-16..` bulk export — y inscrire ZIP + direct), `spec-importacoes-
  exportacoes` §13.
