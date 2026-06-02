# Référence — Types de matériel (CatalogaçãoPage)

> Liste figée le 01/06/2026 après revue PT-BR sur capture de prod. Source de vérité pour la spec UX et pour l'i18n. **PT-BR strict** — aucun PT-PT, aucun gallicisme.

## Les 12 types

| # | Code interne (`tipo_material`) | Label PT-BR (figé) | Clé i18n cible |
|---|---|---|---|
| 1 | `livro` | Livro / brochura | `catalogacao.material.livro` |
| 2 | `periodico` | Periódico / revista / boletim | `catalogacao.material.periodico` |
| 3 | `tract` *(→ voir note)* | **Panfleto / volante** | `catalogacao.material.panfleto` |
| 4 | `cartaz` | **Cartaz / lambe-lambe** | `catalogacao.material.cartaz` |
| 5 | `audio` | Áudio (podcast, gravação) | `catalogacao.material.audio` |
| 6 | `audiovisual` | Audiovisual (vídeo, filme) | `catalogacao.material.audiovisual` |
| 7 | `recurso_digital` | Recurso digital nativo | `catalogacao.material.recurso_digital` |
| 8 | `dossie` | Dossiê / conjunto militante | `catalogacao.material.dossie` |
| 9 | `tese` | Tese / dissertação | `catalogacao.material.tese` |
| 10 | `artigo` | Artigo / capítulo | `catalogacao.material.artigo` |
| 11 | `relatorio` | Relatório / documento interno | `catalogacao.material.relatorio` |
| 12 | `zine` | Zine / fanzine | `catalogacao.material.zine` |

## Corrections appliquées (01/06)

- **#3** « Panfleto / **tracto** » → « Panfleto / **volante** ». *Tracto* = gallicisme (« tract » FR luso-déguisé), n'existe pas en PT-BR. *Volante* = feuille volante distribuée, terme militant brésilien courant.
- **#4** « Cartaz / **afixo** » → « Cartaz / **lambe-lambe** ». *Afixo* sonne faux en BR (évoque l'acte d'afficher, pas l'objet). *Lambe-lambe* = affiche collée en rue, vivant et à-propos pour l'affiche militante.

Le reste de l'interface (capture de prod) est en **PT-BR propre** : marqueurs vérifiés *cotidiano*, *sobrenome*, *rascunho*, *buscar*, *dossiê* (et non *dossier*).

## Doctrine

- **Liste entièrement sélectionnable quel que soit le palier** (Simples/Avançado/Completo). Seule la *profondeur des champs par type* suit le palier — pas la liste elle-même : on doit pouvoir déclarer une *tese* même en mode Simples.
- **i18n** : un label par type × **8 locales** (pt-BR, fr, es, it, de, en, ca, eo). Harmoniser le namespace sur `catalogacao.material.<code>` (l'existant mélange `material.*` et `section.*` — à uniformiser).
- **Code interne `tract`** : c'est aussi un gallicisme côté valeur stockée. Deux options :
  - **(a) minimal** — ne corriger que le *label* d'affichage, garder le code `tract` (zéro migration de données).
  - **(b) propre** — renommer la valeur `tract` → `panfleto` (migration touchant les lignes existantes `books`/`book_drafts`/`exemplares` ; basse priorité, à grouper avec une autre vague). 
  - *Reco : (a) maintenant, (b) en option différée.* → à trancher à la rédaction de la spec.
