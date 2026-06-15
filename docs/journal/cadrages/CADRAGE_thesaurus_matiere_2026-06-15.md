# Cadrage — Thésaurus matière : du registre libre au **commun tendu**

- **Statut :** validé (15/06/2026) — implémentation v1 par étapes
- **Date :** 2026-06-15
- **Session :** Fédération — Communs & Entraide
- **Filiation :** prolonge **OPAC-ATL1** (autorité matière, 08/06/2026) ; s'inscrit
  dans la charte relationnelle (`docs/notes-audit/anarbib-charte-relationnelle-v0.1.md`)
  et le cadrage entraide (`CADRAGE_entraide_catalogage_2026-06-15.md`).

## 0. En une phrase

Le thésaurus matière **existe déjà et fonctionne** ; ce cadrage le fait passer
d'une *table en écriture libre* à un **commun multilingue, trouvable et gouverné
par consentement** — sans jamais devenir une méga-machine qui dresse un mur
devant la biblio qui ne sait pas par où commencer.

## 1. Point de départ — ce qui EXISTE (ne rien réinventer)

Déployé en OPAC-ATL1 (migrations `20260608072903/074214/080013`) :

- **`public.subjects`** : `slug` (unique, auto-généré), **`label_i18n` jsonb**
  (`{locale: libellé}`, repli pt-BR), **`parent_id`** (hiérarchie / terme
  générique), `scope_note`, audit (`created_by`/`updated_by`). **29 sujets graine**
  anarchistes, libellés en **pt-BR/fr/es/en**, avec une hiérarchie amorcée.
- **`public.book_subjects`** (notice publiée ↔ sujet) + **`public.book_draft_subjects`**
  (brouillon ↔ sujet) + **synchro brouillon→publié** au publish.
- **Écriture** : tout staff `can_access_catalogacao` peut `INSERT/UPDATE` un sujet
  (RLS `my_access`) — **écriture libre**.
- **`api.search_subjects(query, limit)`** : typeahead (tous libellés + slug,
  normalisés) ; **nuages / facettes OPAC** (P3) ; auto-slug.
- **`ate_o3_merge_subject`** : outil de **fusion de doublons** — preuve que la
  dérive de l'écriture libre est **déjà constatée**.

→ Le backbone est **solide**. Le présent chantier *complète et gouverne*, il ne
reconstruit rien.

## 2. Les trois manques

**A. Complétude multilingue.** `label_i18n` ne porte que **4 locales** sur 10 ;
`ca/de/el/eo/it/nl` retombent sur pt-BR à l'affichage.

**B. Findabilité (SKOS incomplet).** Pas de **synonymes** (`altLabel`) → le
typeahead rate les variantes (« autodéfense » ↔ « autodefesa », sigles, formes
historiques) ; pas de **`hiddenLabel`** (variantes ortho) ; pas de **`notation`**
(code CDD) → aucun pont vers le vademecum cotation/CDD ; pas de relation
**associative** (secondaire).

**C. Gouvernance (le cœur).** L'écriture 100 % libre **dérive** (doublons —
cf. `merge_subject` —, termes idiosyncrasiques, éclatement du vocabulaire).
**Mais** verrouiller = méga-machine : une biblio qui ne sait pas indexer se prend
un référentiel fermé en plein visage. **C'est la tension à tenir.**

## 3. Vision — le thésaurus comme commun *tendu* (charte)

- **Ça tend** : proposer un terme, remplir un libellé, suggérer un sujet,
  expliquer (scope_note).
- **Ça saisit** : imposer une classification, refuser un terme local, geler le
  vocabulaire d'en haut.
- **Conçu pour la plus précaire** : la biblio qui ne sait pas indexer reçoit des
  **suggestions + une note d'usage + un vademecum**, pas un formulaire vide ni un
  référentiel cadenassé.

**Le pivot qui tient la tension A↔C — deux registres :**

| Registre | Quoi | Friction | Charte |
|---|---|---|---|
| **Mots-clés locaux** | texte libre, propres à une notice/biblio | zéro | « ça tend » (soupape) |
| **Sujets du thésaurus** | contrôlés, partagés, multilingues, hiérarchiques | grandissent **par consentement** | le commun |

Indexer = on peut **toujours** taguer librement (mots-clés). **Promouvoir** un
mot-clé en sujet partagé = un **acte gouverné**. Personne n'est jamais bloqué.

## 4. Axe A — Complétude multilingue (← workflow Cowork)

- Étendre `label_i18n` aux **10 locales**. Les sujets sont surtout des **noms
  communs/propres** : peu de langage inclusif en jeu, mais **orthographe et
  diacritiques corrects** par langue (notamment `el`, `eo`).
- **Chaîne de repli explicite** : locale courante → pt-BR → premier libellé dispo.
- Dans le picker : un libellé manquant = **pastille discrète + lien « compléter »**
  (invite, ne bloque pas) → le commun grandit **au point d'usage**.
