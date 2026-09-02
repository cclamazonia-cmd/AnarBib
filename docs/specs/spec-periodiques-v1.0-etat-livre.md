# Périodiques — l'état livré (v1.0)

**1ᵉʳ septembre 2026.** Ce document remplace `spec-periodiques-v0.1`, d'abord
crue perdue — le fichier vivait dans les téléchargements, a été collé en
session le 27/08 (« On met ça en œuvre »), puis supprimé sans jamais être versé
au dépôt. **Retrouvée le soir même, intégrale, dans le transcript de cette
session**, elle est archivée telle quelle :
[`archive-spec-periodiques-v0.1-retrouvee.md`](archive-spec-periodiques-v0.1-retrouvee.md).
Elle reste un document d'intention (« cadré, non implémenté ») ; le présent
texte décrit **ce qui est**, depuis le code et la production — ici, le code
fait foi et le document le suit, pas l'inverse.

> **Leçon d'inventaire** (`DOC-RECENS-1`) : un document de travail qui ne passe
> jamais par le dépôt est invisible à toutes les recherches de fichiers — il
> n'a survécu que parce qu'une session l'avait avalé en entier. Ce qui sert de
> référence à un item de backlog doit être versé quelque part de durable, le
> jour où il sert.

## Ce qui est livré (les neuf paquets, 27–28/08/2026)

Migrations `20260827163000` → `20260827210000`, complétées par l'écran des sept
RPC (`6ece5c93`) et le panneau de gouvernance (`3c520c33`) :

1. **`serials`** — le titre de revue est une autorité : slug automatique,
   statut, filiation prédécesseur/successeur.
2. **`books.serial_id`** — un fascicule est une notice rattachée à son titre.
3. **`books.issue_key`** — clé de désignation **générée** (colonne
   `GENERATED`), calculée par `fn_serial_issue_key`, pour distinguer deux
   fascicules ; l'ordre d'affichage se fait sur `(ano, issue_key)`.
4. **RPC de catalogage** (`api.fn_serial_*`) : créer, modifier, rattacher,
   détacher, déclarer la filiation, l'état de collection.
5. **Anti-faux-doublons** : deux numéros d'une même revue ne sont pas un
   doublon (`fn_editions_distinctes`, intégré au balayage).
6. **État de collection** : déclaré (`serial_holdings.statement`,
   `completeness`) **et** calculé (`computed_first/last/count/at`) — deux
   colonnes séparées, le calcul n'écrase jamais la déclaration.
7. **Entrée dans l'Atelier**, reprise des notices existantes (P7b : reprendre
   une notice ne perd plus sa revue), sélecteur au catalogage.
8. **Page publique de revue.**
9. **Libellés dans les dix langues**, posés d'emblée.

État en production au 01/09 : **4 titres, 7 fascicules rattachés.**

## Les six gardes — vérifiées une à une le 01/09/2026

| # | Garde | Où elle vit | Vérifié |
|---|---|---|---|
| G1 | anti-cycle de filiation **borné à 20 sauts** | trigger `serials_filiation_no_cycle` — `WHILE v_hops < 20` puis exception (`20260827163000` l.269-277) | borne relue à la ligne |
| G2 | réciprocité prédécesseur/successeur | trigger `serials_filiation_symmetry` sur `serials` | présent en prod |
| G3 | `serial_id` interdit sur un non-fascicule | trigger `books_serial_id_requires_periodico` sur `books` | présent en prod |
| G4 | l'importeur ne touche pas la clé générée | `issue_key` est `GENERATED` — toute écriture échouerait bruyamment ; aucun chemin d'import ne la référence | grep du dépôt |
| G5 | la fusion n'écrase pas l'état déclaré | `merge_serial` + colonnes déclaré/calculé séparées | structure en prod |
| G6 | ordre de tri des fascicules | index sur `issue_key`, tri `(ano, issue_key)` | présent en prod |

**Et surtout : les six sont exercées en continu.** La suite
`tests/sql/periodiques_tests.sql` (35 tests, allowlist CI) couvre les gardes de
filiation et de matériel, la clé inécrivable, l'anti-faux-doublons dans les
deux sens, l'état déclaré que le calcul ne doit jamais écraser, et la fusion.
Ce document n'est pas la preuve — la suite l'est, à chaque commit.

## Ce qui a changé depuis la livraison

- **01/09/2026** — l'arbitrage des doublons de périodiques est aligné sur celui
  des livres : `merge_serial`, `mark_serials_not_duplicate` et
  `unmark_serials_not_duplicate` exigent `fn_is_dedup_arbiter()` (coordination
  ou administration réseau), après préavis aux quatre personnes concernées.
  Cataloguer et **signaler** restent ouverts au staff. Voir
  `DECISION_arbitrage_periodiques_2026-09-01.md` et la suite
  `arbitrage_periodiques_tests.sql`.
- **02/09/2026** — le « sélecteur au catalogage » du point 7 ci-dessus
  **n'avait jamais été affiché** en production. `SerialAuthorityPicker` était
  bien dans le bundle, mais déclaré sous `sectionExtras.periodico`, un point
  d'extension que le formulaire ne lit que pour les sections « matériel » —
  et le groupe `periodico` n'en est pas une : ses champs (titre transcrit,
  volume, numéro…) sont rendus un par un dans la grille principale. Aucun
  fascicule n'a donc pu être rattaché à une revue depuis la fiche de
  catalogage entre le 27/08 et le 02/09 ; seuls le panneau de gouvernance
  (« rattacher un numéro ») et les reprises SQL l'ont fait.
  Corrigé : le sélecteur est monté en ligne, en tête de la zone Periódico,
  pour un fascicule (et pour un article déjà rattaché). Un test de dépôt
  (`src/tests/serial-picker-monte.test.js`) empêche qu'une clé de
  `sectionExtras` désigne à nouveau un groupe jamais rendu. Rien n'a changé
  en base : `book_drafts.serial_id` et sa recopie à la publication (P7a)
  étaient en place, ils n'avaient simplement jamais reçu de valeur par ce
  chemin.

## Ce qui reste des gestes manuels

Trois gestes restent à la main du catalogage (aucun n'est un défaut) :
promouvoir un titre existant en autorité de revue, déclarer l'état de
collection d'un fonds, et rattacher les fascicules anciens au fil des reprises.
Le panneau de gouvernance les porte tous les trois.
