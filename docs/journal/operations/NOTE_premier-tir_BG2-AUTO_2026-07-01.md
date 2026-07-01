# NOTE — Premier tir réel des sauvegardes automatiques (#BG2-AUTO)

*Créée le 01/07/2026. À exécuter le jour où Herbes Folles a (a) ajouté la clé
automate `id_ed25519_bg2` aux clés autorisées du compte `anarbib` et (b) désactivé
l'authentification par mot de passe. Tant que ces deux conditions ne sont pas
réunies, les timers tirent mais échouent proprement (drapeau `.last-failure`,
dump PII nettoyé — cf. REGISTRE BG2-AUTO-4 et BG2-AUTO-5).*

## Contexte

- Infrastructure d'automatisation **construite et vérifiée** le 01/07 : clé dédiée,
  script patché (mode automate + filet RGPD), 3 timers systemd user actifs,
  chaîne `OnFailure` + drapeau, amorçage WSL au login Windows.
- **En attente** : feu vert Herbes Folles (mail de relance envoyé le 01/07 avec la
  clé publique `id_ed25519_bg2` + demande de désactivation du mot de passe).
- Décisions : REGISTRE §BG2 (suite), BG2-AUTO-1..5. Exploitation : RUNBOOK §7.

## Checklist du jour J (dans l'ordre)

### 1. Tester la connexion SFTP avec la clé dédiée

La clé dédiée doit être acceptée par le serveur. Test isolé, avant tout backup :

```bash
sftp -i ~/.ssh/id_ed25519_bg2 anarbib@bricolage.herbesfolles.org
# au prompt sftp> : pwd ; ls ; puis bye
```

Attendu : connexion **sans** demande de mot de passe (preuve que la bascule
clé-seule est effective côté serveur) et **sans** passphrase (clé dédiée sans
passphrase). Si le mot de passe est encore demandé -> la désactivation n'est pas
faite côté serveur, relancer Herbes Folles avant d'aller plus loin.

### 2. Déclencher un tir manuel `court` et vérifier qu'il RÉUSSIT

```bash
systemctl --user start anarbib-backup-court.service
journalctl --user -u anarbib-backup-court.service -n 20 --no-pager
```

Attendu :
- plus d'erreur `Permission denied (publickey)` ;
- le `restic backup` aboutit (snapshot créé) ;
- le drapeau `~/anarbib-ops/.last-failure` **disparaît** (effacé par `ExecStartPre`
  au tir suivant, ou absent si ce tir réussit) ;
- vérifier le snapshot : `restic -r sftp:anarbib@bricolage.herbesfolles.org:/data/anarbib-court snapshots | tail`.

### 3. Éprouver les branches jamais testées en exécution réelle

Le prompt de reprise notait : branches `court` / `storage` / `restore-test` du
script **pas encore éprouvées en exécution réelle** (seul `check` était validé).
Une fois la connexion établie :

```bash
# storage (resync + envoi) — le plus long
systemctl --user start anarbib-backup-storage.service
journalctl --user -u anarbib-backup-storage.service -n 30 --no-pager

# restore-test non destructif (Docker jetable, sequence auth -> long -> court)
~/anarbib-ops/anarbib-bg2.sh restore-test
```

Attendu restore-test : comptages cohérents (tables public ~172, auth.users et
profiles non nuls, books ~2674). C'est le juge de vérité, pas le nombre d'erreurs.

### 4. Vérifier que l'accès MANUEL (clé principale) marche encore

La désactivation du mot de passe ne doit pas casser ton accès manuel via la clé
principale à passphrase :

```bash
sftp -i ~/.ssh/id_ed25519 anarbib@bricolage.herbesfolles.org
# passphrase de la cle principale demandee, PAS de mot de passe compte
```

### 5. Éprouver le ré-upload Storage (jamais testé)

Le prompt de reprise notait : le sens **local -> bucket** (ré-upload) n'a jamais
été testé, seul le download l'a été. Sur un bucket-témoin, chronomètre en main,
valider le runbook de restauration Storage de bout en bout (RUNBOOK §3.3 / §4.1).

## Après validation

- Mettre à jour REGISTRE : la MàJ du 01/07 dit « bascule mot de passe -> clé SSH :
  faite ». Une fois le premier tir réel réussi, cette affirmation devient
  pleinement exacte (à ce jour, bascule côté usage faite, désactivation serveur
  en attente).
- Le premier succès efface le drapeau ; les timers tournent alors en régime
  nominal (court quotidien, long/storage hebdo).
- Supprimer cette note (ou l'archiver) une fois les 5 points validés.
