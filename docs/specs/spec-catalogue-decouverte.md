---
Genre : référence
Statut : 🟡 cadrée
Décisions : incarne OPAC-F1, OPAC-AGG1 ; cite OPAC-W1, DOC-PERIM-1, DOC-I18N-1
Supersédé par : —
---

# Spec — Enrichissement de la page catalogue (couche découverte)

> **Statut** : v0.1 du 01/06/2026 — **cadrage**, non implémenté. Issue de l'atelier RebAL (chat « Nouvelle lectrice de la Biblioteca Terra Livre » du 20/05/2026) et des deux captures d'écran de la fiche de résultats RebAL.
> **Périmètre** : la **page de résultats / liste** du catalogue (`CatalogPage.jsx`, vues `api.catalog_list_anon_v1` et `api.catalog_list_session_v1`). C'est la surface équivalente aux captures RebAL « Résultats de la recherche » + « Affiner les résultats ».
> **Hors périmètre** : la **fiche de notice** d'un livre unique (`BookPage.jsx` / ancien `livro.html`). Les six fonctionnalités notice issues du même atelier RebAL sont couvertes par **#OPAC1 à #OPAC6** (cluster #CATALOG-EXT du GLB) et ne sont **pas** reprises ici.
> **Distinction fondatrice** : l'atelier du 20/05 a enrichi la *notice* (citer, MARC, autorités, documents similaires, tags, description). La présente spec enrichit la *découverte en liste* (facettes à compteurs, nuage de sujets, favoris, modes de parcours). Les deux sont complémentaires mais distinctes.
> **Specs liées** : `spec-flux-emprunts.md` (boutons réservation déjà câblés dans la liste), `spec-flux-consultations-v2.2.md` (boutons consulta déjà câblés). Cette spec ne touche **aucun** flux de circulation.

---

## 1. Contexte et objectif politique

La page catalogue d'AnarBib fait déjà, côté **circulation**, davantage que RebAL : filtres avancés (ISBN, langue, CDD, assunto, matériel, collection, lieu), tri par colonnes, export CSV+PDF, facettes bibliothèque et disponibilité, réservation et consultation en un clic depuis la liste. RebAL est un OPAC fédéré ; AnarBib est un SIGB fédéré. Sur la couche transactionnelle, nous sommes en avance.

