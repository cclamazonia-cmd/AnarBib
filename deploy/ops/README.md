# `deploy/ops/` — la chaîne de sauvegarde #BG2

**Ce dossier est la source de vérité.** Ce qui tourne sur le poste de travail
n'en est qu'un lien symbolique.

## Pourquoi ce dossier existe

Jusqu'au 20/08/2026, la chaîne de sauvegarde vivait **entièrement hors dépôt**,
dans `~/anarbib-ops/` et `~/.config/systemd/user/`. Le dépôt, lui, contenait
`scripts/backup/anarbib-backup.sh` — un script du 17/06 décrivant un modèle
*pull* depuis un VPS qui n'a jamais existé. Un lecteur de bonne foi en concluait
que les sauvegardes tournaient sur un serveur, sans le poste de travail. Faux.

Ce script est parti aux archives le 21/08/2026 : plus rien ne l'appelait, et son
nom sous `scripts/` le faisait passer pour vivant. Il est désormais dans
[`operations/archive/`](../../docs/journal/operations/archive/anarbib-backup_modele-pull_HORS-SERVICE_2026-06-17.sh),
sous un nom qui dit son état, gardé comme point de départ le jour d'une bascule
sur un hôte. **Il n'y a donc plus qu'un seul script de sauvegarde dans ce dépôt :
celui d'à côté.**

C'est le même angle mort que `deploy/genkeys.mjs` le 19/08, et que les six
versions d'images épinglées le 20/08 : **ce qui n'est pas dans le dépôt n'existe
qu'une fois.** Ici, sur la brique dont dépend tout le reste.

## Ce qu'il contient

| Fichier | Rôle |
|---|---|
| `anarbib-bg2.sh` | Les trois flux restic (`court`, `long`, `storage`), le filet de classement des tables, le dump du Vault, l'auto-réparation des verrous |
| `anarbib-notify-failure.sh` | Appelé par `OnFailure=` quand un flux échoue |
| `anarbib-bg2-fraicheur.sh` | Le contrôle de fraîcheur : lit les trois dépôts restic et signale les flux en retard (lecture seule) |
| `systemd/*.service` · `systemd/*.timer` | Les unités utilisateur : trois flux, l'unité de notification, le contrôle de fraîcheur |

## Ce qu'il ne contient pas, et pourquoi

- **`bg2-denylist.txt` et `bg2-exclude-long.txt`** — ces deux listes *nomment*
  des tables de données personnelles, et le dépôt est public. Décision maintenue.
  Elles restent dans `~/anarbib-ops/`. (`bg2-known-tables.txt`, lui, est au dépôt
  et vérifié par la CI : il ne nomme rien de sensible.)
- **`fix-filet.sh`** — son propre en-tête porte la consigne « à garder HORS du
  repo ». Respectée.
- **La passphrase restic** — dans `~/.config/restic-anarbib.pass`, jamais ici.
- **`wait-for-docker.sh`** — appartient à la chaîne du runner Forgejo, pas aux
  sauvegardes. Reste à verser, hors périmètre.

## Le lien symbolique, et le sens du lien

```
~/anarbib-ops/anarbib-bg2.sh            -> <dépôt>/deploy/ops/anarbib-bg2.sh
~/anarbib-ops/anarbib-notify-failure.sh -> <dépôt>/deploy/ops/anarbib-notify-failure.sh
~/.config/systemd/user/anarbib-backup-*.{service,timer}
                                        -> <dépôt>/deploy/ops/systemd/…
```

Même convention que `bg2-known-tables.txt`, déjà en place depuis le 20/08 au
matin : **une seule copie, aucune divergence possible.** On modifie ici, on
commite ici ; le poste suit sans qu'on ait à y penser.

### Sur une machine neuve

```sh
ln -sf "$PWD/deploy/ops/anarbib-bg2.sh"            ~/anarbib-ops/anarbib-bg2.sh
ln -sf "$PWD/deploy/ops/anarbib-notify-failure.sh" ~/anarbib-ops/anarbib-notify-failure.sh
for u in deploy/ops/systemd/*; do
  ln -sf "$PWD/$u" ~/.config/systemd/user/"$(basename "$u")"
done
systemctl --user daemon-reload
systemctl --user enable --now anarbib-backup-{court,long,storage}.timer
```

Puis le contrôle de fraîcheur (même convention : une seule copie, dans le dépôt) :

```sh
ln -sf "$PWD/deploy/ops/anarbib-bg2-fraicheur.sh" ~/anarbib-ops/anarbib-bg2-fraicheur.sh
ln -sf "$PWD/deploy/ops/systemd/anarbib-fraicheur.service" ~/.config/systemd/user/
ln -sf "$PWD/deploy/ops/systemd/anarbib-fraicheur.timer"   ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now anarbib-fraicheur.timer
```

… et le bloc `~/.bashrc` ci-dessus, sans lequel le drapeau ne s'affiche nulle part.

