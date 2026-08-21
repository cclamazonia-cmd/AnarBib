# CADRAGE — Hygiène du poste de travail : une seule copie de chaque chose

> **Date** : 2026-08-21
> **Auteur** : Claude (assistant·e), sur demande de Xavier
> **Session** : chantier conventions catalographiques — constat annexe
> **Statut** : cadrage. **Rien n'a été supprimé.** Le plan est à exécuter par
> étapes, avec un point de contrôle réversible entre chacune.
> **Préséance** : ce document **cadre** un chantier (constat + plan). Ce qui
> deviendrait doctrine — s'il y a lieu — s'inscrit au
> [`REGISTRE_decisions.md`](../../specs/REGISTRE_decisions.md), pas ici.

---

## 1. Pourquoi ce document existe

Il ne naît pas d'un souci d'esthétique ni d'espace disque : le disque WSL est
occupé à 1 %. Il naît de **trois incidents survenus dans la même journée**, le
20-21 août 2026, pendant le chantier des conventions catalographiques. Aucun
n'est grave isolément. Ensemble, ils décrivent un poste où l'on ne peut plus
savoir quelle copie d'un fichier fait foi.

**Incident 1 — le fichier demandé n'existait pas, et il a fallu trois essais
pour s'en assurer.** Une version 0.2 du registre des décisions devait être
récupérée. Elle a été cherchée successivement dans `Downloads` (copie identique
au dépôt, même MD5), dans un `.bak` du 1ᵉʳ juillet (777 lignes, arrêté à §35),
puis dans un **second clone complet de l'application** découvert au passage
(`Codeberg\anarbib`, 809 lignes, arrêté à §35). Trois copies du même fichier,
trois états différents, aucune n'était la bonne — et la question « laquelle fait
foi ? » n'avait pas de réponse lisible depuis l'arborescence.

