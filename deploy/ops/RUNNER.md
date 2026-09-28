# Le runner d'intégration continue — remise en route, déménagement

> Pour quelqu'un qui ne l'a pas installé. Relu contre la machine réelle le
> 28/09/2026 (WSL2 Ubuntu-26.04 sur le portable du mainteneur, `forgejo-runner`
> v12.10.2, Docker Desktop 29.8). Le récit d'installation de juin est dans
> `docs/journal/operations/SETUP_runner_wsl2_2026-06-11.md` ; ici, l'exploitation.

## Ce que c'est, et pourquoi ça compte

Rien ne se déploie sans lui. Un push sur `main` chez Codeberg crée des *tâches*
(`app`, `backend`, `sql-tests`, `rejeu-image`…) ; un **runner** — le programme
`forgejo-runner`, enregistré auprès du dépôt sous le label `anarbib-local` —
vient les chercher, les exécute dans des conteneurs Docker et rend le
résultat. Il tourne aujourd'hui **sur le poste de travail du mainteneur**
(backlog A3). Machine éteinte, en veille, Docker coupé : les tâches attendent ;
une tâche interrompue en route est déclarée en échec par la forge au bout d'une
heure, et **le job suivant de la chaîne (`backend` après `app`) ne se lance
jamais de lui-même**. Le 27/09 au soir, une migration a ainsi attendu le push
du lendemain sans que personne le sache. Depuis le 28/09, `health-probe`
envoie un courriel « chaîne de déploiement en retard » (kind `ci_en_retard`).

Le runner traite **une tâche à la fois**. Un push qui touche une migration
déclenche `sql-tests` + `rejeu-image` (12 à 17 min) *et* `app` + `backend` (9 à
14 min) : avec plusieurs sessions qui poussent, la file s'allonge, c'est normal.

## Où il vit sur la machine

