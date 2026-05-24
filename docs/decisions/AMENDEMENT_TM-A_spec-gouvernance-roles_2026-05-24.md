# Amendement TM-A — `spec-gouvernance-roles.md` : notification de la coordination au seuil J-7

> Document préparatoire au **chantier B** du programme de correction post-audit
> #153. Décrit précisément l'amendement à porter dans `spec-gouvernance-roles.md`
> pour entériner la décision actée le 24/05/2026. **À conserver pour mémoire** :
> l'amendement n'est appliqué qu'au moment de l'exécution du chantier B, une fois
> le point corrigé / confirmé dans le code.

**Date de rédaction :** 24 mai 2026
**Chantier de rattachement :** B (internationalisation des mails internes), constat TM-A
**Décision source :** dossier-cadre post-audit #153, §2.0 (D-0) et fiche chantier B
**Spec cible :** `docs/specs/spec-gouvernance-roles.md`, version actuelle **v1.2**
(2026-05-20)
**Version cible après amendement :** **v1.3**

---

## 1. Rappel de la décision

L'audit #153 (constat TM-A) relève que `handleInactiveWarning` dans `team.ts`
envoie une copie au staff au seuil **7 jours** d'inactivité (`if (isShort)`,
l.735), alors que la spec gouvernance réserve la notification du seuil 7j à la
personne seule.

**Décision du 24/05/2026 :** on **n'aligne pas le code sur la spec** ; on
**amende la spec** pour entériner le comportement du code. Le réseau juge utile
que la coordination soit prévenue dès le seuil 7j (et non seulement à la sortie
automatique du 9e mois). Le comportement actuel de `team.ts` devient donc le
comportement *voulu*. TM-A cesse d'être un « écart à corriger » et devient une
**dette documentaire** : mettre la spec à jour.

**Précision d'arbitrage (24/05/2026) — cas du·de la dernier·e coordenador·a.**
Mettre « la coordination » en copie du J-7 pose un cas limite : si la personne
inactive *est* le·la dernier·e coordenador·a de la biblio, il n'y a pas de
coordination à mettre en copie. **Décision retenue : dans ce cas, le J-7
escalade aux administrateur·rices du réseau**, exactement comme le fait déjà la
sortie automatique du J-9 mois (§6.1) et le cas pathologique §6.4. Le
destinataire de l'escalade est la table `network_administrators`
`status='active'`. Une inactivité critique ne doit jamais passer inaperçue faute
de destinataire.

---

## 2. Constat préalable : la référence de l'audit est périmée

L'audit #153 situe le passage à corriger en **« §9, lignes 654-656 »**. Cette
référence ne correspond plus à la spec actuelle : l'audit a travaillé sur une
version antérieure, et la spec a connu deux refontes depuis
(v1.1 le 15/05, v1.2 le 20/05) qui ont décalé la numérotation des sections.