Mais RebAL conserve une avance nette sur une autre couche : la **découverte**. Devant une liste de 2 212 résultats, RebAL propose une navigation par rebonds — un nuage de sujets cliquables, des facettes latérales chiffrées (Format : 1 601 livres, 566 inconnus ; Auteur : Malatesta 13, Galzerano 13…), des modes de parcours alternatifs. Là où AnarBib offre des champs de saisie (il faut *savoir* ce qu'on cherche), RebAL offre des points d'entrée à explorer (on *découvre* en cliquant).

Pour une bibliothèque militante, cette différence n'est pas cosmétique. Une lectrice qui arrive sans référence précise — qui veut « voir ce qu'il y a sur l'antimilitarisme » ou « parcourir les autrices » — est aujourd'hui mal servie par la liste AnarBib. La découverte par rebonds est un acte d'émancipation documentaire : elle permet de tomber sur ce qu'on ne cherchait pas, ce qui est précisément la fonction politique d'une bibliothèque libertaire.

L'objectif de cette spec est donc d'ajouter à la page catalogue une **couche de découverte** inspirée de RebAL, **sans renoncer** aux deux lignes rouges du projet : l'anti-tracking (pas de profilage des lectrices) et l'autonomie de chaque biblio (pas de méga-machine centralisatrice). Ces deux contraintes infléchissent plusieurs choix techniques ci-dessous et sont nommées explicitement à chaque fois.

---

## 2. État de l'existant au 01/06/2026

### 2.1 Ce qui est déjà en place dans `CatalogPage.jsx`

| Capacité | Implémentation actuelle | Équivalent RebAL |
|---|---|---|
| Recherche plein-texte | champ `search`, `or` ilike sur titre/autor/editora/bib_ref/cdd/assuntos/subtitulo/isbn | barre « Tous les champs » |
| Filtres avancés | author, publisher, year, ISBN, langue, CDD, assunto, matériel, collection, lieu (saisie texte) | facettes latérales (mais en *saisie*, pas en *clic*) |
| Facette bibliothèque | `libraryFilter` multi-select, options chargées via `api.libraries_public_v1` | facette « Bibliothèque » |
| Facette disponibilité | `availabilityFilter` multi-select | — (spécifique AnarBib) |
| Tri | par colonne cliquable (ref, autor, titre, ano, editora) + pertinence + statut | « Trier » |
| Export | CSV (UTF-8 BOM) + PDF (fenêtre impression) | « Exporter » de notice (pas en liste) |
| Copier la recherche | `copySearchLink` → lien partageable | « Enregistrer la recherche » (partiel) |
| Mode compact | toggle densité du tableau | — |
| Réservation rapide | bouton inline par ligne (garde-fous service mode + restriction) | — (spécifique AnarBib) |
| Consultation rapide | bouton inline symétrique | — (spécifique AnarBib) |
| Pagination | « Carregar mais » + `totalCount` via Content-Range | pagination numérotée |

### 2.2 Ce qui manque par rapport aux captures RebAL

| Manque | Présent dans RebAL | Statut backlog |
|---|---|---|
| **Compteurs sur les facettes** | « Livre 1 601 », « Malatesta 13 »… | ❌ non inscrit |
| **Nuage « Suggestion de sujets »** | tag-cloud en tête de résultats avec décomptes | ❌ non inscrit |
| **Favoris lecteur** | « Ajouter aux favoris » par notice | ❌ non inscrit |
| **Flux RSS de la recherche** | « S'abonner aux flux RSS » | ❌ non inscrit |
| **Envoyer la recherche par courriel** | « Envoyer cette recherche par courriel » | ❌ non inscrit |
| **Parcours alphabétique** | « Parcours alphabétique » | ❌ non inscrit |
| **Nouveautés** | « Nouveautés » | ❌ non inscrit |
| **Vignettes de couverture** | thumbnails dans la liste | partiel (icônes tipo seulement) |

### 2.3 Note d'architecture

La liste est servie par deux vues matérialisées allégées (Phase B.5.6) : `api.catalog_list_anon_v1` (visiteur) et `api.catalog_list_session_v1` (connecté, filtré par `auth.uid()` via `my_session_context`). Toute facette à compteur devra agréger sur **ces mêmes vues**, sous peine de fuiter le décompte réseau aux anonymes (régression déjà rencontrée et corrigée en B.7 avec le retrait de `api.books_count_v1`). C'est la contrainte de performance et de cloisonnement la plus structurante de cette spec (cf. §5).

---

## 3. Paquets fonctionnels proposés

Numérotation continuant la série OPAC (les notices étant #OPAC1-6). Scores impact×effort sur le barème backlog habituel.

### #OPAC7 — Facettes latérales à compteurs

**Impact 3 · Effort 3 · Score 11 · Priorité haute**

Transformer les filtres « en saisie » en **facettes « en clic »** avec décomptes, présentées dans un panneau latéral « Affiner les résultats » (desktop) ou un accordéon repliable (mobile, cf. doctrine #MOBILE).

Facettes à compteurs visées : **Bibliothèque**, **Format/matériel** (`tipo_material`), **Auteur** (top N), **Langue**, **Décennie** (regroupement de `ano`). Chaque valeur affiche `(count)` et est cliquable pour appliquer le filtre.

Conserver les filtres en saisie texte pour les champs à forte cardinalité (titre, éditeur, ISBN) où une liste de valeurs n'a pas de sens.

**Point dur** : le calcul des compteurs. Trois options à trancher en début d'implémentation (§7-D1).

### #OPAC8 — Nuage « Sugestões de assuntos »

**Impact 3 · Effort 2 · Score 9 · Priorité haute**

En tête des résultats, un nuage de chips de sujets (`assuntos`) avec décomptes, calculé sur le périmètre de la recherche courante. Cliquer une chip ajoute le sujet au filtre `subjectsFilter` (déjà existant côté backend). C'est la fonctionnalité RebAL la plus emblématique et la plus alignée avec la découverte par rebonds militante.

Plafonner à ~15 sujets les plus fréquents + un bouton « plus… » (comme RebAL : « truncate-more plus… »).

### #OPAC9 — Favoris lecteur (wishlist serveur)

**Impact 2 · Effort 2 · Score 6 · Priorité moyenne · ⚠ doctrine anti-tracking**

Bouton « ★ Adicionar aos favoritos » par ligne. La doctrine de stockage est tranchée au registre par **OPAC-W1** : `user_wishlist` **côté serveur** est conservée (elle existe déjà en prod via `BookPage`), sous réserve d'un **audit RLS strict** (`user_id = auth.uid()`, invisible staff/réseau). OPAC-W1 **annule** la recommandation local-first initiale de cette spec. Voir le registre pour le statut courant.

### #OPAC10 — Modes de parcours : alphabétique + nouveautés

**Impact 2 · Effort 2 · Score 6 · Priorité moyenne**

Deux points d'entrée alternatifs, en pied de page catalogue (bloc « Outros modos de busca », calqué sur RebAL) :

- **Parcours alphabétique** : index A-Z par autor (et/ou titre), chaque lettre menant à la liste filtrée. Réutilise le tri existant.
- **Nouveautés** : raccourci vers la liste triée par date d'ajout décroissante (`created_at`/`first_seen` selon le champ disponible dans la vue). Très pertinent pour une biblio militante (signaler les acquisitions récentes).

**Hors scope explicite** : « Exemplaires en réserve pour un cours » (feature universitaire RebAL, sans objet pour une biblio militante) et « Explorer avec les canaux » (notion VuFind non transposable). Si un besoin émerge plus tard, le réinterpréter en « étagères thématiques » curées par le staff biblio.

### #OPAC11 — Outils de recherche : courriel + RSS (prudent)

**Impact 1 · Effort 2 · Score 3 · Priorité basse · ⚠ doctrine anti-tracking**

- **Envoyer la recherche par courriel** : pré-remplit un `mailto:` avec le lien de recherche (déjà produit par `copySearchLink`). Côté client uniquement, aucune donnée serveur. Acceptable.
- **Flux RSS de la recherche** : génère un flux des résultats d'une requête. **À évaluer prudemment** : l'URL du flux encode la requête en clair et, hébergée chez un agrégateur tiers, peut désanonymiser un intérêt documentaire. Recommandation v1 : **différer** ; si demandé, n'exposer le RSS que pour des requêtes non sensibles (nouveautés d'une biblio publique), jamais pour une recherche thématique personnelle.

### Vignettes de couverture (transverse, optionnel)

Afficher les couvertures dans la liste (RebAL le fait, avec un placeholder « NO IMAGE AVAILABLE »). À traiter avec la même prudence anti-tracking que partout : **jamais** d'appel à un service tiers de couvertures (Google Books, OpenLibrary via hotlink) qui fuiterait les consultations. Uniquement des couvertures hébergées par la biblio elle-même. À rattacher à la doctrine d'hébergement des assets, hors v1.

---

## 4. Tableau de priorisation

| Réf | Fonctionnalité | Impact | Effort | Score | Priorité |
|---|---|---|---|---|---|
| #OPAC7 | Facettes latérales à compteurs | 3 | 3 | 11 | 🔴 haute |
| #OPAC8 | Nuage « Sugestões de assuntos » | 3 | 2 | 9 | 🔴 haute |
| #OPAC9 | Favoris lecteur (wishlist serveur, OPAC-W1) | 2 | 2 | 6 | 🟠 moyenne |
| #OPAC10 | Parcours alphabétique + nouveautés | 2 | 2 | 6 | 🟠 moyenne |
| #OPAC11 | Courriel + RSS de recherche | 1 | 2 | 3 | 🟢 basse |

**Recommandation de séquence** : #OPAC8 (nuage de sujets) en premier — meilleur ratio impact/effort, le `subjectsFilter` existe déjà côté backend, c'est la signature RebAL la plus marquante. Puis #OPAC7 (facettes chiffrées) qui partage l'essentiel de l'infrastructure d'agrégation. Le reste à la demande.

---

## 5. Contrainte transverse : le calcul des compteurs

C'est le cœur technique de #OPAC7 et #OPAC8, et le principal risque de régression de performance (rappel : la liste avait une requête à 3,7 s avant l'optimisation B.5.6).

Le décompte d'une facette = `count(*) GROUP BY <champ>` **sur le périmètre de la recherche courante** (donc en appliquant tous les filtres actifs *sauf* celui de la facette elle-même, pour permettre l'élargissement). Réalisé naïvement côté client sur les seuls résultats chargés, le compte serait faux (pagination). Réalisé via une requête serveur par facette, c'est N requêtes d'agrégation à chaque frappe — inacceptable.