| Quoi | Où | Au dépôt ? |
|---|---|---|
| le binaire | `/usr/local/bin/forgejo-runner` (v12.10.2, sha256 `8d8cc22b…2163f`) | non (téléchargé, étape 2 du SETUP) |
| l'enregistrement — **contient un jeton, ne se copie jamais dans le dépôt** | `~/.runner` (`name: anarbib-local`, `labels: [anarbib-local:docker://node:20]`, `address: https://codeberg.org`) | non |
| l'unité systemd | `/etc/systemd/system/forgejo-runner.service` → lien vers `deploy/ops/systemd/forgejo-runner.service` | oui |
| son drop-in (efface le drapeau d'échec au démarrage) | `…/forgejo-runner.service.d/clear-stale-flag.conf` → lien | oui |
| l'attente de Docker (`ExecStartPre`) | `~/anarbib-ops/wait-for-docker.sh` → lien vers `deploy/ops/wait-for-docker.sh` | oui |
| l'alerte locale d'échec (`OnFailure=`) | `forgejo-runner-failure.service` → `deploy/ops/forgejo-runner-notify-failure.sh`, écrit `~/anarbib-ops/.last-failure-runner` | oui |
| le journal | `journalctl -u forgejo-runner` (root ou groupe `systemd-journal`) | — |

Le label du `.runner` dit `node:20` ; les workflows imposent leur propre image
(`container: image: node:22`) — le label n'est qu'un défaut, il ne sert pas.

## Savoir s'il tourne (deux minutes)

```sh
# 1. le processus
pgrep -af "forgejo-runner daemon"          # une ligne, sinon il ne tourne pas
# 2. ce qu'il a fait — JAMAIS `systemctl status`, qui ment sur ce poste
journalctl -u forgejo-runner -n 20 --no-pager
#    « task NNN repo is AnarBib/anarbib » = il prend des tâches ;
#    « ReportLog error: deadline_exceeded » = il ne joint plus codeberg.org (réseau) ;
#    rien depuis longtemps = il dort, ou la file est vide (regarder la forge)
# 3. Docker
docker ps --format '{{.Names}} {{.Status}}' | grep -i FORGEJO   # une tâche en cours = un conteneur FORGEJO-ACTIONS-TASK-…
```

Sur la forge : `https://codeberg.org/anarbib/anarbib/actions` — une tâche
« En attente » avec *« aucun exécuteur en ligne correspondant au libellé
anarbib-local »* dit tout.

## Remise en route

1. **Docker Desktop** (côté Windows) doit tourner, avec l'intégration WSL
   `Ubuntu-26.04` cochée (Settings → Resources → WSL Integration). Le service
   l'attend jusqu'à 120 s (`wait-for-docker.sh`) puis échoue.
2. Dans WSL : `sudo systemctl start forgejo-runner`, puis `journalctl -u forgejo-runner -n 5`.
   Si `~/anarbib-ops/.last-failure-runner` existe, il dit pourquoi le dernier
   démarrage a échoué ; le drop-in l'efface au démarrage suivant.
3. **Relancer ce qui a été perdu.** Un job déclaré en échec pendant l'arrêt ne
   se rejoue pas tout seul : sur la page du run, *Relancer* (ou pousser un
   commit). Vérifier ensuite que la migration attendue est appliquée
   (`supabase_migrations.schema_migrations`) — le marqueur `deployed-functions`
   est posé AVANT `db push`, il ne prouve pas la migration.

Après un redémarrage de WSL (`wsl --shutdown`, mise à jour Windows), le service
repart seul (`WantedBy=multi-user.target`, `Restart=on-failure`). Après une
mise en veille du portable, WSL repart aussi ; ce sont les tâches en cours au
moment de la veille qui sont perdues (point 3).

## Installer sur une autre machine (le déménagement d'A3)

Deux runners peuvent porter **le même label** : la forge donne chaque tâche au
premier disponible. On peut donc enregistrer la nouvelle machine, la laisser
travailler à côté de l'ancienne, puis retirer l'ancienne — sans coupure.

Prérequis : Linux (ou WSL2) avec Docker, 4 Go de RAM libres, ~15 Go de disque
(images `node:22`, `supabase/postgres`, `supabase/edge-runtime`), le réseau
sortant vers `codeberg.org` et `data.forgejo.org`.

```sh
# 1. le binaire (la version qui tourne ; en changer = le noter ici)
curl -sLo forgejo-runner https://code.forgejo.org/forgejo/runner/releases/download/v12.10.2/forgejo-runner-12.10.2-linux-amd64
chmod +x forgejo-runner && sudo mv forgejo-runner /usr/local/bin/
forgejo-runner --version

# 2. l'enregistrement — le JETON D'ENREGISTREMENT, pas l'UUID d'un runner existant
#    Codeberg → dépôt → Paramètres → Actions → Exécuteurs → « Afficher le jeton d'enregistrement »
cd ~ ; read -r TOKEN
forgejo-runner register --no-interactive --instance https://codeberg.org --token "$TOKEN" \
  --name anarbib-<machine> --labels "anarbib-local:docker://node:22"
#    → écrit ~/.runner (0644, à laisser hors de tout dépôt)

# 3. l'unité et ses liens (le dépôt cloné dans ~/anarbib, ou adapter les chemins)
mkdir -p ~/anarbib-ops
ln -sf ~/anarbib/deploy/ops/wait-for-docker.sh ~/anarbib-ops/wait-for-docker.sh
sudo ln -sf ~/anarbib/deploy/ops/systemd/forgejo-runner.service /etc/systemd/system/forgejo-runner.service
sudo ln -sf ~/anarbib/deploy/ops/systemd/forgejo-runner-failure.service /etc/systemd/system/forgejo-runner-failure.service
sudo mkdir -p /etc/systemd/system/forgejo-runner.service.d
sudo ln -sf ~/anarbib/deploy/ops/systemd/forgejo-runner.service.d/clear-stale-flag.conf /etc/systemd/system/forgejo-runner.service.d/clear-stale-flag.conf
#    l'unité nomme l'utilisateur `accattone` et /home/accattone : sur une autre
#    machine, un drop-in local (non versionné) les remplace :
sudo tee /etc/systemd/system/forgejo-runner.service.d/machine.conf >/dev/null <<EOF
[Service]
User=$USER
WorkingDirectory=$HOME
ExecStartPre=
ExecStartPre=$HOME/anarbib-ops/wait-for-docker.sh 120
EOF
sudo systemctl daemon-reload && sudo systemctl enable --now forgejo-runner
journalctl -u forgejo-runner -n 5 --no-pager
```

Ou, sans systemd, le runner en conteneur : `deploy/runner/` (compose), même
enregistrement, même label.

4. Vérifier : pousser un commit anodin (ou *Relancer* un run) et lire sur la
   forge quel runner a pris la tâche (le nom apparaît en tête du journal du job :
   `anarbib-<machine>(version:v12.10.2) received task…`).
5. Retirer l'ancienne machine : `sudo systemctl disable --now forgejo-runner` chez
   elle, puis, sur la forge, supprimer le runner `anarbib-local` (Paramètres →
   Actions → Exécuteurs). Les secrets du dépôt ne bougent pas : c'est la forge
   qui les transmet au runner à chaque tâche.

## Ce qui n'est pas réglé par un déménagement

Le runner est **un**, en série : deux workflows par push de migration, l'un
derrière l'autre. Le sortir du poste règle la disponibilité (A3), pas la
lenteur. Ce qui la réglerait : `rejeu-image` une fois par nuit plutôt qu'à
chaque push, ou un second runner.
