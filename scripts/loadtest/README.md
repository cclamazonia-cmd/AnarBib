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
