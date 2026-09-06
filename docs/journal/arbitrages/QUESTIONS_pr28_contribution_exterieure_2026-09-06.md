# Quatre questions nées de la première contribution extérieure — 06/09/2026 *(tranchées le soir même)*

> Page préparée pour Xavier le soir du 06/09, après relecture complète de la
> PR #28 (`codeberg.org/anarbib/anarbib/pulls/28`, Bastien, `ASR2026`) et de la
> PR #2 du site vitrine (`codeberg.org/AnarBib/pages/pulls/2`). Aucune de ces
> questions ne demande du code : elles demandent un verdict, et le verdict entre
> au REGISTRE dans la foulée (`GOUV-19`, `FED-O11`, `DOC-CONTRIB-1`). **On
> répond par une lettre par question** — par exemple `Q1 A-B-C · Q2 A · Q3 A ·
> Q4 A`. Ce qui est déjà décidé est marqué comme tel.
>
> Constat complet : `journal/operations/CONSTAT_PR28_rejeu_vs_production_revoke_anon_2026-09-06.md`.
> Rappel du cadre : rien n'est fusionné avant le 14/09 (décidé le 06/09), rien
> ne touche la production avant le retour de Bologne.

---

## Q1 — Le premier administrateur d'une instance (`GOUV-19`, backlog `G11`)

**Ce qu'on sait.** Le circuit des administrateurs réseau est collégial de bout en bout et suppose qu'il en existe déjà un ; sur une base vide, personne ne peut proposer personne. La première ligne de `network_administrators` a été écrite à la main en mai 2026 ; l'exception n'est inscrite nulle part. Le `seed-admin.mjs` de la PR #28 refait ce geste par script (compte GoTrue, profil, biblio `demo` si la table est vide, rôles `coordenador` + `librarian`, ligne admin), et **refuse de tourner s'il existe déjà un admin actif**. Il est juste vis-à-vis du schéma de production (colonnes, `UNIQUE (user_id, library_id, role)`, PK ; `demo` reste `private`). En mode local il pose `admin@anarbib.local` / `anarbib-admin` en dur, et le guide vitrine les publie.

**Les options** (cumulables).

- **A — L'amorçage est un geste unique, hors circuit, refusé dès qu'il existe quelqu'un.** On l'écrit au REGISTRE comme la seule exception à P2, et `deploy/README.md` le présente comme l'amorçage, jamais comme une façon de créer des comptes.
- **B — Mot de passe aléatoire dans tous les modes**, affiché une fois à la fin de l'installation puis effacé (le mode `prod` de la PR le fait déjà ; le mode local ne le fait pas).
- **C — Le premier compte est coordination de la première bibliothèque ET administrateur réseau.** Pour une instance d'une seule bibliothèque, les deux se confondent ; pour une instance qui en accueillera plusieurs, l'admin réseau est celui qui coopte les suivants.
- **C′ — Le premier compte n'est que coordination** ; l'admin réseau s'active par un geste séparé, documenté.
- **D — La biblio `demo` se crée** avec ce nom ; **D′ — l'installateur demande le nom** de la bibliothèque (une question de plus dans `install.sh`, qui en pose déjà pour le mail).

**Recommandation : A + B + C + D′.**

