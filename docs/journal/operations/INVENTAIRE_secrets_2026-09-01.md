# Inventaire des identifiants — « Ficheiros diversos »

Scan du 2026-09-01 · 275 fichiers parcourus (md, txt, docx, ts, js, html, sql, env, template, zip)
**74 valeurs distinctes** repérées, **233 occurrences**.

Ce document ne contient aucune valeur : chaque secret est désigné par une empreinte
`#xxxxxx` (6 premiers caractères du SHA-256), sa longueur, et la liste de ses emplacements.
Deux lignes portant la même empreinte désignent la même valeur.

---

## 1. Comptes et services identifiés

| Service | Ce qui traîne en clair | Gravité |
|---|---|---|
| **Supabase** (projet `uflwmikiyjfnikiphtcp`) | clé **service_role** `#2bd50e` (219 c) | **critique** |
| Supabase (projet `asptfmokzykwzlshsncw`, hors compte actuel) | clé anon `#4d702f` | faible (legacy) |
| **PostgreSQL** | 5 URI de connexion distinctes, mot de passe inclus | **critique** |
| **Brevo** | 6 clés API `xkeysib-` + 2 clés SMTP `xsmtp-` | élevée |
| **OVH** | mot de passe Zimbra + **10 codes de récupération 2FA** | **critique** |
| **Cloudflare** | **8 codes de récupération 2FA** | **critique** |
| Webhooks Edge Functions | 8 secrets de 40 c + 1 `VAULT_SECRET` de 64 c | élevée |
| Partenaires (import catalogue) | `x-import-secret` `#56c145` (28 c) | moyenne |
| Comptes de test | 3 mots de passe | moyenne |
| WorldCat | `WSKEY` / `SECRET` présents mais valeurs de 4 à 7 c → à vérifier | à confirmer |

Le projet Supabase actif est **`uflwmikiyjfnikiphtcp` (« anarbib », sa-east-1)** : c'est le
seul du compte. `asptfmokzykwzlshsncw` est un projet antérieur dont la clé anon subsiste dans
`SQL AnarBib.txt` et le thème `anarbib-theme-20260319.zip`.

---

## 2. Le point critique : la clé service_role en clair

`#2bd50e` (`role=service_role`, `ref=uflwmikiyjfnikiphtcp`, expire 2036-03-17)

Cette clé contourne toutes les politiques RLS. Elle est présente dans :

- `SECRETS STAGING COMPLET.template:13`
- `anarbib-edge-deploy/functions.env:3`
- `anarbib-staging-rede secrets e credenciais.txt:21`
- `Zip/anarbib_edge_bundle_rewritten.zip!functions.env:13`

Le dernier emplacement est le plus inquiétant : un fichier `.env` complet **à l'intérieur d'une
archive zip**, c'est-à-dire dans un objet fait pour être déplacé, envoyé ou déposé quelque part.

---

## 3. Contradictions à trancher

Trois cas où le même nom de variable porte deux valeurs différentes. Il faut déterminer
laquelle est active avant de ranger quoi que ce soit.

### 3.1 `WEBHOOK_SECRET_NOTIFY_INTERNAL_TASK`

| Empreinte | Emplacements | Date |
|---|---|---|
| `#e239a7` | `SECRETS STAGING COMPLET.template:38`, `notify-internal-task.SECRETS.txt:1`, `process_internal_task_queue.env.example.txt:1`, `anarbib_edge_bundle_rewritten.zip!functions.env:38` | 2026-04-04 |
| `#5dbcca` | `WEBHOOK_STAGING.txt:5` | 2026-04-04 |

### 3.2 `BREVO_API_KEY_NOTIFY_INTERNAL_TASK`

| Empreinte | Type | Emplacements |
|---|---|---|
| `#d9784a` | clé SMTP `xsmtp-` (90 c) | `SECRETS STAGING COMPLET.template:28`, `notify-internal-task.SECRETS.txt:2` |
| `#cfed56` | clé API `xkeysib-` (89 c) | `process_internal_task_queue.env.example.txt:2` |

Deux valeurs **et** deux types de clé sous le même nom. Le code attend l'un ou l'autre, pas les deux.

### 3.3 Six clés Brevo pour un seul compte

`BREVO_API_KEY` `#7f2bb1`, `_STAGING` `#55ad7a` (et une autre `_STAGING` `#fc6af0` dans
`anarbib-staging-rede secrets e credenciais.txt:23`), `_NOTIFICATIONS` `#182051`,
`_NOTIFY_RESERVA` `#da00e3`, `_NOTIFY_INTERNAL_TASK` `#cfed56`.

Toutes partagent le même préfixe de compte : ce sont six sous-clés du même compte Brevo,
créées au fil des fonctions. Rien ne l'interdit, mais aucune n'est révocable
indépendamment sans savoir laquelle sert à quoi.

---

## 4. Bonne nouvelle : « Secrets perdus.docx » n'est plus perdu

Le fichier contient quatre valeurs orphelines. Deux sont ré-identifiées :

- ligne 3 → `#b982e2` = le `VAULT_SECRET` de `WEBHOOK_STAGING.txt:7`
- ligne 5 → `#e1cb76` = l'URI Postgres de `Récupérer le SQL du projet.txt:10`