Cloisonnement à respecter impérativement : les compteurs doivent être agrégés sur `api.catalog_list_anon_v1` pour les visiteurs et `api.catalog_list_session_v1` pour les connectés, **jamais** sur une vue réseau globale (sinon fuite du décompte network aux anonymes — régression B.7 déjà corrigée).

Les trois options de calcul sont détaillées en §7-D1.

---

## 6. Invariants

- **INV-1 (cloisonnement)** : aucun compteur de facette ne révèle à un·e anonyme un décompte calculé sur le périmètre réseau. Source = vue `*_anon_v1` pour les non connectés.
- **INV-2 (wishlist privée, OPAC-W1)** : `user_wishlist` est isolée par RLS `user_id = auth.uid()`, jamais lisible par le staff ni le réseau ; audit RLS obligatoire avant de confirmer le stockage serveur.
- **INV-3 (anti-tracking découverte)** : aucune fonctionnalité de cette spec ne logge l'historique de navigation/recherche d'une lectrice côté serveur. Le « historique de recherche » de RebAL n'est **pas** repris (ou alors strictement local).
- **INV-4 (autonomie biblio)** : les facettes et modes de parcours respectent le périmètre de filtrage existant ; aucune agrégation ne contourne le cloisonnement par biblio quand il s'applique.
- **INV-5 (pas de tiers)** : aucune vignette, aucun flux, aucune action ne déclenche un appel à un service tiers susceptible de fuiter une consultation.

