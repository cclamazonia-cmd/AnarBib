# PROMPT DE REPRISE — Export de fonds niveau 2 (EX-5/EX-3/EX-4) + déploiements EF
*(rédigé le 14/06/2026, fin d'une grosse session : OAI + ILL livrés, EX-1/EX-2 livrés)*

Tu reprends le chantier **Importações/Exportações — face Export, niveau 2 (export de fonds
en lot)** sur AnarBib (SIGB fédéré anarchiste). **Charge d'abord les mémoires** (elles portent
tout le contexte) : `oai-etre-source-chantier-parked.md` (état complet + reprise),
`resend-sender-domain.md`, `local-db-scratch-validation.md`, `wsl-repo-access.md`,
`codeberg-ci-status-check.md`, `multi-session-staging-protocol.md`.

## Accès repo (WSL-only)
- Repo : `~/anarbib` = `\\wsl$\Ubuntu-26.04\home\accattone\anarbib`. Fichiers via UNC (Read/Edit/Write).
  **Glob ne marche pas sur UNC** → Grep avec `path=\\wsl$\...` ou `wsl ... find`.
- Git/shell : `wsl -d Ubuntu-26.04 -- bash -lc "cd ~/anarbib && <cmd>"` (guillemets **doubles** dehors,
  **simples** dedans ; `$VAR`/`$()`/backticks mangés par PowerShell → pour le quoting tricky, **écrire
  un `.sh`** et `tr -d '\r' < f.sh > g.sh && bash g.sh`). Push : `git push codeberg main`.
- **Tu es SEUL sur le repo** (plus de contrainte multi-session ; `git add` nominatif reste une bonne habitude).

## DÉJÀ FAIT & LIVE — ne pas refaire
- **OAI « Être source »** (O1-O5) : gouvernance ouverture endpoint OAI-PMH (ascendant 1 admin /
  descendant vote 21j unanime tacite, scrutin secret), EF `oai-pmh-provider`, notif `notify-oai-opening`,
  onglet rede `OaiSourcePanel`. Commits `30bbbee9` + `080f54a3`. CI verte, déployé, **mail testé OK**.
- **ILL-digital ponctuel** (I1-I5) : tables `ill_digital_shares`+audit, RPC `fn_ill_*`, EF
  `read-ill-shared-asset` + `notify-digital-share`, frontend `LibraryDigitalSharesSection`
  (BibliotecaPage onglet `ill`), section hebdo. Commits `fa9f0ddd` + `4e0782ef`. Gaté `digital_share`.
- **Export de fonds** : **EX-1** RPC `fn_export_fonds_records(p_library_id, p_book_ids[])` +
  `fn_export_fonds_eligible_count(p_library_id)` (gate coordenador/admin, filtre
  `public_domain_confirmed` strict, renvoie notices forme serialize.ts + métadonnées fichiers).
  Commit `6e4a3d90`. **EX-2** table `fonds_export_runs` + EF `export-fonds-bundle` (ZIP : notices via
  `../export-catalog-lote/serialize.ts` + manifest.json + fichiers des buckets, borne 80 Mo/150 fichiers).
  Commit `417853b8`. Tout CI vert, migrations appliquées.

## ⚠️ ÉTAPE 0 — déployer 2 Edge Functions (la CI NE déploie PAS les EF)
Besoin d'un token CLI : dashboard → avatar → Access Tokens → `sbp_…`, puis
`export SUPABASE_ACCESS_TOKEN=sbp_…`. Ensuite :
```
cd ~/anarbib && supabase functions deploy export-fonds-bundle notify-weekly-report
```
(`export-fonds-bundle` = EX-2 ; `notify-weekly-report` = section hebdo « Partilhas digitais » de I5.)
Tester EX-2 : `curl -X POST .../functions/v1/export-fonds-bundle -H "Authorization: Bearer <jwt>" -d '{"library_id":"…","format":"json"}'` → doit renvoyer un ZIP.
**Resend** : tout `from` de mail doit être sur `@notifications.anarbib.org` (vérifié), jamais `@anarbib.org` (403).

