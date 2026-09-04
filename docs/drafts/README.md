# `docs/drafts/` — un sas, pas une réserve

**Règle (item I10 du backlog v34, 04/09/2026).** Ce dossier reçoit du travail
en cours qui n'a pas encore sa place : un SQL pas encore migré, une note pas
encore journalisée. **Ce qui y entre en sort** — promu (migration, spec,
`docs/journal/`), tranché par décision écrite, ou supprimé — **dans le mois**.
Rien ici ne fait foi, rien n'est présumé à jour, et rien ne s'y cherche : un
fichier qu'on y laisse est un fichier qu'on perd. C'est exactement là que le
SQL des sujets SOLIDAIRES est resté cinq semaines sans que personne le
retrouve (item C1).

`archive/` garde la trace de ce qui est sorti, avec sa date d'entrée dans le
nom, pour pouvoir dire d'où vient une migration ou une décision. On n'y
travaille pas, on n'en déploie rien.

## État au 04/09/2026

Le sas est vide. Deux traces en `archive/` :

| Fichier | Entré le | Sorti |
|---|---|---|
| `archive/20260616_opac_catalog_search_accent_rank_DRAFT.sql` | 16/06/2026 | **remplacé** par la RPC en production `api.catalog_search_ids_v1` (accents, pertinence, multi-mots, chemins anon et session), constaté le 03/07/2026 ; son en-tête le dit. Archivé le 04/09 — il traînait à la racine du sas depuis deux mois. |
| `archive/20260828_sujets_solidaires_ficedl.sql` | 28/08/2026 | **tranché par décision écrite** le 01/09/2026 (clôture de C1) : le vocabulaire fédéral embarque, les sujets locaux et leurs alignements n'embarquent pas. Jamais déployé, conservé pour trace. |
