# Plan d'action — recyclage du Dell Latitude 3310 en serveur AnarBib toujours-ON

**Date** : 2026-07-04
**Auteur** : Xavier (session avec Claude)
**Machine** : Dell Latitude 3310 — i3 bi-cœur, 8 Go RAM, SSD 128 Go (actuellement Windows 11).
**Intention** : faire avancer **BG2-AUTO-1** (« bascule vers VPS-pull quand AnarBib aura un trafic réel »). Sortir le convoyeur de sauvegarde et le runner CI de ton PC principal (WSL2, allumé par intermittence) vers une machine dédiée **toujours allumée**, **Linux natif** (fin du frottement WSL/MSYS), alignée sur la doctrine de souveraineté (auto-hébergé, pas de loyer cloud).

---

## 0. Périmètre — ce que la box FAIT et ne fait PAS

**Elle FAIT (rôles sortants, aucun IP public requis — OK derrière NAT résidentiel) :**
- **Convoyeur de sauvegarde #BG2** : tire depuis Supabase (pooler) → pousse vers Herbes Folles (SFTP restic) → miroir storage. Remplace les timers WSL2.
- **Runner Forgejo Actions** (`anarbib-local`) : exécute la CI (ci.yml + sql-tests.yml) 24/7.
- **Dead-man's-switch** (BG2-AUTO-4 niveau 3, reporté jusqu'ici) : ping externe de vie.

**Elle ne fait PAS :**
- Pas d'hébergement public de l'appli (frontend = statique ailleurs ; backend = Supabase cloud). Résidentiel + IP dynamique + CGNAT = à proscrire pour de l'entrant.
- Pas la base de données (Supabase).
- Pas le **dépôt** de sauvegarde : Herbes Folles + réplique froide `F:` restent les vrais dépôts. La box n'est qu'un **convoyeur**.

---

## 1. Pré-requis matériel & BIOS (à faire une fois, clavier/écran branchés)

1. **BIOS Dell** (F2 au boot) :
   - *AC Power Recovery* / *Power On After Power Loss* → **On** (redémarre seule après coupure).
   - Désactiver *Secure Boot* seulement si l'install Linux le demande (Debian gère Secure Boot, laisser On de préférence).
   - Vérifier ordre de boot USB pour l'install.
2. **Sauvegarder** tout ce qui compte encore sous Windows (on va effacer le disque).
3. Prévoir : clé USB ≥ 2 Go (image Debian), un accès réseau **filaire** (Ethernet) de préférence — plus fiable que le Wi-Fi pour un serveur.

---

## 2. Phase 0 — Préparation hors-ligne (avant de toucher la box)

Décisions et récupération des secrets **depuis le PC WSL actuel** (ou Dashlane + clé USB du coffre BG2) :

- **Nom d'hôte** : ex. `anarbib-srv`. **Utilisateur** : reprendre `accattone` = portage *zéro-édition* (tous les scripts/units sont en `$HOME`/`%h`). Sinon un user dédié `anarbib` (propre, mais rester cohérent).
- **IP locale fixe** : réserver une IP par bail DHCP (box internet) ou config statique — pour un SSH stable.
- **Les 4 secrets à transférer** (perms cibles `600`) :
  | Secret | Source (WSL) | Cible (box) |
  |---|---|---|
  | Clé SSH Herbes Folles | `~/.ssh/id_ed25519_bg2` | `~/.ssh/id_ed25519_bg2` |
  | Passphrase restic | `~/.config/restic-anarbib.pass` | idem |
  | Mot de passe DB (pooler) | `~/.pgpass` | idem |
  | Token CLI Supabase | `~/.supabase/access-token` | idem |
  - Transfert : **clé USB chiffrée** de préférence (le coffre BG2), ou `scp` direct WSL→box une fois le SSH en place. Ne jamais passer par un canal en clair.
- **Bloc SSH** à recréer dans `~/.ssh/config` de la box :
  ```
  Host bricolage.herbesfolles.org
      User anarbib
      IdentityFile ~/.ssh/id_ed25519_bg2
      IdentitiesOnly yes
      IdentityAgent none
  ```
