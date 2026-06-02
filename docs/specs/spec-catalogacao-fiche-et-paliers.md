# Spec — CatalogaçãoPage : fiche, registre de champs & paliers

- **Version :** 0.3 (arbitrages A1–A3 actés)
- **Date :** 2026-06-01
- **Statut :** 🟡 Spécification, à implémenter — premier lot du chantier Catalogação (lot UX/champs, Q1 du cadrage)
- **Périmètre :** modèle de champs de la fiche, profondeur en 3 paliers, types de matériel et champs par type, lisibilité au niveau champ. Page chrome (header/hero/polices) **hors périmètre** — renvoyée au cahier des charges visuel.
- **Auteur :** Xavier (coordination AnarBib) — rédaction assistée
- **Méthode :** parité fonctionnelle + qualitative + audit doctrinal (même grille que #BIBLIO / Importações / Acquisition)
- **Référence visuelle normative :** `maquette_fiche_catalogacao_v2.html` (01/06) — maquette interactive aux **vrais tokens AnarBib** (Bitter + Fira Sans, `#b32025`/`#e11d2f`, classes `.ab-*` réelles, topbar/hero/badges) ; *fait foi* pour le comportement palier × matériel et le relief des champs. (v1 = brouillon de concept, archivé.)

**Dépendances entrantes :**
- `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01` (arbitrages Q1, Q7, Q9, Q11 ; sections 8.E/8.F/8.G/8.H)
- `ref_types_materiel_catalogacao_2026-06-01` (liste figée des 12 types)
- `cles_i18n_requises_catalogacao_2026-06-01` (audit des 258 clés + dette d'externalisation)

**Dépendances sortantes :**
- `spec-acquisition-provenance-v0_1` (les champs acquisition/proveniência migrent vers l'exemplaire — section 5.7 ci-dessous)
- *spec exemplaires & circulation* (à venir — la destination de circulation par exemplaire ; ici on ne pose que le **padrão** fiche)
- *spec module capas* (à venir — l'emplacement capa et le bouton « Buscar capa »)
- `spec-granularite-item` (#MODEL-item-grain — articulation circulation padrão ↔ exemplaire)

---

## 1. Objet & posture

La page Catalogação est l'atelier éditorial du réseau : c'est là qu'une fiche bibliographique prend forme avant publication. Le portage React actuel souffre de trois maux qui se renforcent : une **lisibilité faible** (labels peu contrastés, bordures de champ quasi invisibles, formulaire posé en transparence sur le hero de la biblio), une **profondeur binaire** (simple/complet) gérée par des conditions `isComplete` éparpillées et fragiles, et une **internationalisation partielle** (plusieurs composants encore en pt-BR codé en dur).

Cette spec pose le **socle** qui résout les trois d'un coup : un **registre de champs déclaratif** unique d'où découlent le rendu, la profondeur en **trois paliers** (Simples / Avançado / Completo), le filtrage par **type de matériel**, et un **système de champs lisibles**. Tout le reste du chantier Catalogação (circulation par exemplaire, doublons, capas, sources externes) se branche sur ce socle.

Posture (Q7, validée) : **UI sobre**. On ne reproduit pas les pavés pédagogiques du legacy (`*StructureSummary`, `*FlowSummary`, pills multiples). La posture « commons en construction » de Bologne est mieux servie par des fiches lisibles que par des panneaux doctrinaux denses ; on conserve au plus un **guide contextuel concis** par palier et un résumé « arquitetura documental » réservé au mode Completo.

---

## 2. Périmètre

**Dans le périmètre :**
- Le modèle de champs (registre déclaratif) et sa fonction de rendu.
- Les trois paliers et la répartition des champs.
- La liste des 12 types de matériel et les champs propres à chaque type, par palier.
- La règle de visibilité `tier × matériel`.
- Les principes de lisibilité **au niveau champ** (relief, focus, surface).
- L'i18n : harmonisation des clés, externalisation des chaînes en dur, livraison 8 locales.

**Hors périmètre (renvoyé ailleurs) :**
- **Header / hero / choix de polices / palette de marque** → **cahier des charges visuel** (à venir). Les choix typographiques de la maquette v1 sont *illustratifs*, non normatifs.
- **Destination de circulation par exemplaire** (`circulation_policy` + `visibility`) → *spec exemplaires & circulation*. Ici on ne traite que le **padrão** au niveau fiche (§5.6).
- **Recherche/import de couverture** → *spec module capas*. Ici on ne pose que l'emplacement et le point d'entrée.
- **Détection de doublons** → traitée au lot circulation/doublons. Ici on réserve seulement l'emplacement du bandeau (§7.4).
- **Migration des données** : ce lot n'entraîne **aucune migration DB** (hors libellés i18n et bascule de la valeur de mode en localStorage). La valeur `tipo_material='tract'` reste inchangée (correction de *label* seulement, option (a) de la référence types).

---

## 3. Le registre de champs (architecture 8.E)

### 3.1 Principe

Le formulaire **n'est plus** une suite de blocs JSX conditionnés par des `isComplete` épars. Il est **rendu à partir d'un registre déclaratif** : une liste de groupes, chaque groupe contenant des champs, chaque champ portant les métadonnées qui décident *quand* et *comment* il s'affiche. C'est exactement ce que la maquette v1 met en œuvre et valide.

Bénéfices : cohérence de rendu, lisibilité du code, i18n centralisée, maintenance (un champ = une entrée), et extensibilité (les lots suivants ajoutent des entrées, pas des branches JSX).

### 3.2 Descripteur de champ

```js
// Champ
{
  id:        'titulo',              // identifiant stable (= clé d'état + ancre)
  label:     'catalogacao.field.title',   // clé i18n (jamais de littéral)
  tier:      1,                     // palier minimal : 1 Simples · 2 Avançado · 3 Completo
  mat:       'all',                 // 'all' | ['livro','periodico', …] types applicables
  type:      'text',                // text | select | textarea | seg | contrib | cover | fine
  span:      2,                     // 1 | 2 | 3 colonnes (grille 3-col)
  ph:        'catalogacao.ph.title',// clé i18n du placeholder (optionnel)
  hint:      'catalogacao.hint.title', // clé i18n d'aide sous le champ (optionnel)
  opts:      [...],                 // pour select/seg : options (clés i18n ou valeurs)
  req:       true,                  // marqueur visuel « requis » (optionnel)
  watch:     'dup',                 // déclencheur optionnel (ex. ISBN → bandeau doublon)
}

// Groupe (section)
{
  id:      'ident',
  title:   'catalogacao.section.ident',
  tag:     'catalogacao.tag.core',  // libellé discret (núcleo / avançado / completo / material)
  tier:    null,                    // palier minimal du groupe entier (optionnel)
  mat:     'all',                   // matériels applicables au groupe (optionnel)
  special: null,                    // 'contrib' | 'fine' | 'cover' (rendu dédié)
  fields:  [ … ],
}
```

### 3.3 Règle de visibilité

```
champ visible  ⇔  champ.tier ≤ palierCourant  ET  matchMat(champ.mat)
groupe visible ⇔  matchMat(groupe.mat)  ET  (groupe.tier ?≤ palierCourant)  ET  (≥1 champ visible OU special)
matchMat(m)    ⇔  m === 'all'  OU  m.includes(matérielCourant)
```

Le rendu se recalcule à chaque changement de **palier** ou de **type de matériel**, avec une micro-transition de révélation (cf. maquette). Pas d'état caché : un champ masqué par le palier conserve sa valeur (on ne perd jamais de donnée déjà saisie en redescendant de palier — cf. legacy `catalogModeHint` : « muda só a profundidade, não altera dados salvos »).

---

## 4. Les trois paliers (Q11, validé)

| Palier | `data-catalog-mode` | Esprit | Contenu (cœur livre) |
|---|---|---|---|
| **Simples** | `simple` | Biblio militante, sans prétention académique | Type · titre · autoria/responsabilité · ano · editora · idioma · cote/CDD · **circulação padrão** · capa · ISBN (livro) / ISSN (periódico) |
| **Avançado** | `advanced` | « Bon·ne bibliothécaire » sans MARC | + subtítulo · edição · coleção/série · local · páginas · contributeurs typés · assuntos · notas · acquisition de base |
| **Completo** | `complete` | Exhaustif, non touffu | + zones ISBD · MARC JSON · identifiants d'autorité (VIAF/ISNI/Wikidata) · sous-formulaires matériels complets · proveniência complète (renvoi spec acquisition) · arquitetura documental |

**Rétro-compatibilité** (§9, **arbitrage A3**) : on **insère** `advanced` au milieu sans toucher les deux valeurs existantes → `simple | advanced | complete`. **Aucun remap** de la valeur localStorage existante (`simple`/`complete` restent valides ; `advanced` est nouvelle). La classe CSS `.mode-complete-only` est **retirée** : la visibilité passe par le registre (JS), plus par des sélecteurs CSS de mode.

---

## 5. Types de matériel & champs par type

Liste des 12 types et libellés PT-BR : voir `ref_types_materiel_catalogacao_2026-06-01` (source de vérité). **La liste est entièrement sélectionnable à tous les paliers** ; seule la profondeur des champs par type suit le palier.

### 5.1 Champs cœur (`mat: 'all'`)

| Champ | tier | span | note |
|---|---|---|---|
| `tipo_material` (sélecteur) | 1 | — | pilote le filtrage matériel |
| `titulo` | 1 | 2 | requis |
| `autor` / responsabilité | 1 | 2 | + bloc contributeurs en tier 2 (§5.5) |
| `ano` | 1 | 1 | |
| `editora` | 1 | 1 | `mat` ≠ digital/audio/audiovisual (cf. 5.4) |
| `idioma` | 1 | 1 | select 8+ langues |
| `cdd` (cote) | 1 | 1 | |
| `circulação local padrão` | 1 | — | §5.6 |
| `subtitulo` | 2 | 2 | |
| `edicao` | 2 | 1 | livro/zine/dossie |
| `local_publicacao` | 2 | 1 | |
| `paginas` | 2 | 1 | livro/zine/dossie |
| `assuntos` | 2 | 3 | textarea |
| `notas` | 2 | 3 | textarea |

### 5.2 Identifiants & ISBN/ISSN

| Champ | tier | `mat` |
|---|---|---|
| `isbn` | 1 | `livro` |
| `issn` | 1 | `periodico` |
| `marc_json` | 3 | all |
| zones ISBD (0–8, générées) | 3 | all |
| `viaf` / `isni` / `wikidata` | 3 | all |

### 5.3 Capa (renvoi spec capas)

Emplacement capa + bouton « Buscar capa » à tous les paliers (le bouton ouvre le module capas — hors périmètre ici, on réserve l'ancre `cover_object_path` et l'entrée d'action).

### 5.4 Champs propres à chaque type (jeux *simple* / *complet*)

> **Source de vérité.** Ces jeux ne sont pas à inventer : ils existent déjà dans l'i18n sous `catalogacao.guide.<code>.simple` et `catalogacao.guide.<code>.complete` (12 types, déjà traduits). Le registre **s'aligne sur ces chaînes**, qui font foi. Le tableau ci-dessous les reprend (pt-BR).

| Type | `guide.<code>.simple` | `guide.<code>.complete` |
|---|---|---|
| **livro** | Título, autoria, editora, local, data, idioma e assuntos | Coleção, detalhes materiais, notas, identificadores e campos especiais |
| **periodico** | Título do periódico, volume, número, data, ISSN | Fascículo, periodicidade, dados de seriado |
| **panfleto** (`tract`) | Título, campanha, emissor, data aproximada | Local de difusão, formato, técnica de impressão |
| **cartaz** | Título, campanha, emissor, formato | Técnica, estado físico, recto/verso |
| **audio** | Título, duração, suporte, participantes | Formato técnico, idioma falado, tipo de gravação |
| **audiovisual** | Título, duração, direção, suporte | Idioma, legendas, participantes |
| **recurso_digital** | Título, URL, condição de acesso | Restrição, uso, nota de arquivo |
| **dossie** | Título, alcance, período | Organizações, contexto político |
| **tese** | Título, autoria, universidade, ano | Coleção, CDD, notas, orientador |
| **artigo** | Título, autoria, periódico ou livro-fonte | Volume, número, páginas, ISSN/ISBN |
| **relatorio** | Título, organização emissora, data | Destinatário, notas internas |
| **zine** | Título, autoria/coletivo, data, local | Edição, tiragem, formato, técnica |

panfleto et cartaz partagent la même famille « material efêmero militante » (`catalogacao.section.tract`) : champs `campaign`/`emitterOrg`/`approxDate`/`physicalFormat`/`rectoVerso`/`printTechnique`/`physicalState`/`diffusionPlace`, paramétrés par `mat: ['tract','cartaz']`. Les libellés de champ sont tous présents en pt-BR sous `catalogacao.field.*` (81 clés disponibles).

> **Palier intermédiaire.** Les guide strings sont aujourd'hui **binaires** (`.simple` / `.complete`). Le mapping ternaire retenu : champs du `.simple` → **tier 1** ; structurels transversaux (subtítulo, edição, local, páginas, contribuintes, assuntos, notas) → **tier 2 (Avançado)** ; champs du `.complete` → **tier 3**. Le coût i18n de cette 3ᵉ marche est traité au §8.

### 5.5 Autores e responsabilidades (tier 2, all)

Bloc contributeurs typés (Autor / Coautor / Coletivo-Organização / Tradutor / Prefácio), avec marqueur « principal ». Conserve l'existant React (`addContributor` etc.). En tier 1, on se contente du champ `autor` libre.

### 5.6 Circulação local padrão (le **padrão** fiche, pas la destination exemplaire)

Le champ « Circulação local padrão » existe déjà en prod au niveau fiche. On le **conserve** ici comme **valeur par défaut** à 3 valeurs : `Emprestável` · `Consulta` · `Empréstimo + consulta`.

> **Articulation (Q9 / 8.D / #MODEL-item-grain).** Ce padrão ne décide rien à lui seul : il **pré-remplit** la destination de chaque exemplaire créé. La **vérité de circulation est portée par l'exemplaire** (`circulation_policy` + `visibility`, dont l'« archivo » staff_only), traitée dans la *spec exemplaires & circulation*. Le mot « padrão » est déjà juste : il invite l'override par exemplaire. Cette spec-ci **n'introduit pas** la 4ᵉ valeur « Arquivo » au niveau fiche (l'archivage est une visibilité par copie, pas un défaut de fiche).

### 5.7 Aquisição & proveniência (tier 3) — arrimage spec acquisition

Les champs `acquisition_mode` / `acquisition_date` / `provenance_note` existent au niveau fiche aujourd'hui (renseignés 0/2450 — capacité latente). La `spec-acquisition-provenance-v0_1` (Q1) **descend la proveniência à l'exemplaire**. Donc ici :
- on **conserve** ces champs en tier 3 comme legacy fiche-level, marqués « à relocaliser » ;
- on **n'over-spécifie pas** : le modèle cible (colonnes exemplaire) appartient à la spec acquisition, et sa migration sera **mutualisée avec la migration circulation** sur `exemplares`/`exemplar_drafts` (une seule vague — cf. cadrage Q9).

---

## 6. Règle de visibilité — synthèse opérationnelle

- Sélecteur de palier (segmented Simples/Avançado/Completo) en tête de page, persisté en localStorage (clé `catalogacaoMode`, valeurs `simple | advanced | complete`).
- Sélecteur `tipo_material` dans la fiche.
- À chaque changement, re-render depuis le registre selon §3.3.
- **Liste de types non tierée** : tous les types restent sélectionnables en Simples.
- Aucune perte de données en changeant de palier (les valeurs persistent en état).

---

## 7. Lisibilité au niveau champ (8.G)

Principes normatifs **au niveau champ** (le chrome — header/hero/polices — relève du cahier des charges).

> **Constat clé (revue du kit, 01/06).** Le design system fournit **déjà** des champs lisibles : `.ab-input` / `.ab-select` / `.ab-textarea` ont une bordure de repos visible (`--brand-panel-border-strong` = `rgba(255,255,255,.18)`), un anneau de focus rouge (`box-shadow: 0 0 0 3px rgba(225,29,47,.24)`) et un padding correct (`12px 14px`). **L'illisibilité de Catalogação ne vient donc pas d'un manque de système, mais de styles *inline* qui court-circuitent ces classes.** La correction 8.G est par conséquent une **adoption**, pas une création (§7.5).

### 7.1 Relief des champs
- **Utiliser les classes `.ab-*`** plutôt que des styles inline : bordure de repos visible, anneau de focus marque, padding confortable sont déjà fournis.
- Ne jamais réintroduire `border: rgba(255,255,255,.12)` / `background: rgba(0,0,0,.3)` en inline (cause directe du flou actuel).

### 7.2 Labels & hiérarchie
- `.ab-field__label` (`--brand-muted` = `#d4cec3`, poids 600) est déjà lisible — l'adopter au lieu des labels inline ternis.
- Sections en `.ab-sheet` / cartes avec en-tête clair (`.ab-sheet__head`) ; séparation nette entre groupes.
- Indices/aides (`hint`) discrets mais lisibles, sous le champ.

### 7.3 Surface du formulaire (cas « fresque »)
- Le formulaire doit reposer sur une **surface pleine ou un voile** (scrim) garantissant le contraste **quel que soit le hero/thème** choisi par la biblio. Sur la capture de prod, les champs en transparence sur la fresque murale sont illisibles — à proscrire.

### 7.4 Réservation d'emplacements (hors périmètre, ancrés ici)
- Bandeau **doublon** (lot doublons) : emplacement réservé en tête de fiche, surgit sur signal `watch:'dup'`.
- Point d'entrée **capa** : emplacement réservé (§5.3).

### 7.5 Réduction de l'inline
- **Remplacer les styles inline par les composants/classes existants** : `<Input>`/`<Select>`/`<Textarea>` (de `@/components/ui`) ou directement `.ab-input` / `.ab-select` / `.ab-textarea` / `.ab-field` / `.ab-field__label` ; sections en `.ab-sheet`. Ne pas créer de nouvelles classes `.cat-*` : le kit existe.
- Pour les contrôles propres à la fiche sans équivalent direct (segmented paliers, segmented circulation), styler **sur le même registre** que `.ab-button--mini` / `.ab-pill`, en variables `--brand-*`.

---

## 8. i18n

- **Couverture pt-BR : complète (Q3 clos, 01/06).** Sur 258 clés extraites des composants, **246 réelles sont présentes** dans `pt-BR.json` (qui compte 388 clés `catalogacao.*`) ; les 12 « manquantes » sont des faux positifs (id de panneaux/onglets : `booksPanel`, `queuePanel`, `isbd`…). Reste à diffé les **7 autres locales** (fr, es, it, de, en, ca, eo) quand les fichiers seront fournis.
- **Coût i18n du palier intermédiaire (ternaire) — arbitré.** Les guide strings existent en **binaire** (`catalogacao.guide.<code>.simple` / `.complete`) et les libellés d'interface aussi (`catalogacao.interfaceSimple`, `catalogacao.interfaceComplete`, `catalogacao.modeLabel = "Modo da ficha"`). Le passage en ternaire **ajoute un seul libellé d'interface `catalogacao.interfaceAdvanced`** (× 8 locales). **Arbitrage A2 : mapping-only acté** — aucune nouvelle guide string ; le palier Avançado est défini par mapping (`.simple` → tier 1 ; structurels → tier 2 ; `.complete` → tier 3, cf. §5.4), le panneau guide affichant `.simple` + `.complete`. Rédiger un `guide.<code>.avancado` dédié (12 × 8 = 96 chaînes) reste une **amélioration différable**, non bloquante.
- **Dette d'externalisation** : QueuePanel, CatalogPanel, ExemplarDraftForm, AuthorDraftForm contiennent plus de chaînes pt-BR en dur que de clés. Le re-render par registre est **le** moment pour tout externaliser.
- **Harmonisation des namespaces** : labels de type sur `catalogacao.material.<code>` (l'existant mélange `material.*` et `section.*`). Champs `catalogacao.field.*` (81 clés déjà là), placeholders `catalogacao.ph.*`, aides `catalogacao.hint.*`, sections `catalogacao.section.*`.
- **Correction de deux labels** (cf. `ref_types_materiel`) : `catalogacao.material.tract` « Panfleto / **tracto** » → « Panfleto / **volante** » ; `catalogacao.material.cartaz` « Cartaz / **afixo** » → « Cartaz / **lambe-lambe** » — sur les 8 locales. **Arbitrage A1 : correction de label seulement** ; le code interne stocké `tract` est **conservé** (renommage `tract→panfleto` = dette différée, hors Bologne).
- **Livraison 8 locales en une passe** par paquet. Fichiers plats, LF sans BOM, 2 espaces.
- **PT-BR strict** : aucun PT-PT, aucun gallicisme.

---

## 9. Implémentation & rétro-compatibilité

**Aucune migration DB** pour ce lot (hors libellés i18n).

Séquence de paquets proposée :
1. **P1 — Registre + rendu.** Définir le registre (groupes/champs cœur) et la fonction de rendu pilotée par `tier × matériel`. Migrer `BookDraftForm` en premier (le plus riche) vers le rendu par registre.
2. **P2 — Paliers ternaires.** `data-catalog-mode` `simple | advanced | complete` (insertion de `advanced`, **sans remap** des valeurs existantes) ; segmented control 3 états ; retrait de `.mode-complete-only`.
3. **P3 — Champs par type.** Brancher les jeux simple/complet des 12 types (§5.4) ; familles partagées (panfleto+cartaz).
4. **P4 — Lisibilité.** Adopter les classes `.ab-*` (relief/focus déjà fournis), surface/scrim ; suppression de l'inline (§7).
5. **P5 — i18n.** Harmonisation des clés + externalisation des chaînes en dur + 8 locales. Externaliser au passage QueuePanel/CatalogPanel/Exemplar/Author.
6. **P6 — Réservations.** Ancres bandeau doublon + entrée capa (emplacements seulement ; logique dans les lots dédiés).

Rétro-compat : les valeurs localStorage existantes (`simple`, `complete`) restent valides telles quelles ; `advanced` est simplement une nouvelle valeur intermédiaire. Aucune fiche existante n'est touchée.

---

## 10. Liens

- **Référence visuelle :** `maquette_fiche_catalogacao_v1.html`
- **Types de matériel :** `ref_types_materiel_catalogacao_2026-06-01.md`
- **Clés i18n :** `cles_i18n_requises_catalogacao_2026-06-01.md`
- **Cadrage parent :** `CADRAGE_catalogacao_parite_et_module_capas_2026-06-01.md`
- **Specs sœurs :** `spec-acquisition-provenance-v0_1` (proveniência exemplaire), *spec exemplaires & circulation* (à venir), *spec module capas* (à venir), `spec-granularite-item` (#MODEL-item-grain)

---

*Fin v0.3. Arbitrages actés : A1 (correction de label seulement, code `tract` conservé) ; A2 (palier Avançado en mapping-only, +1 libellé `interfaceAdvanced` × 8 locales) ; A3 (`simple | advanced | complete` — insertion sans remap). À promouvoir en 🟢 référence après réception du cahier des charges visuel (chrome) et diff des 7 autres locales.*
