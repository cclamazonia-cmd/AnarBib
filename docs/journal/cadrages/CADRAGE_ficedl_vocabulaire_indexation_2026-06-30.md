---
Genre : cadrage
Statut : 🟡 à débattre en AG réseau (avec représentant·es FICEDL) — n'arrête rien
Décisions citées : THES-1, THES-URI (REGISTRE §30) ; charte de langage inclusif v2 (source unique)
Origine : intégration du thésaurus partagé FICEDL (P1 → P3b, 25-30/06/2026) ; question soulevée le 30/06
Supersédé par : —
---

# Cadrage — Place du thésaurus FICEDL dans l'indexation matière d'AnarBib

> **Note de travail pour l'ordre du jour d'une AG réseau.** Elle **n'arrête rien** :
> elle pose une question politique et en expose les options, pour que l'assemblée —
> **en présence de représentant·es de la FICEDL** — tranche en connaissance de cause.
> La gouvernance du vocabulaire matière relève de l'AG, pas d'un arbitrage technique
> (THES-1, et doctrine « ouvrir l'édition = décision d'AG »).

## 1. La question

Jusqu'où s'appuyer sur le **thésaurus partagé FICEDL** (thesaurus.ficedl.info) pour
l'**indexation matière** d'AnarBib ? Faut-il pouvoir **cataloguer directement avec des
termes FICEDL**, ou conserver un vocabulaire propre **aligné** sur le commun ?

C'est une question de **principe** (souveraineté éditoriale et langage inclusif d'un
côté, fédération et interopérabilité de l'autre), pas de faisabilité : techniquement,
les trois options ci-dessous sont réalisables.

## 2. Ce qui existe déjà (état au 30/06/2026, en prod)