Dans la **v1.2 actuelle**, le passage cité est dans la **section §8.2** (« Pattern
d'event types »). Les numéros de ligne 654-656 tombent, eux, encore sur la bonne
table — coïncidence à ne pas confondre avec une référence de section valide.

**Conséquence pour l'amendement :** l'amendement vise des *sections nommées*
(§5.10, §8.2, Annexe Q7), pas des numéros de ligne, qui rebougeront.

---

## 3. Constat préalable : la règle est écrite à plusieurs endroits

L'audit ne pointe qu'un seul passage. En réalité, la règle « le seuil J-7 ne
notifie que la personne » est portée — explicitement ou implicitement — par
**quatre endroits** de la spec. Amender le seul §8.2 laisserait la spec en
contradiction interne, exactement le type de défaut que l'audit #153 reproche
par ailleurs au code. L'amendement doit être **cohérent sur les quatre
endroits**.

| # | Section | Nature du passage | Action |
|---|---|---|---|
| A | §5.10, étape 2 du workflow T9 | Description narrative : « mail de rappel » | **Modifier** — expliciter le nouveau destinataire |
| B | §8.2, table des event types | `inactive_warning_7d ... personne uniquement` | **Modifier** — c'est le passage cité par l'audit |
| C | §7, table de synthèse des events | event / transition / source — **pas de colonne destinataire** | **Inchangé** — vérifier seulement qu'aucun texte adjacent ne redit la règle |
| D | Annexe, table des décisions Q7 | « Sortie auto à 9 mois + mails J-30 et J-7 » | **Modifier** — tracer l'amendement (statut « ✏️ Amendée v1.3 ») |

---

## 4. Le diff d'amendement, section par section

> Notation : `-` lignes retirées, `+` lignes ajoutées. Les numéros de ligne sont
> indicatifs (état v1.2) et bougeront ; se repérer au contenu.

### 4.1 — §5.10, étape 2 du workflow de la transition T9

**Contexte.** §5.10 décrit le workflow de la sortie automatique. L'étape 2
décrit le mail J-7. Aujourd'hui elle ne mentionne pas de destinataire, mais le
contraste avec l'étape 3 (« mail final à la personne + à toute la coordination »)
implique que le J-7 ne va qu'à la personne.

```diff
 1. **J-9 mois - 30 jours** : mail d'avertissement à la personne (« votre membership va être désactivée dans 30 jours sans connexion »).
-2. **J-9 mois - 7 jours** : mail de rappel.
+2. **J-9 mois - 7 jours** : mail de rappel à la personne **et copie à la
+   coordination** (tous les `coordenador` actifs de la biblio). *(amendé v1.3)*
+   Si la personne inactive est elle-même le·la **dernier·e coordenador·a** de la
+   biblio — donc s'il n'existe aucun·e autre coordenador·a à mettre en copie —,
+   la copie est **escaladée aux administrateur·rices du réseau** (table
+   `network_administrators` `status='active'`), selon le même mécanisme que
+   l'escalade « dernier·e coordenador·a » de §6.1.
 3. **J-9 mois** : passage à `inactive` automatique. Mail final à la personne + à toute la coordination.
```

### 4.2 — §8.2, table des event types `team.*`

**Contexte.** C'est le passage explicitement cité par l'audit. La ligne
`team.inactive_warning_7d` indique « personne uniquement ».

```diff
 | `team.inactive_warning_30d` | T9 (J-30) | personne uniquement |
-| `team.inactive_warning_7d` | T9 (J-7) | personne uniquement |
+| `team.inactive_warning_7d` | T9 (J-7) | personne + coordenadores *(amendé v1.3)* |
 | `team.inactive_auto` | T9 (J-9 mois) | personne + coordenadores |
```

> **Note à porter sous la table** (au choix, en complément de la « Note v1.1 »
> existante) :
>
> > **Note v1.3** : le seuil J-7 (`inactive_warning_7d`) notifie désormais la
> > coordination en copie, et non plus la seule personne concernée — afin que la
> > coordination soit alertée d'une inactivité critique avant la sortie
> > automatique. Si la personne inactive est le·la dernier·e coordenador·a, la
> > copie est escaladée aux administrateur·rices du réseau (cf. §5.10 et §6.1).
> > Le seuil J-30 (`inactive_warning_30d`) reste, lui, adressé à la personne
> > uniquement : un mois avant l'échéance, l'information est encore strictement
> > individuelle.

### 4.3 — §7, table de synthèse des events

**Aucune modification.** La table §7 a pour colonnes *event / transition /
source*. Elle ne décrit pas les destinataires — la ligne
`inactive_warning_7d | T9 (mail J-7) | cron cron_team_inactive_cleanup` reste
exacte. Vérifier seulement, à la relecture, qu'aucune phrase du texte entourant
cette table ne redit la règle « personne uniquement » pour le J-7.

### 4.4 — Annexe, table des décisions politiques cadrées, ligne Q7

**Contexte.** L'Annexe acte les 14 décisions politiques. Q7 porte sur le compte
abandonné. La colonne de droite indique le statut de la décision face à la
refonte v1.1+ (« ✅ Conservée », etc.). C'est l'endroit naturel pour **tracer**
l'amendement.

```diff
-| Q7 (compte abandonné) | Sortie auto à 9 mois + mails J-30 et J-7 | ✅ Conservée |
+| Q7 (compte abandonné) | Sortie auto à 9 mois + mails J-30 et J-7 | ✏️ Amendée v1.3 — le mail J-7 notifie aussi la coordination (escalade réseau si dernier·e coord) ; le J-30 reste individuel |
```

### 4.5 — En-tête de la spec : bloc « Historique »

**Contexte.** La spec maintient un bloc « Historique » en tête (v1.0, v1.1,
v1.2). Tout amendement y ajoute son entrée.

```diff
 - **v1.2 (2026-05-20)** : doctrine « **rôle exclusif** » actée et implémentée [...]
+- **v1.3 (2026-05-24)** : amendement TM-A (issu de l'audit #153 des contenus de
+  mails). Le seuil d'inactivité J-7 (`team.inactive_warning_7d`) notifie
+  désormais la coordination en copie, et non plus la seule personne concernée ;
+  si la personne inactive est le·la dernier·e coordenador·a, la copie est
+  escaladée aux administrateur·rices du réseau (même mécanisme que §6.1). Cet
+  amendement entérine le comportement déjà en production dans `team.ts` plutôt
+  que de l'aligner sur l'ancienne règle. Sections amendées : §5.10, §8.2 ;
+  traçage Annexe Q7. Le seuil J-30 reste inchangé (personne uniquement).
```

Mettre également à jour la ligne **Version** de l'en-tête :

```diff
-**Version** : 1.2 — 2026-05-20 (doctrine « rôle exclusif » actée)
+**Version** : 1.3 — 2026-05-24 (notification coordination au seuil J-7)
```

---

## 5. Vérification de cohérence post-amendement

Avant de clore l'amendement, contrôler que les points suivants tiennent :

1. **§12.2 (cron `cron_team_inactive_cleanup`).** L'étape 2 du cron
   (« envoyer `team.inactive_warning_7d` ») ne nomme pas de destinataire — elle
   reste donc correcte sans modification. Mais c'est le **code du handler**, pas
   la spec, qui matérialise la liste des destinataires. Vérifier en chantier B
   que le handler `team.ts` produit bien : personne + coordenadores, avec
   escalade réseau si dernier·e coord. **C'est le cœur de la coordination
   spec ↔ code de TM-A** : la spec dit *quoi*, le handler fait *comment*.
2. **Le J-30 n'est pas touché.** L'amendement ne concerne que le J-7. Le J-30
   (`inactive_warning_30d`) reste « personne uniquement » partout. S'assurer
   qu'aucune modification ne déborde sur le J-30 par symétrie hâtive.
3. **Clés i18n.** La liste i18n indicative de §8.3 mentionne des clés `.intro` /
   `.sub` / `.coord_intro` par event. Si `inactive_warning_7d` ne disposait que
   d'une clé personne et pas de clé `.coord_intro`, l'ajout de la copie
   coordination crée un **besoin de clé i18n nouvelle** (`.coord_intro` pour
   `inactive_warning_7d`), à produire sur les 8 locales en langage inclusif.
   À inventorier dans le chantier B (sous-tâche TM-B). Idem, le cas « escalade
   réseau » peut réclamer une clé dédiée si le mail à l'admin réseau diffère du
   mail à la coordination.
4. **Cohérence avec la spec admin réseau.** L'escalade vers
   `network_administrators` est un mécanisme déjà décrit par la spec admin
   réseau v0.3.1 et utilisé en §6.1 / §6.4 de la présente spec. L'amendement
   ne crée pas de mécanisme neuf, il réutilise l'existant — aucune modification
   de la spec admin réseau n'est requise. Vérifier seulement que le constat
   #114 (events `network.*`) couvre, ou non, un event d'escalade J-7 ; sinon,
   c'est une micro-dette à signaler.

---

## 6. Ce que cet amendement implique pour le code (mémoire chantier B)

L'amendement de la spec **entérine** le code existant, il ne le pilote pas
entièrement. Au moment du chantier B, vérifier / faire côté `team.ts` :

- **Confirmé par l'audit :** la copie staff au J-7 existe déjà (`if (isShort)`,
  l.735). L'amendement la rend légitime — rien à ajouter sur ce point précis.