---

## 7. Décisions à prendre en début d'implémentation

**D1 — Calcul des compteurs de facettes (#OPAC7/#OPAC8).** Trois options :
- *(a)* Vue/RPC d'agrégation dédiée `api.catalog_facets_v1(filters)` retournant tous les compteurs en un seul appel JSONB. Le plus propre, le plus performant, mais demande une fonction backend soignée (SECURITY INVOKER, REVOKE doctrine). **Recommandé.**
- *(b)* `count` PostgREST par facette via header `Prefer: count=exact` + `select=...&limit=0`. Simple mais N requêtes.
- *(c)* Agrégation côté client sur l'échantillon chargé. Rapide mais **faux** dès qu'il y a pagination — à proscrire pour les compteurs affichés comme exacts.

**D2 — Favoris (#OPAC9).** Tranchée au registre : **OPAC-W1** (wishlist serveur conservée, audit RLS à faire). Annule la reco local-first.

**D3 — Périmètre des facettes auteur/sujet.** Top N (15 comme RebAL) + bouton « plus » : quelle valeur de N, et tri par fréquence ou alphabétique ?

**D4 — Mobile (#MOBILE).** Le panneau latéral de facettes devient quoi sur mobile ? Accordéon en tête ? Bottom-sheet ? À aligner avec la doctrine mode terrain en cours.

**D5 — i18n.** Nouvelles clés conformes à **DOC-I18N-1** (registre).

---

## 8. Articulation avec le backlog

Cette spec **ajoute** cinq sous-tickets (#OPAC7 à #OPAC11) au cluster **#CATALOG-EXT** du GLB, en regard des six existants (#OPAC1-6, qui restent strictement *notice*). Elle ne modifie aucun ticket existant. À inscrire au prochain backlog (v18) et à mentionner dans la prochaine version du GLB.

Le ticket backlog **#62** (« Filtres avancés catalogue : année, ISBN, assunto ») est partiellement recouvert par #OPAC7 (les filtres en saisie deviennent des facettes en clic). À fusionner ou à requalifier lors de la mise à jour du backlog — arbitrage à acter.

---

**Spec close (cadrage v0.1). Prochaine étape : arbitrage des décisions D1-D5, puis implémentation — commencer par #OPAC8 (nuage de sujets, meilleur ratio impact/effort).**