**Verdict (Xavier, 06/09 au soir) : A + B + C + D′.** → REGISTRE `GOUV-19` ✅, backlog `G11` passe à *ouvert* (à appliquer dans `seed-admin.mjs` et `install.sh`, PR #28). A et B ne se discutent pas. C parce que l'instance auto-hébergée typique est une bibliothèque seule, et que C′ ajoute une marche là où le guide promet « une seule commande ». D′ parce qu'une bibliothèque nommée `demo` finit par s'appeler `demo` pour toujours.

---

## Q2 — Ce qui relie les instances (`FED-O11`, backlog `G12`, conditionne `J3`)

**Ce qu'on sait.** Chaque installation auto-hébergée est un réseau à elle seule : base, bibliothèques, admins, assemblées. Ce qui traverse aujourd'hui, c'est le catalogue, par OAI-PMH : chaque instance le sert (`oai-pmh-provider`) et peut moissonner celui d'une autre (`harvest-oai-pmh`) vers sa file de révision, sur décision admin. Ce qui ne traverse pas : comptes, appartenances, prêts entre bibliothèques, gouvernance, gazette. Le guide vitrine promet « même installée chez vous, votre bibliothèque peut coopérer avec les autres camarades du réseau ».

**Les options.**

- **A — Inscrire la doctrine telle quelle** (« une instance = un réseau ; entre instances, seul le catalogue traverse ») et la faire dire au site vitrine dans ces termes. Rien d'autre n'est promis.
- **B — A, plus ouvrir l'annuaire des instances comme domaine** : une liste des instances qui se reconnaissent, pour que la moisson ne dépende pas d'une adresse tapée à la main. C'est un domaine nouveau au sens de `DOC-GEL-1` : il faudrait une décision datée qui pèse son coût contre la fenêtre restante. Pas avant le retour.
- **C — Annoncer une fédération de protocole** (prêts, comptes, gouvernance entre instances). Écartée : elle n'existe pas, et rien ne l'annonce.

**Recommandation : A maintenant, B à instruire au retour, si le collectif le demande.**

**Verdict (Xavier, 06/09 au soir) : A.** → REGISTRE `FED-O11` ✅, backlog `G12` passe à *ouvert* (faire dire la phrase au site vitrine et à `deploy/README.md`) ; l'annuaire n'est pas ouvert. L'auto-hébergement va multiplier les instances ; si le projet ne dit pas ce qui les relie, chaque guide le dira à sa façon.

---

## Q3 — Le site vitrine (backlog `J3`) — *déjà tranché le 06/09*

**Décidé** (Xavier, 06/09, « il vaudrait mieux attendre un peu ») : la PR pages #2 reste ouverte et se fusionne **après** la PR « auto-hébergement », une fois quatre phrases corrigées (fédération, 2 Go / Raspberry Pi, identifiants par défaut, mode simulation) et l'avertissement « traduit automatiquement, corrigez-moi » ajouté au générateur. Le README multilingue du dépôt vitrine peut partir seul. Réponse posée à Bastien dans ces termes. **Rien à répondre ici**, la ligne est là pour que la décision ait une date.

---

## Q4 — Les règles de contribution (`DOC-CONTRIB-1`, backlog `A4`)

**Ce qu'on sait.** En un après-midi : trois PR sur deux dépôts, cinq réécritures d'historique, 46 fichiers dont trois Edge Functions, le transport mail et le résolveur d'URL du frontend. Fusionner aurait déployé le tout en production par la CI. `CONTRIBUTING.md` ne dit rien du périmètre d'une PR, du force-push pendant une relecture, ni de ce que le mainteneur promet en retour.

**Les options.**

- **A — Trois règles courtes dans `CONTRIBUTING.md`** (fr, pt, en) : une PR = un sujet ; le code déployé en production va dans une PR distincte de l'outillage ; pendant une relecture, on ajoute des commits, on ne force-pousse pas. Et la contrepartie : un premier retour sous une semaine, et le motif d'un refus toujours écrit.
- **B — Les mêmes règles, appliquées au cas par cas** sans les écrire. C'est ce qui s'est passé le 06/09 : ça a demandé un commentaire de deux pages.
- **C — Un gabarit de PR** (`.forgejo/PULL_REQUEST_TEMPLATE.md`) qui pose les questions à l'ouverture : quel sujet, quels fichiers de production, quel test. Complète A ; ne le remplace pas.

**Recommandation : A, et C quand quelqu'un a une soirée.**

**Verdict (Xavier, 06/09 au soir) : A.** → REGISTRE `DOC-CONTRIB-1` ✅ ; les trois règles écrites dans `CONTRIBUTING.md` le soir même ; backlog `A4` passe à *en cours* (reste : la PR #28 scindée). Une règle écrite protège la contribution autant que le projet : elle évite qu'un travail sincère finisse refusé en bloc parce qu'il était impossible à lire.

---

*Répondu le 06/09 au soir : `Q1 A-B-C-D′ · Q2 A · Q3 (déjà) attendre · Q4 A`. Les trois entrées du REGISTRE sont passées à ✅, les items du backlog ont changé d'état, cette page reste comme trace.*