- **Livrable Cowork** : je lui exporte `slug + label_i18n` actuels ; il complète
  les 6 locales manquantes (même cadre que le BRIEF traductions Communs) ; je
  réimporte par `UPDATE label_i18n`. Pas de schéma à toucher pour l'axe A.

## 5. Axe B — Findabilité (la vraie question de modèle)

- **Option 1 — tout-jsonb** : `label_i18n` devient `{locale: {pref, alt[], hidden[]}}`.
  Un seul lieu, migration douce, `search_subjects` parcourt `pref+alt+hidden`.
- **Option 2 — table dédiée** : `subject_labels(subject_id, locale, kind, label)`
  (SKOS pur). Plus normalisé, contraintes/req. plus riches, mais 2ᵉ table +
  jointures.

**Reco : Option 1** (cohérente avec l'existant tout-jsonb, suffit au typeahead) ;
garder l'Option 2 en réserve si on exporte du **SKOS/RDF** un jour (interop avec
d'autres catalogues anar — CIRA, etc.). Ajouter une colonne **`notation text`**
(code CDD de la grille cotation, optionnel) = pont vademecum + aide au rangement.

## 6. Axe C — Gouvernance par consentement

- Colonne **`status`** sur `subjects` : `proposto` | `ativo` | `depreciado`
  (+ l'état « fusionné » géré par l'outil de merge existant).
- **Proposer** : tout staff catalogage crée un sujet en **`proposto`** et **peut
  l'utiliser tout de suite** (aucun blocage) → la précarité n'attend pas.
- **Activer** (`proposto → ativo`) : réservé à une **capacité de coordination
  catalogage** — *un droit, pas une personne*. Tenu par **Baqueiro aujourd'hui**,
  puis **Adriano Skoda, Karina Goto** et les suivant·es à mesure qu'ils·elles se
  saisissent de l'outil. *Une validation, pas un comité* ; le défaut penche vers
  « **oui, et** » (on intègre + on range), jamais « non » sec.
- **Dédoublonner** : l'outil de fusion (`ate_o3`) promu en **action gouvernée et
  tracée**.
- **Soupape** : le registre **mots-clés locaux** rend l'activation non bloquante.
- Traçabilité : `created_by`/`updated_by` déjà là.

## 7. Axe D — Le pont vademecum

- **Vademecum « Indexer un sujet »** (Communs) : comment choisir, granularité,
  quand proposer un terme, à quoi sert `scope_note`.
- **Cotation/CDD** (déjà en Communs) ← relié par `notation`.
- `scope_note` affichée **inline** dans le picker (guidance au point d'usage).
- **Suggestions assistées** (les 135 livres de la mémoire indexation) = « ça tend »
  injecté au catalogage.

## 8. UI — surtout de l'existant à compléter

- **Picker catalogage** (`search_subjects`) ✅ — ajouter : affichage `scope_note`,
  pastille « libellé manquant », bloc « mots-clés locaux ».
- **OPAC facettes/nuages** ✅ — afficher les libellés **localisés** (repli).
- **Écran gouvernance** (coordination) : file des `proposto`, activer / fusionner /
  déprécier ; **éditeur multilingue de libellés** (communauté de langue).

## 9. Confidentialité

Le vocabulaire matière est **public** (c'est la langue du catalogue) — **aucune
donnée sensible**. Seul l'audit « qui a proposé/modifié » est interne. Risque
quasi nul. (À l'opposé de la carte réseau — cf. mémoire cartographie.)

## 10. Décisions — actées / à trancher

**Actées (par l'existant)** : modèle `jsonb + parent_id` ; écriture catalogage
gardée RLS ; typeahead ; synchro publish ; fusion de doublons.

**Tranchées avec Xavier (15/06/2026) :**
- **D1. ✅ Oui** — registre à deux étages (mots-clés locaux libres **+** sujets contrôlés).
- **D2. ✅ jsonb** `{pref, alt[], hidden[]}` ; table SKOS dédiée en réserve (si export RDF un jour).
- **D3. ✅ Capacité de coordination catalogage** (un rôle, pas une personne) : Baqueiro aujourd'hui, Skoda/Goto et les suivant·es ensuite.
- **D4. ✅ v2** — `notation` CDD différée (non bloquante).
- **D5. ✅ Périmètre v1** validé (cf. §11), **par étapes** — mais la **v2 ne tardera pas** à être pensée/travaillée (consigne Xavier).

## 11. Périmètre — v1 (proposé) vs v2 (différé)

**v1** : (a) compléter les **10 locales** via Cowork ; (b) `status`
`proposto/ativo` + **soupape mots-clés locaux** ; (c) `scope_note` + pastille
« libellé manquant » dans le picker ; (d) vademecum « Indexer un sujet ».

**v2 (différé)** : synonymes/`notation` complets ; export **SKOS/RDF** ; écran de
gouvernance riche ; suggestions assistées automatisées ; relations associatives.