- **Accès Git** : prévoir de quoi cloner le repo privé Codeberg (clé de déploiement SSH dédiée, ou token). NE PAS réutiliser la clé Herbes Folles.
- **Token d'enregistrement runner** : Codeberg → org/repo `AnarBib/anarbib` → Settings → Actions → Runners → *Create new runner* → noter le **registration token** (usage unique, phase 4).

---

## 3. Phase 1 — Socle Debian

### 3.1 Installation
- **Debian 12 (bookworm) stable**, netinst, **sans environnement de bureau**. Cocher uniquement *SSH server* + *standard system utilities*. Partition simple (tout dans `/`, ou `/` + swap).
- Post-install : `sudo apt update && sudo apt full-upgrade -y`.

### 3.2 Hygiène « laptop-serveur » (critique)
```bash
# Ne jamais dormir/suspendre, capot fermé compris
sudo sed -i 's/^#\?HandleLidSwitch=.*/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/^#\?HandleLidSwitchExternalPower=.*/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Swapfile 4 Go (coussin sur 8 Go de RAM, surtout pour la CI)
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Mises a jour securite sans reboots sauvages
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades   # activer ; regler reboot planifie de nuit si voulu
```
- Vérifier l'heure : `timedatectl` (systemd-timesyncd actif → OnCalendar fiable).

### 3.3 Dépendances (versions relevées le 04/07 à égaler ou dépasser)
```bash
sudo apt install -y git curl ca-certificates jq openssh-client bzip2 coreutils

# Docker (flux storage + runner CI)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker "$USER"     # se reconnecter ensuite

# Client Postgres 17 (psql + pg_dump ; depot PGDG)
sudo install -d /usr/share/postgresql-common/pgdg
sudo curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt update && sudo apt install -y postgresql-client-17

# restic 0.18.x (binaire officiel ; apt bookworm est trop vieux)
curl -fsSL -o /tmp/restic.bz2 https://github.com/restic/restic/releases/download/v0.18.1/restic_0.18.1_linux_amd64.bz2
bunzip2 /tmp/restic.bz2 && sudo install -m755 /tmp/restic /usr/local/bin/restic

# Supabase CLI (.deb depuis les releases ; verifier la version courante)
curl -fsSL -o /tmp/supabase.deb https://github.com/supabase/cli/releases/download/v2.105.0/supabase_2.105.0_linux_amd64.deb
sudo dpkg -i /tmp/supabase.deb

# node LTS (optionnel : les workflows tournent en container node:20 ; utile si dev local)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs
```
Contrôle : `restic version` · `supabase --version` · `docker run --rm hello-world` · `pg_dump --version` (→ 17.x) · `jq --version`.

---

## 4. Phase 2 — Secrets & connectivité

1. **Poser les 4 secrets** (depuis USB ou scp), puis :
   ```bash
   chmod 700 ~/.ssh ~/.config ~/.supabase
   chmod 600 ~/.ssh/id_ed25519_bg2 ~/.config/restic-anarbib.pass ~/.pgpass ~/.supabase/access-token ~/.ssh/config
   ```
2. **Tests de connectivité** (aucune écriture) :
   ```bash
   ssh -o BatchMode=yes bricolage.herbesfolles.org true && echo "SSH Herbes Folles OK"
   RESTIC_PASSWORD_FILE=~/.config/restic-anarbib.pass \
     restic -r sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-long snapshots | tail
   psql "host=aws-1-sa-east-1.pooler.supabase.com port=5432 dbname=postgres user=postgres.uflwmikiyjfnikiphtcp sslmode=require" -c "select 1"
   supabase projects list        # doit voir le projet via le token
   ```

---

## 5. Phase 3 — Portage du convoyeur de sauvegarde (#BG2)

### 5.1 Cloner + lier le repo (nécessaire au flux storage `--linked`)
```bash
git clone <url-codeberg-ssh>:AnarBib/anarbib.git ~/anarbib
cd ~/anarbib && supabase link --project-ref uflwmikiyjfnikiphtcp   # recree supabase/.temp/*
```

