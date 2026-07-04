# RUNBOOK — Migration AnarBib : Supabase hébergé → hôte self-hosted (stratégie A)

> Transforme le [`MEMO_migration_supabase_vers_vps`](../cadrages/MEMO_migration_supabase_vers_vps_2026-06-19.md)
> + la [`DECISION_arbitrage`](../arbitrages/DECISION_arbitrage_migration_vps_2026-07-03.md) en séquence
> d'exécution. **Cible = un hôte Linux avec shell + Docker** (Herbes Folles *ou* un VPS loué qu'on
> administre — cf. `SHORTLIST_vps_calcul_2026-07-04`). Rédigé 2026-07-04.
>
> ⚠️ Ce runbook donne la **séquence exacte et les commandes** là où elles sont sûres, et **pointe la
> doc officielle** là où l'exactitude dépend de la version (surtout la restauration `auth`/`storage`).
> **Rien ne se fait sans dry-run préalable** (Phase 1). Les deux instances tournent **en parallèle**
> jusqu'à validation ; la bascule = un **changement DNS réversible**, fait en dernier.

## Préalables (acquis)
- **#BG2 sauvegardes validé** → on sait produire un dump exploitable et le restaurer.
- **Volumétrie mesurée** : base **~102 Mo** (PostgreSQL **17.6**), Storage **~430 Mo** sur **16 buckets**.
- **Extensions** à réinstaller : `pg_cron`, `pg_net`, `pg_trgm`, `pgcrypto`, `uuid-ossp` (toutes dans l'image `supabase/postgres`).
- **43 edge functions** (Deno), secrets listés dans [`.env.example`](../../../.env.example).
- **Décisions** : A (self-hosted Docker), **auth.users migrée + secret JWT ROTATÉ** (D4), Storage backend **fichier local** (D5), mail **Resend/relais** (D2, hors bascule), front **statique** (D3).

## Repères de sécurité (à lire avant tout)
1. **Ne rien éteindre côté Supabase** tant que le nouvel hôte n'est pas validé.
2. **Dry-run obligatoire** (Phase 1) : restaurer un dump sur l'hôte et tester connexion + catalogue + 1 mail + 1 cron **avant** la vraie bascule.
3. **DNS en dernier**, réversible (TTL court posé à l'avance).
4. **Le schéma n'est PAS reproductible via `migrations/` seules** (socle créé hors migrations, cf. baseline). → La source de vérité pour la restauration est un **`pg_dump` de la base live**, pas un rejeu de migrations.

---

## Phase 0 — Préparer l'hôte
0.1 Accès **SSH par clé** + shell. Docker + Docker Compose installés. **≥ 8 Go RAM** visés (4 minimum).
0.2 Cloner la pile self-hosted officielle :
```bash
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
```
0.3 **Fixer PostgreSQL en majeure 17** (aligner l'image `supabase/postgres` sur la 17.x pour que le dump 17.6 se restaure sans friction).
0.4 Éditer `.env` (secrets **neufs**, D4) : `POSTGRES_PASSWORD`, `JWT_SECRET` (nouveau), `ANON_KEY` + `SERVICE_ROLE_KEY` (**régénérés à partir du nouveau `JWT_SECRET`** via l'outil de génération de clés Supabase), `SITE_URL`, `API_EXTERNAL_URL`, `SUPABASE_PUBLIC_URL`. Storage en backend **fichier** (défaut local). Réf : doc officielle *Self-Hosting with Docker*.
0.5 `docker compose up -d` puis vérifier que tous les services montent (`docker compose ps`).

## Phase 1 — Dry-run (à blanc, AVANT la vraie bascule)
Restaurer un dump récent sur l'hôte, puis tester : login, une recherche catalogue, l'envoi d'un mail, un job cron. C'est le juge de vérité. On ne passe aux phases suivantes en « pour de vrai » qu'après un dry-run concluant.

## Phase 2 — Exporter la base (source de vérité)
2.1 **Rôles** : `pg_dumpall --roles-only` (recrée `anon`, `authenticated`, `service_role` + GRANTs — sans eux toute la RLS tombe à plat, piège §5.2 du mémo).
2.2 **Base complète** : `pg_dump` de la base, en **incluant les schémas** `public`, `api`, `ingest`, `private`, **`auth`**, **`storage`** + les extensions.
2.3 ⚠️ **Point délicat = `auth` et `storage`.** La pile self-hosted crée déjà ces schémas (GoTrue/Storage à l'init). Restaurer par-dessus demande une approche **data-only** ciblée (ou un ordre précis), **pas** un simple `pg_restore` brut. → **Suivre la procédure officielle Supabase « migrate / backup-restore self-hosted »** et **l'éprouver en Phase 1**. Ne pas improviser ici : c'est LE piège (sessions cassées / mots de passe perdus si mal fait).
2.4 Garder ce dump **chiffré** de côté (cohérent avec la chaîne #BG2).

## Phase 3 — Transférer
`rsync`/`scp` du dump vers l'hôte (reprise si coupure). Idem pour les fichiers Storage (Phase 5).

## Phase 4 — Restaurer la base
4.1 Restaurer d'abord les **rôles**, puis la base (ordre : extensions → schémas → data), en suivant la procédure éprouvée en Phase 1.
4.2 Vérifier : `select count(*)` sur `public` (~172 tables, `books` ~2674, `auth.users` non nul), et que les **policies RLS** sont présentes.

## Phase 5 — Migrer le Storage (les deux moitiés)
5.1 **Fichiers physiques** : recopier les objets des **16 buckets** (~430 Mo) vers le backend fichier de l'hôte (`rsync`).
5.2 **Lignes `storage.objects`** : venues avec le dump (Phase 4). Vérifier la correspondance fichier ↔ ligne (une moitié sans l'autre = images cassées / objets fantômes, piège §5.3).
5.3 Buckets publics vs privés + leurs policies : re-vérifier après restauration.

## Phase 6 — Edge Functions + secrets
6.1 Redéployer les **43 EF** sur l'hôte (runtime Deno de la pile).
6.2 **Re-saisir tous les secrets** depuis [`.env.example`](../../../.env.example) : `RESEND_API_KEY`, `WEBHOOK_SECRET_NOTIFY_*`, `ANTHROPIC_API_KEY`, `GAZETTE_CRON_SECRET`, `TURNSTILE_SECRET_KEY`, `ACOUSTID_API_KEY`, `NOMINATIM_URL`, `SENDER_*`/`ADMIN_*`, `APP_BASE_URL`, + les `SUPABASE_URL`/`ANON_KEY`/`SERVICE_ROLE_KEY` **neufs** de l'hôte.

## Phase 7 — pg_cron (réactiver + corriger les URLs)
Les ~30 jobs `cron.job` **appellent les EF par HTTP** (`pg_net`). Après bascule, l'adresse des fonctions change → **réécrire les URLs** dans les jobs (sinon rapports/relances échouent en silence, piège §5.4). Vérifier que `pg_cron` + `pg_net` sont actifs et que les jobs sont `active=true`.

## Phase 8 — Repointer le frontend
8.1 Nouvelles valeurs de build : `VITE_SUPABASE_URL` + `VITE_SUPABASE_ANON_KEY` (**clés neuves** de l'hôte). Les `VITE_TURNSTILE_SITE_KEY` / `VITE_JITSI_DOMAIN` inchangés.
8.2 `rebuild` + redéploiement (Codeberg Pages pour l'instant, D3).

## Phase 9 — DNS (en dernier, réversible)
9.1 Poser un **TTL court** sur les enregistrements **avant** le jour J.
9.2 Faire pointer `app.anarbib.org` (et l'API si domaine dédié, ex. `api.anarbib.org`) vers le nouvel hôte, avec **TLS** (Caddy/Traefik + Let's Encrypt).
9.3 **Mail (D2)** : si on garde Resend → rien. Si relais HF → publier SPF/DKIM/DMARC pour `@anarbib.org` (doc DNS séparée à faire quand le choix mail est arrêté).

## Phase 10 — Validation post-bascule
10.1 Rejouer les tests de la Phase 1 sur l'infra live. Surveiller logs + un cycle cron complet.
10.2 **Garder Supabase en secours** quelques jours (bascule DNS réversible), puis décommissionner.
10.3 **Rotation** : retirer/rotater les anciens secrets Supabase + les mots de passe SFTP passés en clair (cf. note sécurité du fil HF).

---

## Les 6 pièges AnarBib (rappel condensé du mémo §5)
1. **Secret JWT + mots de passe** : on **rotate** le JWT (D4) → sessions invalidées, **chacun·e se reconnecte une fois** ; les mots de passe (hash dans `auth.users`) **survivent** car on migre `auth`. Régénérer `anon`/`service_role` depuis le nouveau secret.
2. **Rôles Postgres** : `anon`/`authenticated`/`service_role` recréés (Phase 2.1) sinon RLS à plat.
3. **Storage = 2 moitiés** : fichiers **et** `storage.objects` (Phase 5).
4. **`pg_cron` → EF par HTTP** : réécrire les URLs (Phase 7).
5. **Clés changent** : tout ce qui est en dur (front + EF) mis à jour (Phases 6/8).
6. **Extensions** installées avant restauration (Phase 0/4).

## Plan de repli
À tout moment avant la Phase 9, l'ancienne infra Supabase est intacte et sert encore le front (DNS inchangé). En cas d'échec d'une phase : corriger sur l'hôte, re-dry-run ; **ne jamais avancer le DNS tant que la Phase 1 n'est pas verte sur l'infra cible**.

> **À verrouiller au moment du dry-run** (avec l'hôte réel + la doc Supabase self-hosting courante) :
> les commandes exactes de Phase 2.3 / 4 (restauration `auth`+`storage`) et le générateur de clés JWT.
> Je peux les préciser dès que l'hôte est choisi et que je peux m'appuyer sur la doc officielle à jour.