- **Cache FICEDL** (`public.ficedl_thesaurus_terms`) : copie ré-aspirable, **lecture
  seule**, du thésaurus FICEDL — **anti-fork absolu** (FICEDL = source de vérité ;
  AnarBib ne réécrit jamais un libellé, les affiche tels qu'aspirés). Navigation
  publique : `/thesaurus-ficedl`.
- **Vocabulaire matière PROPRE** (`public.subjects`) : c'est lui qui indexe les
  notices, **gouverné** par la coordination catalogage, **multilingue selon la charte
  inclusive**, avec hiérarchie, relations, statuts (`proposto` → `ativo` → `depreciado`),
  URI stable `app.anarbib.org/thesaurus/<slug>` (THES-URI), export SKOS.
- **Alignement** (P3b) : la coordination peut **relier** un sujet AnarBib à un ou
  plusieurs descripteurs FICEDL (`skos:exactMatch`/`closeMatch`). Effets : bloc
  « dans les catalogues partenaires » sur la page-sujet publique, et `skos:exactMatch`
  dans l'export. **Fédération entrante** déjà livrée.

> Autrement dit, le modèle actuel = **vocabulaire souverain + alignement au commun**.

## 3. La tension de fond

| Valeur | Tire vers… |
|---|---|
| **Souveraineté éditoriale** + **charte de langage inclusif** | un vocabulaire **propre** (le collectif décide ses termes, leur graphie inclusive, sa hiérarchie, ses notes) |
| **Fédération / interopérabilité / anti-silo** | s'appuyer sur le **commun FICEDL** (ne pas réinventer, faire dialoguer les catalogues libertaires) |

Le point dur : la charte régit **l'UI propre d'AnarBib**, **pas** le vocabulaire partagé
(le lui imposer serait un fork). Tant que FICEDL est une **référence/alignement**, pas de
conflit. Mais si les termes FICEDL deviennent les **libellés d'indexation affichés**,
leur graphie (non inclusive, coquilles, langues manquantes, conventions el/nl encore
provisoires, termes non traduits) **remonte dans la surface propre d'AnarBib**, sans
possibilité de correction (anti-fork). Symétriquement, l'indexation directe **cède
l'autonomie éditoriale** à une instance externe.

## 4. Les options

**Option A — Référence + alignement (statu quo, en prod).**
On catalogue avec les `subjects` AnarBib ; la coordination les aligne sur FICEDL.
→ *Préserve* autonomie + charte ; *offre* la fédération (découverte inter-catalogues,
SKOS). *Coût* : il faut entretenir son propre vocabulaire.

**Option B — Création de sujet assistée par FICEDL (proposée).**
Au catalogage, on cherche dans FICEDL → on **crée (ou réutilise) un sujet AnarBib
pré-rempli** depuis FICEDL, **possédé par le collectif** (libellé éditable selon la
charte) et **déjà aligné**. Le sujet naît en statut `proposto` → **revue d'activation
par la coordination = filtre charte** avant mise en service.
→ *Réconcilie* les deux valeurs : moins de réinvention, **sans céder** souveraineté ni
charte (anti-fork préservé, FICEDL inchangé). *Chiffrage* : ~½–1 j (1 RPC
`fn_subject_create_from_ficedl` + UI dans le picker de catalogage), pas de table neuve.

**Option C — Indexation directe par termes FICEDL (écartée en l'état).**
FICEDL devient le vocabulaire d'indexation affiché.
→ *Importe* la graphie/les choix FICEDL dans l'UI propre (**contre la charte**) et
*cède* l'autonomie. Non recommandée sans décision politique explicite.

## 5. Ce qui rend l'option B « propre »

Le mécanisme clé est le **statut `proposto` + la revue d'activation** : le libellé naît
en graphie FICEDL mais **ne devient public (`ativo`) qu'après passage par la
coordination**, qui l'ajuste à la charte. C'est le garde-fou qui évite que FICEDL
n'impose sa graphie à la surface d'AnarBib, tout en gardant le bénéfice « ne pas partir
de zéro ». À assumer explicitement (UI + doctrine) si l'option est retenue.

## 6. À trancher AVEC la FICEDL (pas seulement en interne)

- **Réciprocité sortante** : comment AnarBib devient atteignable *depuis* les catalogues
  partenaires (clé `mot_id`) — aujourd'hui hors périmètre, suppose une coordination.
- **Remontée des corrections à la source** : circuit pour signaler coquilles / langues
  manquantes / troncatures (déjà repérées à l'audit) — *anti-fork* : on corrige **chez
  FICEDL**, pas en forkant. Qui ? À quel rythme ?
- **Conventions ouvertes** : el et nl encore provisoires côté charte ET côté FICEDL —
  occasion de converger.
- **Gouvernance du commun** : qui décide des évolutions du thésaurus partagé, et comment
  AnarBib y participe sans le capter.

## 7. Ce que cette note NE décide pas

Tout. Le choix A/B/C, l'ampleur du recours au commun, l'ouverture éventuelle de la
création assistée aux contributeur·rices (vs coordination seule), et les points §6
relèvent de l'**AG réseau avec la FICEDL**. La présente note sert de base de discussion.

---

## Annexe — artefacts (vérifiés au 30/06/2026)

- **Base** : `public.ficedl_thesaurus_terms` (cache), `public.subject_ficedl_links`
  (alignement n:m exact/close), `public.subjects` (vocabulaire propre).
- **RPC** : `api.fn_subject_add/remove_ficedl_match` (coord), `api.subject_ficedl_links_v1`,
  `api.subject_detail_v1`, `api.thesaurus_export_v1` (enrichi `ficedl`).
- **Front** : `/thesaurus-ficedl` (navigation FICEDL), `/thesaurus/:slug` (fiche-sujet),
  section « Alignement FICEDL » dans `SubjectLabelEditor` (coordination).
- **Outillage** : `scripts/ficedl_thesaurus_scrape.mjs` (aspiration anti-fork),
  `scripts/ficedl_thesaurus_sync.mjs` (re-sync). Audit : `docs/journal/ficedl/`.
- **Doctrine** : REGISTRE §30 (THES-1/URI) ; charte v2 (source unique langage inclusif) ;
  politique anti-fork de l'import (en-tête du scraper).

*Note de cadrage produite le 30/06/2026 — chantier « Intégration thésaurus FICEDL ».*
