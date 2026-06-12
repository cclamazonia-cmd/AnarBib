# HANDOFF — Perf (mission 2) + mission 3, à reprendre depuis WSL

> Rédigé le 2026-06-12 par la session « Cotisation libellés + audit/refactor perf ».
> **À lire en entier avant de reprendre.** Tout a été vérifié en live.

## 0. RÈGLE D'OR DE CETTE REPRISE — lancer Claude DEPUIS WSL

La cause de tout le bazar du 12/06 : une session Claude lancée **côté Windows**
(outils cloués à `C:\Users\accat\Claude's AnarBib\anarbib-app`) pendant que le
dev server et les autres sessions vivaient dans **WSL** (`~/anarbib` =
`/home/accattone/anarbib`). Résultat : deux clones désynchronisés, edits
invisibles, prod en avance sur le local.

- **Clone canonique unique = WSL** : `/home/accattone/anarbib`. C'est lui qui
  fait tourner `npm run dev` (localhost:5173) et qui pousse vers Codeberg.
- **Le clone Windows a été supprimé** (il était 100 % redondant, 0 commit unique).
- **Lance toujours `claude` depuis WSL** : `cd ~/anarbib && claude`. Une session
  Windows recrée le clone fantôme et on y retourne.
- **Correctif factuel (12/06/2026)** : contrairement à ce qui était écrit ici,
  l'accès UNC `\\wsl.localhost\...` au FS WSL **fonctionne** en lecture/écriture
  via Read/Edit/Write (vérifié sur ce poste, WSL2 Ubuntu-26.04). Ce n'est donc
  PAS un blocage technique. La règle « lancer depuis WSL » reste néanmoins bonne
  sur ses fondements valides : un seul clone canonique dans WSL, CWD propre, pas
  de clone fantôme, outils ergonomiques.

## 1. ÉTAT À LA REPRISE (tout sur Codeberg = prod)

`codeberg/main` HEAD au moment du handoff :
- `daf452d perf(biblioteca): lazy-load des onglets lourds au montage (24 -> 14 requetes)` ← **mission 2-P0, DÉPLOYÉE**
- `7a0d8bf feat(import): fusion des 3 circuits en un flux unique (Livraison 2)` ← autre session, déployée
- `54b6855 i18n(cotisation): libelles explicites du mode de calcul de validite` ← **mission 1, DÉPLOYÉE**

### Fait ✅
- **Mission 1** (cotisation, i18n ×10) : libellés du select `period_anchor`
  clarifiés. Décision : on a gardé « **période civile** » (PAS « année civile »)
  car le mode `calendar` vaut aussi pour mensuel/trimestriel ; le clarificateur
  décisif est « **quelle que soit la date de paiement** », en miroir de
  « Glissant : à partir de la date de paiement ». 3 clés (`periodAnchor` +
  `.rolling` + `.calendar`), valeurs seulement, parité inchangée (4131). NB : la
  capacité « année civile » existait DÉJÀ (colonne `period_anchor`,
  `fn_compute_membership_validity` calcule le 31/12 pour annual+calendar) — on
  n'a fait que clarifier l'UI.
- **Mission 2-P0** (BibliotecaPage) : `loadAll` scindé en `loadCore` (config +
  bandeau KPI `stats` + `allLibraries`, au montage) et `loadHeavy` (membres,
  PEB+items, intercâmbios, tâches+modèles+suggestions) chargé à la 1re visite
  d'un onglet de `HEAD_TABS = ['ill','exchanges','tasks','reports']`, idempotent
  via `heavyLoadedRef`. Fetch mort `library_circulation_policy_sets` retiré.
  **Vérifié live : 24-30 → 14 endpoints uniques au montage ; le clic sur un
  onglet lourd déclenche bien `loadHeavy`.**

## 2. RESTE À FAIRE (aucune migration SQL nécessaire sur tout ça)

### 2-P0 bis — AccountPage (`src/pages/account/AccountPage.jsx`) — MÊME traitement
- Symptôme mesuré (F12 live, /conta) : **~25 endpoints REST uniques au montage**,
  trou systémique de ~1,2 s, stabilisation ~3,8 s.
- Reproduire le pattern BibliotecaPage : `loadCore` (ce que l'onglet par défaut +
  l'en-tête affichent) + `loadHeavy` (historiques prêts/réservations/consultas,
  wishlist, notifications, memberships, paiements, prefs rétention/notif) chargé
  à la 1re visite des onglets consommateurs. Onglets déjà lazy : `ReaderCardSection`,
  `ReservationCard`, `TabBiblios`. **Cartographier d'abord quel onglet lit quelle
  donnée** (grep des states), comme on l'a fait pour Biblioteca, pour ne pas
  différer une donnée affichée par un onglet « léger ».

### 2-P1 — Double chargement de thème (default → blmf)
- Au montage de toute page connectée, les assets thème sont chargés DEUX fois :
  d'abord `themes/default/` (manifest/bg/logo/favicon), puis `themes/<slug>/`
  (ex. `blmf/`). Visible en fin de chargement (flash de thème + round-trips).
- Voir le contexte/loader de thème (chercher `fn_ensure_library_theme`,
  `publicAssetUrl`, `library-ui-assets`, `manifest.json`). Mémoire pertinente :
  les assets chargent depuis le bucket Storage `library-ui-assets`, pas l'origin.
- Objectif : résoudre le thème effectif de la biblio AVANT de charger les assets,
  pour ne charger qu'une fois (pas default puis le vrai).

