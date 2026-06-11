# SETUP — Runner Forgejo Actions auto-hébergé (WSL2)  · 2026-06-11

**Auteur :** Xavier + Claude (session « Catalogação work completion »)
**Statut :** ✅ en place et validé (run `eb15306` vert : `app` 1m56s + `backend` 1m2s).

## Pourquoi

Les runners **mutualisés** Codeberg imposent une **limite ~5 min par job**
(« The runner cancelled the job because it exceeds the maximum run time ») + une
file d'attente → ~15 min par push, intenable en dev fréquent. Le « podman context
deadline exceeded » qu'on pourchassait n'était que le **symptôme** du conteneur tué
à la limite.

**Solution retenue : runner AUTO-HÉBERGÉ en local (WSL2), gratuit.** On reste sur
Codeberg (valeurs intactes, zéro migration). VPS écarté (coût). Justification :
Xavier est **seul dev** → personne ne pushe quand sa machine est éteinte, donc
l'avantage « toujours dispo » d'un VPS ne sert pas — le runner ne doit tourner que
**quand il bosse**. On-brand (cf. `arbitrages/RIFLEXION_self-hosting`).

Machine : Intel i5-10300H (4c/8t), 32 Go RAM, WSL2 **Ubuntu-26.04**, Docker Desktop.

## Procédure (reproductible)

### 1. Docker accessible dans WSL
- Docker Desktop → Settings → Resources → **WSL Integration** → cocher `Ubuntu-26.04`.
- Autoriser l'user à parler à la socket (sinon `permission denied /var/run/docker.sock`) :
  ```bash
  sudo usermod -aG docker $USER
  ```
  puis `wsl --shutdown` (PowerShell) + rouvrir Ubuntu. Vérifier : `docker run --rm hello-world` (sans sudo).

### 2. Installer forgejo-runner
```bash
cd ~
curl -sLo forgejo-runner https://code.forgejo.org/forgejo/runner/releases/download/v12.10.2/forgejo-runner-12.10.2-linux-amd64
chmod +x forgejo-runner && sudo mv forgejo-runner /usr/local/bin/
forgejo-runner --version
```

### 3. Enregistrer le runner
- Jeton : Codeberg → dépôt → **Paramètres → Actions → Exécuteurs → « Afficher le jeton
  d'enregistrement »**. ⚠️ **Ce jeton ≠ l'identifiant (UUID) affiché sous un runner** — le
  piège classique (coller l'UUID → `runner registration token not found`).
- Enregistrer (l'astuce `read` évite les soucis de collage) :
  ```bash
  cd ~ ; read -r TOKEN   # coller le jeton, Entrée
  forgejo-runner register --no-interactive \
    --instance https://codeberg.org --token "$TOKEN" \
    --name anarbib-local --labels "anarbib-local:docker://node:20"
  ```
  Le label `anarbib-local` est ce que cible `runs-on:` (le **nom** est cosmétique).

### 4. Service systemd (démarrage auto + auto-relance)
- systemd doit être actif dans WSL. Si `systemctl is-system-running` répond `offline` :
  ```bash
  grep -q 'systemd=true' /etc/wsl.conf 2>/dev/null || printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf
  ```
  puis `wsl --shutdown` (PowerShell) + rouvrir.
- Service :
  ```bash
  sudo tee /etc/systemd/system/forgejo-runner.service >/dev/null <<'EOF'
  [Unit]
  Description=Forgejo Actions runner (AnarBib anarbib-local)
  After=network-online.target
  Wants=network-online.target

  [Service]
  Type=simple
  User=accattone
  WorkingDirectory=/home/accattone
  ExecStart=/usr/local/bin/forgejo-runner daemon
  Restart=always
  RestartSec=5

  [Install]
  WantedBy=multi-user.target
  EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now forgejo-runner
  systemctl status forgejo-runner --no-pager
  ```
  `WorkingDirectory` doit pointer le dossier contenant le `.runner` (ici `~` = `/home/accattone`).

### 5. Brancher le workflow
`.forgejo/workflows/ci.yml` : `runs-on: anarbib-local` (les 2 jobs `app` / `backend`).
Les **secrets dépôt** sont inchangés — Codeberg les transmet au runner au moment du job.

## Notes d'exploitation

- **Docker Desktop doit tourner** quand Xavier bosse (les jobs s'exécutent dans Docker).
  Le régler en démarrage auto : Docker Desktop → Settings → General → *Start when you sign in*.
- Le runner ne traite les jobs que **machine allumée + WSL up** → voulu (seul dev). S'il est
  hors-ligne, les runs **attendent** (ne se perdent pas).
- 1er run : `docker pull node:20` une fois (~1 Go). Ensuite ~1-2 min/job.
- Le découpage `app`/`backend` n'est plus imposé par la limite 5 min (disparue), mais conservé
  (isolation + parallélisme).

## Pièges rencontrés (et résolus)
1. `permission denied /var/run/docker.sock` → groupe `docker` (étape 1).
2. `runner registration token not found` → on collait l'**UUID** du runner au lieu du **jeton
   d'enregistrement** (« Afficher le jeton d'enregistrement »).
3. `systemctl is-system-running` → `offline` → systemd pas actif dans WSL → `/etc/wsl.conf`.
4. Run « en attente », *« aucun exécuteur en ligne correspondant au libellé anarbib-local »* →
   daemon arrêté (lancé en foreground) → résolu par le service systemd.
