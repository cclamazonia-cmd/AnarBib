# État consolidé « prêt à présenter au monde » — 2026-07-03

> Boussole à jour, vérifiée **en prod + repo** au fil de la session du 03/07/2026.
> Remplace le portrait périmé du backlog v33 (17/06) pour la question « que reste-t-il
> avant le lancement public ? ». Convention inchangée : **REGISTRE > spec > backlog**.

## 0. Verdict

AnarBib est **fonctionnellement prêt** : il ne reste quasi plus de code à écrire. Le
chemin critique est désormais **opérationnel/humain**, pas technique — obtenir l'accord
d'hébergement (Herbes Folles), migrer, et éprouver l'UX en usage réel.

## 1. Soldé / vérifié cette session (03/07)

- **#BG2 sauvegardes** — ✅ validé opérationnellement (confirmé par Xavier).
- **#4 — 5 livrables sandbox** — ✅ **déjà intégrés** (`cd5c7d967`) : multi-mots,
  fiche auteur `variant_forms`, i18n-sujets (47/47 ×10 locales), enrich-AUT (25
  auteur·rices). (1b) accents+pertinence **superseded** par `api.catalog_search_ids_v1`.
- **#5 — perf matching import** — ✅ volets A+B+C confirmés (index scans ~0,08 ms) ;
  band-aid `statement_timeout=0` remplacé par borne **120 s** (`20260703182035`).
- **#7 — cotisations** — #25 (cron 7/1/0 j) ✅, #33 (tests blocage en CI) ✅.
  **#36 CIRA** : barème posé (30 €/an, année civile, requis) `20260703204511` ;
  enforcement laissé **éteint réseau-wide** (`membership_enabled=false` partout) →
  activation = acte conscient du coordenador (case « Activer le système de cotisation »
  **déjà câblée**, écriture directe RLS `libraries_staff_update`).
- **Hygiène base** — `auth_rls_initplan` (31 policies) emballées en `(select auth.*())`
  (`20260703203953`) ; policies **deny explicites** sur 15 tables PII (`20260703125440`).
- **Feature** — bouton **retirer/archiver un règlement périmé** (archivage réversible ;
  hard-delete réservé aux brouillons ; RPC gardé `20260703213318` + front + i18n ×10).
- **Outillage** — `.env.example` complet (secrets EF + VITE_ + checklist DNS).
- **Smoke-test backend des 4 modules** (IMPORT/PARTNER/PEB/ILL) — ✅ **44/44 RPC**
  existent et exécutables par `authenticated` ; données de référence présentes.
- **Migration VPS** — arbitrage formalisé (`DECISION_arbitrage_migration_vps_2026-07-03`) :
  stratégie **A** (Supabase self-hosted), **auth.users** migrée + JWT rotaté, Storage
  local. **D2 (mail) / D3 (front) rouverts** → on veut consolider chez HF (Resend
  plafonne à 100 mails/j + USA ; Codeberg instable). **Message HF envoyé.**

## 2. Reste avant lancement — par criticité

### 🔴 Chemin critique (bloquants, dépendent d'externe/humain)
1. **Réponse Herbes Folles** (message envoyé) : Q1 = *font-ils de l'hébergement
   Docker (VM/shell), au-delà du stockage de sauvegarde ?* → décide **A chez HF vs VPS
   ailleurs**. Puis mail (relais `@anarbib.org` ?) et front statique.
2. **Exécution de la migration** une fois l'hébergement confirmé : transformer le mémo
   + la décision en **runbook daté** (dump rôles+auth+storage+extensions → restore
   PG17 → fichiers Storage → EF + secrets → `pg_cron` URLs corrigées → repointage front
   → DNS en dernier, réversible).
3. **Validation terrain UX** des 4 modules IMPORT/PARTNER/PEB/ILL (backend vert
   confirmé ; reste le parcours réel coordenador + lectrice ; protocole prêt).

### 🟡 À faire, non bloquant immédiat
4. **Secrets & DNS au cutover** — outillés par `.env.example` (RESEND/relais, DKIM/SPF/
   DMARC, webhook secrets, Turnstile, ACOUSTID, Nominatim…).
5. **#36 CIRA** — activation par Thierry (coordenador) quand il le décide (case
   existante) + saisir son paiement si on veut lever le gate.
6. **Données** (travail humain, hors code) : indexation par sujet (~28 % du public,
   Baqueiro) ; supprimer le doublon-sujet `pierre-joseph-proudhon` ; relire en natif
   les termes rares du thésaurus (de/nl/eo/el) **et** les libellés `el/eo` récents
   (bouton règlement).

### ⚪ Pré-montée-en-charge / différé (non bloquant)
7. Hygiène perf : `multiple_permissive_policies` (95, au cas par cas) ; `unused_index`
   (251, à décider sous charge réelle) ; FK non indexées (21, majoritairement vers des
   tables de réf de 0-6 lignes → écartées à dessein).
8. i18n rollout-10 + charte inclusive.
9. Fonctionnel différé assumé : #OPAC5 tags contributifs (décision communauté) ;
   #OPAC11 RSS (anti-tracking) ; #MOBILE P3 permanence / P5 push.

## 3. Rappels de méthode (pour ne pas se refaire piéger)

- **Migrations & EF : fichier + push uniquement.** JAMAIS `apply_migration` /
  `deploy_edge_function` via MCP (cause de la course CI du 03/07 : run d'un commit
  antérieur qui casse car le distant a déjà une migration plus récente). Cf. doctrine
  `anarbib-migrations-mirror-to-repo`. MCP `execute_sql` = lecture/inspection.
- **Worktree partagé** : stager uniquement ses propres fichiers.
- **Enforcement cotisation** : gouverné par `libraries.membership_enabled` (pas par la
  seule présence d'une règle) ; `fn_is_loan_blocked_by_dues` court-circuite si `false`.
