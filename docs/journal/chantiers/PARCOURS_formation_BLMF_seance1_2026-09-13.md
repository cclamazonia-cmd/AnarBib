# Séance 1 de la formation BLMF — parcours du 13/09/2026

> Préparé le 03/09 (bloc 4 de la matinée, K7 · E12 f[3] · E1 · GOUV-18). Tout ce
> qui est écrit ici a été **vérifié en production le 03/09** : comptes, bac à
> sable, pages. Ce que je n'ai pas pu vérifier est marqué ⚠️.
>
> ⚠️ **Les trois documents de référence de K7 — `PLAN_formation_coordination_BLMF_2026-08-26`,
> `GABARITO_exercicio2_formacao_BLMF_2026-08-26`, et le jeu de 89 diapositives —
> ne sont ni dans le dépôt, ni sur ce poste, ni dans les transcripts.** Ce parcours
> est donc reconstruit depuis la fiche K7 (six modules, trois rencontres, six
> exercices) et depuis l'application telle qu'elle est. À ranger dans
> `docs/journal/chantiers/` dès que Xavier les retrouve, sinon ils resteront des
> fantômes (forme `DOC-RECENS-1`).
>
> ⚠️ **Collision de calendrier** : le backlog date la formation du 13/09 **et**
> place Bologne (FICEDL) les 11-13/09, avec l'atelier AnarBib le 12 au matin et
> l'assemblée le 13 (K5). Si la séance est à distance depuis Bologne, prévoir la
> visio et un relais sur place à Belém ; sinon, la dater.

---

## 1. Les personnes et les comptes (vérifié le 03/09)

| Personne | Rôle réel | Bac à sable `blmf-teste` | Dernière connexion |
|---|---|---|---|
| **Mariana S.** | coordination BLMF (active) | coordination (active) | 30/08/2026 |
| **Rafael G.** | coordination BLMF (active) | coordination (active) | **24/06/2026** — deux mois sans connexion : vérifier au début de séance qu'il entre encore (réinitialisation de mot de passe au besoin) |
| Xavier | coordination BLMF + admin réseau | coordination | 03/09 |
| Karina G., Carlos B. | — | coordinations du bac à sable (anciens essais) | 01/09, 01/08 |

**Regard extérieur d'E12 (page Importations) et témoin d'E1 : Mariana S.** — c'est
la coordination active ; Rafael G. fera le second passage s'il est là. Proposition,
pas décision.

### Ce qui est prêt sur `blmf-teste`

- Les **cinq fiches fautives** de l'exercice 2, créées le 26/08 (tombos `TESTE-9001-1` à `TESTE-9005-1`) : *O Cinema E A Anarquia No Brasil* (« FILHO, Fábio Luz »), *Moral Anarquista, A* (« DE OLIVEIRA BRINGEL, Fabiano »), *REGENERACIÓN E A REVOLUÇÃO MEXICANA* (« MAGÓN, Ricardo Flores »), *A revolução russa na Ucrânia* (Makhno), *EducaÇao libertária e concepçao de mundo* (« Reclus, Élisée »). Cinq défauts à trouver : casse du titre, article rejeté, forme du nom, capitale parasite, auteur douteux.
- **Les règles de circulation et les horaires** — copiés de la BLMF réelle le 03/09 (un jeu, six règles, horaires 9h-18h, fuseau `America/Belem`, prêts et réservations ouverts). Sans cela aucune réservation n'était possible sur le bac à sable.
- `is_test_mode = true` : les courriels partent avec le bandeau « contexte de test ».

### Ce qui reste à ta main avant la séance

1. **Deux lecteur·rices fictif·ves** sur `blmf-teste` — il n'y en a aucun (le seul a été retiré le 02/09 avec les fixtures des captures). `blmf-teste` n'accepte pas l'inscription publique : inviter deux adresses depuis le tableau de bord Supabase (Authentication → Users → *Invite user*), puis me dire leurs prénoms pour que je rattache les adhésions. Sans eux, pas de réservation à valider en séance.
2. **Vérifier l'entrée de Rafael G.** (voir tableau).
3. **Décider la date et le format** (collision Bologne).
4. Retrouver le plan et le gabarit de l'exercice 2, et les déposer dans `docs/journal/chantiers/`.

---

## 2. Le parcours de la séance (environ 3 h)

Chaque étape : la page telle qu'elles la voient (libellé pt-BR de la barre), le compte, le geste, et **ce qu'on regarde**. Le fil rouge : *une notice entre, un livre sort, un livre revient* — la vie réelle de la bibliothèque, pas les fonctionnalités.