## À FAIRE — finir le niveau 2
Cadrage + décisions : `docs/journal/cadrages/CADRAGE_export_fonds_numeriques_2026-06-12.md`
(P1 = 2 modes ZIP+direct ; P2 = droit `mutualisation` ; P3 = `public_domain_confirmed` strict ;
P4 = ZIP→ré-import manuel / direct→dépôt semi-auto).

### EX-5 — UI face Export (PRIORITAIRE : rend l'export utilisable par le staff)
- `src/pages/importacoes/ImportacoesPage.jsx`, bloc `sentido === 'export'` (panneaux lote/partilha/serFonte).
  Ajouter un panneau **« Exportação de fonds »** miroir de `handleExportLote` (qui fetch
  `export-catalog-lote` + télécharge le blob via Content-Disposition).
- Aperçu éligibles : `supabase.rpc('fn_export_fonds_eligible_count', { p_library_id: libraryId })`.
  Bouton « Télécharger le ZIP » → `fetch(import.meta.env.VITE_SUPABASE_URL + '/functions/v1/export-fonds-bundle',
  { method:'POST', headers:{Authorization: 'Bearer ' + (await supabase.auth.getSession()).data.session.access_token},
  body: JSON.stringify({ library_id, format }) })` → blob → download. `libraryId` via `useLibrary()`.
- **i18n** : clés `importacoes.export.fonds.*` ×10 locales (`ca,de,el,en,eo,es,fr,it,nl,pt-BR`).
  Modèle : le script `/tmp/digishare_i18n.cjs` (insertion textuelle + garde JSON). Respecter la **charte**
  (pt-BR triple `(o/a/e)`, etc.). Valider : `npx vitest run i18n.test.js` (parité) + `npm run build`.
- Commit + push + vérifier CI verte.

### EX-3 — Réception (miroir importação de arquivo)
- La companheira ré-importe le ZIP (manifest.json + files/) via le pipeline import **existant**
  (`ingest` → `book_drafts`). Étudier `fn_create_partner_catalog_import` / dispatch /
  `fn_bulk_create_book_drafts_from_run` + EF `process-partner-catalog-import`. Mapper le manifest →
  staging `ingest`, déposer les fichiers dans les buckets de la réceptrice.

### EX-4 — Transfert direct fédéré (mode a)
- storage→storage vers une companheira AnarBib (dépôt semi-auto en `ingest` staging chez elle),
  gaté droit `mutualisation`. **Inconnue technique** (storage cross-projet) → cadrer avant de coder.

## Méthodo / gotchas
- **Migrations** : horodatage UTC > max (`ls supabase/migrations | grep -E '^[0-9]' | sort | tail`).
  Valider sur **DB scratch** (port 55422, prélude stubs + `SET check_function_bodies=off` ; la DB locale
  n'a PAS le socle fondateur). La validation sémantique RÉELLE = le `db push` de la CI.
- **CI** : après push, `curl https://codeberg.org/api/v1/repos/anarbib/anarbib/commits/<sha>/status`
  (`.state` success/pending/failure + `.statuses[]` : `CI/CD / app` + `CI/CD / backend`), ~90 s.
- **Doctrine** : `spec-importacoes-exportacoes` §13 (Face Export complète), `spec-flux-partage-numerique`
  (v0.3 impl.), `spec-oai-provider-gouvernance`. REGISTRE §17 : inscrire `IMP-16..` à la réalisation du bulk.
- **Mail maison** : `tMail`/`renderEmail`/`safeSendEmail` (`supabase/functions/_shared/`), sender domaine
  vérifié + reply-to ; le rapport hebdo `notify-weekly-report` est en pt-BR **inline** (pas de mail-i18n).
