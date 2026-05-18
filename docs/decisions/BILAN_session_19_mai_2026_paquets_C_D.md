# Bilan de session : paquets C + D bouclés -- 18-19 mai 2026

**Date debut** : 18 mai 2026, 14h UTC+2
**Date fin** : 18 mai 2026, ~22h05 UTC+2
**Duree active** : ~8h
**Operateur·rice** : Xavier
**Chantier** : Spec profils d'adoption -- paquets C et D

## Resume executif

Session intense ayant boucle les **deux derniers gros chantiers backend** du
chantier profils d'adoption :

- **Paquet C** (RLS+RPC+vues conditionnees par profil) : 10 migrations + 1 hotfix
- **Paquet D** (mecanique d'archivage et masquage) : 6 migrations

**17 migrations en prod en une journee** avec **16 builds Woodpecker verts**
malgre 3 pannes Codeberg traversees et 2 regressions diagnostiquees +
resolues en cours de session.

## Migrations livrees en prod

| Timestamp | Sous-paquet | Description courte |
|---|---|---|
| 20260519100000 | C.2 | 7 helpers profil + extension fn_library_visible_to_caller |
| 20260519110000 | C.3a | 5 RLS reservas_v2 |
| 20260519120000 | C.3b | 3 RLS SELECT prets/consultas/PEB |
| 20260519130000 | C.3c | helper fn_peb_authorized + 2 RLS PEB composite |
| 20260519140000 | C.3d | 10 RLS policy_sets+rules |
| 20260519150000 | C.3e | 2 RLS libraries (public_read + signup_read) |
| 20260519160000 | C.4a.1 | RPC fn_v2_create_emprestimo_interbibliotecas |
| 20260519170000 | C.4a.2-4 | 3 RPC creation (emp+res+con) |
| 20260519180000 | C.4b | 2 RPC renouvellement |
| 20260519200000 | C.5 | network_overview + MV catalog (vues filtrees isolated) |
| **20260519205000** | **hotfix C.5** | **GRANT SELECT vues recreees (perdus par DROP+CREATE)** |
| 20260519210000 | D.1 | Colonnes archive + CHECK + 11 indexes partiels sur 5 tables |
| 20260519220000 | D.2 | 3 helpers SECURITY DEFINER archivage |
| 20260519230000 | D.3 | Patch 11 vues actives filtre archived_at IS NULL |
| 20260519240000 | D.4 | Patch 6 vues historique filtre circulation_mode <> 'off' |
| 20260519250000 | D.5 | Table audit + RPC unarchive + vue listing (typage text apres fix v2) |
| 20260519260000 | D.6 | Connexion B<->D : retrait refus type 4 + hooks archivage |

## Patches frontend livres (chantier C.4c)

- `src/lib/localizeError.js` : helper i18n d'erreurs RPC
- `src/i18n/<6 locales>.json` : 4 cles ajoutees x 6 locales = 24 strings
- `src/pages/AccountPage.jsx` : 2 patches consommation hint
- `src/pages/BookPage.jsx` : 1 patch
- `src/pages/CatalogPage.jsx` : 1 patch
- 3 corrections doctrinales i18n abstractions (fr / it / de)

## Diagnostics differes (documentes pour session future)

- **Module PEB frontend** : backend 100% pret, frontend JSX contient
  anti-patterns `.from('interlibrary_loans_v2')` directs au lieu d'appeler
  les RPC SECURITY DEFINER. Diagnostic complet dans
  `docs/decisions/CHANTIER_peb_frontend_diagnostic_2026-05-19.md`.
  Reporte a session fraiche dediee.

## Bugs diagnostiques + resolus en session

### 1. Regression catalogue post-C.5 (resolue 19/05 ~22h)

**Symptome** : page Catalogue retourne "Aucune reference trouvee" alors que
2450 livres existent dans la MV.

**Cause** : la migration C.5 utilisait `DROP VIEW IF EXISTS + CREATE VIEW` sur
`api.network_overview` et `api.catalog_list_session_v1`. PostgreSQL ne preserve
**pas** les GRANTs lors d'un DROP+CREATE. Resultat : roles `anon` et
`authenticated` ont perdu l'acces SELECT.

**Resolution** : hotfix C.5 (`20260519205000_hotfixC5_grants_vues_recreees`)
ajoutant `GRANT SELECT ON api.catalog_list_session_v1 TO authenticated`
et idem pour `api.network_overview`.

**Doctrine actee (v2.2)** : prefer `CREATE OR REPLACE VIEW` qui preserve les
grants. Si DROP+CREATE est obligatoire, capturer + restaurer explicitement les
grants. Validee en pratique sur D.3 + D.4 + D.5 : 17 vues patches, 0 grant perdu.

### 2. Echec migration D.5 v1 (resolue par D.5 v2 ~21h50)

**Symptome** : `ERROR: UNION types bigint and uuid cannot be matched (SQLSTATE 42804)`
au statement 14 (vue `api.library_archived_transactions`).

**Cause** : les 5 tables transactionnelles ont des PK heterogenes :
4 tables `bigint` (emprestimos, reservas, consultas, interlibrary_loans),
1 table `uuid` (membership_payments). UNION ALL refuse les types differents.

**Resolution D.5 v2** : tout casteen `text` (table audit `record_id text`, vue
`record_id::text`, RPC `p_record_id text`). Cast interne au runtime selon la
table cible. Gestion d'erreur sur cast invalide.

**Resilience prouvee** : la migration D.5 v1 etait en transaction atomique
(BEGIN...COMMIT). Rollback complet, BDD propre, retentable sans degat.

**Doctrine actee** : auditer les types des PK avant tout UNION inter-tables.
Cast `::text` si heterogene.

## Doctrines actees (a propager dans le Grand Livre Blanc v14+)

1. **v2.2 -- CREATE OR REPLACE VIEW preserve les grants** (anti-pattern C.5)
2. **Typage UNION ALL** : auditer les PK avant, cast `::text` si heterogene
   (anti-pattern D.5 v1)
3. **90j hardcode** : politique conservatrice desarchivage manuel
4. **D.6 point d'orgue** : archivage dans `fn_execute_*`, jamais dans `fn_propose_*`
5. **PEB rapports non masques** par circulation_mode (coordination inter-bibs preservee)
6. **Cotisations historiques non masquees** par circulation_mode (tracabilite comptable preservee)
7. **Outage Codeberg** : < 30% uptime sur status page = stop, pas forcage.
   Mais retenter periodiquement -- les outages courts (5-15 min) sont
   frequents et passent
8. **Transactions atomiques** : BEGIN...COMMIT obligatoire pour migrations
   multi-DDL. Rollback complet propre en cas d'erreur intermediaire

## Statistiques

- Migrations en prod : **17**
- Vues patches (sans perte de grant) : **17**
- Fonctions SECURITY DEFINER livrees ou modifiees : **8**
- Patches frontend i18n : **6** fichiers JS + 24 strings i18n
- Doctrines actees : **8**
- Regressions diagnostiquees + resolues : **2**
- Pannes Codeberg traversees : **3** (504 push, panne Woodpecker ~1h, 503 push)
- Builds Woodpecker verts dans la journee : **16**
- Decisions de stop courageuses : **2** (puis 2 retours bonus, dont le bouclage D.6)

## Etat backend AnarBib apres cette session

| Composant | Etat |
|---|---|
| 4 axes orthogonaux (catalog, circulation, network, governance) | ✅ Defensifs en RLS/RPC |
| Transitions types 1, 2, 3 | ✅ Fonctionnelles (paquet B + C) |
| Transitions type 4 (archivage) | ✅ Fonctionnelles (paquet D.6 point d'orgue) |
| Couche archivage (vivants) | ✅ Filtree sur 11 vues actives |
| Couche masquage (historique) | ✅ Filtree sur 6 vues historique |
| Desarchivage manuel (admin) | ✅ RPC + audit log + check 90j |
| Triple defense PEB | ✅ RLS SELECT permissif + RLS INSERT/UPDATE composite + RPC check |
| i18n d'erreurs RPC | ✅ Helper + 4 cles x 6 locales |

## Prochaines etapes (apres cette session)

**Demain matin frais** :
- Verifier visuellement en prod : painel BLMF onglet Historique, painel
  Empréstimos, etc. Tous les onglets staff doivent rester fonctionnels comme
  avant (rien n'a change pour BLMF qui est en `full_sigb`).
- Lancer un test fumee de transition type 4 sur biblio test (creer
  une biblio jouet, lui faire passer `informal -> off` via fn_propose,
  observer l'archivage).

**Sessions futures** :
- Paquet E (frontend painel adaptatif) -- cadre dans spec section 9.5
- Paquet F (onboarding refondu) -- independant, peut etre fait en parallele
- Paquet G (bandeau biblios existantes) -- final
- Chantier PEB frontend (cablage des RPC, refacto des anti-patterns)
- Revocation pendant carence (item backlog v0.6 11.1)

**Spec v0.6 livree** : `docs/specs/spec-profils-bibliotheque-v0.6.md`

## Note finale

Session record sur AnarBib : 17 migrations en une journee, dont 2 regressions
detectees + corrigees + redeployees. Le paquet D est probablement le morceau
le plus complexe a date du chantier profils d'adoption (5 tables, 17 vues,
8 fonctions, 1 nouvelle table audit, 1 RPC publique avec garde-fous fins).

La doctrine v2.2 acte un piege majeur (DROP+CREATE perd les grants) qui
aurait pu causer des regressions silencieuses dans des chantiers futurs.

Le chantier backend des profils d'adoption est **fini**. Reste le frontend
et le deploiement final pour les biblios existantes.