### 5.2 Porter `~/anarbib-ops/` (non versionné)
Copier depuis le WSL **seulement** le code et les listes de classement — **pas** les répertoires de travail :
- À copier : `anarbib-bg2.sh`, `anarbib-notify-failure.sh`, `wait-for-docker.sh`, `bg2-known-tables.txt`, `bg2-denylist.txt`, `bg2-exclude-long.txt`.
- À NE PAS copier : `.work/`, `.storage-work/` (re-sync propre — profite du fix nesting BG2-AUTO-6), `.last-failure`, les `*.bak`.
```bash
mkdir -p ~/anarbib-ops && chmod 700 ~/anarbib-ops
# scp/USB des 6 fichiers ci-dessus, puis :
chmod +x ~/anarbib-ops/*.sh
~/anarbib-ops/anarbib-bg2.sh check     # preflight + filet, aucun envoi
```

### 5.3 Installer les timers systemd (user + linger)
Copier les 7 unités relevées vers `~/.config/systemd/user/` :
`anarbib-backup-{court,long,storage}.{timer,service}` + `anarbib-backup-failure@.service`.
```bash
loginctl enable-linger "$USER"          # timers sans session ouverte (comme le WSL)
systemctl --user daemon-reload
systemctl --user enable --now anarbib-backup-court.timer anarbib-backup-long.timer anarbib-backup-storage.timer
systemctl --user list-timers | grep anarbib
```
Cadence conservée : court quotidien 02:00, long dimanche 03:00, storage dimanche 04:00.

### 5.4 Premier tir réel + validation
```bash
systemctl --user start anarbib-backup-court.service      # ExecStartPre efface .last-failure
systemctl --user start anarbib-backup-long.service
systemctl --user start anarbib-backup-storage.service
# Attendus : rc=0, .last-failure absent, nouveaux snapshots restic, .work vide (hygiene PII)
test -f ~/anarbib-ops/.last-failure && echo "ECHEC" || echo "OK bout-en-bout"
```

### 5.5 Dead-man's-switch (BG2-AUTO-4 niveau 3, enfin possible)
Une box **peut être éteinte** → l'alerte `.bashrc` (WSL) est inutile en headless. Brancher un **ping externe de vie** (healthchecks.io gratuit, ou ntfy auto-hébergé plus tard) : petit `curl` de succès en fin de `anarbib-bg2.sh`, et l'agrégateur alerte **si aucun ping** dans la fenêtre. C'est le seul niveau qui détecte « le timer n'a jamais tourné ». (Édit ciblé du script, à faire proprement — surgery ancrée.)

---

## 6. Phase 4 — Bascule du runner Forgejo Actions

