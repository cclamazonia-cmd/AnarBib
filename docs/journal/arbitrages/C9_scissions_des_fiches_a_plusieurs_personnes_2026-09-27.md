# C9 — les fiches d'autorité qui réunissent plusieurs personnes (27/09/2026)

> Fiche à valider par Xavier avant toute écriture. Relevé en production le 27/09 au soir.
> Verdict `CONV-O8` du 03/09 (« pas de scission avant la quatrième fiche double ») dépassé par les
> faits (REGISTRE §37, MàJ du 03/09 nuit : « décision à reprendre ») — valider cette fiche vaut
> décision de scinder.

## Ce que fera la migration (en son propre nom, jamais sous l'identité de quelqu'un)

- Chaque fiche double est retrouvée par **son id et son nom actuel** ; nom changé depuis → rien.
- **Une personne qui a déjà sa fiche est reliée à celle-ci**, jamais recréée (six cas : Gurucharri,
  Ibáñez, Philopat, Biehl, Bookchin, Sacchetti).
- La première personne **sans** fiche reprend la fiche double (même id : ses liens, son œuvre, son
  historique suivent) ; les autres sont créées ou reliées, et ajoutées aux contributeurs du livre.
- Quand **toutes** les personnes ont déjà leur fiche (deux cas), la fiche double est fusionnée dans
  la première, comme le ferait `merge_author` (contributions, œuvres, alias, brouillons, journal des
  fusions), puis supprimée. `merge_author` elle-même est réservée à une arbitre connectée : la
  migration en reproduit les gestes.
- Le champ libre `books.autor` du livre est réécrit (« Nom, Prénom ; Nom, Prénom ») **seulement s'il
  vaut encore exactement l'ancien texte**, comme le fait `fn_authority_split`.

## A. Dix fiches à scinder

