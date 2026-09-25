# Thésaurus FICEDL — aspirations, audits, esquisse SKOS

Pièces de travail sur le thésaurus de la FICEDL (`thesaurus.ficedl.info`). Rien
ici n'est un export officiel : ce sont des lectures faites depuis l'extérieur, datées.

| Fichier | Ce que c'est | Produit par |
|---|---|---|
| `ficedl_thesaurus_<date>.json` | aspiration du site à cette date (quatre : 25/06, 30/06, 27/08, 03/09) | `scripts/ficedl_thesaurus_scrape.mjs` |
| `AUDIT_thesaurus_ficedl_<date>.md` | relevé des défauts de libellé de l'aspiration du même jour | idem |
| `ficedl_thesaurus_ESQUISSE.csv` | l'**esquisse SKOS** de 28 descripteurs, en tableur (`;`, BOM, CRLF) | `scripts/ficedl_thesaurus_esquisse.mjs` |
| `ficedl_thesaurus_ESQUISSE.jsonld` | la même esquisse en SKOS / JSON-LD | idem |
| `NOTE_export_thesaurus_2026-08-28.pdf` | la note qui accompagnait la première esquisse (Bologne) | à la main |

## Régénérer l'esquisse

```bash
node scripts/ficedl_thesaurus_esquisse.mjs docs/journal/ficedl/ficedl_thesaurus_2026-09-03.json docs/journal/ficedl
```

Sur l'aspiration du 03/09, la sortie est **identique octet pour octet** aux fichiers
versés ici (ceux du 09/09 emportés à Bologne) ; la ligne de compte attendue est
`fiches=623 aspirees=621 injoignables=mot532,mot538 liens=3117 selection=28`.
Le CSV est exclu de la conversion des fins de ligne (`.gitattributes`) pour le
rester après un clone. Ne jamais la régénérer depuis une aspiration plus ancienne.

Le générateur est la copie de `build_esquisse.mjs` du paquet hors ligne préparé
pour Bologne (`ficedl-thesaurus-scraper`, 09/09) : une correction faite ici
va aussi là-bas.

## Ce que l'esquisse encode (révision du 09/09)

Les réponses de la source du 07/09 (REGISTRE §30, `THES-FIC-O1`, `DOC-THES-1`) :
deux `skos:ConceptScheme` en nœuds anonymes — « liste commune » pour les sujets,
« géo-histo » pour les lieux et les dates —, **jamais d'URI de schéma inventé** ;
URI canonique `https://thesaurus.ficedl.info/?motNN`, `skos:notation` = le numéro
nu, la forme `/id/motNN` retirée ; les `broader` vers « X (généralités) »
**confirmés** par la source ; « art : courants » en `skos:Collection` provisoire,
tant que la question (b) reste ouverte ; l'astérisque de la source portée comme
une donnée (`hors_liste_cira`).

**La note du 28/08 est dépassée sur trois points**, gardés tels quels parce
qu'elle a été envoyée ainsi : elle parle de 26 descripteurs sur 620 (l'esquisse en
porte 28, sur 623 fiches), d'un seul vocabulaire, et propose la forme `/id/motNN`.