### 6.1 Installer + enregistrer
```bash
curl -fsSL -o /tmp/forgejo-runner https://code.forgejo.org/forgejo/runner/releases/download/v12.10.2/forgejo-runner-12.10.2-linux-amd64
sudo install -m755 /tmp/forgejo-runner /usr/local/bin/forgejo-runner

mkdir -p ~/forgejo-runner && cd ~/forgejo-runner
forgejo-runner register --no-interactive \
  --instance https://codeberg.org \
  --token <REGISTRATION_TOKEN> \
  --name anarbib-srv \
  --labels anarbib-local          # MEME label -> runs-on: anarbib-local inchange dans les workflows
```
> Le label `anarbib-local` est réutilisé volontairement : les workflows (`runs-on: anarbib-local`) fonctionnent sans toucher au YAML. Le runner a besoin de **Docker** (l'user doit être dans le groupe `docker`) : ci.yml tourne en `container: node:20`, sql-tests lance un service Postgres.

### 6.2 Daemon systemd + capacité
```bash
# /etc/systemd/system/forgejo-runner.service
# [Service]
# ExecStart=/usr/local/bin/forgejo-runner daemon
# WorkingDirectory=/home/accattone/forgejo-runner
# User=accattone
# Restart=always
sudo systemctl daemon-reload && sudo systemctl enable --now forgejo-runner
```
- **8 Go / i3** → limiter la **concurrence à 1 job** (config runner `capacity: 1`). Le pic mémoire (image Postgres 1,67 Go + node + migrations) tient à l'échelle actuelle ; le swap de 4 Go amortit.

### 6.3 Valider avant de couper l'ancien
- Déclencher un `workflow_dispatch` (sql-tests a `workflow_dispatch: {}`) et vérifier que **le nouveau runner** prend le job (log Forgejo → nom du runner).
- Confirmer un run vert de bout en bout.

---

## 7. Phase 5 — Bascule finale & décommission WSL

1. **Backups** : laisser tourner **les deux** (WSL + box) en parallèle **une semaine** (double snapshot = inoffensif) pour confirmer la fiabilité de la box. Puis **désactiver les timers WSL** (`systemctl --user disable --now anarbib-backup-*.timer`) — la box devient l'unique convoyeur.
2. **Runner** : bascule nette (pas de doublon utile). Une fois le nouveau validé, **arrêter** le runner WSL (`forgejo-runner` daemon) et le **supprimer** côté Codeberg (Settings → Runners → delete). Éviter que les deux se partagent le label pendant un run.
3. Mettre à jour le RUNBOOK (`docs/journal/operations/`) : l'exploitation #BG2 vit désormais sur `anarbib-srv`, pas sur le WSL.

---

## 8. Exploitation courante & garde-fous

- **Point de défaillance unique** : box = convoyeur/runner, jamais dépôt. Herbes Folles + `F:` froid restent les remparts.
- **Accès distant sûr** : installer **Tailscale** (`curl -fsSL https://tailscale.com/install.sh | sh`) → SSH depuis n'importe où sans ouvrir de port ni IP publique. Idéal pour une box résidentielle.
- **Disque 128 Go** : `docker system prune -af` mensuel (timer) ; surveiller `~/anarbib-ops/.storage-work` (le fix nesting est en place) et `~/anarbib-ops/.work` (doit rester vide après chaque tir — trap EXIT).
- **Sécurité** : pas de port entrant ouvert sur internet ; UFW en deny-in par défaut, allow SSH sur le LAN/Tailscale ; `unattended-upgrades` pour les CVE.
- **Après coupure courant** : BIOS AC-recovery = On + `Persistent=true` des timers rattrapent un tir manqué au retour.

---

## Annexe — Inventaire relevé sur le WSL le 2026-07-04 (référence de portage)

- **Outils** : restic 0.18.1 · supabase CLI 2.105.0 · docker 29.6.1 · node v22.22.1 · pg_dump/psql (client 17) · git · curl · shred. **jq ABSENT** (à installer).
- **Runner** : `forgejo-runner v12.10.2` (`/usr/local/bin`), daemon actif, fichier `~/.runner`, label `anarbib-local`.
- **systemd user** : court.timer `*-*-* 02:00`, long.timer `Sun *-*-* 03:00`, storage.timer `Sun *-*-* 04:00` (tous `Persistent=true`, `RandomizedDelaySec=120`) ; services `Type=oneshot`, `ExecStartPre=-/bin/rm -f %h/anarbib-ops/.last-failure`, `OnFailure=anarbib-backup-failure@%n.service`. `Linger=yes`.
- **Secrets (perms 600)** : `~/.ssh/id_ed25519_bg2` · `~/.config/restic-anarbib.pass` · `~/.pgpass` · `~/.supabase/access-token`.
- **SSH** : Host `bricolage.herbesfolles.org`, User `anarbib`, `IdentitiesOnly yes`, `IdentityAgent none`.
- **Repo lié** : `~/anarbib` avec `supabase/.temp/linked-project.json` (project-ref `uflwmikiyjfnikiphtcp`). Flux storage : `cd ~/anarbib && supabase storage cp --linked --experimental` (d'où le clone + link requis).
- **Destinations backup** : `sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-{court,long,storage}` + réplique froide `F:` (hors-ligne).

> Rappel doctrine : `~/anarbib-ops/` n'est PAS versionné (contient la chaîne de connexion prod). Ce plan ne contient aucune valeur de secret, seulement leurs emplacements.
