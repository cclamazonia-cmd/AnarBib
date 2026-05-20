# Backlog rapide : chantiers H + I + J (issus reunion BTL/SP 18 mai 2026)

**Date** : 18 mai 2026
**Contexte** : reunion de demonstration AnarBib avec les compas de Sao Paulo
(BTL principalement). Trois demandes spontanees emergees pendant les questions :

1. **Chantier H -- Scanner ISBN mobile** (catalogage par code-barres)
2. **Chantier I -- Integration archive.org** (recuperation de docs web archives)
3. **Chantier J -- Granularite loanable par exemplaire** (4 exemplaires d'un livre : 2 consultables + 2 empruntables)

Ces trois chantiers sont **independants des paquets E/F/G** de la spec profils
d'adoption et peuvent etre attaques en parallele.

## Chantier H -- Scanner ISBN mobile pour catalogage rapide

### Demande utilisateur·rice

Permettre a un·e benevole d'arriver avec une pile de livres a cataloguer, sortir
son telephone, scanner le code-barres ISBN, recuperer automatiquement les
metadonnees (titre, auteur, editeur, annee), valider et ajouter au catalogue.

Objectif politique : reduire le temps de catalogage de 5-10 min/livre a ~30s/livre.
Democratiser le catalogage -- pas besoin d'expertise bibliotheconomique pour
qu'un·e benevole contribue.

### Faisabilite technique

**Lecture code-barres** :
- API `BarcodeDetector` (Chromium Android, Safari iOS recent) -- natif
- Fallback : `@zxing/browser` (~80 Ko) -- universel
- Pas d'app a installer -- fonctionne dans le browser mobile

**Sources de metadonnees ISBN** (gratuit, sans tracking) :

| Source | Couverture | Tracking ? |
|---|---|---|
| Open Library (IA) | Bonne EN, decente FR/ES | Non |
| BnF SRU | Excellente FR | Non (service public) |
| DNB SRU | Excellente DE | Non (service public) |
| WorldCat | Internationale | Mitigee (gratuit limite) |
| Google Books | Excellente | **OUI -- a EVITER** |

**Doctrine** : Open Library en premier (libre, multilingue), fallback BnF
ou DNB selon zone ISBN-13. **Jamais Google Books**.

### Composants a livrer

| Composant | Description |
|---|---|
| Edge Function `isbn-lookup` | Query Open Library, fallback BnF / DNB |
| Page `/catalogar-rapido` (mobile-first) | Scanner camera + form pre-rempli + bouton "Ajouter au catalogue" |
| RPC `fn_create_book_from_isbn_lookup` | Cree book + book_holdings + exemplares en une transaction (verification ISBN unique, fusion si livre existe deja) |
| i18n × 6 locales | ~20 cles UI scanner |
| Doc utilisateur | Tutoriel court "Comment cataloguer avec son telephone" |

### Effort estime

**2-3 sessions de travail** (1 backend + 1 frontend + 0.5 tests sur livres reels).

### Sequencage proposé

1. Edge Function `isbn-lookup` (peut etre testee depuis Postman/curl avant frontend)
2. RPC `fn_create_book_from_isbn_lookup` avec test sur ISBN connu
3. Page `/catalogar-rapido` avec scanner camera
4. Tests mobiles reels avec une boite de livres
5. Documentation utilisateur

### Questions doctrinales a trancher avant demarrage

- Que faire si Open Library renvoie des metadonnees mais l'auteur n'existe pas
  encore dans `book_contributors` ? Auto-creer ou demander confirmation ?
- Que faire si l'ISBN scanne correspond a un livre deja dans `books` avec
  les memes metadonnees ? Proposer "Ajouter un exemplaire" plutot que "Creer".
- Granularite : un·e benevole peut-il cataloguer directement, ou doit-il
  passer par un staff pour validation ? (depend de `governance_mode`).

---

## Chantier I -- Integration archive.org pour docs web

### Demande utilisateur·rice

Permettre d'integrer dans le catalogue AnarBib :
- Des sites militants disparus archives sur Wayback Machine
- Des PDF/brochures militantes deposees sur archive.org
- Des articles de blog/webzines archives
- Des periodiques numerises

Objectif politique : preserver la memoire militante numerique, eviter la
disparition d'archives suite a la fermeture de sites, garantir l'acces
durable a des textes parfois introuvables.

### Faisabilite technique

archive.org a une **API publique** :
- Wayback Machine API : `http://archive.org/wayback/available?url=...&timestamp=...`
- IA Item API : `https://archive.org/metadata/<item_id>` pour fichiers IA
- Stockage objet : Supabase Storage pour mise en cache locale si souhaitee

### Composants a livrer

| Composant | Description |
|---|---|
| Nouvelle table `web_documents` | URL d'origine, ID archive.org, snapshot date, titre, auteur, type (article / PDF / video / etc.), excerpt, library_id, added_by |
| Edge Function `archive-org-fetch` | Recupere snapshot HTML ou fichier binaire depuis archive.org |
| Vue `api.web_documents_catalog` | Listing public des docs web archives par biblio |
| RPC `fn_add_web_document_from_archive_org` | Cree l'entree + optionnellement met en cache le binaire dans Supabase Storage |
| UI catalogage : onglet "Importer Wayback" | Champ URL ou ID, preview, validation manuelle |
| Optionnel : UI public lecture | Page `/documento-arquivado/:id` qui affiche le doc ou redirige vers archive.org |

### Decisions doctrinales a trancher

1. **Stockage local vs simple lien ?**
   - Lien seul : economise stockage, mais si archive.org disparait ou fait
     un takedown, le doc disparait aussi
   - Mirror local : pereniste vraie, mais consomme stockage, et pose la
     question de la responsabilite editoriale (AnarBib heberge-t-il ?)
   - **Proposition** : les deux, avec toggle par doc `mirror_locally boolean`

2. **Doctrine moderation** : eviter qu'AnarBib devienne un mirror de
   pages reactionnaires ou hostiles sous pretexte d'archivage. Seuls
   les staffs bibliotheque peuvent ajouter, avec possibilite de retirer.

3. **Doc web entre dans `books` ou table separee ?** Un blog post n'a pas
   d'ISBN, pas d'editeur, pas de tombo. Table separee `web_documents` plus
   propre. Vue UNION pour exposer dans le catalogue global si voulu.

4. **Periodiques numerises** (revues anarchistes scannees) : table separee
   `web_documents` ou alors entree dans `books` avec champ `format = 'periodical'` ?
   A trancher en debut de chantier.

5. **Visibilite reseau** : un doc web ajoute par BLMF est-il visible par
   BTL automatiquement (si BLMF est `network_published`) ? **Probable oui**,
   pour coherence avec doctrine catalogue federe.

### Effort estime

**1-2 sessions de travail** (1 backend + 0.5 frontend simple).

### Sequencage proposé

1. Table `web_documents` + RLS conditionnees profil (utilise les helpers C.2)
2. Edge Function `archive-org-fetch` (test avec URL connu)
3. RPC `fn_add_web_document_from_archive_org`
4. UI onglet "Importer Wayback" dans painel catalogage
5. Vue publique optionnelle `/documento-arquivado/:id`

---

## Chantier J -- Granularite loanable par exemplaire

### Demande utilisateur·rice

Cas concret evoque par les compas : un livre present en **4 exemplaires** dans
une biblio, dont **2 destines a l'emprunt** et **2 destines a la consultation
sur place uniquement** (ex : reserve, exemplaire rare, ouvrage de reference).

Question : "AnarBib sait-il gerer ca ?"

### Etat actuel (mai 2026)

**Reponse honnete : NON, pas encore.**

Le modele actuel a :
- 1 ligne `books` par titre/auteur abstrait
- 1 ligne `book_holdings` par couple (book, library) avec un booleen `loanable`
  partage par TOUS les exemplaires du livre dans cette biblio
- N lignes `exemplares` (un par tombo physique) sous le meme holding, sans
  champ `loanable` individuel

**Consequence** : impossible de distinguer "exemplaire 0042 empruntable" de
"exemplaire 0043 consultation-only" si les deux pointent vers le meme livre
dans la meme biblio.

**Verification prod (BLMF, 18/05/2026)** : 7 cas de `exemplares_total = 2`
deja en base (Emma Goldman, A Historia da Luta pela Terra, Autogestao Hoje,
Fragmentos de Antropologia anarquista, etc.), tous avec `loanable = true`
uniformement. Aucun cas mixte encore tente -- limite non-bloquante a court
terme mais identifiable.

### Faisabilite technique

3 options ont ete examinees :

**Option A -- `exemplares.loanable boolean DEFAULT true` (recommandee)** :
- Granularite au niveau de l'exemplaire physique
- Modelise fidelement la realite : un exemplaire est un objet distinct du
  livre abstrait
- Permet d'autres nuances utiles : exemplaire temporairement abime
  non-empruntable, exemplaire dedicace, etc.

**Option B -- `exemplares.usage_mode enum`** :
- Enum `('loan_and_consultation', 'consultation_only', 'loan_only', 'reference')`
- Plus expressif que le booleen mais sur-engineering pour la demande actuelle
- Reserve a une evolution future si necessaire

**Option C -- dedoubler les `book_holdings`** :
- Workaround sans changement de schema : 2 holdings pour la meme paire
  (book, library), un avec `loanable=true`, l'autre `loanable=false`
- **REJETE** : viole la regle "1 livre x 1 biblio = 1 holding" qui est
  implicite dans pas mal de logiques metier et de vues SQL

**Choix recommande : Option A**.

### Composants a livrer

| Composant | Description |
|---|---|
| Migration `exemplares` | Ajout colonne `loanable boolean NOT NULL DEFAULT true` |
| Doctrine de propagation | Au moment de la migration, propager `book_holdings.loanable` a tous les exemplaires existants (la plupart `true`, sera surchargeable par exemplaire ensuite) |
| Patch RPC `fn_v2_create_emprestimo_by_holdings` | Verifier que l'exemplaire choisi est `loanable=true` -- sinon RAISE EXCEPTION + i18n |
| Patch RPC `fn_v2_create_consulta_local_by_holdings` | Aucune contrainte ajoutee (consulta valable sur tous exemplaires existants) |
| Vue `api.book_holdings_summary` (nouvelle) | Pour chaque holding, compter `loanable_count` et `consultation_only_count` parmi exemplaires actifs |
| UI catalogage exemplaire | Toggle "Empruntable" / "Consultation uniquement" sur chaque exemplaire dans le formulaire de catalogage |
| UI catalogue (page livre) | Affichage type "4 exemplaires : 2 empruntables, 2 en consultation" |
| i18n × 6 locales | ~8 cles UI |

### Decisions doctrinales a trancher

1. **Que devient `book_holdings.loanable` apres la migration ?**
   - Le garder comme "valeur par defaut pour les nouveaux exemplaires" ?
   - Le retirer apres propagation ?
   - **Proposition** : le garder comme defaut + compatibilite ascendante,
     en le marquant deprecated dans la doc

2. **Une reservation peut-elle viser un exemplaire `loanable=false` ?**
   - Probable NON (cf. fn_v2_create_reserva_by_holdings doit verifier)
   - A acter dans la doctrine

3. **PEB sur un exemplaire `loanable=false` ?**
   - NON par definition (consultation_only ne quitte pas la biblio)
   - fn_v2_create_emprestimo_interbibliotecas doit verifier

4. **Affichage catalogue public** : faut-il afficher la repartition
   empruntable/consultation a un·e lecteur·rice anonyme, ou seulement
   "disponibilite" globale ? Probable affichage detaille pour la
   transparence militante.

5. **Doctrine cohherence avec network_mode** : un exemplaire
   `loanable=false` est-il quand meme expose au reseau federe ? OUI
   (le livre existe, juste pas empruntable hors biblio).

### Effort estime

**2 sessions de travail** :
- Session 1 (backend) : migration + propagation + patches RPC + vue summary
- Session 2 (frontend) : UI catalogage + affichage catalogue + i18n + tests

### Sequencage proposé

1. Audit complet des RPC et vues qui consomment `book_holdings.loanable`
2. Migration colonne `exemplares.loanable` + propagation initiale
3. Patch RPC `fn_v2_create_emprestimo_by_holdings` avec check
4. Vue `api.book_holdings_summary` (nouvelle granularite)
5. UI catalogage : ajout toggle par exemplaire
6. UI catalogue public : affichage repartition
7. Tests fumee : creer 2 exemplaires loanable + 2 consultation_only, tester emprunt+consulta+reservation+PEB

---

## Priorisation suggeree

Les compas ont demande spontanement ces 3 fonctionnalites pendant la demo.
Trois signaux forts que ce sont des features qui parlent immediatement
au public cible (biblios militantes).

| Chantier | Priorite | Effort | Type d'apport |
|---|---|---|---|
| H -- ISBN scanner | **TRES HAUTE** | 2-3 sessions | UX massive au quotidien |
| J -- granularite exemplaire | **HAUTE** | 2 sessions | Couvre un cas reel des biblios |
| I -- archive.org | MOYENNE-HAUTE | 1-2 sessions | Politiquement fort, moins frequent |

**Ordre propose** :
1. **H** d'abord (gain rapide visible, democratise le catalogage)
2. **J** ensuite (necessaire pour les biblios qui ont deja des reserves
   ou exemplaires speciaux)
3. **I** en troisieme (gros impact politique mais moins de cas d'usage
   quotidien)

**Insertion dans le planning** :
- Apres bouclage paquet E (frontend painel adaptatif) ou en parallele
- Ou comme respiration entre deux gros paquets, pour livrer rapidement
  une feature visible aux compas qui ont demande

## Liens vers la spec source

- Specs profils d'adoption : `docs/specs/spec-profils-bibliotheque-v0.6.md`
- Bilan session 19/05 : `docs/decisions/BILAN_session_19_mai_2026_paquets_C_D.md`
- Diagnostic PEB frontend : `docs/decisions/CHANTIER_peb_frontend_diagnostic_2026-05-19.md`

---

## Note finale

Ce backlog a ete redige a la volee a 23h45-23h55 apres la reunion BTL pour ne
pas perdre les demandes des compas. A retravailler en specs proprement dites
quand le moment sera venu de demarrer ces chantiers (probablement post-paquet E
ou en parallele).

Les trois chantiers H/I/J sont **independants entre eux** et **independants
de la spec profils d'adoption**, ce qui permet de les attaquer dans n'importe
quel ordre selon l'energie et les disponibilites des compas.
