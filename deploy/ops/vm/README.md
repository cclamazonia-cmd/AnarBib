# `deploy/ops/vm/` — sauvegarder une AnarBib depuis la machine qui l'héberge

> Écrit le 12/10/2026 pour la VM d'essai d'ASR2026. La chaîne d'à côté
> ([`../README.md`](../README.md), #BG2) sauvegarde la production **hébergée**
> depuis le poste de maintenance ; celle-ci sauvegarde une pile `deploy/`
> **depuis la machine qui la fait tourner**. Même doctrine, mêmes garde-fous,
> un script à part : on ne rend pas bimodale la brique dont la production dépend.

## Ce qui est sauvegardé

| Flux | Contenu | Quand | Rétention | Témoin en base |
|---|---|---|---|---|
| `base` | `schema.sql`, `data.sql`, `migrations.sql` — produits par `pg_dump` dans le conteneur `db` avec **la recette exacte de `supabase db dump` v2.98.1** (schémas exclus, filtres sed), donc restaurables par `deploy/scripts/restore.sh` — et `vault.sql` (les secrets du Vault déchiffrés, dont `pseudonym_salt`) | chaque jour, 03:30 Europe/Paris | 7 jours, 4 semaines, 6 mois | `court` et `long` |
| `storage` | le volume Docker `anarbib-selfhost_storage-data` (les fichiers de tous les buckets, **fond de carte `map-tiles` compris** depuis le 19/10/2026 ; `MAP_TILES=exclu` dans `sauvegarde.env` pour l'en retirer si le dépôt distant manque de place — `check` dit ce qu'il pèse, ~33 Go pour la planète en z13) | dimanche 04:30 | idem | `storage` et `lourd` |

Les témoins portent les noms que la sonde `health-probe` de l'instance attend
(`court` 36 h, `long` 9 j, `storage` 9 j, `lourd` 9 j depuis le 18/10/2026,
contrainte en base) : un tir `base` témoigne pour `court` **et** `long`,
puisqu'il contient les deux ; un tir `storage` pour `storage` **et** `lourd`,
puisque le volume porte tous les buckets. (Sur le poste de maintenance,
`../anarbib-bg2.sh` sépare les buckets lourds dans un dépôt à part faute de
place chez l'hébergeur de sauvegarde ; une instance n'a pas cette contrainte.) Sans témoin,
la sonde ouvre un incident et écrit aux admins de l'instance. C'est toute la
supervision ; il n'y a rien d'autre à installer.

**Pas de découpage court/long** (données personnelles à rétention courte) :
il demande deux listes de tables qui ne sont pas au dépôt. Les données
personnelles de l'instance vivent donc six mois dans le dépôt restic ; à écrire
dans son registre des traitements. Une instance qui dispose des listes peut
reprendre `../anarbib-bg2.sh`.

## Installer (en root, sur la machine)

```bash
apt install restic                                   # Debian 12/13
mkdir -p /etc/anarbib && chmod 700 /etc/anarbib
cp /opt/anarbib/deploy/ops/vm/sauvegarde.env.example /etc/anarbib/sauvegarde.env
openssl rand -base64 48 > /etc/anarbib/restic.pass && chmod 600 /etc/anarbib/*
nano /etc/anarbib/sauvegarde.env                     # RESTIC_REPOSITORY : un dépôt HORS de la machine
restic -r "$RESTIC_REPOSITORY" -p /etc/anarbib/restic.pass init
/opt/anarbib/deploy/ops/vm/anarbib-vm-sauvegarde.sh check
cp /opt/anarbib/deploy/ops/vm/systemd/*.service /opt/anarbib/deploy/ops/vm/systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now anarbib-vm-sauvegarde-base.timer anarbib-vm-sauvegarde-storage.timer anarbib-vm-sauvegarde-prune.timer
systemctl start anarbib-vm-sauvegarde-base.service   # premier tir, tout de suite
```

- La passphrase restic se garde **aussi** ailleurs (gestionnaire de mots de passe) :
  sans elle, le dépôt est illisible, et une sauvegarde illisible n'existe pas.
- Le dépôt sftp demande une clé SSH dédiée, sans passphrase, routée par
  `/root/.ssh/config` (`IdentitiesOnly yes`), et l'hôte distant connu
  (`ssh-keyscan`). Un dépôt `rest:` ou `s3:` évite SSH.
- Les unités sont des copies, pas des liens : un changement dans `deploy/ops/vm/`
  se recopie (`cp … && systemctl daemon-reload`). Le chemin `/opt/anarbib` est
  écrit dans les unités : l'adapter si le dépôt est ailleurs.
- Le script tourne en root (il lit le point de montage du volume Docker).

## Vérifier

```bash
journalctl -u anarbib-vm-sauvegarde-base.service --since today
/opt/anarbib/deploy/ops/vm/anarbib-vm-sauvegarde.sh snapshots
cat /var/lib/anarbib-sauvegarde/echecs.log            # vide = aucun tir en échec
```

et dans l'application, la sonde : `select * from public.fn_backup_heartbeat_status();`
(ou la page de santé de l'administration).

## Restaurer

Sur une pile **vierge** (`docker compose down -v` dans `deploy/`, puis
`docker compose up -d db`) :

```bash
restic restore latest --tag flux-vm-base --target /tmp/r      # les quatre fichiers
mkdir -p /opt/anarbib/deploy/dumps && cp /tmp/r/var/lib/anarbib-sauvegarde/.work/*.sql /opt/anarbib/deploy/dumps/
cd /opt/anarbib/deploy
docker compose exec -T db psql -U supabase_admin -d postgres < dumps/vault.sql   # le sel AVANT tout (bootstrap le vérifie)
./bootstrap.sh --depuis-une-sauvegarde                          # schema → data → vues → historique → crons → plafonds
shred -u dumps/vault.sql
```

puis les fichiers :

```bash
docker compose stop storage
restic restore latest --tag flux-vm-storage --target /tmp/s
rsync -a /tmp/s/var/lib/docker/volumes/anarbib-selfhost_storage-data/_data/ "$(docker volume inspect -f '{{.Mountpoint}}' anarbib-selfhost_storage-data)/"
docker compose start storage
```

La disposition sur disque est celle du service (`<s3>/<tenant>/<bucket>/<objet>/<version>`) :
un volume sauvegardé ici se remet tel quel. (Une sauvegarde de la chaîne #BG2,
elle, pose `<bucket>/<nom>` et passe par `../anarbib-storage-restore.py`.) Le
fond de carte se refait avec `scripts/maptiles/`.

**Avant de restaurer un dump dans une pile plus récente** : les pins GoTrue et
Storage doivent être au moins ceux qui ont produit le dump
(`deploy/banc-paliers.sh`, `deploy/README.md`).

## Ce que ce script ne fait pas

- Pas de test de restauration automatique (le `restore-test` de #BG2 monte un
  Postgres jetable) : à faire à la main, au moins une fois, sur une seconde VM.
- Pas de contrôle de fraîcheur côté machine : la sonde en base le fait, à
  condition que l'instance envoie du courriel (`RESEND_API_KEY`).
- Pas de copie froide : un second dépôt restic (`restic copy`) sur un disque
  qu'on débranche est la suite naturelle, cf. `../anarbib-copie-froide.sh`.