Restent à fournir à la main, et ce n'est pas un oubli : les deux listes PII, la
passphrase restic, et `~/.pgpass`.

## Le contrôle de fraîcheur

Trois gardes veillaient déjà sur la chaîne, et le 16/08 les trois se sont tues
en même temps. Le tir `storage` a été tué au bout de 20 s par l'extinction de la
machine ; `OnFailure=` n'a pas pu partir — systemd refuse d'enfiler un job de
notification pendant un arrêt — et le flux est resté **onze jours** sans
sauvegarder sans que personne le sache.

Chaque garde a le même angle mort, à sa façon :

| Garde | Ce qu'elle voit | Ce qu'elle ne voit pas |
|---|---|---|
| `OnFailure=` | les erreurs | les silences — et elle se tait quand la cause est l'arrêt |
| Témoin de vie (BG2-16) | qu'un tir a abouti | rien du tout si le poste est éteint : il n'émet pas |
| `fn_backup_heartbeat_status()` | très bien le silence | mais depuis la base, et elle ne parle à personne assis devant la machine |

`anarbib-bg2-fraicheur.sh` regarde depuis le quatrième point de vue : **le poste,
au réveil**. Il ouvre les trois dépôts restic, lit la date du dernier snapshot de
chaque flux et la compare à l'intervalle attendu.

Il lit **les dépôts**, pas la table des témoins — que la sonde surveille déjà. Un
témoin dit « le script a cru réussir » ; un snapshot dit « la donnée est là ».
Deux affirmations différentes : mieux vaut deux témoins indépendants qu'un seul
consulté depuis deux endroits.

Trois issues, et les confondre serait refaire le bug :

- **flux en retard** → drapeau `~/anarbib-ops/.fraicheur-alerte`, sortie `1` ;
- **dépôt injoignable** → aucun verdict, et surtout **aucune affirmation de
  fraîcheur** : on n'a pas pu regarder, on ne dit pas que tout va bien ;
- **aveuglement prolongé** → au-delà de 72 h sans avoir pu lire un dépôt,
  l'impossibilité de vérifier devient elle-même l'alerte, sortie `3`.

Les seuils (36 h · 9 j · 9 j) sont **alignés sur `fn_backup_heartbeat_status()`**.
Si tu changes ici, change là-bas : deux gardes qui jugeraient différemment
feraient perdre du temps à se demander laquelle a raison.

> ⚠️ **Piège restic, vérifié le 21/08/2026.** `restic snapshots --latest 1` rend
> *n* snapshots **par groupe** `(host, paths)`. Le dépôt `long` en a trois groupes
> depuis que le dump du Vault s'est ajouté au chemin (BG2-15) : `--latest 1` y
> rend donc **trois** lignes, dont la première date du 30/06. Un `head -1` dessus
> fait dire au contrôle que le flux a 51 jours de retard, tous les jours — le
> genre d'alerte permanente qu'on apprend à ignorer en une semaine. Le script lit
> toutes les dates et prend le maximum. `snapshot_id_de()` dans `anarbib-bg2.sh`
> portait le même défaut ; corrigé.

### Comment l'alerte devient visible

Le drapeau ne sert à rien si personne ne le lit. C'est `~/.bashrc` qui l'affiche,
à chaque ouverture de terminal, à côté du bloc qui surveille déjà `.last-failure` :

```sh
# --- ANARBIB_FRAICHEUR_FLAG_CHECK : alerte si une sauvegarde a pris du retard ---
if [ -f "$HOME/anarbib-ops/.fraicheur-alerte" ]; then
  printf '\033[1;33m[AnarBib] Sauvegarde EN RETARD :\033[0m %s\n' \
    "$(head -1 "$HOME/anarbib-ops/.fraicheur-alerte")"
  printf '  Details : cat ~/anarbib-ops/.fraicheur-alerte\n'
fi
```

`~/.bashrc` n'est pas versionné : sur une machine neuve, ce bloc est à recopier.

## Les horaires

`19:00`, `dimanche 20:00`, `dimanche 21:00` — **en `Europe/Paris`**, fuseau nommé
dans les unités. L'heure de tir suit la personne qui exploite la chaîne, pas le
fuseau du portable, qui change en voyage ; et l'heure d'été se gère seule.

Avant le 20/08 les tirs étaient à 2 h, 3 h et 4 h heure machine — ils ne
tombaient donc jamais sur une machine éveillée, et `Persistent=true` les
rattrapait au réveil, au pire moment. C'est ainsi que le tir du 20/08 est mort en
plein repack. Voir
[`NOTE_angle-mort_tir-interrompu_2026-08-20`](../../docs/journal/operations/NOTE_angle-mort_tir-interrompu_2026-08-20.md).

## Pour restaurer

[`RUNBOOK_restauration_BG2_2026-07-01`](../../docs/journal/operations/RUNBOOK_restauration_BG2_2026-07-01.md)
— trois flux, rétention 7/4/6, procédure de réinjection des secrets du Vault.
