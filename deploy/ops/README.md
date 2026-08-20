# `deploy/ops/` — la chaîne de sauvegarde #BG2

**Ce dossier est la source de vérité.** Ce qui tourne sur le poste de travail
n'en est qu'un lien symbolique.

## Pourquoi ce dossier existe

Jusqu'au 20/08/2026, la chaîne de sauvegarde vivait **entièrement hors dépôt**,
dans `~/anarbib-ops/` et `~/.config/systemd/user/`. Le dépôt, lui, contenait
`scripts/backup/anarbib-backup.sh` — un script du 17/06 décrivant un modèle
*pull* depuis un VPS qui n'a jamais existé. Un lecteur de bonne foi en concluait
que les sauvegardes tournaient sur un serveur, sans le poste de travail. Faux.

C'est le même angle mort que `deploy/genkeys.mjs` le 19/08, et que les six
versions d'images épinglées le 20/08 : **ce qui n'est pas dans le dépôt n'existe
qu'une fois.** Ici, sur la brique dont dépend tout le reste.

## Ce qu'il contient

| Fichier | Rôle |
|---|---|
| `anarbib-bg2.sh` | Les trois flux restic (`court`, `long`, `storage`), le filet de classement des tables, le dump du Vault, l'auto-réparation des verrous |
| `anarbib-notify-failure.sh` | Appelé par `OnFailure=` quand un flux échoue |
| `systemd/*.service` · `systemd/*.timer` | Les unités utilisateur : trois flux + l'unité de notification |

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

Restent à fournir à la main, et ce n'est pas un oubli : les deux listes PII, la
passphrase restic, et `~/.pgpass`.

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