| Fiche | Livre(s) | Devient | Confiance |
|---|---|---|---|
| 10709 « Ibáñez, Salvador Gurucharri y Tomás » | *Insurgencia libertaria* | **Gurucharri, Salvador** (fiche 10683, existante) + **Ibáñez, Tomás** (10090, existante) — la fiche double est fusionnée dans 10683 | sûre |
| 10748 « KAISER, William Young and David E. » | *Postmortem* (Sacco-Vanzetti) | **Young, William** (reprend la fiche) + **Kaiser, David E.** (créée) | sûre |
| 10942 « Musté, Ignacio Vidal y Pedro Costa » | *Las colectividades campesinas, 1936-1939* | **Vidal, Ignacio** (reprend) + **Costa Musté, Pedro** (créée) | probable |
| 11035 « Philopat, Duka e Marco » | *Roma K.O.*, *Rumble Bee* | **Duka** (nom unique, reprend) + **Philopat, Marco** (11037, existante) | probable (« Duka » : pseudonyme ?) |
| 11359 « Antonio Serra & Cristina Pereira » | *Os carreiristas da indisciplina / A psiquiatria como discurso político* | **Serra, Antonio** (reprend) + **Pereira, Cristina** (créée) | sûre |
| 11376 « Bookchin, Janet Biehl/Murray » | *Las políticas de la ecología social* | **Biehl, Janet** (10335, existante) + **Bookchin, Murray** (10, existante) — fusionnée dans 10335 | sûre |
| 11389 « Doris Accioly e Silva, Sonia Alem Marrach (Org.) » | *Maurício Tragtenberg : uma vida para as ciências humanas* | **Marrach, Sonia Alem** (reprend) + **Silva, Doris Accioly e** (créée) — rôle **organizador** pour les deux | sûre |
| 11420 « Giorgio Sacchetti, Augusto Gayubas, Manuel Vicent Balaguer, Ignacio Donézar, José Luis Gutiérrez Molina » | *Germinal – Revista de estudios libertarios* 9 (auteurs d'articles) | **Gayubas, Augusto** (reprend) + **Sacchetti, Giorgio** (11134, existante) + **Vicent Balaguer, Manuel** + **Donézar, Ignacio** + **Gutiérrez Molina, José Luis** (créées) | sûre |
| 11424 « Durval Muniz de Albuquerque Júnior, Alfredo Veiga-Neto, Alípio de Souza Filho (orgs.) » | *Cartografias de Foucault* | **Albuquerque Júnior, Durval Muniz de** (reprend) + **Veiga-Neto, Alfredo** + **Souza Filho, Alípio de** (créées) — rôle **organizador** | sûre |
| 11475 « MORAES, Carla Kelen de Andrade. Acioli, Edane de Jesus França et al. » | *Terceira margem Amazônia* | **Moraes, Carla Kelen de Andrade** (reprend) + **Acioli, Edane de Jesus França** (créée) ; « et al. » tombe | sûre |

## B. Trois fiches à corriger sans scinder

| Fiche | Correction |
|---|---|
| 11448 « LUDMILA, Aline (et al.) » (2 livres) | **Ludmila, Aline** — « (et al.) » et capitales retirés |
| 11540 « SILVÉRIO, Beatriz (et al.) » | **Silvério, Beatriz** |
| 11457 « Noir et Rouge » | type **collectivité** (groupe et revue, 1956-1970) |

## C. Onze brouillons non publiés, à plusieurs personnes dans le champ « auteur »

Aucune contribution n'y est enregistrée : publiés tels quels, ils entreraient au lot « auteurs sans
autorité », qui ne propose que le premier nom de la chaîne. La migration leur pose **une contribution
par personne**, reliée à l'autorité existante quand il y en a une ; le texte du champ « auteur » ne
change pas. Le lot 63 est celui de Solidaires, en révision par l'administration du réseau.

| Brouillon | Auteur (tel qu'importé) | Contributions posées |
|---|---|---|
| 116 (lot 8) | Errico Malatesta e Luigi Fabbri | Malatesta, Errico (4) ; Fabbri, Luigi (10031) |
| 278 (lot 8) | Karl Marx & Engels | Marx, Karl (25) ; Engels, Friedrich (26) |
| 418 (lot 8) | G.Sorel/E.berth/H.Lagardelle/S. Pannunzio/V. Griffuelhes/P. Delesalles/E. Pouget | Sorel, Georges (10190) ; Berth, Édouard ; Lagardelle, Hubert ; Panunzio, Sergio ; Griffuelhes, Victor ; Delesalle, Paul ; Pouget, Émile (11055) — noms complets **déduits des initiales** |
| 4726 (lot 63) | Bruno Astarian et Robert Ferro | Astarian, Bruno ; Ferro, Robert |
| 4866 (lot 63) | Cédric Biagini, David Murray et Pierre Thiesset | Biagini, Cédric ; Murray, David ; Thiesset, Pierre |
| 4917 (lot 63) | Bella et Roger Belbéoch | Belbéoch, Bella ; Belbéoch, Roger |
| 4955 (lot 63) | Daniele et Emmanuelle Flamant-Paparatti | **à vérifier** : le livre (*Emmanuelle ou l'enfance au féminin*) est-il de deux personnes, ou de Danielle Flamant-Paparatti seule ? — laissé tel quel si doute |
| 5771 (lot 63) | André et Dori Prudhomeaux | Prudhommeaux, André ; Prudhommeaux, Dori (orthographe corrigée) |
| 5786 (lot 63) | A. et D. Prudhommeaux | Prudhommeaux, André ; Prudhommeaux, Dori |
| 5842 (lot 63) | Jaime Balius & Amigos de Durruti | Balius, Jaime ; Amigos de Durruti (collectivité) |
| 5862 (lot 63) | Informations et Correspondances Ouvrières | une seule contribution : la collectivité — **pas** une scission |

## Vu en passant, non traité ici

- **« Sorel, G. » (11190)** double **« Sorel, Georges » (10190)** : doublon ordinaire, à fusionner par
  l'assistant de dédoublonnage (geste d'arbitre).
- Aucune autre fiche d'autorité publiée ne porte « Prénom Nom & Prénom Nom » (ni « e », « y »,
  « et », « and », « und », « i », « / ») hors collectivités légitimes ; aucune notice publiée n'a
  un champ « auteur » de plusieurs personnes pour une seule autorité liée, hors les dix ci-dessus.

## Décision attendue

Valider A, B et C (en retirant les lignes douteuses si besoin : 10942, 11035, 418, 4955).

## Décision (27/09, soir)

- **Xavier : tout, sauf le brouillon 4955** (laissé tel quel, faute de certitude).
- Et, sur sa parole : « Sorel, G. est forcément Georges Sorel » — la fiche 11190 est fusionnée dans 10190 par la même migration.
- Migration `20260927193940_c9_les_fiches_a_plusieurs_personnes_sont_scindees.sql`, éprouvée sur copie jetable du banc (scission toute-existante fusionnée, scission mixte à cinq personnes, rôle organizador, champ libre saisi à la main respecté, œuvre qui suit, brouillon relié, second passage nul).
