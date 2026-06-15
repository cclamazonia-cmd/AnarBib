# Audit i18n d'AnarBib

**Date** : 2026-04-28
**Périmètre** : intégralité du dossier `src/`
**Commit analysé** : `7a4b7ec`
**Méthode** : extraction statique des appels `t({id:'...'})` dans tous les fichiers `.jsx`/`.js`, comparaison avec les 6 fichiers JSON de locale.

---

## Sommaire

1. [Synthèse](#synthèse)
2. [Méthode](#méthode)
3. [État de la couverture par locale](#état-de-la-couverture-par-locale)
4. [Clés manquantes dans les 6 locales (123)](#clés-manquantes-dans-les-6-locales-123)
5. [Asymétrie entre locales](#asymétrie-entre-locales)
6. [Clés dynamiques (16 sites)](#clés-dynamiques-16-sites)
7. [Clés orphelines (316)](#clés-orphelines-316)
8. [Bugs annexes détectés](#bugs-annexes-détectés)
9. [État du langage inclusif](#état-du-langage-inclusif)
10. [Plan de correction proposé](#plan-de-correction-proposé)

---

## Synthèse

L'infrastructure `react-intl` d'AnarBib est saine — un seul pattern d'appel utilisé partout (`t({id:'...'})`), une configuration propre, une logique de détection de locale fonctionnelle. Les fichiers JSON sont étonnamment équilibrés en taille (1277 à 1297 clés). **Mais il y a 123 clés référencées dans le code qui ne sont définies dans aucune des 6 locales** : sur les pages concernées, l'utilisateur·rice voit l'identifiant brut (`auth.create.acceptRules` au lieu de « J'accepte les règles ») au lieu du texte traduit.

Les autres constats principaux sont :

- **990** clés distinctes utilisées dans le code applicatif.
- **123** clés sont utilisées mais absentes des 6 locales (~12,5% de la surface).
- **316** clés vraiment orphelines (présentes dans les JSON mais jamais utilisées dans le code) — soit ~25% de chaque fichier de locale est mort.
- **114** clés présentes dans les JSON sont alimentées dynamiquement (préfixes connus comme `gender.*`, `material.*`, etc.) — ce ne sont **pas** des orphelines réelles.
- **16** sites d'appel construisent l'identifiant à la volée (`` t({id: `country.${author.country}`}) ``) — à auditer un par un, deux familles ont 0 clé en base.
- **2 préfixes critiques sont vides** : `country.*` et `account.renew.*` — les valeurs s'affichent en raw.
- **Asymétrie historique pt-BR** : la locale de référence accuse un retard de 14 à 20 clés sur les 5 autres (clés `rede.admins.*`, `biblioteca.comms.sendMode.*`, `notif.category.*` ajoutées dans le code et traduites partout sauf en pt-BR).
- **Langage inclusif inégal** entre les langues : excellent en fr et de, partiel en pt-BR et es, absent en it.

### Vue d'ensemble en chiffres

| Métrique | Valeur |
|---|---|
| Clés distinctes utilisées dans le code | 990 |
| Sites d'appel dynamiques (`t({id: \`...${x}\`})`) | 16 |
| Clés manquantes dans les 6 locales | **123** |
| Clés orphelines (apparentes) | 430 |
| dont alimentées dynamiquement (faux orphelins) | 114 |
| dont **vraiment** orphelines | **316** |

---

## Méthode

L'extraction repose sur trois patterns d'appel à `react-intl` :

```
t({id: '...'})              ← seul pattern réellement utilisé dans AnarBib
formatMessage({id: '...'})
<FormattedMessage id="..." />
```

Un seul pattern est effectivement utilisé dans le code (`t({id:'...'})` après destructuration `const { formatMessage: t } = useIntl()`). Les sites d'appel dynamiques (avec template literal `` `prefix.${var}` ``) sont détectés séparément, parce qu'ils ne peuvent pas être validés statiquement et nécessitent un audit manuel des familles de clés correspondantes.

L'extraction s'effectue par expression rationnelle ligne à ligne — robuste pour le pattern usuel mais ne gérerait pas un appel en multi-lignes. Vérification empirique : aucun appel multi-ligne détecté dans le code actuel.

---

## État de la couverture par locale

La couverture mesure le pourcentage de clés *utilisées dans le code* qui sont *présentes dans la locale*.

| Locale | Total clés | Clés utilisées présentes | Couverture | Manquantes |
|---|---|---|---|---|
| `pt-BR` | 1277 | 866 | 87.5% | 124 |
| `fr` | 1277 | 866 | 87.5% | 124 |
| `es` | 1291 | 867 | 87.6% | 123 |
| `en` | 1297 | 867 | 87.6% | 123 |
| `it` | 1296 | 867 | 87.6% | 123 |
| `de` | 1296 | 867 | 87.6% | 123 |

Toutes les locales ont une couverture similaire (~87,5%) — preuve que les clés manquantes ne sont pas un problème de retard de traduction d'une locale, mais bien des clés référencées dans le code et **jamais ajoutées nulle part**.

---

## Clés manquantes dans les 6 locales (123)

Ces clés sont utilisées dans le code mais **n'existent dans aucun fichier de traduction**. À l'écran, l'utilisateur·rice voit l'identifiant brut (`auth.create.addr1`) au lieu du texte traduit. Il faut les ajouter dans les 6 locales en une passe.

### Répartition par domaine

| Domaine | Nombre | Page principale concernée |
|---|---|---|
| `auth.*` | 43 | src/pages/public/CriarContaPage.jsx & CadastroPage.jsx |
| `catalog.*` | 22 | src/pages/public/CatalogPage.jsx |
| `catalogacao.*` | 21 | src/pages/catalogacao/*.jsx |
| `account.*` | 10 | src/pages/account/AccountPage.jsx |
| `resource.*` | 9 | src/pages/public/ResourcePage.jsx |
| `reader.*` | 8 | src/pages/public/ReaderPage.jsx |
| `panel.*` | 7 | src/pages/painel/PanelPage.jsx |
| `book.*` | 2 | src/pages/public/BookPage.jsx |
| `roles.*` | 1 | (clé dynamique mal détectée) |

### Détail des clés manquantes

#### `auth.*` — 43 clés

```
auth.create.acceptRules
auth.create.acceptRulesRequired
auth.create.addr1
auth.create.addr2
auth.create.addressTitle
auth.create.back
auth.create.bairro
auth.create.cep
auth.create.checkConsent
auth.create.city
auth.create.consentEmail
auth.create.country
auth.create.email
auth.create.fillRequired
auth.create.firstName
auth.create.gender
auth.create.genderF
auth.create.genderM
auth.create.genderNB
auth.create.genderNone
auth.create.genderOptional
auth.create.genderOther
auth.create.haveAccount
auth.create.lastName
auth.create.libraryHint
auth.create.noLibrary
auth.create.phone
auth.create.phonePh
auth.create.publicIdHint
auth.create.required
auth.create.securityId
auth.create.securityPw
auth.create.securityTitle
auth.create.selectLibrary
auth.create.selectPh
auth.create.state
auth.create.statePh
auth.create.submit
auth.create.submitting
auth.create.subtitle
auth.create.title
auth.create.unit
auth.create.yourPublicId
```

#### `catalog.*` — 22 clés

```
catalog.advancedSearch.toggle
catalog.chip.cdd
catalog.chip.collection
catalog.chip.isbn
catalog.chip.language
catalog.chip.material
catalog.chip.place
catalog.chip.subjects
catalog.filters.cdd
catalog.filters.cddPh
catalog.filters.collection
catalog.filters.collectionPh
catalog.filters.isbn
catalog.filters.isbnPh
catalog.filters.language
catalog.filters.languagePh
catalog.filters.material
catalog.filters.materialAll
catalog.filters.place
catalog.filters.placePh
catalog.filters.subjects
catalog.filters.subjectsPh
```

#### `catalogacao.*` — 21 clés

```
catalogacao.author.notes
catalogacao.bio.placeholder
catalogacao.bio.save
catalogacao.bio.translations
catalogacao.field.focusNow
catalogacao.msg.bnOpened
catalogacao.msg.noCandidates
catalogacao.msg.worldcatOpened
catalogacao.ph.bioHint
catalogacao.ph.bioPlaceholder
catalogacao.ph.notesHint
catalogacao.ph.notesPlaceholder
catalogacao.ui.addAuthor
catalogacao.ui.addCoauthor
catalogacao.ui.addCollective
catalogacao.ui.addTranslator
catalogacao.ui.bnIsbn
catalogacao.ui.bnLoading
catalogacao.ui.bnManual
catalogacao.ui.coverAlt
catalogacao.ui.worldcat
```

#### `account.*` — 10 clés

```
account.history.cancelledOn
account.history.fulfilledOn
account.history.hide
account.history.reservedOn
account.loans.checkout
account.loans.returnedOn
account.renew.renewed
account.reserve.alreadyLoaned
account.reserve.alreadyLoanedPlural
account.wishlist.addedOn2
```

#### `resource.*` — 9 clés

```
resource.authorized
resource.checking
resource.error
resource.errorLoading
resource.errorStatus
resource.loaded
resource.noId
resource.noUrl
resource.title
```

#### `reader.*` — 8 clés

```
reader.backToBook
reader.error.noPdf
reader.loginToAccess
reader.onlineReading
reader.page
reader.pageNav
reader.pageTitle
reader.title
```

#### `panel.*` — 7 clés

```
panel.loan.returnFullLabel
panel.tab.actions.hint
panel.tab.consultations.hint
panel.tab.grouped.hint
panel.tab.loans.hint
panel.tab.reader.hint
panel.tab.reservations.hint
```

#### `book.*` — 2 clés

```
book.holding.unavailableUntil
book.nextAvailable
```

#### `roles.*` — 1 clés

```
roles.
```

---

## Asymétrie entre locales

Au-delà des 123 clés manquantes partout, **certaines locales ont des clés que pt-BR n'a pas**. Ce sont des clés ajoutées au fil du développement et traduites dans les langues secondaires, mais oubliées dans la langue de référence.

### Clés présentes dans d'autres locales mais absentes en pt-BR

Au total, **20 clés distinctes** sont dans 1 à 5 autres locales mais pas en pt-BR.

Détail (clé → langues qui l'ont) :

```
biblioteca.comms.sendMode.disabled  →  de, en, es, it
biblioteca.comms.sendMode.normal  →  de, en, es, it
biblioteca.comms.sendMode.testOnly  →  de, en, es, it
rede.admins.promote  →  de, en, es, it
rede.admins.promoteHint  →  de, en, es, it
rede.admins.promotePlaceholder  →  de, en, es, it
rede.libraries.title  →  de, en, es, it
rede.members.allRoles  →  de, en, es, it
rede.members.searchPlaceholder  →  de, en, es, it
rede.members.title  →  de, en, es, it
rede.requests.reviewNote  →  de, en, es, it
rede.requests.select  →  de, en, es, it
rede.requests.title  →  de, en, es, it
rede.subtitle  →  de, en, es, it
notif.category.alerta  →  de, en, it
notif.category.emprestimo  →  de, en, it
notif.category.info  →  de, en, it
notif.category.reserva  →  de, en, it
notif.category.sistema  →  de, en, it
rede.admins.title  →  en
```

**Action recommandée** : rétro-traduire ces clés en pt-BR. Comme on a déjà la traduction dans 5 autres langues, on a tout le matériau pour reconstruire un sens cohérent.

---

## Clés dynamiques (16 sites)

Ces appels construisent l'identifiant à la volée à partir d'une variable. La validation est manuelle : il faut vérifier que pour chaque valeur possible de la variable, la clé correspondante existe dans les locales.

| # | Préfixe | Site d'appel | Couverture |
|---|---|---|---|
| 1 | `gender.*` | `pages/painel/PanelPage.jsx:720` | 5 clés en pt-BR |
| 2 | `country.*` | `pages/public/AuthorPage.jsx:26` | 🔴 **0 clé** |
| 3 | `country.*` | `pages/public/AuthorPage.jsx:123` | 🔴 **0 clé** |
| 4 | `catalogacao.material.*` | `pages/public/CatalogPage.jsx:493` | 12 clés en pt-BR |
| 5 | `catalogacao.material.*` | `pages/public/CatalogPage.jsx:524` | 12 clés en pt-BR |
| 6 | `account.status.*` | `pages/account/AccountPage.jsx:338` | 4 clés en pt-BR |
| 7 | `roles.*` | `pages/account/AccountPage.jsx:339` | 4 clés en pt-BR |
| 8 | `account.renew.*` | `pages/account/AccountPage.jsx:557` | 🔴 **0 clé** |
| 9 | `reservation.stage.*` | `pages/account/AccountPage.jsx:609` | 13 clés en pt-BR |
| 10 | `catalogacao.material.*` | `pages/catalogacao/BookDraftForm.jsx:122` | 12 clés en pt-BR |
| 11 | `catalogacao.role.*` | `pages/catalogacao/BookDraftForm.jsx:123` | 10 clés en pt-BR |
| 12 | `catalogacao.guide.*` | `pages/catalogacao/BookDraftForm.jsx:1367` | 48 clés en pt-BR |
| 13 | `catalogacao.guide.*` | `pages/catalogacao/BookDraftForm.jsx:1372` | 48 clés en pt-BR |
| 14 | `catalogacao.guide.*` | `pages/catalogacao/BookDraftForm.jsx:1373` | 48 clés en pt-BR |
| 15 | `catalogacao.guide.*` | `pages/catalogacao/BookDraftForm.jsx:1376` | 48 clés en pt-BR |
| 16 | `notif.type.*` | `pages/biblioteca/BibliotecaPage.jsx:482` | 14 clés en pt-BR |

### Préfixes critiques avec 0 clé (urgent)

- **`country.*`** : utilisé dans `AuthorPage.jsx` pour afficher le pays d'un·e auteur·rice. Aujourd'hui, le code ISO du pays s'affiche en raw (`BR` au lieu de « Brésil »).
- **`account.renew.*`** : utilisé dans `AccountPage.jsx` pour afficher la raison de renouvellement d'un emprunt. La valeur DB s'affiche en raw.

---

## Clés orphelines (316)

Clés présentes dans les JSON mais **jamais utilisées dans le code**. Elles ne nuisent pas au fonctionnement mais alourdissent les fichiers et créent du bruit.

### Top 10 des domaines orphelins

| Domaine | Vraiment orphelin | Notes |
|---|---|---|
| `catalogacao.*` | 96 | beaucoup de clés ajoutées en prévision puis non utilisées |
| `biblioteca.*` | 49 | inclut le module `comms.*` et `tasks.*` |
| `account.*` | 27 | sous-domaine `address.*` largement orphelin |
| `panel.*` | 22 | duplicats avec d'autres domaines |
| `importacoes.*` | 19 | page d'imports — tableau de bord pas finalisé ? |
| `common.*` | 18 | clés communes (close, confirm, copy, create, delete) jamais réutilisées |
| `catalog.*` | 17 | doublons avec les filtres |
| `rede.*` | 17 | page Réseau — partie inachevée |
| `book.*` | 12 | inclut auteur, collection, édition (pourrait être obsolètes) |
| `auth.*` | 9 | reliquats de LoginPage.jsx supprimée |

Total détaillé pour les 17 domaines : voir l'annexe technique générée séparément.

**Action recommandée** : ne pas supprimer maintenant. D'abord vérifier si certaines orphelines correspondent en fait à du code déclaré mais non rendu (ex. boutons qui n'apparaissent que dans certaines conditions). Une passe manuelle au moment de la phase 4 (patches) permettra de trier celles qui sont vraiment du code mort.

---

## Bugs annexes détectés

Au cours de l'analyse, j'ai détecté plusieurs anomalies qui ne sont pas strictement des trous de couverture mais qui méritent correction :

### 1. Fuite de portugais dans toutes les langues

Les clés suivantes contiennent du **portugais brésilien** dans les 5 autres locales (es, en, it, de) :

```
catalogacao.ui.layer1desc
catalogacao.ph.refCompat
```

Exemple : en allemand, `catalogacao.ui.layer1desc` vaut `"Ficha comum — o núcleo bibliográfico compartilhável entre bibliotecas."` au lieu d'être traduit.

### 2. Clé dynamique cassée dans BibliotecaPage

Dans `src/pages/biblioteca/BibliotecaPage.jsx:575`, l'extraction détecte `roles.` (avec un point final, sans suffixe). C'est probablement une concaténation qui produit une chaîne mal formée — à investiguer.

### 3. Clés `auth.login.*` orphelines suite à la suppression de LoginPage

`LoginPage.jsx` a été supprimé dans la session précédente, laissant 5 clés orphelines : `auth.login.email`, `auth.login.password`, `auth.login.submit`, `auth.login.title`, `auth.login.forgot`. À supprimer dans le patch de nettoyage.

---

## État du langage inclusif

Mesure indirecte : pour chaque langue, on cherche les marqueurs typiques d'écriture inclusive militante.

| Langue | État | Convention dominante |
|---|---|---|
| 🇫🇷 fr | ✅ Cohérent | Point médian (`lecteur·rice`, `administrateur·rice`) — **92 occurrences** |
| 🇩🇪 de | ✅ Cohérent | Genderstern (`Leser*in`, `Genoss*in`) — **64 occurrences** |
| 🇬🇧 en | ✅ OK par nature | Termes épicènes (`reader`, `comrade`, `they/them`) |
| 🇧🇷 pt-BR | ⚠️ Incohérent | 39 `(a)` bureaucratique, 8 `(a/e)` militant, 0 médian |
| 🇪🇸 es | ⚠️ Incohérent | 41 `/a` séparé, 11 `(a)`, 2 `(a/e)`, 2 médians |
| 🇮🇹 it | ⚠️ Aucune marque | Probablement masculin générique partout |

### Cas particulier : traduction de « camarade »

Les langues romanes ont un mot épicène (`camarada` en pt et fr, `comrade` en en) ce qui simplifie la chose. Mais en es, it, de, le mot a un genre, et les choix actuels sont inégaux :

| Langue | Forme actuelle | Évaluation |
|---|---|---|
| pt-BR | `camarada` | ✅ épicène, parfait |
| fr | `camarade` | ✅ épicène, parfait |
| en | `comrade` | ✅ épicène, parfait |
| es | `un/a camarada`, `del/la camarada` | ⚠️ slash bureaucratique alors que `camarada` est en réalité épicène en espagnol |
| it | `compagno/a`, `del/la compagno/a` | ⚠️ slash bureaucratique |
| de | `Genoss*in` | ✅ Genderstern — cohérent avec le reste de la locale |

**Note importante** : la mémoire de session précédente contient une consigne d'utiliser `Genoss·innen` (avec point médian) en allemand. **Aujourd'hui le code utilise `Genoss*in` (Genderstern)**, ce qui est cohérent avec le reste de la locale allemande. À discuter en phase 2 (charte) : maintenir le Genderstern (cohérence interne) ou imposer le point médian (cohérence transversale avec le français) ?

---

## Plan de correction proposé

Le chantier se divise en 4 phases. Phase 1 (cet audit) est terminée.

### Phase 2 — Charte de langage inclusif (à venir)

Document court qui formalise pour chaque langue :
- La convention typographique adoptée (médian, Genderstern, slash, etc.)
- Les termes politiques de référence (camarade, lecteur·rice, bibliothécaire, etc.)
- Les exceptions tolérées et les anti-conventions à proscrire
- Une procédure de cohérence pour les ajouts futurs

Ce document sera commité dans `docs/` du repo et servira de référence pour toute traduction future.

### Phase 3 — Harmonisation des clés existantes selon la charte

Pour les clés *déjà présentes* mais dont l'écriture inclusive est incohérente :
- Réécrire les ~50 occurrences de `(a)` bureaucratique en pt-BR selon la convention adoptée.
- Réécrire les 41 `/a` espagnols selon la convention adoptée.
- Introduire systématiquement l'écriture inclusive en italien (sujet politique délicat — voir phase 2).
- Vérifier la cohérence du `Genoss*in` allemand avec la mémoire de session.

### Phase 4 — Patch de complétion des 123 clés manquantes

Pour chaque clé manquante :
- Définir le sens à partir du contexte d'usage dans le code.
- Traduire dans les 6 langues selon la charte.
- Livrer un patch unique par fichier de locale.

### Phase 5 (suggérée) — Nettoyage des orphelines et test de garde-fou

Une fois les phases 2-4 livrées :
- Supprimer les ~316 vraies orphelines (en plusieurs passes pour limiter le risque).
- Ajouter au fichier `i18n.test.js` un test de cohérence entre clés du code et clés des locales (extraction automatique au build).
- Documenter dans `README.md` le workflow d'ajout d'une nouvelle clé.

---

*Rapport généré automatiquement par extraction statique du code source. Pour reproduire l'audit, voir le script `/tmp/extract_keys.py` utilisé pour cette analyse.*