| # | Durée | Page | Compte | Geste | Ce qu'on regarde |
|---|---|---|---|---|---|
| 0 | 15′ | — | — | **Ouverture.** Dire ce qu'est la séance, et lire à voix haute la décision `GOUV-18` (le SIGB refuse d'exécuter un changement de rôle sur une seule main ; décision prise seul le 02/09, **fenêtre d'objection ouverte ici**). | Une objection ? Elle entre au REGISTRE. Aucune ? Le collectif a existé une minute, et ça suffit. |
| 1 | 15′ | **Minha conta** (`/conta`) | chacune, sur `blmf-teste` | Se connecter, choisir la bibliothèque courante (« Biblioteca corrente » : BLMF / Teste), lire ses badges. | Le bloc « Meu pedido » n'apparaît pas (aucune demande) : c'est normal. Le sélecteur de bibliothèque est compris ? |
| 2 | 15′ | **Catálogo** (`/catalogo/blmf-teste`) → une notice (`/livro/…`) | sans compte, puis avec | Chercher « Makhno », ouvrir la notice, repérer l'exemplaire `TESTE-9004-1`. | La différence public / connecté ; la casse fautive de « REGENERACIÓN » vue **depuis l'extérieur**. |
| 3 | 45′ | **Catalogação** (`/catalogacao`) | chacune | **Exercice 2** : corriger les cinq fiches — titre, forme du nom (autorité), article rejeté. Puis **une fiche neuve de A à Z**, brouillon → publication → un exemplaire, **avec son mode d'acquisition** (l'engagement K7 : plus une fiche sans provenance). | Où elles cherchent l'autorité ; si le pop-up « œuvre ou nouvelle édition » est compris ; si le champ d'acquisition est trouvé sans aide. |
| 4 | 30′ | **Painel** (`/painel`, onglets *reservas*, *emprestimos*, *leitor*, *acoes*) | coordination + un·e lecteur·rice fictif·ve sur un second écran | Le·la lecteur·rice réserve la fiche neuve ; la coordination voit la réservation, la valide, enregistre le prêt, puis le retour. | Le fil complet en dix minutes ; où le regard se perd entre les onglets. |
| 5 | 20′ | **Painel** → *consultas locais* | coordination + lecteur·rice | **Une consultation sur place menée de bout en bout, avec négociation réelle** (K7) : la personne demande un créneau, la coordination en propose un autre, accord, clôture. | Les horaires du bac à sable (copiés de la BLMF) rendent le créneau crédible. |
| 6 | 15′ | **Biblioteca** (`/biblioteca`) | coordination | Lire l'identité, les horaires, l'équipe. Si trois personnes sont présentes (Xavier + les deux), **proposer un changement de rôle et le ratifier** : c'est `GOUV-18` en actes. | Que « ratifier » est compris comme *attester qu'une décision collective existe*, pas comme voter. |
| 7 | 15′ | **Importações** → onglet **Exportação** (`/importacoes`) | **Mariana S., seule, sans aide** | **Regard extérieur E12.** Deux consignes écrites sur un papier : *(a)* « exporte le catalogue de la bibliothèque en CSV » ; *(b)* « explique-moi avec tes mots ce que veut dire « Ser fonte » et qui décide ». Chronomètre, silence. | On note chaque hésitation et chaque mot qu'elle ne comprend pas — c'est le matériau d'E12, pas une évaluation d'elle. |
| 8 | 10′ | **Catálogo** → notice → réservation | Rafael G. ou Mariana, **clavier seul** (souris retournée) | **Témoin E1, version légère** : chercher, ouvrir, réserver, sans souris. | Où le focus se perd. Ce n'est **pas** un audit d'accessibilité — E1 reste ouvert ; on continue de dire « implémenté, pas audité ». |
| 9 | 15′ | — | — | **Clôture.** Instituer le rituel hebdomadaire de trente minutes et ses trois questions fixes ; fixer le jour de comptoir ; ouvrir la **feuille de lacunes** (tout ce qu'on a noté aux étapes 3, 4, 7, 8) ; dater la séance 2. | La feuille de lacunes est l'ordre du jour suivant **et** un matériau pour le projet (K7). |

Ce qu'on ne fait **pas** le 13 : le Réseau (`/rede`, réservé aux admins), la Fédération, l'import de fichiers, le thésaurus. Trois heures, une bibliothèque, un livre qui sort et qui revient.

---

## 3. Les trois questions fixes du rituel hebdomadaire

1. Combien de fiches cette semaine, et toutes ont-elles leur provenance ?
2. Qu'est-ce qui a bloqué, et où (la page, le mot) ?
3. Qu'est-ce qu'on ne sait pas faire ?

Les réponses vont dans la feuille de lacunes. Après huit semaines, K7 se ferme sur cette feuille, pas sur un sentiment.

---

## 4. Ce que la séance rapporte au dépôt

- **E12 f[3]** : le compte rendu de l'étape 7 — hésitations et mots incompris — entre dans la fiche ; c'est le seul lot d'E12 qui reste.
- **E1** : l'étape 8 donne une première liste de blocages clavier, sans prétendre à l'audit.
- **GOUV-18** : la fenêtre d'objection est fermée à la fin de l'étape 0, dans un sens ou dans l'autre — à consigner au REGISTRE.
- **K7** : la préparation du bac à sable est faite (règles, horaires, fiches) ; la suite est le suivi de huit semaines.
- **G10** (transfert de mandat) : si l'étape 6 a lieu, c'est un premier chemin éprouvé sur `blmf-teste`.

---

## 5. Bologne, en parallèle (K5, pour mémoire)

La fiche K5 tient sa propre liste : demander le créneau à l'assemblée du 13, chronométrer la version italienne à voix haute, imprimer le dossier, répéter la démonstration **hors ligne**. Sur l'accessibilité, dire les deux : implémenté, pas audité — et l'étape 8 ci-dessus ne change pas cette phrase.