**Incident 2 — une autre session a commité mon travail en cours.** Le dépôt
`C:\AnarBib` est un worktree partagé entre plusieurs sessions. Pendant la
rédaction du §37 du registre, une session voisine a commité le fichier tel qu'il
se trouvait sur le disque : le commit `948cd7d67` contient une **version
partielle** de mon texte (la section, sans la ligne de version ni l'entrée §0).
Rien n'a été perdu — mais le commit a ensuite été **poussé sur la forge** :
`origin/main` porte donc un état intermédiaire que personne n'a relu, et dont
l'auteur apparent n'est pas celui qui l'a écrit. Le même jour, HEAD a bougé
**sept fois** sous une session en cours de lecture, dont deux fois pendant la
rédaction de ce document.

**Incident 3 — `npm run build` a échoué pour une raison de chemin, pas de
code.** Lancé depuis Git Bash, le build s'est exécuté avec `C:\Windows` pour
répertoire courant (« Les chemins d'accès UNC ne sont pas pris en charge ») et a
cherché ses scripts au mauvais endroit. Le dépôt vit dans WSL, il est vu depuis
Windows par un lien `C:\AnarBib` → `\\wsl.localhost\...`, et selon l'outil qui
l'ouvre — bash, Python, node, npm — le même chemin marche, marche à moitié, ou
ne marche pas. Il a fallu rebasculer dans WSL pour construire.

**Ce que ces trois incidents ont en commun** : ce ne sont pas des erreurs de
jugement, ce sont des **erreurs rendues possibles par la topographie**. Un poste
où le même fichier existe en quatre exemplaires, où deux sessions écrivent dans
le même répertoire, et où la même arborescence a trois adresses selon l'outil,
est un poste qui *produit* ces erreurs — quel que soit le soin qu'on y met.

> **Le vrai risque n'est pas de perdre du travail. C'est d'en publier un
> mauvais.** Une migration écrite dans la bonne copie et poussée depuis la
> mauvaise, un secret corrigé dans un fichier qui n'est pas celui que lit le
> serveur, une doctrine réécrite à partir d'un registre périmé de deux mois :
> aucun de ces accidents ne déclenche d'alerte. Ils se voient plus tard, sur des
> données.

---

## 2. État des lieux — relevé du 21/08/2026

### 2.1 Le dépôt de l'application existe en quatre exemplaires

| Emplacement | Taille | Nature | Dernier commit |
|---|---|---|---|
| `~/anarbib` (WSL) — vu comme `C:\AnarBib` | 1,8 G | **dépôt de travail réel** | 21/08, actif |
| `C:\Users\accat\Codeberg\anarbib` | 604 M | clone complet, propre | 19/08 |
| `C:\Users\accat\Codeberg\anarbib-mirror.git` | 155 M | miroir nu | — |
| `C:\Users\accat\anarbib-staging` | 84 M | copie **hors git**, contient `anarbib-app` | fichiers du 19/08 |

**Fait vérifié** : les 15 derniers commits du clone `Codeberg\anarbib` existent
tous dans le dépôt WSL, et son arbre de travail est propre (0 fichier modifié).
**Il ne contient aucun travail absent d'ailleurs.**

### 2.2 Des dossiers-satellites accumulés

| Emplacement | Taille | Ce que c'est |
|---|---|---|
| `C:\Users\accat\node_modules` | 117 M | dépendances installées **à la racine du profil** — trace d'un `npm install` lancé dans le mauvais répertoire |
| `C:\Users\accat\Downloads` | 398 M | 24 entrées, sert de zone de transit entre outils |
| `C:\Users\accat\AnarBib` | 1,2 M | dumps de schéma de juillet, **homonyme du lien `C:\AnarBib`** |
| `C:\Users\accat\anarbib-snapshot-paquet26-…` | — | instantané de mai |
| `C:\Users\accat\anarbib-tools`, `notify-event-downloaded` | ~0 | vides ou quasi |
| `~/Autres dossiers AnarBib` (WSL) | ~8 M | maquettes, PDF, exports, **et des secrets** |

Un répertoire s'appelle littéralement `{public,src` : une accolade de shell non
développée, devenue un dossier. C'est le symptôme, sous sa forme la plus pure.

### 2.3 Deux worktrees fantômes

`git worktree list` déclare trois arbres, dont deux **prunables** — leur
répertoire n'existe plus, seule l'inscription subsiste :

```
/home/accattone/anarbib-i18n-discard   [fix/i18n-discard-errors]   prunable
/home/accattone/anarbib-merge-authors  [feat/catalog-audit-fixes]  prunable
```

Vérifié : **aucune des deux branches ne porte de commit absent de `origin/main`**.
Elles se nettoient sans risque (`git worktree prune`, puis suppression des
branches). Elles montrent surtout que le mécanisme recommandé en **H-3** est
déjà utilisé sur ce poste — simplement sans étape de clôture.

### 2.4 Le point sérieux : des secrets en clair, hors de tout coffre

Relevés à l'existence (**contenu non ouvert**) :

- `~/Autres dossiers AnarBib/Divers secrets.txt`
- `~/Autres dossiers AnarBib/Autres secrets et autres machins casse-couilles.txt`
- `~/Autres dossiers AnarBib/proton-recovery-kit.pdf`
- `~/anarbib-staging/functions.env`, `~/anarbib-staging/secrets-list.json`
- `~/.pgpass`, `~/.git-credentials` (WSL)

S'y ajoute au moins un export de données personnelles :
`catalogo-…-2026-06-12.csv`, et des cartes-lecteur nominatives en PDF.

Ce n'est pas un problème de rangement. Ces fichiers sont **hors du périmètre de
la sauvegarde #BG2** (qui dumpe `--schema=public` de la base, pas le poste), et
hors de toute politique de rétention. Ils vivent dans un profil utilisateur
Windows synchronisé par OneDrive.

---

## 3. Principes — ce qu'on veut obtenir

Cinq règles, dans l'ordre d'importance. Elles ne demandent pas de discipline
quotidienne : elles rendent l'erreur **difficile**, ce qui est le seul mécanisme
qui tient dans la durée.

**H-1 — Une seule copie de travail par dépôt.** Un dépôt, un chemin, une
adresse. Les autres copies sont soit supprimées, soit rendues manifestement
mortes (renommées `.ARCHIVE-<date>`, en lecture seule). Une copie qu'on hésite à
supprimer est une copie qu'on finira par éditer.

**H-2 — Le dépôt vit dans WSL, et tout ce qui l'exécute vit dans WSL.** `npm`,
`node`, `git`, `psql`, `supabase` : depuis WSL. Le lien `C:\AnarBib` reste utile
pour *lire* et pour les éditeurs, mais aucune commande de build ne part de
Windows. C'est déjà la règle de fait ; elle n'est simplement écrite nulle part,
et elle a été enfreinte aujourd'hui même.

**H-3 bis — On stage des FICHIERS NOMMÉS, jamais un répertoire.** Corollaire
appris à mes dépens le 21/08, deuxième occurrence du même incident. Un
`git add -- src/i18n/locales` a emporté, dans un commit qui ne parlait que d'une
clé, **quatre clés d'une autre session** en cours d'écriture — 40 chaînes sur
10 locales, poussées sous un message qui ne les mentionne pas. `git add -A` est
la faute évidente ; `git add <répertoire>` est la même faute en plus discret, et
elle passe inaperçue parce qu'on croit avoir été précis. La règle utile n'est pas
« pas de `-A` », c'est : **le `git add` énumère exactement les fichiers que le
message décrit**, et on relit `git show --stat` avant de pousser, pas après.

**H-3 ter — nommer le fichier ne suffit pas : il faut qu'il soit propre.**
Troisième occurrence dans la même journée, et la règle précédente n'a pas tenu.
`git add -- src/pages/catalogacao/CatalogPanel.jsx` ne désigne qu'**un seul
fichier nommé** — et a quand même publié une fonctionnalité entière d'une autre
session (signalements d'autorités, ~80 lignes appelant une RPC
`list_authority_reports` **qui n'existe pas encore en base**). Le fichier
lui-même était sale. La règle utile est donc : **avant de stager, lire
`git diff <fichier>` et vérifier qu'il ne contient que ses propres lignes.**

> **Et il faut le dire : la discipline a échoué trois fois en une journée.**
> Trois formulations successives de la même règle — pas de `-A`, puis nommer les
> fichiers, puis vérifier qu'ils sont propres — chacune écrite juste après
> l'incident que la précédente n'avait pas empêché. C'est le signe que le
> problème n'est pas la règle mais la **topographie** : deux sessions qui
> écrivent dans le même arbre de travail produiront cet incident quelle que soit
> l'attention qu'on y met. C'est l'argument empirique pour **H-3**, et il vaut
> mieux que n'importe quel raisonnement : un worktree par session, ou une seule
> session qui écrit à la fois.

**H-3 — Une session à la fois par worktree, ou un worktree par session.** Le
partage de `~/anarbib` entre sessions concurrentes a produit l'incident 2. Deux
issues : sérialiser (une seule session écrit à la fois), ou donner à chaque
session son `git worktree` sur une branche à elle. La seconde est la seule qui
tient si le travail en parallèle doit continuer.

> **La recette, appliquée le 21/08.** Un worktree par session, et le push qui va
> avec — c'est le second geste qui compte, et il manquait à la formulation
> d'origine.
>
> ```bash
> # une fois par session
> git -C ~/anarbib fetch origin
> git -C ~/anarbib worktree add -b claude/<id> ~/anarbib-wt-<id> origin/main
> cd ~/anarbib-wt-<id> && npm ci        # un worktree n'hérite pas de node_modules
>
> # pour livrer : rejouer la chaîne de la CI, puis pousser SES commits seuls
> npm run lint && npm test && npm run build
> git fetch origin && git rebase origin/main
> git push origin HEAD:main
>
> # en fin de session
> git -C ~/anarbib worktree remove ~/anarbib-wt-<id>
> git -C ~/anarbib branch -d claude/<id>
>
> # et surtout : le main partage ne doit rien garder de moi (HYG-Q3)
> git -C ~/anarbib fetch origin
> git -C ~/anarbib log --oneline origin/main..main   # doit etre vide
> ```
>
> **La derniere commande n'est pas une precaution de confort.** Une sortie non
> vide signale un commit sans porteur : personne ne l'emportera, puisque chacun
> pousse desormais depuis sa branche. Soit on le pousse s'il est de soi, soit on
> previent la session qui l'a pose. Ce qu'elle evite, c'est du travail termine,
> teste et jamais livre.
>
> **Pourquoi `push origin HEAD:main` et pas `push origin main`.** C'est ce qui
> règle le *second* incident de la journée, distinct du premier : une branche
> personnelle ne contient que ses propres commits, donc le push ne peut pas
> emporter le travail commité-mais-non-poussé d'une autre session — ce qui est
> arrivé quatre fois le 20/08, dont une fois avec deux migrations parties en
> déploiement sans que personne l'ait décidé. Et la branche déployant sur `main`,
> on ne perd pas le déclenchement du pipeline.
>
> **Ce que ça coûte** : `npm ci` à l'ouverture (~20 s) et deux commandes à la
> fermeture. **Ce que ça supprime** : l'index partagé, la fenêtre entre écriture
> et commit, et le push élargi. Soit les quatre incidents du 20/08 d'un coup.

**H-4 — Les secrets ne sont pas des fichiers .txt.** Un gestionnaire de mots de
passe, ou le Vault Supabase déjà en place pour les 21 secrets applicatifs. Un
fichier nommé « Divers secrets.txt » dans un profil OneDrive n'est pas un
stockage, c'est une fuite en attente.

**H-5 — `Downloads` est un sas, pas un plan de travail.** Ce qui y arrive est
soit rangé dans les 24 h, soit supprimé. Le chantier d'aujourd'hui a commencé
par huit fichiers déposés là, et deux d'entre eux se sont révélés être des
copies périmées du dépôt.

---

## 4. Plan d'exécution

Cinq étapes, **dans cet ordre**, avec un point de contrôle réversible entre
chacune. Rien ne se supprime avant que l'étape 1 soit finie.

### Étape 1 — Établir ce qui est unique *(aucune suppression)*

Avant tout ménage, prouver qu'aucune copie ne détient de travail unique. Pour
chaque copie candidate, deux questions et deux commandes.

Pour un clone git — a-t-il des commits absents du dépôt de référence, et un
arbre sale ?

```bash
cd /c/Users/accat/Codeberg/anarbib && git status --short && git log --format=%H -50 | while read c; do git -C /c/AnarBib cat-file -e "$c" 2>/dev/null || echo "UNIQUE: $c"; done
```

Pour une copie hors git (`anarbib-staging`, `AnarBib`, les snapshots) — il n'y a
pas d'historique à comparer : la seule méthode honnête est un `diff` récursif
contre le dépôt, en ignorant `node_modules`, et la lecture de ce qui en sort.
Tout fichier qui n'existe nulle part ailleurs est à **reclasser dans le dépôt ou
dans le corpus de specs**, pas à conserver sur place.

> **Résultat déjà acquis pour `Codeberg\anarbib`** : arbre propre, aucun commit
> unique. Cette copie est prête à partir dès l'étape 3.

### Étape 2 — Mettre les secrets à l'abri *(avant tout déplacement)*

C'est l'étape qui a une conséquence si elle est faite dans le désordre : un
fichier de secrets déplacé avant d'être lu est un secret perdu.

1. Ouvrir chacun des six fichiers listés en §2.3 et **transférer chaque entrée**
   dans le gestionnaire de mots de passe.
2. Vérifier au passage lesquels sont encore **valides** — un secret de mai peut
   avoir été tourné depuis.
3. Supprimer les fichiers d'origine, y compris de la corbeille **et de
   l'historique OneDrive** (le fichier survit à la suppression locale).
4. Traiter séparément le CSV de catalogue et les cartes-lecteur : ce sont des
   données personnelles de lectrices et lecteurs, relevant de la même exigence
   que la denylist PII de #BG2.

### Étape 3 — Neutraliser les copies redondantes *(réversible)*

**Ne rien supprimer d'emblée.** Renommer, attendre, supprimer ensuite.

```bash
cd /c/Users/accat && mv Codeberg/anarbib Codeberg/anarbib.ARCHIVE-20260821
```

Un dossier ainsi renommé casse immédiatement tout script, tâche planifiée ou
raccourci qui en dépendait encore — et c'est précisément le but : on découvre
les dépendances oubliées **pendant** qu'on peut encore revenir en arrière. Après
deux semaines sans incident, la suppression est sûre.

Même traitement, dans l'ordre du moins risqué au plus risqué :

| Cible | Geste | Risque |
|---|---|---|
| `notify-event-downloaded` (vide) | supprimer | nul |
| `anarbib-tools`, `anarbib-snapshot-paquet26-…` | archiver puis supprimer | nul |
| `C:\Users\accat\node_modules` | supprimer | nul — se régénère |
| `C:\Users\accat\AnarBib` (dumps de juillet) | vérifier §5, puis archiver | faible |
| `Codeberg\anarbib` | archiver 2 semaines, puis supprimer | faible (vérifié §1) |
| `anarbib-staging` | **diff d'abord** — hors git, non vérifié | **à ne pas précipiter** |
| `Codeberg\anarbib-mirror.git` | garder si c'est la sauvegarde du dépôt | — |

### Étape 4 — Fixer une adresse unique

Une fois les doublons partis, écrire noir sur blanc, dans le `CLAUDE.md` du
dépôt, les quatre lignes qui manquent aujourd'hui :

- le dépôt de l'application est `~/anarbib`, dans WSL Ubuntu-26.04 ;
- `C:\AnarBib` en est une **vue**, pour lire et éditer, jamais pour exécuter ;
- toute commande (`npm`, `git`, `psql`, `supabase`) se lance dans WSL ;
- le site vitrine est un **autre dépôt** (`Codeberg/anarbib_site`), à ne pas
  confondre.

Ces quatre lignes auraient évité l'incident 3 et une partie de l'incident 1.

### Étape 5 — Régler la concurrence entre sessions

Trancher entre les deux options de **H-3**. Si le travail en parallèle continue,
donner à chaque session son worktree :

```bash
git -C ~/anarbib worktree add ../anarbib-session-b -b session-b
```

Chaque session commite sur sa branche, la fusion est explicite, et personne ne
commite plus le fichier à moitié écrit d'un autre.

---

## 5. Ce qu'il ne faut pas supprimer

Un cadrage de ménage qui ne dit pas où s'arrêter est un cadrage dangereux.

- **`~/anarbib`** — le dépôt de travail. Seule source de vérité.
- **`Codeberg\anarbib-mirror.git`** — miroir nu ; à conserver tant qu'il n'est
  pas établi qu'une autre sauvegarde du dépôt existe.
- **`~/anarbib-ops/`** — les listes de la sauvegarde #BG2 y vivent, et
  `bg2-known-tables.txt` y est un **lien symbolique** vers le dépôt. Casser ce
  lien fait échouer toutes les sauvegardes, en silence, jusqu'à l'alarme de
  silence ~36 h plus tard.
- **`.pgpass`, `.ssh`, `.git-credentials`, `.supabase`** — infrastructure
  d'accès. À sécuriser (H-4), pas à supprimer sans remplacement.
- **`Codeberg\anarbib_site`** — dépôt **distinct**, celui de `anarbib.org`.
- **Tout ce que l'étape 1 n'a pas encore examiné.**

---

## 6. Ce que ça coûte, et ce que ça rapporte

**Coût** : une demi-journée pour les étapes 1 à 4, plus deux semaines de délai
d'archivage avant les suppressions définitives. L'étape 2 (secrets) est la plus
ingrate et la moins reportable.

**Gain** : la disparition d'une classe entière d'erreurs. Pas leur réduction —
leur disparition. On ne peut pas éditer la mauvaise copie d'un fichier qui n'a
qu'une copie ; on ne peut pas construire depuis le mauvais système quand une
seule adresse fonctionne ; on ne peut pas commiter le brouillon d'autrui quand
chaque session a sa branche.

**Ce que ça ne règle pas** : la charge documentaire du projet. Le corpus de
specs, le registre et le journal sont volumineux **par conception** — c'est ce
qui permet à une session qui reprend le travail de savoir ce qui a été décidé et
pourquoi. Ce cadrage ne propose pas d'y toucher.

---

## 7. `HYG-Q1` — tranché le 21/08 : `anarbib-staging` est mort

La question était : ce dossier de 84 Mo, hors git, aux fichiers datés
d'avant-hier, est-il encore un chemin de déploiement vers l'instance de
staging ? Trois vérifications, toutes négatives.

**Rien ne l'appelle.** Aucun script (`.ps1`, `.sh`, `.cmd`, `.mjs`, `.cjs`),
aucune tâche planifiée Windows, aucun `crontab` WSL ne référence le chemin. Les
seules occurrences de la chaîne « anarbib-staging » sur la machine désignent
`anarbib-staging-rede`, le **nom du projet Supabase** — pas le dossier.

**Presque rien n'y est récent.** Sur l'ensemble du dossier, **trois** fichiers
seulement sont postérieurs au 1ᵉʳ mai ; tout le reste date d'avril 2026. Le
`19/08` que portait le dossier était son propre horodatage, pas celui de son
contenu.

**Et ces trois-là ne contiennent rien d'unique.**

| fichier | verdict |
|---|---|
| `git-pages/_redirects` | **identique** à `public/_redirects` du dépôt |
| `git-pages/ci-git-pages-step.yml` | brouillon d'une étape **déjà intégrée** à `.forgejo/workflows/ci.yml` (lignes 138-158, 20/08) |
| `anarbib-bg2-patche.sh` | 363 lignes contre 411 au dépôt ; ses 8 lignes de code propres sont une version **antérieure** du témoin de vie (`fn_record_backup_heartbeat` à 3 arguments, contre 4 au dépôt) |

Le `diff -r` complet relève 38 entrées présentes seulement côté staging. Deux
semblaient prometteuses et ne le sont pas : `catalog_metadata_lookup` **existe**
au dépôt, dans une arborescence plus récente ; `ResourcePage.jsx` date du
14 avril et n'a pas de suite. Le reste est du bundle (`anarbib_lookup_v2_bundle`,
`anarbib-functions`), des variantes `_staging` d'Edge Functions, un `sql/`
d'avril, et le répertoire `{public,src` — l'accolade de shell non développée.

**Conclusion** : le dossier est superseded en entier. Il reste néanmoins la
**seule chose du poste qui contienne des secrets hors coffre** (`functions.env`,
`secrets-list.json`, `supabase/functions/catalog_metadata_lookup/.env.local`).
L'étape 2 du plan (§4) s'y applique donc en priorité, et l'étape 3 peut suivre
immédiatement après — sans le délai d'archivage de deux semaines, puisque la
question « est-ce que ça sert encore ? » est répondue.

---

## 8. Point ouvert

**HYG-Q2 — le placeholder n'était que le premier.** La correction du filtre de
langue (21/08) a montré qu'une chaîne d'interface peut survivre au composant
pour lequel elle avait été écrite : `catalog.filters.languagePh` proposait
encore de *taper* « fr, pt, es, en… » des heures après que le champ soit devenu
un sélecteur. Rien ne détecte ce genre de survivance — ni le build, ni les tests
de parité i18n, qui vérifient que les 10 locales ont les mêmes clés, jamais que
la clé dit encore la vérité. À voir s'il existe d'autres `*Ph` orphelins.

---

## 9. Point ouvert — ce que la recette elle-même ouvre

**HYG-Q3 — le worktree partagé n'a plus de porteur.** *(Tranché le 21/08 : le
contrôle est intégré à la recette du §5.)* La recette du §5 supprime
le push élargi, et c'est son objet. Mais elle supprime du même coup un mécanisme
*accidentel* qui rendait service : jusqu'ici, un commit oublié sur le `main` du
worktree partagé finissait par partir avec le push de quelqu'un d'autre. C'était
le bug ; c'était aussi la voie de sortie.

Une fois que chaque session pousse `HEAD:main` depuis sa branche, **plus rien
n'emporte ce qui reste sur le `main` partagé**. Un commit posé là par une session
qui bascule ensuite dans son worktree n'a plus de porteur du tout.

Constaté le 21/08 vers 03:45 : quatre commits `#BG2` (contrôle de fraîcheur des
sauvegardes) attendaient sur le `main` partagé pendant que leur session
travaillait dans `anarbib-wt-a7592c54`. Une autre session, sollicitée pour
« pousser tout ce qui reste », a refusé de les emporter — à raison, c'est le
travail d'autrui — et leur propriétaire les a poussés lui-même quelques minutes
plus tard. **Rien n'a été perdu, mais la fenêtre a existé**, et elle serait
restée ouverte indéfiniment si cette session n'était pas repassée par là.

Ajout proposé à la recette, à côté du `worktree remove` :

```bash
# en fin de session — le main partage ne doit rien garder de moi
git -C ~/anarbib fetch origin
git -C ~/anarbib log --oneline origin/main..main
```

Une sortie non vide veut dire qu'un commit attend sans porteur : soit on le
pousse (s'il est de soi), soit on prévient la session qui l'a posé. Le coût est
de deux commandes ; ce qu'il évite, c'est du travail terminé, testé, et jamais
livré — la panne la plus silencieuse de toutes.

*(Constat annexe de la session « Dédoublonnage & arbitrage », 21/08/2026.)*