- **À vérifier :** le handler gère-t-il le cas « dernier·e coordenador·a » au
  J-7 ? L'audit ne le dit pas. Si le handler envoie la copie « aux
  coordenadores » sans traiter le cas où la liste est vide (personne = dernier·e
  coord), alors **le code ne fait pas encore ce que la spec v1.3 prescrit** :
  l'escalade réseau au J-7 serait une **correction de code à faire**, pas
  seulement une mise à jour de spec. À instruire en session sur le code réel.
- **i18n :** internationaliser le libellé de la copie staff au J-7 (aujourd'hui
  en dur — c'est l'objet de TM-B). Créer la ou les clés `.coord_intro` /
  escalade manquantes sur les 8 locales.
- **TM-D, dans la foulée :** la spec v1.2 nomme déjà correctement
  `team.inactive_auto` ; c'est le **code** qui traite `team.inactive_completed`.
  L'alignement TM-D va donc dans le sens *code → spec* (renommer dans `team.ts`),
  inverse de TM-A. Comme on rouvre `team.ts` et la zone d'inactivité de toute
  façon, traiter TM-D dans la même passe. Voir dossier-cadre, fiche chantier B.

---

## 7. Récapitulatif — points à appliquer

Au moment du chantier B, l'amendement de la spec se résume à :

1. Modifier §5.10 étape 2 (destinataire du J-7 + clause dernier·e coord).
2. Modifier la ligne `inactive_warning_7d` de la table §8.2 + ajouter la note
   v1.3 sous la table.
3. Modifier la ligne Q7 de l'Annexe (statut « ✏️ Amendée v1.3 »).
4. Ajouter l'entrée v1.3 au bloc « Historique » et mettre à jour la ligne
   « Version » de l'en-tête.
5. Relire §7 et §12.2 pour confirmer qu'aucun texte adjacent ne contredit le
   nouveau destinataire (aucune modification attendue, simple contrôle).
6. Commit dédié, mention dans `docs/decisions/`.

Côté code (chantier B, sous-tâches TM-B et TM-A) :

7. Vérifier sur le code réel si le handler `team.ts` gère le cas « dernier·e
   coord » au J-7 ; si non, ajouter l'escalade réseau (correction de code).
8. Internationaliser le libellé de la copie staff J-7 ; créer les clés
   i18n manquantes (8 locales, langage inclusif).
9. Traiter TM-D dans la même passe (renommer `inactive_completed` →
   `inactive_auto` côté code).

---

*Document préparatoire — amendement TM-A. À conserver pour l'exécution du
chantier B. Distribué sous licence CC-BY-SA-4.0.*
