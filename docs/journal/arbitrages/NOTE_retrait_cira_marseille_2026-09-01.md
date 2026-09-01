# Retrait de `cira-marseille` — la trace qui manquait

**1ᵉʳ septembre 2026.**

## Ce qui s'est passé

La bibliothèque `cira-marseille` a été supprimée de `public.libraries` entre le
30 août au soir et le 1ᵉʳ septembre au matin, par un geste direct en production —
aucune migration, aucun commit ne la porte. Le relevé du backlog l'a constaté le
01/09 ; la coordination a **confirmé le jour même que la suppression était
volontaire, et de sa main**.

**Le motif** : le CIRA Marseille a fait retour qu'il ne se lancerait pas dans un
nouvel outil. Ce n'est ni un désaccord ni une rupture — c'est le refus ordinaire,
et parfaitement légitime, d'un centre d'archives qui a déjà ses instruments. La
porte reste ouverte : c'est précisément pourquoi les fichiers de thème sont
conservés (voir plus bas), et pourquoi cette note évite tout vocabulaire de
« départ ».

Cette note existe parce que le geste, lui, n'avait laissé aucune trace : les
journaux d'audit du réseau couvrent les adhésions et les actions d'équipe, pas
la vie des bibliothèques elles-mêmes. *Un geste destructeur volontaire et un
geste destructeur accidentel sont indiscernables tant que personne n'écrit
lequel c'était* — d'où une demi-journée passée à vérifier qu'il n'y avait ni
orphelin ni intrusion, pour aboutir à « c'était voulu ».

## Ce que la suppression a emporté, et ce qu'elle a laissé

- **Emporté, proprement** : la cascade a traversé les 65 tables à clé étrangère —
  canal mail, règle de cotisation (semée par `20260703204511`), cartographie,
  état de service. La bibliothèque avait 0 fonds et 0 exemplaire : aucune donnée
  documentaire n'est partie. Contrôle d'orphelins fait sur les 8 tables portant
  un `library_id` sans FK : rien.
- **Laissé, et c'est décidé ainsi** (arbitrage du 01/09) :
  - les **10 fichiers de thème** dans le bucket `library-ui-assets` sont
    **conservés** — coûteux à refaire, utiles si le CIRA revient ;
  - la **source d'import partenaire** (`ingest.partner_catalog_sources` id 14,
    rattachée à la BLMF — c'est la source du chantier d'import CIRA, lot 55, pas
    la bibliothèque elle-même) est **close** : `import_enabled = false`, motif
    dans ses `notes`. Aucun moissonnage ne repartira sans un geste explicite.

## Ce qui reste vrai ailleurs

Les notices importées du CIRA et déjà promues dans le catalogue **restent** : la
provenance est un fait historique, pas un lien de dépendance. La table des
écarts du backlog v34 et l'item J3 mentionnent `cira-marseille` au passé simple
de leurs relevés respectifs — on ne réécrit pas un relevé daté.

## La leçon, une ligne

Supprimer une bibliothèque du réseau est un acte fédéral : s'il se refait un
jour, il mérite sa ligne de trace **au moment du geste** — cette note aura mis
un jour et demi à exister, et c'est un jour et demi de doute évitable.
