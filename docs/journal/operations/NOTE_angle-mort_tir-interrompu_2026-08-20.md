# NOTE — L'angle mort du tir interrompu

**Date** : 20 août 2026
**Statut** : 🔎 constaté et documenté — correctif proposé, pas encore appliqué
**Portée** : chaîne #BG2, flux `court` / `long` / `storage`

---

## Ce qui s'est passé

Le tir `court` du 20/08 à 11 h 30 a passé le filet, lancé `restic`, et travaillait
au repack quand il a été tué :

```
Main process exited, code=killed, status=15/TERM
Remove(<lock/c0183a1132>) failed: ssh command exited: exit status 255
Failed with result 'signal'
```

Les messages voisins (`gpg-agent-extra.socket has 'stop' job queued`) montrent une
session en cours de démontage : extinction de WSL, ou mise en veille de la
machine pendant le tir. **Il n'a pas été rejeté, il a été interrompu.**

Deux points rassurants, vérifiés : `Linger=yes`, donc les minuteries utilisateur
survivent à la fermeture de session ; et `unlock_stale()` est appelé avant chaque
tir, donc le verrou orphelin laissé chez Herbes Folles sera nettoyé au prochain
passage sans intervention.

---

## Trois instruments locaux qui disent tous « ça va »

C'est le cœur du problème. Après cette mort brutale :

| Instrument | Ce qu'il dit | Ce qui est vrai |
|---|---|---|
| `systemctl show -p Result` | `success` | le journal dit `Failed with result 'signal'` |
| Drapeau `~/anarbib-ops/.last-failure` | absent | l'`ExecStartPre` l'a effacé au démarrage, rien ne l'a reposé |
| `OnFailure=anarbib-backup-failure@…` | n'a pas tiré | `Failed to enqueue … : Transaction is destructive` |

**Seule la base dit la vérité** : aucune ligne `court` dans `backup_heartbeats`
depuis le 19/08 15:31 UTC.

### Le premier trou : `OnFailure` ne survit pas à une extinction

`Transaction is destructive`, c'est systemd qui refuse d'enfiler une tâche neuve
pendant qu'il démonte la session. **Le dispositif d'alerte partage donc le sort de
ce qu'il surveille** — même angle mort que les workflows rouges, transposé aux
sauvegardes.

Sa portée est bornée, et il faut le dire précisément pour ne pas sur-réagir :
pour un échec ordinaire de `restic`, machine allumée, `OnFailure` part
normalement. Le trou n'est pas « l'alerte d'échec ne marche pas », c'est
**« l'alerte d'échec ne survit pas à une extinction »**.

### Le second trou, plus large : un tir interrompu ne laisse aucune trace

`heartbeat()` n'est appelé qu'**à la fin** d'un tir réussi. Un tir qui commence et
meurt n'écrit donc rien en base : ni succès, ni échec, **rien**. Du point de vue
de la sonde, une machine éteinte toute la journée et un tir mort en plein repack
sont **le même événement**.

Conséquence chiffrée sur le cas du jour : le tir meurt à 11 h 30 le 20/08, et la
première information que quiconque en obtient tombe à 00 h 31 le 21/08, quand le
seuil de 36 h est franchi. **Trente-sept heures d'aveuglement**, alors que
l'information « ce tir a commencé et n'a pas fini » existait dès 11 h 31.

---

## Pourquoi le correctif évident est le mauvais

Réflexe naturel : resserrer le seuil de 36 h. **À ne pas faire.**

La chaîne tourne sur un poste de travail qui dort et qu'on éteint. Le flux `court`
tire à 2 h du matin ; un seuil serré sonnerait chaque fois que la machine passe la
nuit éteinte — ce qui est légitime et fréquent. On obtiendrait une alarme qui crie
au loup, donc une alarme qu'on apprend à ignorer, ce qui est pire que pas d'alarme.

Les 36 h ne sont pas de la négligence : ils achètent le droit d'éteindre son
ordinateur.

---

## Le correctif proposé

**Distinguer « aucun tir n'a eu lieu » de « un tir a commencé et n'a pas fini ».**
Le second est sans ambiguïté : il n'a aucun faux positif possible, et il est
actionnable dans l'heure.

1. **Une phase sur le témoin.** `backup_heartbeats` reçoit une colonne `phase`
   (`'started'` / `'ok'`), défaut `'ok'` — les lignes existantes gardent leur sens.
2. **Un quatrième paramètre à `fn_record_backup_heartbeat`**, avec valeur par
   défaut : les appels à trois arguments continuent de fonctionner tels quels.
3. **Le script signale le départ** — `heartbeat <flux> started` juste avant
   `restic`, en plus du témoin de fin déjà présent.
4. **La sonde apprend une seconde règle** : si la dernière ligne d'un flux est
   `started` et qu'elle a plus de quelques heures, c'est un tir interrompu →
   incident, sans attendre le seuil de silence.

**À faire dans la même passe** : `heartbeat()` transmet aujourd'hui `null` comme
`snapshot_id`, sur les quatre lignes de la table. Le témoin prouve donc que le
script est allé au bout, **pas qu'un instantané existe dans le dépôt restic**.
`restic backup --json` rend l'identifiant ; le passer ferme cet écart, qui est
noté depuis le §7.1 du plan de marche.

---

## État au moment de la note

| Flux | Dernier témoin | Âge | Seuil | Hôte |
|---|---|---|---|---|
| `court` | 19/08 15:31 UTC | 24,7 h | 36 h | `ACCATTONE` (réel) |
| `long` | 19/08 14:53 UTC | 25,3 h | 216 h | `amorcage-migration` (semis) |
| `storage` | 19/08 14:53 UTC | 25,3 h | 216 h | `amorcage-migration` (semis) |

