# Spec profils d'adoption v0.7 — Write-up final cloture chantier (paquets E + F + G)

**Date** : 20 mai 2026 (UTC+2 ; jour ouvre 19 mai chez Xavier)
**Statut** : version consolidee apres bouclage du chantier complet
**Auteur** : Xavier (session avec Claude)
**Remplace** : v0.6 (livree 19/05/2026 apres bouclage paquet D)

## Resume executif

Cette version consolide la spec v0.6 avec les arbitrages et livraisons de la
session marathon du 19-20 mai 2026 qui a livre **les paquets E, F et G en
production**. Le chantier profils d'adoption est desormais **entierement
clos** : backend complet (paquet D bouclé en v0.6), frontend painel adaptatif
(E.0-E.3), frontend compte lecteur adaptatif (E.4), vote sur transitions (E.5),
wizard d'onboarding refondu (F.0-F.4) et banniere biblios existantes (G).

**Onze points sont raffines, clarifies ou ajoutes par rapport a la v0.6** :

1. **Paquet E** (frontend painel + compte adaptatifs + vote transitions) en prod
2. **Paquet F** (wizard d'onboarding 4 axes) en prod, backend + frontend
3. **Paquet G** (banniere biblios existantes) en prod
4. **Hotfix backend 280000** : colonne `libraries.profile_template_chosen`
   manquante, ajoutee post-G avec propagation depuis `library_requests` et
   recalcul automatique apres chaque transition (matching profils A/B/C/D ou
   retombant sur `custom`)
5. **Hotfix backend 290000** : FK profile manquantes (`proposed_by`,
   `cancelled_by`, `voter_id`, `changed_by`), requises par PostgREST pour les
   JOINs auto cote frontend
6. **Refactor architectural** : banner + onglet `transicoes` deplaces de
   PanelPage vers BibliotecaPage (gouvernance politique != travail
   operationnel quotidien)
7. **Doctrine d'ancrage geographique** : 1 lecteur·rice = 1 biblio, verifiee
   en prod (0 user multi-reader)
8. **Doctrine deliberation politique vs travail operationnel** : Biblioteca =
   identite/configuration collective ; Painel = quotidien
9. **Doctrines techniques actees** : v2.3 (DO block via information_schema),
   v2.4 (DROP+CREATE signature), v2.5 (verifier patches via grep)
10. **Doctrine i18n militante 6 locales** : 672 strings ajoutees cette session
    avec conventions par langue (@ pt-BR, point median fr, neutre arg es,
    epicene en, asterisque it, Genderstern de)
11. **Articulation onboarding/profils** : nouvelle section 13 qui clarifie le
    pont technique et l'asymetrie politique entre creation et evolution

## Sections 1 a 8 (inchangees v0.4)

Voir spec v0.4.

## Sections 9.1 a 9.6 (inchangees v0.5)

Voir spec v0.5.

## Section 9.7 (inchangee v0.6)

Voir spec v0.6 (implementation backend paquet D bouclé).

## Section 9.8 -- Frontend painel adaptatif staff (paquet E.0-E.3, livre 19/05)

### 9.8.1 Architecture du hook usePanelAvailability

**Fichier** : `src/hooks/usePanelAvailability.js` (53 lignes).

Hook React qui retourne une matrice `{[tabKey]: boolean}` calculee a partir
du contexte `useLibrary()`, indiquant quels onglets du painel staff doivent
etre affiches selon le profil de la biblio courante.

**Pattern d'utilisation** :
```javascript
const availability = usePanelAvailability();
const tabs = ALL_TABS.filter(t => availability[t.key]);
```

### 9.8.2 Matrice de visibilite painel staff

| Onglet | Visible si |
|---|---|
| `trabalho-do-dia` | toujours (vue d'ensemble) |
| `acoes` | toujours (actions admin) |
| `reservas` | `circulation_mode = 'full_sigb'` |
| `consultas-locais` | `circulation_mode IN ('informal', 'full_sigb')` |
| `emprestimos-livro` | `circulation_mode IN ('informal', 'full_sigb')` |
| `emprestimos-lote` | `circulation_mode = 'full_sigb'` (mecanique SIGB pure) |
| `leitor` | toujours (recherche lecteur) |
| `historico` | toujours (couche D.4 masque deja si circulation = off) |
| `contribuicoes` | `membership_enabled` ET `circulation_mode != 'off'` |

**Note importante** : l'onglet `transicoes` (vote sur transitions de profil)
N'EST PAS dans PanelPage. Il est dans BibliotecaPage (voir section 9.11 :
refactor architectural).

### 9.8.3 Enrichissement LibraryContext (paquet E.0)

`src/contexts/LibraryContext.jsx` enrichi pour exposer les 4 axes + 
`membership_enabled` :

```javascript
const DEFAULT_CONTEXT = {
  librarySlug: 'default',
  libraryId: null,
  // ...
  catalog_mode: 'network_published',
  circulation_mode: 'full_sigb',
  network_mode: 'federated',
  governance_mode: 'full_governance',
  membership_enabled: false,
};
```

**Defaults safe = profil D** pour preserver le comportement actuel pendant
le chargement (BLMF et BTL sont toutes deux en profil D).

Le SELECT Supabase de l'effect est enrichi :
```javascript
.select('library_id, role, is_primary, libraries(id, slug, name, short_name, 
        catalog_mode, circulation_mode, network_mode, governance_mode, 
        membership_enabled)')
```

### 9.8.4 Garde-fou bascule auto (E.3)

useEffect dans PanelPage qui surveille l'onglet actif vs availability et
re-bascule sur `trabalho-do-dia` (toujours disponible) si l'onglet courant
devient indisponible (changement de biblio ou transition profil pendant
session).

```javascript
useEffect(() => {
  if (availability[tab] === false) {
    setTab('trabalho-do-dia');
  }
}, [tab, availability]);
```

## Section 9.9 -- Frontend compte lecteur·rice adaptatif (paquet E.4, livre 19/05)

### 9.9.1 Doctrine d'ancrage geographique

**Verification empirique en prod (20/05/2026)** : 0 user avec memberships
multiples role=reader.

**Doctrine actee** : un·e lecteur·rice est ancre·e dans une seule
bibliotheque physique (la sienne, geographiquement). Le reseau federal
permet la federation entre bibliotheques (PEB), pas le nomadisme individuel.

Consequence frontend : AccountPage n'a pas de selecteur de biblio. La biblio
courante est celle du contexte `useLibrary().libraryId`, point final.

### 9.9.2 Hook useAccountAvailability

**Fichier** : `src/hooks/useAccountAvailability.js` (56 lignes).

Similaire a usePanelAvailability mais pour AccountPage (compte lecteur·rice).

| Section/Onglet | Visible si |
|---|---|
| `perfil` | toujours (compte personnel) |
| `reservar` | `circulation_mode = 'full_sigb'` |
| `curso` (emprestimos) | `circulation_mode IN ('informal', 'full_sigb')` |
| `historico` | `circulation_mode != 'off'` |
| `consultas` | `circulation_mode IN ('informal', 'full_sigb')` |
| `avisos` | toujours |
| `desejos` | toujours (wishlist marche sans circulation) |
| `cotisacoes` | `membership_enabled` ET `circulation_mode != 'off'` |

Les chips du Hero (reservas, consultas, emprestimos) suivent la meme
matrice.

### 9.9.3 6 patches sur AccountPage.jsx

1. Import du hook useAccountAvailability
2. Appel du hook + recuperation availability
3. ALL_TABS + filtre par availability
4. 3 chips Hero conditionnees
5. Section cotisations conditionnee par `availability.cotisacoes && (membership || membershipRules.length > 0)`
6. Garde-fou useEffect bascule auto vers `perfil` si onglet courant devient
   indisponible

## Section 9.10 -- Vote sur transitions de profil (paquet E.5, livre 19/05)

### 9.10.1 Composant TransitionsPanel

**Fichier** : `src/components/TransitionsPanel.jsx` (474 lignes).

Composant React tout-en-un qui integre **trois sections** :

1. **Formulaire de proposition** : select axe (4 valeurs) + select nouvelle
   valeur (depend de l'axe) + textarea motivation (>=5 chars). Appel a
   `fn_propose_library_profile_change`.
2. **Liste des propositions ouvertes** : pour chaque proposition, header
   (axe / old -> new / type / governance / proposeur / date), motivation
   citee, boutons pro/contre/abstain, textarea rationale_against obligatoire
   si "contre", bouton annuler pour le proposeur uniquement.
3. **Historique** : 10 dernieres transitions completed/cancelled/expired
   avec statut colore.

### 9.10.2 Backend deja en prod (cf. paquets B + C + D)

4 RPCs cote backend, deja en prod depuis les paquets B+C+D :

- `fn_propose_library_profile_change(library_id, axis, new_value, motivation)`
- `fn_vote_library_profile_change(proposal_id, vote, rationale_against)`
- `fn_cancel_library_profile_change(proposal_id, motivation)`
- `fn_execute_library_profile_change(proposal_id)` (cf. paquet D.6 + hotfix G)

### 9.10.3 Conditions de visibilite

L'onglet `transicoes` est visible si **les deux conditions** sont vraies :

1. `governance_mode IN ('staff_roles', 'full_governance')` -- les biblios en
   gouvernance informelle ne formalisent pas leur deliberation via le SIGB.
2. Utilisateur·rice est `coordenador` ou `administrador` (pas
   `librarian` ni `reader`).

### 9.10.4 Frontend gestion d'erreurs

Mapping des hints backend vers messages i18n :

| Hint backend | Message i18n |
|---|---|
| `error.profile_change.motivation_too_short` | `transitions.error.motivationTooShort` |
| `error.profile_change.axis_already_open` | `transitions.error.axisLocked` |
| `error.profile_change.quorum_not_met` | `transitions.error.quorumNotMet` |
| `error.profile_change.not_staff` | `transitions.error.notStaff` |

Ainsi, les messages backend sont **localises militants** dans 6 langues
(354 strings au total pour E.5).

## Section 9.11 -- Onboarding refondu (paquet F, livre 19/05)

### 9.11.1 Backend F.0+F.1+F.2

**Migration 20260520100000** (749 lignes SQL) :

- **6 CHECK constraints** sur `library_requests` :
  - 4 axes profil + cohérence catalog/network + profile_template valide
- **fn_submit_library_request** etendue de 20 a 25 parametres (les 5
  nouveaux : `requested_catalog_mode`, `requested_circulation_mode`,
  `requested_network_mode`, `requested_governance_mode`,
  `profile_template_chosen`)
- **fn_submit_library_request_via_claim** etendue a 26 parametres (idem +
  claim_token)
- **fn_activate_approved_library_request** propage les 4 axes vers
  `libraries` via variables `v_eff_*` (fallback defaults BDD profil D)

**Hotfix DROP+CREATE** : un changement de signature impose DROP FUNCTION IF
EXISTS avant CREATE (doctrine v2.4). CREATE OR REPLACE FUNCTION ne permet
pas de changer la liste de parametres ; il cree une 2e fonction overloaded.
La premiere tentative F v1 a planté la-dessus (pronargs=20 incompatible).

### 9.11.2 Frontend F.3 : Wizard 4 etapes

**Fichier** : `src/components/LibraryProfileWizard.jsx` (330 lignes).

5 etapes :
- **Etape 0** : choix d'un profil pre-cable A/B/C/D + intro pedagogique
- **Etape 1** : `catalog_mode` (local_only vs network_published)
- **Etape 2** : `circulation_mode` (off / informal / full_sigb)
- **Etape 3** : `network_mode` (isolated / observer / federated)
- **Etape 4** : `governance_mode` (informal / staff_roles / full_governance)
- **Etape 5** : recapitulatif + soumission

Logique **`detectTemplate(axes)`** : detecte automatiquement si le quadruplet
modifie matche encore un profil-type pur ; sinon, marque `profile_template_chosen`
comme `custom`. `profile_template_chosen` reste NULL **uniquement si la
personne clique "Profil D" SANS RIEN MODIFIER** dans les etapes suivantes
(doctrine Q2-C : pas de defaults silencieux).

### 9.11.3 Frontend F.3 (integration) : SolicitarBibliotecaPage

**Fichier modifie** : `src/pages/public/SolicitarBibliotecaPage.jsx`
(587 lignes, 6 patches).

- Import du wizard
- State form etendu (+5 champs profile)
- Validation handleSubmit (les 4 axes obligatoires + profile_template_chosen
  optionnel)
- Migration de l'INSERT direct vers l'appel RPC `fn_submit_library_request`
- Wizard insere entre summary et confirmations

### 9.11.4 Frontend F.4 : i18n militante

**318 strings** (53 cles x 6 locales) ajoutees dans `src/i18n/locales/*.json`.

Conventions par langue (voir section 12 du bilan de session) :
- **pt-BR** : @ final (`ativ@`) pour neutraliser le genre
- **fr** : point median (`activ·e`)
- **es** : neutre argentin (`-e` final, ex `activ@` pour activo/a/e)
- **en** : forme epicene quand disponible
- **it** : asterisque (`attiv*`)
- **de** : Genderstern (`Mitarbeiter*innen`), ASCII pur

### 9.11.5 Cle politique : `profile_template_chosen`

Cette colonne dans `library_requests` capture le **consentement conscient
au profil** :

- `NULL` : la pessoa de contact a accepte le default safe sans choisir
  consciemment (banner G s'affichera apres activation)
- `'A'`/`'B'`/`'C'`/`'D'` : choix explicite d'un profil-type pur
- `'custom'` : configuration personnalisee (utilise au moins une fois la
  modification axe-par-axe dans le wizard)

A l'activation, `fn_activate_approved_library_request` propage cette valeur
vers `libraries.profile_template_chosen` (cf. section 9.13 -- hotfix G).

## Section 9.12 -- Banniere biblios existantes (paquet G, livre 19/05)

### 9.12.1 Composant LibraryProfileBanner

**Fichier** : `src/components/LibraryProfileBanner.jsx` (124 lignes).

Banniere bleue informative qui s'affiche en haut de **BibliotecaPage** (PAS
PanelPage, cf. refactor section 9.14) si :

1. `profile_template_chosen IS NULL` sur la biblio courante (= pas de choix
   conscient enregistre)
2. Utilisateur·rice est `coordenador` ou `administrador`
3. Pas dismissed dans cette session (sessionStorage par library_id)

**Texte (pt-BR original)** : "Sua biblioteca funciona em perfil
{template} -- {nom complet}. Este perfil foi definido automaticamente na
criação. Para confirmá-lo ou redefini-lo coletivamente, discutam em
assembleia e utilizem o mecanismo de votação coletiva."

### 9.12.2 Detection automatique du profil-type actuel

Fonction `detectCurrentTemplate(library)` qui matche le quadruplet actuel
contre les 4 profils-types pre-cables et retourne 'A'/'B'/'C'/'D' ou
'custom'.

### 9.12.3 Politique du banner

**Le banner ne FORCE rien**. Il rappelle simplement que le choix existe et
oriente vers le mecanisme collectif (vote, section 9.10).

**Pas de dismiss permanent** : seul sessionStorage, donc le banner reapparait
au prochain login. C'est intentionnel : tant que le collectif n'a pas vote
consciemment, le rappel revient.

## Section 9.13 -- Hotfix paquet G (migration 20260519280000, livre 20/05)

### 9.13.1 Contexte du bug

Le paquet G livre initialement faisait `supabase.from('libraries').select('profile_template_chosen')`,
mais la colonne **n'existait pas dans `libraries`** (elle existait uniquement
dans `library_requests`). Erreur PostgREST 400 silencieuse attrapee dans
le catch -> `setProfileTemplateChosen(null)` -> banner s'affichait "par
accident" pour BLMF/BTL.

Decouvert pendant le test fumee visuel.

### 9.13.2 Migration 20260519280000

**Trois actions** :

1. `ALTER TABLE libraries ADD COLUMN profile_template_chosen text DEFAULT NULL`
   + CHECK `('A','B','C','D','custom') OR NULL`
2. Patch `fn_activate_approved_library_request` pour propager
   `library_requests.profile_template_chosen` vers
   `libraries.profile_template_chosen` au moment de l'activation
3. Patch `fn_execute_library_profile_change` pour **recalculer** le template
   apres chaque transition : matching du nouveau quadruplet aux profils
   A/B/C/D ou retombant sur `custom`

### 9.13.3 Semantique de la colonne `libraries.profile_template_chosen`

- `NULL` : biblio en profil par defaut, pas de choix conscient. Banner G
  visible.
- `'A'/'B'/'C'/'D'` : biblio sur profil-type pur, choisi via wizard de
  creation ou via transition collective ulterieure.
- `'custom'` : biblio sur configuration personnalisee, choisie via
  transitions collectives.

**Etat post-migration** : les 3 biblios prod (BLMF, BTL, blt-test-informal)
ont toutes `profile_template_chosen=NULL` -- le banner G s'affichera donc
correctement.

### 9.13.4 Boucle vertueuse

A chaque transition collective (paquet E.5), `fn_execute_library_profile_change`
recalcule `profile_template_chosen`. Donc des qu'une biblio commence a faire
des transitions consciemment, son banner disparait automatiquement (la
colonne devient non-NULL).

## Section 9.14 -- Refactor architectural : Painel vs Biblioteca (livre 20/05)

### 9.14.1 Decouverte

A 21h15 le 19/05, apres voir E.5 livre sur PanelPage, intuition utilisateur :
"cet onglet, ce banner, leur place ne serait pas plus logiquement dans la
page Biblioteca, aux cotes des onglets d'identite, de fonctionnement,
etc. ?"

### 9.14.2 Doctrine actee : deliberation politique vs travail operationnel

| Page | Vocation | Audience | Outils |
|---|---|---|---|
| **Painel** | Travail operationnel quotidien | Tout staff (librarian/coord/admin) | Reservas, emprestimos, consultas, lecteurs, taches internes |
| **Biblioteca** | Identite et configuration collective | Staff politique (coord/admin) | Regimento, gouvernance, profil, transitions, equipe |

**Test simple pour decider du placement** :
- "Est-ce que je touche a la configuration de la biblio comme collectif ?"
  -> Biblioteca
- "Est-ce que je fais une operation courante avec ou pour un·e lecteur·rice ?"
  -> Painel

### 9.14.3 Refactor execute

- Retire de **PanelPage** :
  - Import LibraryProfileBanner + TransitionsPanel
  - State + useEffect profileTemplateChosen
  - Onglet `transicoes` dans ALL_TABS
  - Banner JSX entre Hero et ab-painel-card
  - Conditional render `{tab === 'transicoes' && ...}`
  - Cle `transicoes` dans usePanelAvailability

- Ajoute a **BibliotecaPage** :
  - Import LibraryProfileBanner + TransitionsPanel
  - Enrichissement destructuring `useLibrary` avec `governance_mode`
  - State + useEffect profileTemplateChosen
  - Onglet `transicoes` dans ALL_TABS (entre `documents` et `team`),
    marque `coordOnly: true` + `governance_only: true`
  - Filtre `visibleTabs` enrichi pour les conditions governance_mode
  - Banner JSX juste apres cat-statusbar
  - Conditional render `{tab==='transicoes' && <TransitionsPanel libraryId={libraryId} role={role} />}`

### 9.14.4 Cle i18n unifiee

Une nouvelle cle `biblioteca.tab.transitions` ajoutee dans 6 locales (6
strings). Les anciennes cles `panel.tab.transitions*` sont laissees
orphelines (non bloquant, juste warning lint qu'on pourra nettoyer).

### 9.14.5 Backlog technique : nettoyer les cles orphelines

A faire en session future : retirer `panel.tab.transitions` et
`panel.tab.transitions.hint` des 6 fichiers i18n (12 strings orphelines).

## Section 9.15 -- Hotfix paquet E.5 : FK profile (migration 20260519290000, livre 20/05)

### 9.15.1 Contexte du bug

Le code TransitionsPanel.jsx fait `supabase.from('library_profile_proposals').select('*, profiles:proposed_by(first_name, last_name)')`,
mais aucune FK n'etait declaree de `proposed_by` vers `profiles.id`.
PostgREST refusait le JOIN avec :

```
Could not find a relationship between 'library_profile_proposals' and 
'proposed_by' in the schema cache
```

### 9.15.2 Migration 20260519290000

4 FK ajoutees :

| Source | Cible | ON DELETE |
|---|---|---|
| `library_profile_proposals.proposed_by` | `profiles.id` | SET NULL |
| `library_profile_proposals.cancelled_by` | `profiles.id` | SET NULL |
| `library_profile_votes.voter_id` | `profiles.id` | CASCADE |
| `library_profile_history.changed_by` | `profiles.id` | SET NULL |

**Doctrine ON DELETE** :
- **SET NULL** pour les references historiques (proposed_by, cancelled_by,
  changed_by) : on garde la trace historique (motivations, dates,
  transitions) meme si le profile est supprime.
- **CASCADE** pour les votes : un vote anonymise n'a pas de sens pour
  calculer le quorum.

### 9.15.3 NOTIFY pgrst, 'reload schema'

Apres ajout de FK, PostgREST a besoin de rafraichir son schema cache. La
migration inclut un `NOTIFY pgrst, 'reload schema'` en fin de transaction
pour declencher le rechargement immediat (sinon il faut attendre le poll
periodique).

## Section 10 -- Doctrine creation objets backend (MAJ v2.5)

Les doctrines v2 a v2.2 sont detaillees dans la spec v0.6. La session 19-20/05
ajoute trois doctrines suplementaires :

### Ajout v2.3 -- DO block via `information_schema`, pas `pg_get_functiondef` + ILIKE

**Issue** : incident hotfix D.6 v1 (18/05). Un DO block utilisait
`pg_get_functiondef + ILIKE '%change_reason%'` pour verifier l'absence
d'une chaine. La nouvelle version contenait le commentaire `-- HOTFIX:
motivation au lieu de change_reason` qui matchait -> faux positif ->
rollback inutile.

**Methode validee** :

1. Verif structurelle via `information_schema.columns` ou `pg_constraint`
2. Ou test fonctionnel `INSERT/SELECT` temporaire dans un BEGIN/ROLLBACK
3. Si grep necessaire, inclure la syntaxe SQL pour exclure les commentaires

Exemple :

```sql
DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'libraries'
      AND column_name = 'profile_template_chosen'
  ) THEN
    RAISE EXCEPTION 'VERIF FAIL';
  END IF;
END
$verify$;
```

### Ajout v2.4 -- DROP+CREATE FUNCTION si changement de signature

**Issue** : tentative paquet F v1 (19/05). `CREATE OR REPLACE FUNCTION` ne
peut PAS changer la liste de parametres. Si on essaie, ca cree une 2e
fonction overloaded au lieu de remplacer. Symptome : `pronargs` reste a
l'ancienne valeur, les nouveaux appels echouent.

**Methode validee** :

```sql
DROP FUNCTION IF EXISTS public.fn_foo(param1 uuid, param2 text);
CREATE OR REPLACE FUNCTION public.fn_foo(param1 uuid, param2 text, param3 boolean) ...
```

Verifier `pg_depend` avant DROP pour identifier les dependants (triggers,
vues SECURITY DEFINER, etc.). Si CASCADE necessaire : auditer les fonctions
qui appellent.

### Ajout v2.5 -- Verifier les patches via grep apres ecriture

**Issue** : paquet G livre initialement (19/05). Script Python avec 3 patches
successifs (G.1 import, G.2 state, G.3 JSX). Les logs disaient "OK" pour les
3, mais en realite G.1 et G.2 ont ete perdus a cause de conditions de course
(un script a relu le fichier avant que le precedent n'ait ecrit).

**Methode** :

- Apres ecriture, grep explicite pour chaque pattern attendu : 
  `grep -c 'import LibraryProfileBanner'`
- Compter les occurrences (grep -c) pour eviter les faux positifs
  (commentaires contenant le pattern)
- Regrouper les patches dans UN SEUL script Python pour garantir
  l'atomicite

## Section 10 ter -- Doctrines PowerShell + Git (nouvelle v0.7)

### Doctrine UTF-8 PowerShell

**Get-Content sur Windows FR affiche UTF-8 valide en mojibakes** (CP1252
par defaut). Affiche `TransiÃ§Ãµes` alors que le fichier contient
`Transições` correctement encode.

**Methode sure pour LIRE** :

```powershell
$content = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
```

**Methode sure pour ECRIRE** :

```powershell
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
```

### Doctrine Select-String -SimpleMatch

`Select-String -SimpleMatch` est rigoureux sur les espaces. Le pattern
`"tab === 'transicoes'"` (avec espaces autour de `===`) ne matche pas
`tab==='transicoes'` (sans espaces, style condense). Toujours retester
sans `-SimpleMatch` (regex tolerante) avant de conclure a une absence.

### Doctrine git commit --amend

`git commit --amend` ne rattrape pas les fichiers untracked. Incident E.4 :
nouveau fichier `useAccountAvailability.js` cree mais jamais `git add`.
Amend du commit precedent (qui ne le contenait pas) -> commit final sans le
fichier -> Vite build fail "ENOENT".

**Methode** : toujours `git status --short` APRES `git add`, ET avant
`amend`. Verifier que les nouveaux fichiers sont stages avant tout amend.

### Doctrine Codeberg stale info

Quand `origin` push vers GitHub + Codeberg en cascade : GitHub accepte le
force, Codeberg refuse avec `stale info` (deja synchronise mais ne sait
pas). Solution :

```powershell
git push codeberg main --force-with-lease
```

Generalement retourne `Everything up-to-date`.

## Section 11 -- Backlog post-cloture chantier (mise a jour v0.7)

Items deplaces du backlog :

- ~~"Frontend painel adaptatif paquet E"~~ -> bouclé 19/05
- ~~"Onboarding refondu paquet F"~~ -> bouclé 19/05
- ~~"Bandeau biblios existantes paquet G"~~ -> bouclé 19/05
- ~~"Test fumee transitions type 4"~~ -> bouclé 20/05 (decouverte bugs E.5 + G hotfixes)

Items conserves / ajoutes en v0.7 :

| Item | Source | Priorite | Statut |
|---|---|---|---|
| 11.1 Revocation pendant carence | v0.3 | Moyenne | Reportee (necessite RPC `fn_revoke_profile_proposal`) |
| 11.2 Gel des jobs pendant carence | v0.3 | Moyenne | Reporte (necessite analyse cron) |
| 11.3 `libraries.unarchive_grace_days` configurable | v0.5 | Basse | Reporte (90j hardcode suffit) |
| 11.4 Tests fumee transitions type 4 reelles | v0.6 | A faire | Sur biblio test (blt-test-informal) |
| 11.5 Disabler GitHub Pages | session 19/05 | **Haute** | A faire prochaine session (confusion) |
| 11.6 Code-splitting AccountPage.jsx (1968 lignes) | session 19/05 | Moyenne | Warning Vite chunks >500KB |
| 11.7 Refactor LanguagePicker (sans flags nationaux) | session 19/05 | Moyenne | Coherence politique |
| 11.8 Secrets hygiene audit (tokens Codeberg) | session 19/05 | Moyenne | Local auth breaks regularly |
| 11.9 Delete `C:\Users\accat\AnarBib-functions\` vestige | session 19/05 | Basse | Vestige obsolete |
| 11.10 Nettoyer 5 cles charte langue inclusive | session 19/05 | Basse | Cles preexistantes non conformes |
| 11.11 Warning useMemo dependency LibraryProfileBanner | session 19/05 | Basse | Non bloquant |
| 11.12 Migration Brevo -> Resend | spec dediee | Moyenne | Chantier independant, ~16h |
| 11.13 Wizard de redefinition collective (post-creation) | section 13.2.1 | Strategique | Spec dediee future |
| 11.14 Audit historique du choix initial | section 13.2.2 | Moyenne | Alimenter library_profile_history des activation |
| 11.15 Mecanisme de sortie du reseau (fork) | section 13.2.3 | Strategique | Spec dediee future |
| 11.16 Suppression role administrador (deprecie D.8) | spec v0.4 | Moyenne | Spec v0.8 |
| 11.17 Nettoyer cles `panel.tab.transitions*` orphelines | section 9.14.4 | Basse | 12 strings dans 6 locales |

## Section 12 -- Bilan complet chantier profils d'adoption

| Critere | Etat avant chantier | Etat post-cloture v0.7 |
|---|---|---|
| Tables transactionnelles avec archived_at | 0/5 | 5/5 |
| Helpers archivage backend | 0/3 | 3/3 |
| Vues actives filtrees | 0/11 | 11/11 |
| Vues historique filtrees | 0/6 | 6/6 |
| Tables vote/proposition transitions | 0/2 | 2/2 (library_profile_proposals, library_profile_votes) |
| RPC de vote transitions | 0/4 | 4/4 |
| Colonne `libraries.profile_template_chosen` | absente | livree (hotfix G) |
| FK profile sur tables votes | 0/4 | 4/4 (hotfix E.5) |
| Frontend painel adaptatif | absent | en prod (E.0-E.3) |
| Frontend compte lecteur·rice adaptatif | absent | en prod (E.4) |
| Frontend vote transitions | absent | en prod (E.5, BibliotecaPage) |
| Wizard onboarding profil 4 axes | absent | en prod (F.3) |
| Banniere biblios existantes | absente | en prod (G, BibliotecaPage) |
| i18n strings militantes ajoutees | -- | 672 (354 E.5 + 318 F.4 + 48 G + 6 refactor + 60 E.4) |
| Migrations BDD chantier profils | -- | 11 (B + C + D x6 + F + G hotfix + E.5 hotfix) |
| Doctrines actees | -- | v2.2 + typage UNION ALL + 90j + point d'orgue + v2.3 + v2.4 + v2.5 + ancrage geo + Painel vs Biblioteca + PowerShell + Codeberg |
| Bibliotheques federales en prod | 2 (BLMF, BTL) | 3 (+ blt-test-informal banc d'essai) |

**Le chantier profils d'adoption est entierement cloture.** Toute la chaine
est fonctionnelle, de la creation d'une biblio via wizard 4 axes jusqu'a la
deliberation collective de transitions, en passant par l'adaptation
automatique des UIs (painel et compte) selon le profil.

## Section 13 -- Articulation onboarding ↔ profils (nouvelle v0.7)

Cette section pose les questions strategiques que les specs ulterieures
devront clarifier. Elle complete les sections 9.11 (onboarding) et 9.10
(vote transitions) en explicitant le **pont** entre les deux outils.

### 13.1 Deux outils, deux moments de vie

Les paquets F (onboarding) et E.5 (transitions) touchent aux **MEMES 4 axes
profil**, mais a deux moments tres differents :

| Phase | Outil | Auteur·rice | Mecanisme |
|---|---|---|---|
| **Creation** | Wizard SolicitarBibliotecaPage (F.3) | Pessoa de contact (futur·e coordenador·a) -- choix individuel | `fn_submit_library_request` -> review par reseau -> `fn_activate_approved_library_request` |
| **Evolution** | TransitionsPanel BibliotecaPage (E.5) | Staff actif collectif | `fn_propose` -> `fn_vote` (x N) -> `fn_execute_library_profile_change` |

### 13.2 Le pont technique

**Deux fonctions** font le pont entre les deux phases :

- `fn_activate_approved_library_request` (post-hotfix G) : copie
  `library_requests.profile_template_chosen` vers
  `libraries.profile_template_chosen` au moment de l'activation
- `fn_execute_library_profile_change` (post-hotfix G) : recalcule
  `libraries.profile_template_chosen` apres chaque transition, matching le
  quadruplet final aux profils A/B/C/D ou retombant sur `custom`

La colonne `libraries.profile_template_chosen` joue ainsi un role
d'**indicateur de consentement conscient au profil** : NULL = choix non
explicite (banner G s'affiche), 'A/B/C/D/custom' = choix explicite.

### 13.3 Asymetrie politique entre creation et evolution

Une difference fondamentale separe les deux outils :

- **Creation** : UNE personne propose, le reseau valide. Seuil bas, parce
  qu'on a besoin que des biblios puissent emerger sans friction inutile.
- **Evolution** : LE STAFF delibere collectivement avec quorums et voting
  types. Seuil eleve, parce qu'on a besoin que les changements de
  configuration soient des decisions collectives, pas le caprice d'un·e
  coordenador·a.

**Cette asymetrie n'est pas un bug, c'est un choix politique**. La doctrine
est : on fait confiance a une personne pour initier (en se laissant juger
par le reseau), mais on demande au collectif local de deliberer pour
evoluer (avec garde-fous proportionnels a l'enjeu via les 4 types de
transition).

### 13.4 Questions ouvertes pour les specs ulterieures

#### 13.4.1 Wizard de redefinition collective ?

Aujourd'hui, une biblio qui veut tout reconfigurer apres creation doit le
faire transition par transition, axe par axe (E.5). C'est lourd : 4
propositions, 4 deliberations, 4 votes.

**Question** : faut-il prevoir un "wizard de redefinition" qui propose un
changement de quadruplet COMPLET en une seule deliberation collective ?

Pro :
- Plus efficace, moins de friction administrative
- Coherent avec le wizard d'onboarding (meme UX, meme philosophie)
- Permet aux assemblees de discuter une refondation collective plutot que
  des micro-decisions

Contre :
- Risque de fast-track non delibere : un·e coordenador·a presse·e peut
  faire passer 4 changements ensemble en evitant la deliberation
  axe-par-axe
- Mecanique de quorum complexe : si chaque axe a un transition_type
  different, comment combiner ?
- Le mecanisme existant (transitions axe-par-axe) FORCE de fait une
  reflexion par dimension

**Position pour v0.7** : laisser le mecanisme existant. Backlog 11.13.

#### 13.4.2 Audit historique du choix initial

Aujourd'hui, `library_profile_history` capture les transitions individuelles,
mais on perd la trace du **CHOIX INITIAL** (qui est dans `library_requests`
separe, non visible dans l'onglet Transicoes).

**Proposition** : alimenter `library_profile_history` avec une ligne
initiale au moment de l'activation, du type :

```sql
INSERT INTO library_profile_history (...)
VALUES (library_id, 'profile_initial', NULL, profile_template_chosen,
        activated_by, now(), 'Choix initial via wizard onboarding');
```

Cela donne aux compas une vision complete de la trajectoire de leur biblio
depuis sa creation, dans un seul endroit (TransitionsPanel).

**Position pour v0.7** : a faire dans une session future, backlog 11.14.

#### 13.4.3 Sortie du reseau (fork)

Aucun mecanisme aujourd'hui pour qu'une biblio sorte d'AnarBib (decision
politique de quitter le reseau federal). Ce n'est pas une transition de
profil, c'est une transition de STATUT (federe -> independant).

**Position pour v0.7** : hors scope, backlog 11.15 (spec dediee future).

#### 13.4.4 Suppression de l'accuse "administrador"

Le role `administrador` est deprecie en D.8 (sessions precedentes). Sa
suppression est prevue au paquet F.5 mais n'a pas ete realisee dans cette
session (faute de besoin urgent). Confirmer si on garde administrador
comme legacy ou si on le supprime dans v0.8.

**Position pour v0.7** : backlog 11.16, spec v0.8.

## Annexes

### Migrations du chantier complet

| Timestamp | Paquet | Description |
|---|---|---|
| ... | A-C | Voir spec v0.5 |
| 20260519210000 | D.1 | Colonnes archive_at + indexes |
| 20260519220000 | D.2 | 3 helpers archivage SECURITY DEFINER |
| 20260519230000 | D.3 | Patch 11 vues actives |
| 20260519240000 | D.4 | Patch 6 vues historique |
| 20260519250000 | D.5 | Table library_unarchive_log + RPC |
| 20260519260000 | D.6 | Hooks archivage dans fn_execute_* |
| 20260519270000 | D.6 hotfix | Fix column motivation (non change_reason) |
| 20260519280000 | G hotfix | Colonne libraries.profile_template_chosen + propagation + recalcul |
| 20260519290000 | E.5 hotfix | 4 FK profile (proposed_by, cancelled_by, voter_id, changed_by) |
| 20260520100000 | F backend | Onboarding 4 axes (749 lignes) |
| 20260520100000 hotfix v2 | F backend | DROP+CREATE FUNCTION pour changement signature |

### Fichiers livres session 19-20/05

**Backend** :
- 11 migrations SQL (paquet D x6 + D.6 hotfix + G hotfix + E.5 hotfix + F + F hotfix)

**Frontend (composants nouveaux)** :
- `src/components/LibraryProfileWizard.jsx` (330 lignes, F.3)
- `src/components/LibraryProfileBanner.jsx` (124 lignes, G)
- `src/components/TransitionsPanel.jsx` (474 lignes, E.5)
- `src/hooks/usePanelAvailability.js` (53 lignes, E.1)
- `src/hooks/useAccountAvailability.js` (56 lignes, E.4)

**Frontend (fichiers modifies)** :
- `src/contexts/LibraryContext.jsx` (enrichissement E.0, +20 lignes)
- `src/pages/painel/PanelPage.jsx` (patches E.2-E.3 puis retrait refactor)
- `src/pages/account/AccountPage.jsx` (patches E.4, +16 lignes)
- `src/pages/public/SolicitarBibliotecaPage.jsx` (patches F.3, +30 lignes)
- `src/pages/biblioteca/BibliotecaPage.jsx` (patches refactor, +46 lignes)

**i18n** :
- 6 fichiers `src/i18n/locales/*.json` enrichis de 672 strings (354 E.5 +
  318 F.4 + 48 G + 6 refactor + 60 E.4) (rappel : E.4 reutilise des cles
  existantes pour la plupart, +60 marginal)

**Specs et bilans** :
- `docs/specs/spec-profils-bibliotheque-v0.7.md` (ce document)
- `docs/decisions/SESSION_2026-05-19_au_20_chantier_profils_cloture.docx`

### Doctrines de session a propager dans le Grand Livre Blanc v14+

Reprises des sections 10 et 10 ter ci-dessus :

1. **v2.3** -- DO block via information_schema, pas pg_get_functiondef + ILIKE
2. **v2.4** -- DROP+CREATE FUNCTION pour changement de signature
3. **v2.5** -- Verifier les patches via grep apres ecriture (atomicite Python)
4. **Ancrage geographique** -- 1 lecteur·rice = 1 biblio (verifie en prod)
5. **Deliberation politique vs travail operationnel** -- Biblioteca = identite/configuration, Painel = quotidien
6. **PowerShell UTF-8** -- Methode `[System.IO.File]::ReadAllText/WriteAllText`, mojibakes Get-Content sont faux positifs
7. **Select-String -SimpleMatch** -- rigoureux sur les espaces, retester en regex
8. **git commit --amend** -- ne rattrape pas les untracked, verifier git status apres add
9. **Codeberg stale info** -- normal apres force-push origin, push codeberg main --force-with-lease

### Statistiques cumulees chantier profils

- Date debut chantier : 12 mai 2026 (livraison spec v0.3)
- Date cloture chantier : 20 mai 2026 (cette spec v0.7)
- Duree : 8 jours calendaires, ~30 heures de travail cumulees
- Sessions de travail : 4 (12/05 ; 18/05 + 19/05 matin ; 19/05 soir + 20/05 nuit)
- Migrations livrees chantier : 11 + 4 fix/hotfix
- Composants frontend crees : 3 nouveaux + 2 nouveaux hooks
- Pages frontend modifiees : 5 (BibliotecaPage, PanelPage, AccountPage, SolicitarBibliotecaPage, LibraryContext)
- Strings i18n militantes ajoutees : 672 (sur 6 locales = 4032 strings cumulees)
- Doctrines actees : 9 nouvelles (v2.3-v2.5 + 6 doctrines politiques/techniques)
- Bibliotheques federales utilisatrices : 3 (BLMF, BTL, blt-test-informal)
- Tests fumee passes : 42/42 (vitest)
- Pipelines Woodpecker verts : 12+ dans la session 19-20/05
