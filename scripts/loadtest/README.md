# Harnais de test de charge

Mesure ce que le service public encaisse : lectures anonymes, lectures
connectées et écritures, avec montée en charge configurable. Écrit lors de la
campagne du 16–17 août 2026 (rapport de solidité FICEDL Bologne).

## Pourquoi un bac à sable

Il n'existe **qu'un seul projet Supabase** : les tests tapent donc sur
l'environnement réel, avec de vraies données et de vrais comptes. D'où
`bac-a-sable.sql`, qui crée une bibliothèque jetable — privée, isolée, catalogue
local, absente de la cartographie, donc invisible des trois surfaces publiques —
et trente comptes dédiés en `@loadtest.invalid`. Toutes les écritures y sont
confinées, et la purge remet les compteurs à l'identique.

## Marche à suivre

```bash
# 1. Relever les compteurs AVANT (voir la fin de bac-a-sable.sql), puis créer
#    le bac à sable : exécuter la PARTIE 1 de bac-a-sable.sql. Noter l'UUID.

# 2. Lancer une mesure
node scripts/loadtest/anarbib-loadtest.mjs --lib=<UUID> --vu=40 --duration=60 --write-pct=20

# 3. Purger : décommenter et exécuter la PARTIE 2 de bac-a-sable.sql,
#    puis vérifier que les compteurs sont revenus à leur valeur d'avant.
```

Options : `--vu` (usagers simultanés), `--duration` (secondes), `--write-pct`
(part d'écritures), `--accounts`, `--label`, `--exclude=op1,op2` pour retirer
des opérations du mix.

## Précautions

**Ne jamais mettre dans le volume une opération qui déclenche un e-mail.**
Réservations et consultations ont des triggers `pg_net` → `notify-event` →
Resend : les inclure enverrait des milliers de messages réels. Le harnais écrit
dans `user_wishlist` et `book_drafts`, qui n'ont aucun trigger de notification.
Vérifier avant d'ajouter une écriture.

**Alterner les variantes quand on compare.** Les tâches planifiées tournent
toutes les 5 minutes et certaines durent plusieurs dizaines de secondes : une
comparaison A/B en série peut mesurer un cron plutôt que le changement étudié.
Répéter en alternant.

## Repères mesurés le 17 août 2026

Après correctifs, mix complet fiche livre incluse :

| Usagers simultanés | Débit | Erreurs | p95 |
|---|---|---|---|
| 40 | 68 req/s | 0 | 196 ms |
| 80 | 106 req/s | 0,09 % | 1 028 ms |
| 120 | 101 req/s | 0 | 1 487 ms |

Le plafond structurel n'est ni `max_connections` (60) ni le CPU, mais le **pool
de connexions PostgREST, limité à 20**. Les latences incluent le trajet réseau
vers São Paulo (~100–130 ms depuis l'Europe).

## Mesurer à grande échelle sur le banc LOCAL (B32, B33 — 27/09/2026)

Le harnais ci-dessus mesure ce que la production encaisse aujourd'hui. Pour
savoir ce qu'elle encaissera avec dix ou cinquante fois plus de notices, on
fabrique un catalogue synthétique **dans une base jetable du banc local** — jamais
en production : le script écrit des milliers d'autorités, de notices et de fonds.

- `catalogue-synthetique.sql` : autorités (noms et formes de tri réalistes, alias
  aux formes relevées en production), éditeurs, notices (titres de 2 à 6 mots,
  une édition sur cinq rattachée à l'œuvre d'une autre), contributeurs, et des
  fonds répartis entre la bibliothèque publique du seed et quatre bibliothèques
  créées pour l'occasion — une par branche de `fn_library_visible_to_caller`
  (publique, réseau, privée, isolée). Rafraîchit les deux vues matérialisées.
- `catalogue-mesure.sql` : les parcours réels de l'OPAC (page par œuvre, recherche,
  filtres, facettes, liste plate triée, `count(*)` sous RLS), sans compte puis en
  session, quatre appels chronométrés par psql (`\timing`) ; `catalogue-mesure-resume.cjs`
  en tire la moyenne des trois derniers, sans plafond de temps. Pas d'enveloppe
  PL/pgSQL : l'image Supabase précharge `plpgsql_check`, dont la couche pldbgapi2
  casse après certains appels imbriqués depuis une fonction (constaté le 28/09/2026).

```bash
# base jetable, clonée du banc (scripts/ci/run-sql-suites.sh l'a construit)
psql -d postgres -c "CREATE DATABASE anarbib_perf TEMPLATE anarbib_test"
psql -d anarbib_perf -v n_auteurs=50000 -v n_notices=100000 -v n_editeurs=10000 \
     -f scripts/loadtest/catalogue-synthetique.sql
psql -X -d anarbib_perf -f scripts/loadtest/catalogue-mesure.sql > mesure-avant.log
node scripts/loadtest/catalogue-mesure-resume.cjs avant mesure-avant.log
# … appliquer la migration à mesurer, puis :
psql -X -d anarbib_perf -f scripts/loadtest/catalogue-mesure.sql > mesure-apres.log
node scripts/loadtest/catalogue-mesure-resume.cjs apres mesure-apres.log
psql -d postgres -c "DROP DATABASE anarbib_perf"
```

À 100 000 notices, la génération prend une bonne demi-heure (34 min le 28/09 :
chaque notice traverse ses déclencheurs, dont ceux qui s'exécutent après
l'instruction, un par notice). Le rôle `anon` n'a pas son
plafond de 3 s sur le banc (réglage de rôle appliqué à la connexion, pas à
`SET ROLE`) : `catalogue-mesure.sql` affiche la durée réelle, à comparer au
plafond.