### 2-P2 — Bundle initial + N+1
- **pt-BR hors chunk initial** : `src/i18n/index.js` importe pt-BR en STATIQUE
  (fallback synchrone) → ~70 Ko gz embarqués dans le chunk `index` (482 Ko). Le
  sortir en chunk dédié (accepter un court chargement du fallback) allège le 1er
  paint. ⚠️ Aucun chunk ne dépasse 500 Ko aujourd'hui (max 482) — la lenteur est
  data-shaped, pas bundle-shaped ; c'est un bonus.
- **N+1 sur `/rede`** (`RedePage`) : `library_circulation_stats` est tirée **une
  fois par bibliothèque** dans une boucle. Batcher en une seule requête
  (`.in('library_id', [...])` ou un RPC agrégé).

### Cleanup — 2 bugs console (vus en live)
- `src/pages/catalogacao/AuthorDraftForm.jsx` (~lignes 720-734) : clé i18n
  **`catalogacao.status.retaken` MANQUANTE** (pt-BR → donc les 10 ; à ajouter via
  script .cjs additif, parité +1) ET un id passé brut **`cancelled`** au lieu de
  `catalogacao.status.cancelled`. Ça crache une MISSING_TRANSLATION par ligne.
- **`key` React manquante** dans `TabTrabalhoDoDia` (onglet « travail du jour »
  du painel) — warning « Each child in a list should have a unique key prop ».

### Mission 3 — Sélection par lot dans la file éditoriale (PAS commencée)
- Fichier : `src/pages/catalogacao/QueuePanel.jsx`. Tout est déjà câblé : prop
  `batches` (id/name/status), `batch_id` dans le payload de chaque item
  (book/author/exemplar drafts), `assignBatchToSelected` existe, et il y a déjà un
  bouton **« tout sélectionner dans le filtre » cross-pages** (`selectAllInFilter`).
- Manque : un **4e filtre « Lot »** (à côté de type/statut/action, ~lignes 284-316)
  = `<select>` listant `batches` (+ « Tous les lots » + « Sans lot »). Le brancher
  dans `loadQueue` (`.eq('batch_id', batchFilter)` ou `.is('batch_id', null)`) ET
  dans `selectAllInFilter` (même `.eq`), pour que le bouton existant capture
  exactement le lot choisi, cross-pages.
- i18n : +3 clés ×10 (`catalogacao.queue.batchLabel`, `.allBatches`, `.noBatch`).
- Variante possible (non retenue) : bouton direct « Sélectionner le lot… » sans
  filtrer la vue. Le filtre est plus cohérent avec l'UI existante.

## 3. DOCTRINE GIT / PUSH (apprise à la dure le 12/06)

- **Pousser vers `git push codeberg main`, JAMAIS `git push origin main`.**
  `origin` tente GitHub en premier, et l'auth par mot de passe GitHub est morte
  (depuis 2021) → ça meurt avant d'atteindre Codeberg. Le miroir GitHub est en
  retard, c'est cosmétique. Pour le réparer un jour : `gh auth login` / PAT / SSH.
- **Creds Codeberg côté WSL** : `credential.helper store` a été posé en global.
  Au 1er push, saisir identifiant + mot de passe (ou jeton) Codeberg ; ensuite
  c'est mémorisé.
- **Règle d'or** : jamais deux push concurrents ; `git fetch` avant de pousser,
  ne pas être en retard ; sérialiser ses propres push (attendre le pipeline vert
  avant le suivant). Plusieurs sessions tournent en parallèle.
- **`git add` EXPLICITE** des seuls fichiers concernés, **jamais `git add -A`/`.`**
  (sinon on avale le travail non commité d'une autre session — c'est arrivé).
- Commits : Conventional Commits, message **ASCII pur** (pas d'accents), trailer
  `Session: <nom>` + `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
  PAS de `[CI SKIP]` sur le frontend.
- i18n : 10 locales, fichiers plats LF sans BOM, parité obligatoire. Édition de
  valeurs = remplacement textuel ; ajout de clés = script .cjs additif (jamais de
  reserialisation JSON). Test : `npx vitest run src/tests/i18n.test.js`.

## 4. MÉTHODE DE VÉRIF LIVE (qui a marché)

- Lancer le dev : `cd ~/anarbib && npm run dev`. Si Windows ne joint pas
  localhost après un redémarrage, c'est le forwarding WSL2 ; relancer suffit en
  général (UNE seule instance — tuer les doublons par port, pas par `pkill -f`
  qui s'auto-tue).
- Mesure F12 via l'extension Claude-in-Chrome : sonde Performance API qui attend
  la fin des appels `supabase.co` puis compte les endpoints REST uniques. ⚠️ En
  dev : **StrictMode double les effets** (÷2) et **Vite compile à la demande**
  (gonfle le 1er chargement « à froid ») — re-mesurer « à chaud ».
- La fenêtre Chrome MCP est un contexte séparé : il faut s'y **reconnecter**
  (Turnstile + mot de passe, que Claude ne peut pas faire) pour tester les pages
  protégées.

## 5. DIVERS
- Backup du patch BibliotecaPage : `C:\Users\accat\biblioteca-refactor.patch`
  (Windows) — supprimable, le refactor est en prod.
- Brouillons WSL mis de côté pendant le ménage : `git stash list` →
  `stash@{0}: menage-2026-06-12-brouillons-WSL` (`.woodpecker.yml` obsolète +
  `package-lock.json`). À dropper si inutiles : `git stash drop`.
