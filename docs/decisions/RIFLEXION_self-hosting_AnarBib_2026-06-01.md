# Réflexion & plan opérationnel — héberger AnarBib sur infrastructure militante

> **Statut :** document de cadrage v0.1, ouvert à amendement
> **Date :** 2026-06-01
> **Articulation backlog :** préalable « modèle cible self-hosted » de **#BG2** (stratégie de sauvegarde militante). Ce document ne remplace pas `MIGRATION.md` ni `RESTAURATION.md` — il les précède et les cadre.
> **Double lectorat :**
> - **Partie I** — pour la coordination AnarBib (CCLA) : faut-il, et sous quelle forme ?
> - **Partie II** — pour les collectives qui ont des serveurs : *pouvez-vous héberger AnarBib ?* (autonome, lisible sans connaître l'app)
> **Licence :** CC-BY-SA-4.0

---

# Partie I — Réflexion stratégique (coordination AnarBib)

## 1. La distinction qui structure tout : deux plans d'administration

Il existe deux « administrations réseau » dans AnarBib, qui n'ont rien à voir l'une avec l'autre. Les confondre, c'est s'effrayer pour rien.

**Plan applicatif** — ce que voient les admins réseau *dans l'app* : la vue `api.network_overview`, les droits `network_staff`, les workflows de cooptation/retrait, les compteurs périmètre, la gouvernance horizontale. Tout cela est de la logique applicative posée sur PostgreSQL. **Un changement d'hébergement n'y touche pas d'un octet.** Même app, même schéma, mêmes RLS, mêmes RPC, mêmes Edge Functions. La valeur fonctionnelle du projet est indépendante de l'hébergeur.

**Plan infrastructure** — ce qui est aujourd'hui *absorbé par Supabase Cloud et Codeberg* et qu'on ne « voit » presque pas : la base elle-même, l'auth (GoTrue), le Storage, le runtime des Edge Functions, les sauvegardes, les logs, le pooler de connexions, le dashboard Studio, le TLS, le réseau. **C'est uniquement ce plan-là qui migre.**

Toute la suite ne parle que du second plan.

## 2. Ce qu'est concrètement un VPS, et ce qu'il porterait

Un VPS, c'est une machine Linux avec accès root, une IP publique, des ressources garanties (CPU/RAM/disque). Contrairement à Supabase (plateforme entièrement managée), c'est « un Ubuntu nu » : tout ce que Supabase fait pour vous, vous l'installez et l'exploitez vous-mêmes.

Pour AnarBib, par couches :

- **Backend Supabase auto-hébergé** — Supabase est open source et se déploie en Docker Compose : Postgres + PostgREST + GoTrue (auth) + Storage + edge-runtime (Deno) + Studio + Kong (gateway). C'est l'option la plus proche de l'existant : l'app continue de parler aux mêmes API, à une URL près.
- **Frontend** — *optionnel*. Le SPA Vite peut rester sur Codeberg Pages ; seule l'URL d'API qu'il appelle change. Le rapatrier (Nginx/Caddy sur le VPS) est un choix séparé, pas une obligation.
- **Mail transactionnel** — *déconseillé en premier*. Faire délivrer du SMTP auto-hébergé sans tomber en spam est un métier. Garder Resend ici reste sain (déjà prévu en RQ-14 de la spec #110).

## 3. L'échelle : c'est petit

200 bibliothèques, 5 000 usager·ères, 200 000 notices. En volume base pure, c'est **modeste** : les métadonnées de 200 k notices tiennent dans 1 à 2 Go, index compris. 5 000 comptes et 200 bibliothèques sont du bruit statistique pour Postgres. La charge réelle d'une bibliothèque militante (bénévoles à temps partiel) plafonne à quelques dizaines de sessions concurrentes en pointe.

Le seul poste qui peut grossir, c'est le **Storage** (couvertures, logos, PDF, assets PEB/multi-format dans `anarbib-media-public` / `anarbib-media-restricted`) : imprévisible selon la politique de mirroring local des documents. C'est aussi le poste de sauvegarde le plus négligé aujourd'hui (cf. #BG2 : « le trou actuel »).

**Le facteur limitant n'est pas la capacité du serveur — c'est la maturité opérationnelle de qui l'administre.**

## 4. Les modèles de migration

| Modèle | Description | Touche au code | Charge d'exploitation | Recommandation |
|---|---|---|---|---|
| **0 — Statu quo** | Supabase Cloud + Codeberg | nulle | très faible | référence actuelle |
| **A — Pile Supabase self-hosted** | Stack Docker complet sur VPS, frontend + CI inchangés | URL d'API + secrets | moyenne | **recommandé** |
| **B — Décomposition** | Postgres nu + PostgREST + auth choisie, sans Studio intégré | forte (conventions Supabase partout) | élevée | déconseillé à cette échelle |
| **C — Hybride** | Modèle A mais mail laissé sur Resend, frontend sur Codeberg Pages | URL d'API + secrets | moyenne | **variante pragmatique du A** |

Intuition : **A/C** est le plus petit pas qui touche le moins de code. L'app continue de parler aux mêmes API GoTrue/PostgREST/Storage ; on change l'URL et les clés.

## 5. Ce qui change concrètement pour les admins réseau (plan infra)

| Aujourd'hui (absorbé par le fournisseur) | Demain (responsabilité explicite) |
|---|---|
| Supabase Studio hébergé (SQL editor, comptes auth, logs, buckets) | Studio *existe toujours* dans la pile, mais **vous** l'exposez (derrière VPN/Tailscale ou tunnel SSH, **jamais en clair**), le mettez à jour, le sécurisez |
| PITR managé (plan Pro) | **#BG2 devient obligatoire** : `pg_dump`/pgBackRest planifiés, chiffrement age/gpg clé hors ligne répartie, test de restauration mensuel, **+ sauvegarde du Storage** |
| Pooler de connexions managé | Supavisor à configurer |
| Métriques/observabilité intégrées | Prometheus/Grafana à poser (ou conteneur analytics, gourmand) |
| OS/sécurité gérés (SOC2) | Patchs OS, pare-feu, fail2ban, TLS (Caddy/Traefik + Let's Encrypt), reverse proxy |
| Codeberg + Woodpecker | **Inchangés.** Seule la *cible* des étapes de déploiement change (`supabase db push` pointe vers l'instance auto-hébergée ; nouveaux secrets Woodpecker) |

**Point de vigilance Edge Functions :** sur self-hosted elles tournent dans le conteneur `edge-runtime`. Les deux cas connus — `notify-event` (>150 Ko, hors limite du MCP) et `register` (seule avec `verify_jwt`) — doivent être validés sur ce runtime. Coût de migration réel, pas bloqueur.

## 6. Les arbitrages, posés franchement

**Géographie — arbitrage tranché.** L'hébergement actuel (Supabase, sa-east-1 / São Paulo) date d'un centre de gravité brésilien. Or ce centre **se recentre vers l'Europe**, du fait de la densité des bibliothèques européennes potentiellement intéressées par AnarBib, et avec Bologna (FICEDL, septembre 2026) comme point de bascule. Dans ce contexte, un VPS militant **européen (français)** ne relève plus du compromis : il **rapproche l'infrastructure de la base d'usager·ères émergente** et réduit la latence API là où l'usage va croître. C'est désormais São Paulo qui constitue le décalage géographique à corriger, pas l'inverse. Le frontend reste de toute façon servi en statique (Codeberg Pages / CDN) ; seul l'aller-retour API se rapproche.

**Bus factor.** Le self-hosting déplace la dépendance « SaaS commercial » vers « disponibilité opérationnelle du collectif ». La doctrine souveraineté répond déjà bien au « et si l'hébergeur ferme » (code exportable, base portable). La vraie question est le *quotidien* : qui patche, qui surveille le disque, qui restaure à 2 h du matin ? Il faut **2-3 compagnə fiables côté infra, pas un·e seul·e.**

**Cohérence doctrinale.** Le cadre RGPD est « pas-GAFAM », pas « UE-only ». Le self-hosting sur infra militante *renforce* la posture (souveraineté, résistance au déplateformage) et nourrit le récit Bologna « commun en construction ». Un collectif hébergeur français devient un **sous-traitant** à inscrire au `registre-traitements.md`. Note : les dépendances Cloudflare-adjacentes restantes (Turnstile sur le login, Anubis côté Codeberg) ne sont pas effacées par cette migration — chantiers distincts.

## 7. Décision proposée

1. Retenir le **modèle C** (Supabase self-hosted + frontend Codeberg Pages + mail Resend) comme cible de référence.
2. **#BG2 est un préalable bloquant, acté.** La migration comporte des opérations complexes voire irréversibles : on ne s'y lance pas sans une chaîne dump → restauration *éprouvée* (testée, pas seulement écrite). La bascule est la suite de #BG2, jamais un chantier parallèle.
3. **Cibler un hébergeur européen**, cohérent avec le recentrage du centre de gravité vers l'Europe (§6) : l'infrastructure suit la base d'usager·ères.
4. Diffuser la **Partie II** aux collectives sondées comme grille d'auto-évaluation, et n'engager la bascule qu'avec un collectif qui coche la grille du §II.6.

---

# Partie II — Plan opérationnel : pouvez-vous héberger AnarBib ?

> *Document autonome à l'intention des collectives disposant de serveurs. Pas besoin de connaître AnarBib pour le lire.*

## II.1 Ce qu'est AnarBib, techniquement

AnarBib est un logiciel de gestion de bibliothèque (SIGB) libre, fédéré, pour bibliothèques militantes. Architecture classique d'application web :

- un **frontend** statique (React + Vite) — du HTML/JS/CSS servi à plat ;
- un **backend Supabase** — c'est-à-dire une base **PostgreSQL** entourée de services standards : API REST auto-générée (PostgREST), authentification (GoTrue), stockage de fichiers (Storage), et quelques fonctions serverless (edge-runtime Deno).

C'est une **instance unique multi-tenant** : un seul serveur sert toute la fédération de bibliothèques. **Pas besoin de cluster, ni de multi-région, ni de haute disponibilité complexe.** Une seule bonne machine suffit.

## II.2 Ce qui tournerait sur votre serveur

La pile Supabase self-hosted se déploie en **Docker Compose**. Conteneurs principaux :

- `postgres` — la base de données (cœur du système) ;
- `rest` (PostgREST) — l'API ;
- `auth` (GoTrue) — comptes et sessions ;
- `storage-api` (+ `imgproxy`) — fichiers et vignettes ;
- `functions` (edge-runtime) — fonctions serverless ;
- `kong` — passerelle d'API ;
- `studio` (+ `meta`) — le tableau de bord d'administration ;
- *optionnels* : `realtime`, pooler `supavisor`, `analytics` (Logflare — gourmand, souvent désactivé sur petites instances).

Devant tout ça : un **reverse proxy** (Caddy ou Traefik recommandés, pour le TLS automatique).

## II.3 Dimensionnement (sizing)

Volume cible : **~200 bibliothèques, ~5 000 comptes, ~200 000 notices.** En base, c'est petit (1-2 Go de données). La charge concurrente est faible. Le poste qui grossit est le stockage de fichiers.

| Usage | CPU | RAM | Disque | Remarque |
|---|---|---|---|---|
| **Pilote / staging** | 2 vCPU | 4 Go | 80 Go NVMe | viable si `analytics` désactivé |
| **Production** | 4 vCPU | 8 Go | 160–320 Go NVMe | confortable, marge de croissance |
| **Sauvegarde** | — | — | ≥ taille prod, **ailleurs** | destination distincte (règle 3-2-1) |

Le disque de production est dimensionné par le **Storage**, pas par la base (qui reste ~2 Go). Projection à partir de l'empreinte réelle de production (juin 2026 : ~235 Mo, déjà dominée par 7 PDF intégraux ≈ 24 Mo pièce) :

| Moteur de croissance | Hypothèse | Volume à pleine échelle |
|---|---|---|
| Couvertures (suit les notices) | ~180 k à ~70 Ko optimisées (webp) | **~15 Go** (plancher prévisible) |
| Assets per-bibliothèque (logos, UI, régiments) | ~15 Mo × 200 biblios | ~3 Go |
| Portraits auteur·rices | — | ~2 Go |
| **Textes intégraux miroités** (facteur de bascule) | ~15 Mo pièce, fraction des 200 k notices | **voir scénarios** |

| Doctrine de miroir | Fraction miroitée | Total Storage (socle + marge 30 %) | Disque cible |
|---|---|---|---|
| **Conservatrice** (liens d'abord ; miroir = domaine public / rare) | ~1 % | **~65 Go** | 160 Go (large) |
| **Modérée** | ~3 % | **~145 Go** | 160 Go |
| **Généreuse** (miroiter l'essentiel du domaine public) | ~8 % | **~340 Go** | 320–500 Go, ou **déport stockage objet** |

**Décision structurante : la doctrine de miroir** (toggle `mirror_locally`, non encore implémenté) pilote à elle seule l'ordre de grandeur. Au-delà de la doctrine modérée, sortir les assets numériques du disque local vers un **stockage objet S3-compatible** (MinIO/Garage chez l'hébergeur) et réserver le VPS à la base + couvertures. Deux leviers réduisent fortement la facture : compresser les scans (~300 DPI niveaux de gris + PDF OCR) et privilégier le lien externe au miroir quand le document est accessible ailleurs.

**Conséquence #BG2 :** la sauvegarde du *dump* base est triviale ; c'est le Storage qui pèse. La destination hors-site chiffrée doit être dimensionnée sur le total ci-dessus — en doctrine généreuse, ~340 Go chiffrés à répliquer hors-site ont un coût bande passante/stockage à anticiper.

## II.4 Compétences et logiciels requis

Pour tenir AnarBib dans la durée, le collectif doit être à l'aise avec :

- **Linux serveur** (Debian/Ubuntu), accès SSH, gestion d'utilisateurs ;
- **Docker / Docker Compose** (démarrer, arrêter, mettre à jour, lire les logs des conteneurs) ;
- **reverse proxy + TLS** (Caddy/Traefik + Let's Encrypt) ;
- **pare-feu** (nftables/ufw), durcissement SSH, fail2ban ;
- **bases de PostgreSQL** : lancer un `pg_dump`, restaurer un dump, comprendre une connexion ;
- **sauvegardes chiffrées** (age ou gpg) et leur **test de restauration** ;
- **supervision** : surveiller disque, RAM, disponibilité, et savoir réagir à une alerte.

Aucune compétence en bibliothéconomie ni en développement applicatif n'est requise : **le code et l'app sont maintenus par l'équipe AnarBib**, pas par l'hébergeur.

## II.5 L'engagement réel : ce n'est pas une installation, c'est un *quotidien*

Le piège classique : croire que c'est « installer une fois ». Héberger AnarBib, c'est s'engager sur la durée à :

- **patcher** régulièrement l'OS et les images Docker (sécurité) ;
- **surveiller** l'espace disque (un disque plein = panne) et la santé de la base ;
- **vérifier** que les sauvegardes tournent — et **tester une restauration au moins une fois par mois** (une sauvegarde jamais testée n'est pas une sauvegarde) ;
- **être joignable** quand quelque chose casse, idéalement à plusieurs (pas de point unique humain) ;
- **renouveler/sécuriser** les secrets (clé JWT, clé service_role, mot de passe DB).

Estimation honnête : **quelques heures par mois en régime de croisière**, plus une capacité de réaction en cas d'incident. Le risque n'est pas la charge machine, c'est l'abandon silencieux.

## II.6 Grille d'auto-évaluation

Cochez. Si une réponse est « non » sans plan pour y remédier, ce n'est pas encore le bon moment.

- ☐ Nous avons un VPS / serveur d'au moins **4 vCPU / 8 Go / 160 Go** disponible durablement.
- ☐ Nous avons **un second emplacement** pour les sauvegardes (autre machine, autre lieu, ou stockage objet).
- ☐ **Au moins 2-3 personnes** chez nous savent administrer Docker + Linux + Postgres de base.
- ☐ Nous pouvons garantir une **supervision** et une capacité de réaction aux incidents.
- ☐ Nous acceptons de **tester une restauration chaque mois**.
- ☐ Nous comprenons que nous devenons un **sous-traitant de données personnelles** (usager·ères de bibliothèques) et acceptons l'inscription au registre des traitements + la juridiction qui en découle.
- ☐ Nous nous engageons sur la **durée** (pas un essai de deux mois).

## II.7 Répartition des responsabilités (qui fait quoi)

| Domaine | Hébergeur (vous) | Équipe AnarBib |
|---|---|---|
| Machine, OS, Docker, réseau, TLS | ✅ | |
| Sauvegardes + tests de restauration | ✅ | accompagne / documente |
| Supervision, patchs sécurité infra | ✅ | |
| Secrets d'infrastructure (clé JWT, DB) | ✅ (génération + garde) | spécifie le besoin |
| Code applicatif, migrations, Edge Functions | | ✅ |
| CI/CD (Woodpecker sur Codeberg) | | ✅ |
| Gouvernance, comptes, contenu | | bibliothèques + coordination |
| Doctrine RGPD, registre des traitements | co-signé | ✅ pilote |

## II.8 Étapes de bascule (vue d'ensemble, le détail ira dans `MIGRATION.md`)

1. **Provisionner** le serveur, durcir l'OS, installer Docker + reverse proxy.
2. **Déployer** la pile Supabase self-hosted (Docker Compose), générer les secrets.
3. **Migrer les données** : restaurer un `pg_dump` de la base cloud (schémas `public`, `api`, **et `auth`** pour conserver les comptes et mots de passe hachés bcrypt) ; **copier les objets Storage** (fichiers + métadonnées des buckets) — étape à ne pas oublier, c'est la plus laborieuse.
4. **Valider les Edge Functions** sur le edge-runtime (cas `notify-event` et `register`).
5. **Repointer** le frontend (URL d'API + clé anon) et les **secrets de déploiement Woodpecker** vers la nouvelle instance.
6. **Bascule DNS** quand la validation est verte ; conserver l'ancienne instance en *standby froid* un temps.
7. **Tour de validation** (login, emprunt, réservation, notification, carte-lecteur) en navigation privée avant de déclarer la bascule effective.

> Note : le changement de clé JWT invalide les sessions en cours — les usager·ères se reconnectent simplement. Sans gravité, à annoncer.

## II.9 Ce qui ne change pas

Pour rassurer : l'**expérience des usager·ères et du staff bibliothèque est identique** avant/après. Mêmes écrans, mêmes droits, même gouvernance. La fédération ne se réorganise pas. Seul l'« arrière-cuisine » technique déménage.

---

*Document de travail interne AnarBib / CCLA. Préalable « modèle cible » de #BG2. À amender en coordination, puis à scinder le moment venu en `MIGRATION.md` (runbook) et `RESTAURATION.md` (procédure de restauration testée).*