**L'observateur externe n'est pas lent** : `cron.job` n°51 passe toutes les cinq
minutes. Ce qui est long, c'est le seuil, et c'est un choix. Il a déjà tiré pour
de vrai — incident n°2, ouvert et notifié dans la même minute le 19/08, refermé
quinze minutes plus tard par un tir réel.

**Ce qui va se passer** : `court` franchit les 36 h le **21/08 à 03:31 UTC
(00 h 31 locales)**. Incident et courriel dans les cinq minutes. Le tir automatique
suivant est à 2 h locales, soit **après** l'alarme — et il ne refermera l'incident
que si la machine est éveillée, c'est-à-dire précisément ce qui a manqué le 20/08.

**Les deux flux `long` et `storage` restent tenus par une ligne de semis** et
passeront muets le **28/08 à 14:53 UTC** si aucun témoin réel n'arrive d'ici là.
Le statut les marque désormais `temoin_amorcage: true` — la moitié du §7.1 du plan
de marche est donc faite.

---

## Suite donnée, le 20/08

### Palier 1 appliqué — la colonne `phase`

Migration `20260820163045_temoin_phase_depart`. Elle pose la colonne
(`'started'` / `'ok'`, défaut `'ok'`), ouvre `fn_record_backup_heartbeat` à un
quatrième paramètre, et **immunise la sonde** : `fn_backup_heartbeat_status` ne
compte plus que les témoins `'ok'`.

Cette immunisation n'est pas cosmétique. Sans elle, le jour où le script
enverrait un témoin de départ, le statut y verrait un témoin frais et
**masquerait le silence** — l'alarme serait devenue moins bonne qu'avant. C'est
ce qui rend le palier 2 sûr.

L'ancienne signature à trois arguments est **supprimée** plutôt que laissée à
cohabiter : deux surcharges dont l'une porte un paramètre par défaut rendent
l'appel à trois arguments ambigu. Le script, qui appelle à trois arguments,
continue de fonctionner tel quel.

**Contrôle après déploiement** : statut identique à avant — mêmes hôtes, mêmes
seuils, `ok: true`, une seule signature, toutes les lignes en `'ok'`.

Le palier 2 — apprendre à la sonde « dernière ligne `started` et vieille de
quelques heures → tir interrompu » — reste à faire, et le script ne signalera son
départ qu'à ce moment-là.

#### Au passage, la règle 11 du plan de marche est incomplète

Elle dit qu'une migration appliquée par le MCP doit être poussée avant ou avec
son application, et que **« le remède est de pousser le fichier ; le run suivant
repasse au vert seul »**. Ce n'est pas suffisant, et le CI l'a montré aussitôt.

**Le MCP attribue sa PROPRE version** — l'horodatage du moment où il applique,
ici `20260820163045` (16 h 30 min 45 s UTC). Le fichier avait été nommé
`20260820235500_…` d'après la simple numérotation du dossier. Pousser ce
fichier-là ne répare donc rien : le distant réclame `20260820163045`, que le
dépôt ne contient toujours pas, et `supabase db push` échoue **à chaque run**,
indéfiniment. Ce n'est plus une course transitoire, c'est un orphelin permanent.

**Le remède exact** : nommer le fichier avec la version que le MCP a attribuée.
On la lit dans `supabase_migrations.schema_migrations`, ou dans le message
d'erreur lui-même — c'est le numéro que le CLI propose de « réparer », et qu'il
ne faut surtout pas réparer.

La bonne pratique existait déjà dans le dépôt : la migration
`20260820145716_catalog_duplicates_tri_par_niveau_de_preuve.sql`, appliquée par
le MCP le même jour, porte exactement son numéro d'application. Il n'y avait
qu'à regarder.

### Horaire de tir déplacé en Europe/Paris

Les trois minuteries tiraient à 2 h, dimanche 3 h et 4 h — heure machine, donc en
pleine nuit quelle que soit la latitude. Elles ne tombaient jamais sur une machine
éveillée ; `Persistent=true` les rattrapait au réveil, **au pire moment**. C'est
exactement ainsi que le tir du 20/08 est mort.

| Flux | Avant | Après |
|---|---|---|
| `court` | `*-*-* 02:00:00` | `*-*-* 19:00:00 Europe/Paris` |
| `long` | `Sun *-*-* 03:00:00` | `Sun *-*-* 20:00:00 Europe/Paris` |
| `storage` | `Sun *-*-* 04:00:00` | `Sun *-*-* 21:00:00 Europe/Paris` |

**Le fuseau est nommé, à dessein.** L'heure de tir suit la personne qui exploite
la chaîne — Dunkerque jusqu'en décembre 2027 — et non le fuseau du portable, qui
change en voyage. La machine était en `America/Cayenne` au moment du changement,
où 19 h Paris tombe à 14 h. systemd applique le fuseau nommé et gère donc l'heure
d'été et l'heure d'hiver seul : **rien à rebasculer deux fois par an.**

Unités sauvegardées en `*.timer.bak-20260820`, `daemon-reload` fait,
`systemd-analyze verify` silencieux.

### Une lacune repérée au passage

Les unités systemd (`~/.config/systemd/user/anarbib-backup-*.{service,timer}`)
**ne sont dans aucun dépôt**. Le script `anarbib-bg2.sh` et ses listes vivent dans
`~/anarbib-ops/`, hors dépôt lui aussi. La chaîne de sauvegarde n'est donc pas
reconstructible depuis Git — même angle mort que `deploy/genkeys.mjs` le 19/08,
et sur la brique dont dépend tout le reste. À traiter, hors périmètre de cette
note.
