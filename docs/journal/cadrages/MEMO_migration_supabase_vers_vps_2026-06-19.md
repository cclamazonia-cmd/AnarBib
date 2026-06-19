# Mémo — Quitter Supabase pour le VPS des camarades

> Document de **préparation** (pas un runbook d'exécution). But : comprendre le
> terrain à froid, pour ne pas découvrir les pièges le jour de la bascule.
> Rédigé le 2026-06-19. À relire avant le « moment fatidique ».
> Statut : note de travail personnelle, dans le repo **WSL** (`~/anarbib`), non commitée.

---

## 0. À retenir en une phrase

**On ne « déménage » pas Supabase comme on copie un dossier.** Supabase n'est pas
*un* serveur : c'est un **assemblage de 5–6 briques** qui marchent ensemble. Migrer,
c'est remonter ce même assemblage sur le VPS, **puis** y recopier les données. Le
transfert de fichiers (le fameux **SFTP**) n'est qu'**une étape au milieu**.

---

## 1. Ce qu'on quitte vraiment : les briques de Supabase

Aujourd'hui, Supabase te fournit (et donc le VPS devra fournir) :

| Brique | Ce que ça fait chez toi | Nom technique |
|---|---|---|
| **Base de données** | Le cœur : catalogue, prêts, membres, autorités… | PostgreSQL |
| **Authentification** | Comptes, connexion, mots de passe, jetons | GoTrue (`auth.users`) |
| **API automatique** | Expose les tables/fonctions au frontend | PostgREST |
| **Stockage de fichiers** | Couvertures, PDF, logos, cartes | Storage (+ buckets) |
| **Fonctions serveur** | Tes ~36 Edge Functions (mails, lookups…) | Edge Runtime (Deno) |
| **Tâches planifiées** | Rapports hebdo, relances, digests | `pg_cron` dans Postgres |
| **Passerelle / sécurité** | Routage + clés (anon / service_role) | Kong + clés JWT |

> 💡 La bonne nouvelle : il existe une version **auto-hébergeable de Supabase**
> (un `docker-compose` officiel qui regroupe toutes ces briques). C'est presque
> certainement la voie à privilégier — voir §2.

---

## 2. Les deux stratégies possibles

**Stratégie A — Ré-héberger Supabase en entier (recommandée).**
On installe la pile **Supabase self-hosted** (Docker) sur le VPS. On retrouve les
mêmes briques, les mêmes noms, le même comportement → **le code de l'appli ne change
quasiment pas** (juste les adresses et les clés). C'est le moins de réécriture.

**Stratégie B — Décomposer brique par brique.**
On remplace chaque morceau par un équivalent « classique » (Postgres nu + un autre
système d'auth + un autre stockage…). Beaucoup **plus de travail** et de réécriture.
À n'envisager que si les camarades ont une raison forte de ne pas faire tourner
Docker/Supabase.

➡️ **Décision à trancher tôt** (avec les camarades) : A ou B. Le reste du mémo
suppose **A**.

---

## 3. Inventaire concret de TES données et services

Ce qu'il faudra effectivement transférer / reconstruire (vérifié dans le dépôt) :

- **La base Postgres** : ~390 migrations, schémas `public` / `api` / `private`,
  RLS (sécurité ligne par ligne), des centaines de fonctions et triggers.
- **Extensions Postgres** à réinstaller : **`pg_cron`** (tâches planifiées),
  **`pg_net`** (les `net.http_post` qui appellent les Edge Functions),
  **`pg_trgm`** (recherche), + les standards (pgcrypto, uuid…).
- **Tâches `pg_cron`** (à recréer ET réactiver) : digest inter-biblio hebdo,
  retrait de collectif, relances de cooptation, cycle de vie des propositions
  (paquet B.4), rapports hebdomadaires… Chacune **appelle une Edge Function par
  HTTP** → l'URL changera (voir piège §5).
- **Buckets de Storage** (5 repérés) : `library-ui-assets` (public),
  `library-privacy-public`, `anarbib-carte-rede` (privé),
  `partner-catalog-deposits`, `catalogos_parceiros_raw`. Chacun a ses **policies
  RLS** + des **fichiers physiques** (les deux à migrer, voir piège §5).
- **Edge Functions** (~36, en Deno) : notifications, `read-pdf`,
  `read-digital-asset`, lookups catalogue, `login`/`register`…
- **Secrets** des fonctions : `RESEND_API_KEY`, `WEBHOOK_SECRET_NOTIFY_EVENT`,
  `SENDER_EMAIL` / `SENDER_NAME`, `ADMIN_EMAIL`, etc. → à reporter sur le VPS.
- **Les comptes** (`auth.users`) : identités + **mots de passe hachés**.
- **Le frontend** (React/Vite) : il pointe vers `SUPABASE_URL` + la clé `anon`.
  Ces deux valeurs changeront.

---

## 4. La séquence de migration (vue d'ensemble)

Dans l'ordre, et **sans rien couper avant la fin** :

1. **Préparer le VPS** : Docker + pile Supabase self-hosted, **même version majeure
   de Postgres** que l'actuelle (sinon le dump peut coincer).
2. **Exporter la base** : `pg_dump` → un fichier de sauvegarde. Penser à inclure
   les **rôles**, les **extensions** et les schémas `auth` / `storage`.
3. **Transférer** le dump **par SFTP** (ou `rsync`) vers le VPS.
4. **Restaurer** la base sur le VPS (`pg_restore` / `psql`).
5. **Migrer les fichiers de Storage** : recopier les objets de chaque bucket
   (SFTP/`rsync` ou outils Storage) **et** s'assurer que les lignes
   `storage.objects` correspondantes sont là.
6. **Redéployer les Edge Functions** + **re-saisir tous les secrets**.
7. **Réactiver les tâches `pg_cron`** en **corrigeant les URL** des Edge Functions
   (elles pointent vers l'ancienne adresse Supabase).
8. **Repointer le frontend** : nouvelles `SUPABASE_URL` + clé `anon`, `rebuild`,
   redéploiement des Pages.
9. **DNS / domaine** : faire pointer `app.anarbib.org` (et l'API) vers la nouvelle
   infra — **en dernier**, une fois tout testé.
10. **E-mails (SMTP)** : décider — garder **Resend** (rien à changer) ou **relayer
    par le serveur des camarades** (petite modif de code + DNS SPF/DKIM/DMARC).
    Cf. mémo précédent sur SMTP.

---

## 5. Les pièges spécifiques à AnarBib ⚠️

À lire deux fois — c'est là qu'on « arrive comme un bleu » sinon :

1. **Le secret JWT et les mots de passe.** Les comptes vivent dans `auth.users`
   avec des **mots de passe hachés** ; les sessions reposent sur un **secret JWT**.
   Si on ne migre pas proprement le secret GoTrue et la table `auth`, soit **toutes
   les sessions cassent**, soit **tout le monde doit refaire son mot de passe**.
   À cadrer précisément avant la bascule.
2. **Les rôles Postgres** (`anon`, `authenticated`, `service_role`). Toute la
   sécurité (RLS, GRANT, policies) **dépend de ces rôles**. Le dump doit les
   recréer, ou les policies tomberont à plat.
3. **Storage = deux moitiés.** Un fichier dans un bucket, c'est **une ligne** dans
   `storage.objects` **+** un **fichier physique** (sur disque/S3). Migrer une
   moitié sans l'autre = images cassées ou objets fantômes.
4. **Les `pg_cron` rappellent les Edge Functions par HTTP.** Après migration,
   l'adresse des fonctions change : il faut **réécrire les URL** dans les jobs,
   sinon les rapports/relances échouent en silence.
5. **Les clés changent** (`anon`, `service_role`, project ref). Tout ce qui est
   **en dur** dans les Edge Functions ou le frontend doit être mis à jour.
6. **Les extensions** (`pg_cron`, `pg_net`, `pg_trgm`) doivent être **installées
   sur le VPS** avant la restauration, sinon le dump échoue à la création des
   objets qui en dépendent.

---

## 6. Le filet de sécurité (très important)

- **Ne pas éteindre Supabase tant que le VPS n'est pas validé.** On fait tourner
  les deux **en parallèle** pendant la transition.
- **Faire un essai à blanc** (dry run) : restaurer un dump sur le VPS, tester
  connexion / catalogue / un mail / une tâche cron, **avant** la vraie bascule.
- **La bascule = un changement de DNS**, fait en dernier et réversible.
- **Sauvegardes** : un dump frais juste avant, gardé de côté. Et prévoir comment
  les camarades **sauvegarderont** la base ensuite (c'est désormais à vous) —
  tout le sujet est détaillé en **§7 (#BG2)**, qui est un préalable *bloquant*.

---

## 7. Les sauvegardes (#BG2) — un préalable BLOQUANT

C'est le point le plus important de tout le mémo, et il a son propre numéro de
backlog : **#BG2** (« stratégie de sauvegarde militante »). Cadré dans
[`RIFLEXION_self-hosting_AnarBib_2026-06-01.md`](../../decisions/RIFLEXION_self-hosting_AnarBib_2026-06-01.md).

**Ce qui change radicalement.** Aujourd'hui, Supabase **sauvegarde pour toi** : le
plan Pro fournit du **PITR managé** (restauration à n'importe quelle minute passée,
automatique). Sur le VPS, **ce filet disparaît** : personne ne sauvegarde à ta
place. Le cadrage le dit noir sur blanc — *« #BG2 devient obligatoire »*.

**#BG2 est un préalable BLOQUANT, déjà acté.** On **ne dit pas au revoir à Supabase**
tant que la chaîne **sauvegarde → restauration n'a pas été *testée et validée*** sur
le VPS. Citation du cadrage : *« La bascule est la suite de #BG2, jamais un chantier
parallèle. »* Écrire la procédure ne suffit pas : il faut l'avoir **éprouvée**.

**Ce que #BG2 doit mettre en place** (à la main, désormais) :

- [ ] **`pg_dump` / pgBackRest planifiés** — sauvegardes automatiques et récurrentes
      de la base (pas un dump manuel de temps en temps).
- [ ] **Chiffrement** des sauvegardes (age/gpg), avec une **clé hors ligne
      répartie** entre plusieurs personnes (jamais stockée sur le serveur lui-même).
- [ ] **Test de restauration mensuel** — restaurer pour de vrai une sauvegarde sur
      une instance jetable, et vérifier qu'elle est exploitable.
- [ ] **Sauvegarde du Storage** — explicitement *« le trou actuel »* : les fichiers
      (couvertures, PDF, logos) sont des **fichiers physiques**, à sauvegarder
      **séparément** du dump de la base. C'est le poste le plus négligé.

**Le vrai facteur limitant.** Le cadrage est net : la base est petite (1–2 Go), le
serveur encaissera sans peine. *« Le facteur limitant n'est pas la capacité du
serveur — c'est la maturité opérationnelle de qui l'administre. »* La question à
poser aux camarades n'est donc pas « avez-vous le disque ? » mais **« qui va lancer,
surveiller et *tester* la restauration chaque mois, durablement ? »**.

> 📌 Concrètement, #BG2 débouchera sur deux documents d'exécution que le cadrage
> appelle déjà : un `MIGRATION.md` et un `RESTAURATION.md`. Le présent mémo les
> **précède** et les cadre.

---

## 8. À demander / vérifier avec les camarades (dimensionnement)

- **Ressources** du VPS : RAM, CPU, **espace disque** (la base + les fichiers
  Storage + les images Docker — prévoir large).
- **Docker** disponible ? Version de **PostgreSQL** prévue ?
- **Accès SSH/SFTP** : identifiant, port, **clé SSH** (préférable au mot de passe).
- **Qui administre** la machine au quotidien, **sauvegardes** automatiques ?
- **IP fixe + reverse DNS** (utile si on relaie les mails via leur SMTP).
- **Bande passante** et politique de la structure (logs, juridiction, etc.).

---

## 9. Décisions à trancher (pas maintenant, mais à avoir en tête)

1. **Stratégie A (Supabase self-hosted) vs B (décomposition)** → §2. *Recommandé : A.*
2. **E-mails : garder Resend vs relayer par le SMTP des camarades** → §4.10.
3. **Où vit le frontend** : il peut **rester** sur Codeberg Pages (il se contente de
   pointer vers la nouvelle API), ou être servi par le VPS. *Le plus simple : le
   laisser sur Pages au début.*

---

## 10. Petit glossaire (pour t'y retrouver)

- **SFTP** : copie de fichiers chiffrée, via SSH. Le « FTP » sécurisé.
- **SSH** : connexion à distance chiffrée au serveur (la base de SFTP/rsync).
- **`rsync`** : copie maligne (n'envoie que les différences, reprend si ça coupe).
- **dump** : export complet de la base dans un fichier (`pg_dump`).
- **restauration** : réimport de ce fichier dans une base vide (`pg_restore`/`psql`).
- **RLS** (Row-Level Security) : règles de sécurité au niveau de chaque ligne.
- **GoTrue** : la brique d'authentification de Supabase (`auth.users`).
- **`pg_cron`** : le planificateur de tâches **dans** Postgres.
- **JWT** : le jeton signé qui prouve qu'un utilisateur est connecté.
- **bucket** : un « dossier-conteneur » de fichiers dans le Storage.
- **PITR** (Point-In-Time Recovery) : restauration de la base à n'importe quelle
  minute passée. Fourni automatiquement par Supabase (plan Pro) ; **à reconstruire
  soi-même** sur le VPS (cf. #BG2, §7).
- **#BG2** : la tâche backlog « stratégie de sauvegarde militante » — préalable
  *bloquant* à la migration.

---

*Suite logique quand le serveur sera confirmé : transformer ce mémo en runbook
d'exécution daté, étape par étape, avec les commandes exactes.*
