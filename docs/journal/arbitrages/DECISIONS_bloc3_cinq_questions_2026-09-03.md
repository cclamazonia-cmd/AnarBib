# Cinq décisions qui n'attendent que le collectif — 03/09/2026

> Page préparée pour Xavier le matin du 03/09 (bloc 3 de la matinée). Cinq
> fiches du backlog v34 sont à l'état « décision » : elles ne demandent pas de
> code, elles demandent un verdict. Pour chacune : ce qu'on sait (mesuré en
> production le 03/09), les options, la recommandation. **On répond par une
> lettre par fiche** — par exemple `C5 B · C9 A · D2 A · E11 A · I16 A` — et
> le verdict entre au REGISTRE dans la foulée.
>
> Rappel du cadre : « le collectif, c'est moi » (Xavier, 02/09) — la décision
> est prise seul tant que personne d'autre ne s'est saisi de l'outil, et elle
> est écrite comme telle (`DECISION_G2…`).

---

## C5 — Le champ libre `books.autor`

**Ce qu'on sait (03/09).**

| Mesure | Valeur |
|---|---|
| Livres | 2 659 |
| `autor` non vide | 2 653 |
| Livres **sans aucun lien** vers `authors` (le champ libre est leur seule information d'auteur) | **226** — BTL 138, MLEG 52, BLMF 36 |
| … dont plusieurs personnes dans la chaîne (`;`) | 121 |
| … dont forme « Nom, Prénom » | 133 |
| … dont tout en majuscules | 39 |
| … anonymes / « non identifié » | 5 |
| `autor` encore écrit par le formulaire de catalogage depuis le 01/08 | 8 livres — `BookDraftForm` l'écrit toujours (ligne 1908) |

Exemples réels des 226 : `Moissonnier, Maurice ; Pruvost, Georges`, `GIMENEZ, Antoine; Les Giménologues`, `Heredia, Juan Manuel ; Pérez, Pablo M. ; Villasenin, Hernán`, `Filósofo da Selva`, `Coletivo`, `Anônimo`.

**Les options.**

- **A — Déprécier maintenant.** Reprise des 226 (parser « Nom, Prénom ; … » → créer et lier les autorités), puis le formulaire cesse d'écrire le champ. Coût : la reprise n'est **pas** automatisable proprement — 121 chaînes portent plusieurs personnes, et l'import a déjà fabriqué trois fiches doubles de cette façon (`CONV-O8`). Une soirée à la main, minimum.
- **B — Conserver comme forme transcrite.** Le champ devient ce que dit la page de titre (au sens de `P3` des périodiques) ; l'autorité liée est la vérité ; le rendu affiche l'autorité si elle existe, la transcription sinon. `DOC-CONV-1` se lit alors « une vérité, une transcription, plusieurs rendus ». Les 226 deviennent un lot de la file (`autor_sans_autorite`) à traiter à la main dans l'Atelier autorités, sans échéance.
- **C — Différer à l'Atelier autorités** (statu quo : la question reste ouverte au REGISTRE).

**Recommandation : B.** Elle ferme la question sans rendre 226 livres anonymes, elle est cohérente avec ce que les périodiques ont déjà tranché (`P3`), et elle transforme la dette en lot de file — la forme que ce dépôt sait traiter. Deux gestes de code : le formulaire ne pré-remplit plus l'autorité depuis `autor` (il pré-remplit la transcription), et un rendu unique « autorité sinon transcription » remplace les choix écran par écran. `CONV-O3` passe à ✅.

---

## C9 — Les huit questions ouvertes des conventions catalographiques

**Ce qu'on sait (03/09).** `authors` : 1 305 fiches — 45 `person`, 19 `collective`, **1 241 non typées** ; `name_lang` renseigné sur 22. File de vérification : lot `autorite_collectivite` **14 validés et appliqués, 2 à revoir** ; lots `titre_casse` 211, `autorite_casse` 61, `autorite_patronyme` 22. La scission d'autorité n'existe toujours pas (3 fiches doubles connues).

**Un verdict proposé par question.** Répondre `A` = les huit tels quels ; sinon lister les numéros à changer.

| # | Question | Verdict proposé |
|---|---|---|
| CONV-6 / O1 | `name_lang` distinct de `country` ? | **Oui, confirmé.** La colonne reste nullable ; la règle de coupe ne s'applique **que** si `name_lang` est renseigné, jamais devinée depuis `country`. 22 renseignés : on renseigne au fil de l'eau, pas en campagne. |
| O2 | Conventions des collectivités | **Adopter la proposition de la spec comme convention provisoire** (nom officiel, dans la langue de la collectivité, sans inversion), révisable à `D7`. Les 2 « à revoir » se posent à la main. |
| O3 | `books.autor` | = **C5**. |
| O4 | Bascule EDTF : critère | **Pas de bascule sans déclencheur externe.** Le critère est écrit : une source moissonnée ou un partenaire (FICEDL, VIAF) qui exige EDTF, ou un intervalle que « deux entiers + qualificatif » ne sait pas dire. Tant qu'aucun des deux n'arrive, `CONV-5` reste le modèle. Fermé. |
| O5 | Périmètre de l'écran de vérification | **Le périmètre, c'est la file** : tout ce qui passe par `catalog_review_queue` — autorités **et** titres d'œuvres. L'intitulé « corpus partagé d'autorités » est faux : renommer en « file de vérification du catalogue » (dix locales, une clé). |
| O6 | L'instantané `avant` peut mentir | **Garde stricte confirmée** (refuser d'appliquer si l'état a changé — déjà vécu le 21/08), plus un rafraîchissement de `avant` à l'affichage. Petit chantier S, à ranger dans C6. |
| O7 | Le type d'autorité existe, personne ne le lit | **`authors.authority_type` est la vérité** ; le SQL le lit désormais ; les 1 241 non typées s'affichent comme personnes **à l'écran seulement**, jamais réécrites en base. Le moissonnage FICEDL pose `collective` pour ce qu'il connaît (organisations). |
| O8 | La scission d'autorité n'existe pas | **Pas de fonction `split_author`.** Les trois fiches doubles se traitent à la main (créer, repointer, fusion inverse) à l'Atelier autorités. On construit l'outil à la **quatrième** occurrence, pas avant. |

**Recommandation : A** (les huit). Le seul qui coûte du code est O5/O6 (une clé, un rafraîchissement) ; le reste est de l'écriture au REGISTRE.

---

## D2 — Les cinq questions restées ouvertes sur les périodiques

**Ce qu'on sait (03/09).** 4 titres dans `serials`, `periodicidade` **jamais renseignée** (0 sur 4), `library_id` absent (le code a tranché), page `/periodico/<slug>` livrée. Le fonds Anarchief (une centaine de titres) n'est pas importé ; SOLIDAIRES (12 titres, 91 fascicules) est passé.

| # | Question | Verdict proposé |
|---|---|---|
| 1 | `periodicidade` libre ou fermée ? | **Libre, avec une liste de suggestions non contraignante** (`datalist` : mensuel, bimestriel, trimestriel, irrégulier…). On ferme la liste le jour où Anarchief en fait apparaître le besoin, pas avant. |
| 2 | Filiation n-n ou deux liens ? | **Deux liens simples** (prédécesseur / successeur) suffisent jusqu'au premier cas réel de fusion ou de scission de titres — Anarchief le fournira. |
| 3 | `serials.library_id` ? | **Non, confirmé par le code.** Un titre est une autorité du réseau ; ce qui varie par bibliothèque vit dans `serial_holdings`. Au premier conflit de description : une note par bibliothèque, pas un `library_id`. |
| 4 | Promotion automatique d'un titre proposé ? | **Non : un geste, pas un seuil.** Confirmé. |
| 5 | Page dédiée ou facette ? | **Page dédiée, confirmé par le code livré.** |

**Recommandation : A** (les cinq). Trois sont déjà tranchés par le code ; les deux autres attendent un cas réel et le disent.

---

## E11 — Les deux différés de l'OPAC : tags contributifs et flux RSS

**L'instruction, enfin.**

- **Tags posés par les lectrices (#OPAC5).** Un tag public **signé** dit qui a lu quoi et ce qu'iel en pense — c'est exactement la donnée que l'application refuse de laisser sortir (historique de lecture masqué, doctrine de vie privée). Un tag **anonyme** ne se modère pas et ouvre au spam. Entre les deux, « collectif modéré » est un chantier M (modération, RLS, dix locales) pour un besoin déjà couvert par l'autorité matière et le thésaurus FICEDL.
- **Flux RSS de recherche (#OPAC11).** L'URL du flux encode la requête en clair : un agrégateur tiers voit ce que la personne cherche, à chaque rafraîchissement, pendant des mois. Un flux authentifié résoudrait l'anonymat en devenant un identifiant permanent. Le besoin réel derrière — « être prévenu des nouveautés » — n'a pas besoin de la requête.

| Item | Options | Recommandation |
|---|---|---|
| #OPAC5 | **A** fermer · **B** livrer « tags collectifs anonymes modérés » (M) | **A — fermer**, motif écrit : lecture = donnée sensible ; besoin couvert par l'autorité matière. |
| #OPAC11 | **A** fermer · **B** requalifier en **flux des nouveautés par bibliothèque** (sans requête, sans compte, S) | **B — requalifier.** `OPAC-RSS1` passe de « différé » à « requalifié : nouveautés seulement ». |

**Recommandation : A pour les tags, B pour le flux** — répondre `E11 A` si tu prends les deux tels quels.

---

## I16 — supabase-js : un régime, pas un mélange

**Ce qu'on sait (03/09).** Relevé des imports dans `supabase/functions/` : **1** épinglé (`env.ts` → `2.112.4`), **16** en `esm.sh …supabase-js@2` flottant, **14** en `npm:@supabase/supabase-js@2` flottant. Le 01/09, l'épinglée avait soixante versions de retard et ignorait les clés `sb_` que les flottantes supportaient en silence.

**Les options.**

- **A — Tout épingler, en un seul endroit.** Un module `_shared/deps.ts` ré-exporte `createClient` d'une version précise ; les trente fonctions importent de là ; **la montée de version est un rituel daté** — rangé avec le recompte mensuel de `CLAUDE.md` déjà en place, et un test de banc (`gazette`, `harvest`) qui casse si l'import n'est pas celui de `deps.ts`. Déploiements reproductibles ; le retard ne peut plus être silencieux parce qu'il est **un seul nombre à lire**.
- **B — Tout flotter en `@2`.** Toujours à jour dans la mineure ; une rupture de comportement dans une mineure (il y en a eu) arrive en production au prochain déploiement, sans commit qui la porte — donc sans diff où la chercher.

**Recommandation : A.** Ce dépôt a déjà payé le prix d'un état que personne ne lit (`DOC-RECENS-1`, trois fois cette semaine) ; un nombre unique dans un fichier unique est le contraire de cela. Coût : une heure (le module, trente lignes d'import, une règle dans `CONTRIBUTING.md`).

---

## La lettre

```
C5  → A / B / C          (recommandé B)
C9  → A ou « A sauf O5, O8… »   (recommandé A)
D2  → A ou « A sauf 1, 2… »     (recommandé A)
E11 → A ou « tags A, flux A »   (recommandé A = tags fermés, flux requalifié)
I16 → A / B              (recommandé A)
```

Dès la réponse : les verdicts entrent au REGISTRE (§37 `CONV-*`, `OPAC-RSS1`, spec périodiques §13, `CONTRIBUTING.md`), les cinq fiches passent de « décision » à « ouvert » avec leur chantier réduit — ou se ferment.
