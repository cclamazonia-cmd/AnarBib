---
Genre : référence
Statut : ✅ implémentée en prod (notice BookPage #OPAC1-6 + autorité AuthorPage #AUT1/2/4) — référence consolidée a posteriori (18/06). Face contribution des autorités = spec-atelier-autorites.
Décisions : incarne OPAC-W1, OPAC-SIM1, OPAC-PRIV1, OPAC-COM1, OPAC-MARC1, OPAC-AUTH1, OPAC-X1, OPAC-UI1, OPAC-ATL1, OPAC-AGG1 ; cite DOC-I18N-1, DOC-PERIM-1, CAT-D6
Supersédé par : —
---

# Spec — Notice et autorités enrichies

> **Statut** : v1.0 — **✅ implémentée en prod** (consolidé a posteriori le 18/06 ; vérifié `BookPage`/`AuthorPage`). **Notice** (`BookPage`) : #OPAC1 citations + export **BibTeX/RIS**, toggle **ISBD**, #OPAC4 documents similaires (`api.similar_books`), #OPAC6 sections. **Autorité** (`AuthorPage`) : #AUT1 réseau d'auteur·rices (`api.similar_authors`), #AUT2 nuage de sujets (`api.author_subjects_v1`), **formes du nom** (`authors.variant_forms`), bio multilingue, identifiants **VIAF/ISNI/Wikidata**. La **face contribution** des autorités (Atelier) est portée par `spec-atelier-autorites` (paquet 1 livré). Issue du même atelier RebAL que la spec catalogue, étendue à la page d'autorité (`AuthorPage.jsx`).
> **Périmètre** : la **fiche de notice** d'un livre (`BookPage.jsx`) et la **fiche d'autorité** d'un·e contributeur·rice (`AuthorPage.jsx`). Volet amont : la **face contribution** des autorités (Atelier), cadrée ici au niveau orientation, à détailler dans une spec dédiée le moment venu.
> **Spec sœur** : `spec-catalogue-decouverte.md v0.1` (couche liste/découverte). Les deux spécifient des surfaces distinctes — liste *vs* notice/autorité — mais partagent une brique commune : l'agrégation de sujets en chips cliquables (#OPAC8 liste ↔ §4.2 autorité).
> **Specs liées** : `spec-administrateur-reseau-v0.4.md` (modèle de gouvernance réseau dont l'Atelier s'inspire *en s'en distinguant* : consentement sans vote), chantier criar-conta sans biblio (compte réseau non rattaché, base du compte contributeur·rice).
> **Recadrage majeur (cf. §3)** : plusieurs « manques » RebAL identifiés le 20/05 sont **déjà couverts** par AnarBib, parfois mieux. Cette spec corrige #OPAC2, #OPAC3 et #OPAC9 en conséquence.

---

## 1. Contexte et objectif politique

La fiche de notice et la fiche d'autorité sont les deux pages où une lectrice *rencontre* un document et la personne qui l'a écrit. RebAL traite richement la notice (barre d'actions, onglets, documents similaires, MARC) mais ne sait pas faire de vraie page d'autorité — il se contente de lier une facette `author_facet`. AnarBib a fait l'inverse : une page d'autorité déjà riche (VIAF / ISNI / Wikidata, biographie multilingue, photo, bibliographie) mais une notice encore en deçà de RebAL sur la couche découverte.

L'objet de cette spec est double. D'abord, combler le retard de la notice sur RebAL, en distinguant nettement ce qui est *réellement* manquant de ce qui est *déjà fait autrement* (la lecture du 20/05 surestimait le retard). Ensuite — et c'est le cœur politique — assumer que la page d'autorité n'est pas un sous-produit du catalogue mais un **lieu de mémoire**. Les SIGB institutionnels ont historiquement mal documenté les compas du mouvement libertaire : dates fausses, pseudonymes mélangés, omissions des camarades qui n'avaient pas accès à l'imprimerie. Faire des autorités libertaires correctes est un acte de réparation historiographique.

Cette ambition dépasse les forces d'une biblio seule. Elle appelle un travail fédéré, distribué, soigneux — ce que l'**Atelier autorités** propose d'organiser (§5). La présente spec prépare le terrain frontend de cet atelier : une page d'autorité qui *montre* le soin documentaire est ce qui donne envie d'y contribuer.

---

## 2. État de l'existant au 01/06/2026

### 2.1 `BookPage.jsx` (notice)

| Élément | Implémentation actuelle |
|---|---|
| En-tête (Hero) | titre, sous-titre, contributeurs liés, chips ref/année/éditeur/exemplaires/prochaine dispo |
| Holdings par biblio | liste « biblio — disponible / indisponible jusqu'au … » |
| **Toggle Standard / ISBD** | `viewMode` : vue pills *ou* énoncé ISBD construit (`buildIsbdStatement` + `buildIsbdZones`) |
| Champs Standard | ~20 MetaPill : ref, tombo, année, éditeur, lieu, édition, ISBN, ISSN, langue, pages, type, collection, volume, traducteur, organisateur, auteurs secondaires, sujets, CDD + notas |
| Contributeurs liés | `BookAuthorLinks` : `authors_json`/`author_chips`, chaque entité à `author_id` → `/autor/:id` avec rôle |
| Statut | pastille session-aware (doctrine A1/A2/A3) |
| Accès numérique | chip + bouton lecture + attribution source |
| Actions | Réserver, Agendar consulta, **Salvar para depois (`user_wishlist`, serveur)**, login |

### 2.2 `AuthorPage.jsx` (autorité)

| Élément | Implémentation actuelle |
|---|---|
| En-tête (Hero) | nom d'affichage, intro (pays · dates · nb livres) |
| Chips | naissance/mort, pays (via `getCountryName`), nb livres, **VIAF / ISNI / Wikidata** (liens sortants), source |
| Biographie | multilingue (`author_translations`), chaîne de fallback locale → langue de base → pt-BR → première dispo → colonne originale ; indicateur des langues disponibles |
| Photo | `photo_object_path` ou placeholder initiale |
| Bibliographie | `author_books_public` triée année↓ puis titre ; cartes (couverture, titre, sous-titre, ref, année, éditeur, **rôle**) |

### 2.3 Tables d'autorité pertinentes

`authors` (identifiants externes inclus), `author_translations` (biographies i18n), `book_contributors` + `link_author_to_book_contributors` (graphe contributeur·rice ↔ ouvrage), `author_books_public` (vue bibliographie). **Pas de table** pour les autorités *collectivité* ni *matière* à ce stade (point structurant pour §5).

---

## 3. Recadrage : ce qui est déjà fait (correction du 20/05)

| Réf | Constat du 20/05 | Réalité 01/06 | Reste à faire |
|---|---|---|---|
| **#OPAC2** | « afficher le MARC » | ✅ **Mieux fait** : vue **ISBD humaine** (toggle Standard/ISBD). RebAL n'affiche qu'un `fullrecord` UNIMARC illisible. | (optionnel) onglet « MARC brut » pour interop externe — complétude, pas valeur lectrice |
| **#OPAC3** | « lier tous les contributeurs » | ✅ **En grande partie fait** : `BookAuthorLinks` lie toute entité à `author_id` avec rôle | résidu : `autores_secundarios` reste un MetaPill texte plat → qualité de données, pas frontend |
| **#OPAC9** | « favoris (proposé local-first par anti-tracking) » | ⚠ **Déjà serveur** : `user_wishlist` (upsert `user_id,book_id`) | **arbitrage à acter** : assumer le serveur (audit RLS strict, invisible staff) — recommandé — *ou* basculer local. Le retour-arrière casserait une feature livrée |

**Décision proposée sur #OPAC9** : conserver `user_wishlist` côté serveur, sous réserve d'un **audit RLS** garantissant `user_id = auth.uid()` en lecture/écriture et **aucune** lecture par le staff/réseau (INV-2). Annule la reco local-first de la spec catalogue v0.1, à corriger là-bas.

---

## 4. Enrichissements

### 4.1 Notice — ce qui manque réellement

**#OPAC1 — Barre d'actions de notice.** *Impact 3 · Effort 2 · Score 9.*
Citer (formats APA/Chicago/MLA, matière déjà disponible via l'ISBD), Imprimer (CSS print), Permalien (l'URL `/livro/:id` est **déjà stable** — quasi gratuit), Exporter (BibTeX / RIS). **Hors scope** : « Envoyer par SMS » (passerelle télécom + traçage). « Envoyer par courriel » → `mailto:` client-only seulement.

**#OPAC4 — Documents similaires.** *Impact 2 · Effort 3 · Score 6.*
Recommandation **par contenu** (même auteur·rice, mêmes sujets, même collection) — jamais par comportement. Distinction politique cardinale : pas de filter-bubble, pas de surveillance, pas de log de navigation. Affichage en colonne droite (desktop) façon RebAL ou bloc en pied (mobile).

**#OPAC6 — Description structurée.** *Impact 3 · Effort 2 · Score 8.*
Aujourd'hui `book.notas` est inline. Exposer un bloc/onglet description (résumé, notes, sujets). ⚠ **Onglet « Commentaires » public écarté** : sur une biblio militante, des commentaires publics exposent les intérêts politiques des lectrices. Si un besoin émerge, le réserver au staff (note interne), jamais public.

### 4.2 Autorité — dérivations (RebAL ne sait pas faire)

**#AUT1 — Auteur·rices lié·es.** *Impact 3 · Effort 3 · Score 11.*
Transposition de « documents similaires » au plan autorité : co-auteur·rices (graphe `book_contributors`), auteur·rices sur les mêmes sujets, dans la même collection. Donne à voir le **réseau intellectuel** d'un·e auteur·rice militante. Colonne ou bloc dédié sur `AuthorPage`.

**#AUT2 — Nuage de sujets de l'auteur·rice.** *Impact 3 · Effort 2 · Score 9.*
Agréger les `assuntos` de la bibliographie en chips cliquables → catalogue filtré. **Brique partagée avec #OPAC8** (nuage de sujets de la liste) : même fonction d'agrégation, à mutualiser. Pivot fort de la découverte par rebonds.

**#AUT3 — Barre d'actions d'autorité.** *Impact 2 · Effort 2 · Score 6.*
Permalien (`/autor/:id` déjà stable), **Exporter la bibliographie** complète (BibTeX/RIS de tous les ouvrages — réellement utile aux chercheur·euses), éventuellement « suivre l'auteur·rice » (même arbitrage que #OPAC9).

**#AUT4 — Bibliographie enrichie.** *Impact 2 · Effort 2 · Score 6.*
Les cartes n'affichent **pas la disponibilité**. Ajouter la pastille session-aware (« disponible dans ma biblio ») relie `AuthorPage` à la circulation. Filtrage par rôle (auteur principal / traducteur / organisateur — `book.role` déjà chargé), tri optionnel.

**⚠ Piège anti-tracking spécifique autorité.** Les chips VIAF/ISNI/Wikidata sont aujourd'hui de simples liens sortants — c'est bien. **Ne jamais** enrichir la fiche par un appel client à l'API Wikidata (photo, mouvement, dates) : cela fuiterait à Wikimedia quel·le auteur·rice est consulté·e. Tout enrichissement externe se fait par **moissonnage serveur au catalogage**, stocké localement (INV-5).

---

## 5. Horizon amont : l'Atelier autorités

> Statut du chantier (rappel du texte vitrine) : **annonce d'intention**, non ouvert. Le module technique (interface contributeur·rice, file de propositions, tableau de bord, gouvernance des litiges) relève de **la phase suivante**, après stabilisation du catalogage. Cette section cadre l'orientation et son articulation avec les §4 ; elle **n'est pas** un plan d'implémentation. Une **spec dédiée** (`spec-atelier-autorites`) sera rédigée le moment venu.

### 5.1 Ce que l'Atelier ajoute au modèle

L'Atelier ouvre un **quatrième cercle** de contribution, à côté des biblios adhérentes, des lecteur·rices et des compas du code : des compas attaché·es à la mémoire libertaire **sans rattachement à une biblio adhérente**. Leur établi : la couche d'autorités partagée (personnes, **collectivités**, **matières**).

Tâches prévues : créer des fiches manquantes, enrichir les lacunaires, fusionner/désambiguïser les doublons, sourcer les affirmations, **traduire** les biographies courtes (dans les locales d'AnarBib, DOC-I18N-1). C'est le pendant *production* de ce que les §4.2 affichent en *lecture*.

### 5.2 Articulation avec l'existant (ce que la spec dédiée devra trancher)

- **Compte contributeur·rice** = compte **réseau global non rattaché à une biblio** → s'appuie sur le chantier criar-conta sans biblio (déjà livré pour les lectrices orphelines). Nouveau **rôle** distinct de `{reader, librarian, coordenador}` et distinct de `network_administrators`. À modéliser : `network_contributors` (ou rôle dédié), avec ses droits propres (proposer, jamais éditer directement).
- **Propositions plutôt qu'édition directe** : une proposition (création/modification/fusion) est examinée et validée par une biblio adhérente ou la coordination de l'atelier. Parenté avec le pattern propositions/votes du réseau (`spec-administrateur-reseau`), **mais distinction nette** : ici **consentement sans vote, sans hiérarchie** (l'esprit Fédération jurassienne). Pas de quorum, pas de scrutin — discussion entre compas concerné·es et biblios utilisatrices.
- **Tables manquantes** : autorités collectivité et matière n'ont pas de schéma à ce jour (§2.3). Leur création est un préalable structurant — sans elles, l'Atelier ne peut travailler que les autorités personnes.
- **Tableau de bord & journal** : files de tâches, tableau personnel, journal des contributions validées. Audit immuable des décisions (cohérent avec `*_audit` du réseau).

### 5.3 Ce que les §4 préparent pour l'Atelier

Une page d'autorité enrichie (#AUT1-4) est le **rendu public** du travail de l'atelier : elle montre qu'une fiche bien faite relie une œuvre, un réseau intellectuel, des sujets, des sources et des traductions. C'est l'argument qui donne envie de contribuer. Implémenter §4 d'abord, c'est rendre l'Atelier désirable avant de le rendre possible.

---

## 6. Invariants

- **INV-1 (recommandation par contenu)** : #OPAC4 et #AUT1 reposent exclusivement sur des métadonnées (auteur, sujet, collection, graphe de contribution). **Aucune** recommandation fondée sur le comportement de navigation. Aucun log de ce qu'une lectrice consulte.
- **INV-2 (wishlist privée)** : `user_wishlist` est isolée par RLS `user_id = auth.uid()`, jamais lisible par le staff ni le réseau. Audit obligatoire avant de confirmer #OPAC9 côté serveur.
- **INV-3 (pas d'appel tiers au runtime)** : aucun enrichissement de notice ou d'autorité ne déclenche d'appel à un service externe (Wikidata, couvertures, etc.) révélant la consultation. Moissonnage serveur au catalogage uniquement.
- **INV-4 (autorités = entités liées, pas chaînes)** : tout contributeur doit, à terme, pointer vers une fiche d'autorité (objectif de l'Atelier), pas une chaîne de caractères saisie à la main. #OPAC3 résiduel s'inscrit dans cette trajectoire.
- **INV-5 (commentaires non publics)** : aucune couche de commentaire public sur les notices. Toute annotation est staff-only.
- **INV-6 (consentement Atelier)** : la gouvernance de l'Atelier procède par consentement et discussion, sans vote ni autorité hiérarchique tranchante — à respecter dans la future spec dédiée.

---

## 7. Décisions à prendre

**D1 — #OPAC9 serveur ou local.** Tranchée : **OPAC-W1** (registre) — wishlist serveur conservée, audit RLS à faire ; répercutée dans `spec-catalogue-decouverte`.
**D2 — Formats d'export (#OPAC1/#AUT3).** BibTeX + RIS suffisent-ils ? Ajouter MARC/MODS pour interop biblio ?
**D3 — Logique de similarité (#OPAC4/#AUT1).** Pondération auteur/sujet/collection ; côté serveur (RPC `api.similar_*`) ou dérivation client sur données déjà chargées ?
**D4 — Mutualisation #OPAC8 ↔ #AUT2.** Une seule fonction d'agrégation de sujets paramétrée (périmètre = recherche *ou* bibliographie d'auteur·rice) ? **Recommandé.**
**D5 — Onglets vs sections.** Reproduire le pattern onglets RebAL (Exemplaires / Description / Documents similaires / MARC) ou garder le défilement à sections d'AnarBib ? Trancher selon ergonomie mobile (#MOBILE).
**D6 — i18n.** Nouvelles clés conformes à **DOC-I18N-1** (registre).
**D7 — Préalable Atelier.** Créer les tables autorités *collectivité* et *matière* avant ou pendant le chantier catalogage ? Décision structurante hors périmètre de cette spec mais à inscrire au backlog.

---

## 8. Articulation avec le backlog

Ajouts au cluster **#CATALOG-EXT** du GLB : requalification de **#OPAC2/#OPAC3** (« déjà fait / résiduel »), correction de **#OPAC9** (serveur + audit), maintien de **#OPAC1/#OPAC4/#OPAC6**, et quatre nouveaux tickets autorité **#AUT1 à #AUT4**. Création d'un macro-item **#ATELIER** (annonce d'intention, spec dédiée à venir, préalable #D7 tables collectivité/matière). À verser au backlog v18 et au prochain GLB.

| Réf | Surface | Fonctionnalité | Score | Statut |
|---|---|---|---|---|
| #OPAC1 | notice | Barre d'actions (citer/imprimer/permalien/export) | 9 | 🆕 réel |
| #OPAC4 | notice | Documents similaires (par contenu) | 6 | 🆕 réel |
| #OPAC6 | notice | Description structurée (sans commentaires publics) | 8 | 🆕 réel |
| #OPAC2 | notice | Onglet MARC brut (optionnel) | 6 | ✅ ISBD déjà fait |
| #OPAC3 | notice | Contributeurs secondaires → entités liées | 9 | ✅ en grande partie fait |
| #OPAC9 | transverse | Wishlist serveur + audit RLS | 6 | ⚠ déjà livré, à auditer |
| #AUT1 | autorité | Auteur·rices lié·es (réseau intellectuel) | 11 | 🆕 dérivation |
| #AUT2 | autorité | Nuage de sujets (mutualisé #OPAC8) | 9 | 🆕 dérivation |
| #AUT3 | autorité | Barre d'actions + export bibliographie | 6 | 🆕 dérivation |
| #AUT4 | autorité | Bibliographie enrichie (dispo + filtres) | 6 | 🆕 dérivation |
| #ATELIER | amont | Atelier autorités (contribution fédérée) | — | 🔭 horizon, spec dédiée |

---

**Spec close (cadrage v0.1). Prochaine étape : arbitrer D1-D7, puis implémenter dans l'ordre #AUT2 ↔ #OPAC8 (brique de sujets mutualisée, meilleur ratio), puis #AUT1 et #OPAC1. L'Atelier autorités fera l'objet de sa propre spec après stabilisation du catalogage.**