Restent deux valeurs non rattachées : ligne 2 (`#337087`, 36 c, forme d'UUID) et
ligne 4 (`#ab2f2c`, 64 c, forme d'un second secret de coffre).

---

## 5. Faux positifs écartés

Les clés `anon` et `sb_publishable_` présentes dans les fichiers HTML du thème
(`criar-conta.html`, `painel.html`, `index.html`, `autor.html`) **ne sont pas des fuites** :
ces clés sont publiques par conception et protégées par les politiques RLS. Elles sont
listées ici pour mémoire, pas pour rotation.

Le scan a aussi remonté une soixantaine d'identifiants de code (`gotSecret`, `tokens`,
`webhookOk`, `surnameTokens`…) qui ne sont que des noms de variables JavaScript. Écartés.

---

## 6. Fichiers porteurs de secrets

À traiter en priorité, du plus au moins chargé :

1. `SECRETS STAGING COMPLET.template` — 15 secrets réels malgré l'extension `.template`
2. `anarbib-staging-rede secrets e credenciais.txt` — 8 secrets, dont service_role et URI Postgres
3. `WEBHOOK_STAGING.txt` — 7 secrets
4. `Zip/anarbib_edge_bundle_rewritten.zip` — contient `functions.env` complet
5. `anarbib-edge-deploy/functions.env` — service_role + anon
6. `Récupérer le SQL du projet.txt` — 3 URI Postgres + 1 mot de passe
7. `Secrets.txt` — 4 secrets, sans étiquette
8. `Secrets perdus.docx` — 4 valeurs orphelines
9. `Codes récupération OVH.txt` — 10 codes 2FA
10. `cloudflare-x.vanwelden@gmail.com-2026.05.05.txt` — 8 codes 2FA
11. `notify-internal-task.SECRETS.txt`, `process_internal_task_queue.env.example.txt`
12. `ANARBIB_PARTNER_IMPORT_SECRET.txt`, `Mail Zimbra OVH Cloud.txt`, `Codes CLI Supabase.txt`
13. `anarbib-edge-deploy/supabase/.temp/pooler-url` — URI Postgres écrite par la CLI Supabase

---

## 7. Dépôts git : résultat de la recherche

Trois dépôts inspectés **objet par objet**, historique complet inclus
(`git cat-file --batch-all-objects`), et non pas seulement l'état courant :

| Dépôt | Objets | Valeurs de l'inventaire retrouvées |
|---|---|---|
| `Codeberg/anarbib` | 23 880 | 10, toutes non secrètes |
| `Codeberg/anarbib-mirror.git` | miroir | les 10 mêmes |
| `Codeberg/anarbib_site` | 105 commits | 1 (clé anon) |

**Aucun secret réel n'est présent dans git, ni dans l'historique.** Ni la clé
service_role, ni une clé Brevo, ni un secret de webhook, ni une URI Postgres,
ni un mot de passe.

Ce que git contient effectivement, et qui n'appelle aucune action :

- la clé **anon** `#d6990e` — publique par conception, compilée dans les bundles `assets/*.js`
- le nom de bucket `catalogos_parceiros_raw` `#ff344e`
- deux UUID (`#337087`, `#b59d01`) et quatre adresses e-mail de service
- la référence du projet Supabase abandonné `asptfmokzykwzlshsncw` `#6640b7`
- un fragment d'enregistrement DNS Brevo `#306db1` — les TXT DNS sont publics

`#337087` est identifié au passage : cette valeur orpheline de « Secrets perdus.docx »
est l'UUID du compte de coordination de Xavier, présent dans
`docs/archive/db-migrations-legacy-pre-woodpecker/20260507_dual_role_xavier_coord_blmf.sql`.

## 8. Archives : ce que chacune transporte

26 archives inspectées membre par membre. Une seule est dangereuse.

| Archive | Contenu sensible |
|---|---|
| **`Zip/anarbib_edge_bundle_rewritten.zip`** | **16 secrets** dans un `functions.env` complet : service_role, 5 clés Brevo, 6 secrets de webhook |
| `Zip/anarbib-theme-20260319.zip` | 2 clés anon + 1 publishable — publiques, sans objet |
| `Zip/notify-*.zip`, `register.zip`, `communications_core_*.zip` | adresses e-mail de service uniquement |
| les 18 autres | rien |
| `Zip/index_probe-partner-catalog.rar` | non inspecté (format RAR) |

Une copie assainie a été produite : `Zip/anarbib_edge_bundle_rewritten_SANS_SECRETS.zip`,
identique à l'originale moins le `functions.env`. L'originale est en quarantaine.

## 9. Ce qui a été fait le 2026-09-01

**Déplacés** dans `_SECRETS_a_detruire_apres_import/` (rien n'est supprimé, tout est récupérable) :

`ANARBIB_PARTNER_IMPORT_SECRET.txt` · `anarbib-staging-rede secrets e credenciais.txt` ·
`cloudflare-x.vanwelden@gmail.com-2026.05.05.txt` · `Codes CLI Supabase.txt` ·
`Codes récupération OVH.txt` · `Mail Zimbra OVH Cloud.txt` · `notify-internal-task.SECRETS.txt` ·
`process_internal_task_queue.env.example.txt` · `Récupérer le SQL du projet.txt` · `Secrets.txt` ·
`Secrets perdus.docx` · `SECRETS STAGING COMPLET.template` · `WEBHOOK_STAGING.txt` ·
`WORLDCAT Secrets.txt` · `anarbib-edge-deploy/functions.env` ·
`anarbib-edge-deploy/supabase/.temp/pooler-url` · `Zip/anarbib_edge_bundle_rewritten.zip`

**Créés** :

- `ANARBIB_import_dashlane.csv` — 38 entrées prêtes à importer, **à supprimer aussitôt après**
- `SECRETS_STAGING.template` — le modèle, sans aucune valeur, chaque ligne renvoyant à son entrée Dashlane
- `anarbib-edge-deploy/functions.env.example`
- `.gitignore`
- `Zip/anarbib_edge_bundle_rewritten_SANS_SECRETS.zip`
- `ROTATION_secrets_2026-09-01.md`
