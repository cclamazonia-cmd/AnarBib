# Arbitrer une revue comme on arbitre un livre

**Décision du 1ᵉʳ septembre 2026.** Constatée au paquet 5 de l'audit `B14`,
posée au collectif plutôt que corrigée seule, tranchée le jour même.

---

## Le constat

Le chantier DOUBLONS P4 avait tranché : **l'arbitrage destructeur revient à la
coordination.** `merge_book`, `mark_books_not_duplicate` et
`unmark_books_not_duplicate` appellent donc `fn_is_dedup_arbiter()` —
administration du réseau **ou** coordenador·es.

Les périodiques, livrés le 27/08/2026, n'ont pas repris cette décision. Leurs
trois fonctions d'arbitrage appellent `fn_caller_is_staff()`, qui répond « oui »
à tout rôle `librarian`, **dans n'importe quelle bibliothèque du réseau**.

| Geste | Livres | Revues (avant) |
|---|---|---|
| fusionner deux autorités | coordination | tout `librarian` |
| marquer « pas un doublon » | coordination | tout `librarian` |
| défaire ce marquage | coordination | tout `librarian` |

Ce n'est **pas une fuite** : les personnes concernées sont des membres du staff
du réseau, pas des inconnues. C'est un **écart de doctrine** — le même geste,
deux niveaux de droit, sans que personne l'ait décidé.

> **Ce que cet écart enseigne, et qui dépasse les périodiques.** Une décision
> prise dans un chantier ne se propage pas toute seule au chantier suivant. Elle
> a été écrite dans un document d'arbitrage, appliquée à trois fonctions, gardée
> par une suite de tests — et trois mois plus tard, un nouveau domaine du même
> modèle (une autorité, ses doublons, sa fusion) est né sans elle. Aucune
> relecture ne l'aurait attrapée : le code des périodiques est cohérent avec
> lui-même. Seule une question posée à l'ensemble — *qui peut détruire quoi ?* —
> pouvait faire apparaître la divergence.

## Ce qui est en jeu, mesuré

- **4 personnes** sont `librarian` sans être coordenador·es — trois dans une
  bibliothèque, une dans une autre, toutes lusophones (`preferred_language` =
  `pt-BR`), d'où un préavis rédigé dans cette langue.

> **Les noms ne sont pas ici, et c'est délibéré.** Ce dépôt est public, et son
> miroir aussi. Écrire « telle personne est bibliothécaire à telle bibliothèque
> anarchiste » dans un document versionné, c'est publier un rattachement
> militant que rien n'oblige à publier — la requête qui donne la liste tient en
> quatre lignes et se rejoue quand on en a besoin. Le nombre suffit à la
> décision ; l'identité ne sert qu'à l'envoi, et l'envoi ne passe pas par le
> dépôt.
- **4 périodiques** en base, **7 numéros rattachés**. L'enjeu pratique est petit
  aujourd'hui — et c'est exactement ce qui rend le moment favorable : décider
  quand rien n'est en jeu coûte moins cher que décider après une fusion
  contestée.

## La décision

**On aligne, en prévenant.** Les trois fonctions d'arbitrage passent à
`fn_is_dedup_arbiter()`, et leur refus reprend mot pour mot le libellé déjà
employé par `merge_book` : « Arbitragem reservada à coordenação. »

**Ce qui ne bouge pas, et c'est la moitié de la décision** : cataloguer une revue
reste le travail du catalogage (`fn_serial_create`, `fn_serial_update`,
`fn_serial_attach_issue`, `fn_serial_detach_issue`, `fn_serial_set_filiation`),
et **le signalement d'un doublon reste ouvert** (`suggest_serial_duplicates`,
`list_serials_not_duplicate`) — exactement comme DOUBLONS P8 l'a voulu pour les
autorités. Repérer un doublon et trancher un doublon sont deux actes différents ;
fermer le premier priverait la coordination de ce qui la fait travailler.

## La condition : prévenir d'abord

Cette migration **retire un pouvoir à quatre personnes nommées**. Le dépôt a déjà
posé la règle à propos des identifiants de lecteur·rice : *changer quelque chose
qui appartient à quelqu'un sans le lui annoncer n'a pas sa place dans un
déploiement automatique.* Elle vaut ici.

**La migration `20260901110559` ne doit pas être poussée avant l'envoi du
préavis ci-dessous.**

---

## Préavis — pt-BR (version à envoyer)

> **Assunto : uma mudança pequena no arbítrio de duplicatas de periódicos**
>
> Companheir·es,
>
> Uma revisão de segurança feita hoje mostrou uma diferença que ninguém decidiu:
> nas fichas de **livros**, fundir duas autoridades ou marcar « não é duplicata »
> é reservado à **coordenação** — foi uma decisão coletiva tomada quando
> construímos o desduplicador. Nas fichas de **periódicos**, entregues no fim de
> agosto, esses mesmos gestos ficaram abertos a qualquer bibliotecári·e da rede.
> Não foi uma escolha: a decisão simplesmente não foi retomada no canteiro
> seguinte.
>
> Vamos alinhar os dois: a partir do próximo deploy, **fundir e arbitrar
> duplicatas de periódicos passa a exigir a coordenação**, como já acontece com
> os livros.
>
> **O que muda para você:** se você tentar fundir duas revistas ou marcar um par
> como « não é duplicata », vai receber uma recusa — « Arbitragem reservada à
> coordenação » — e o gesto não será feito.
>
> **O que NÃO muda:** catalogar periódicos continua igual. Criar uma revista,
> editar a ficha, anexar ou desanexar números, declarar a filiação entre títulos:
> tudo isso continua sendo trabalho do catalogação, sem nenhuma restrição nova.
> **Sinalizar** uma duplicata também continua aberto — é a coordenação que
> decide, mas é você que encontra.
>
> Se esse limite atrapalhar o trabalho de alguém, diga: a decisão é nossa e pode
> ser revista. O que não queríamos era manter duas regras diferentes para o mesmo
> gesto sem ninguém saber.
>
> Um abraço.

## Préavis — fr (pour mémoire, non envoyé)

> Compagn·es,
>
> Une revue de sécurité faite aujourd'hui a montré une différence que personne
> n'avait décidée : sur les **livres**, fusionner deux autorités ou marquer « pas
> un doublon » est réservé à la **coordination** — c'est une décision collective
> prise en construisant le dédoublonneur. Sur les **périodiques**, livrés fin
> août, ces mêmes gestes sont restés ouverts à toute personne bibliothécaire du
> réseau. Ce n'était pas un choix : la décision n'a simplement pas été reprise
> dans le chantier suivant.
>
> Nous alignons les deux : au prochain déploiement, **fusionner et arbitrer les
> doublons de périodiques demandera la coordination**, comme pour les livres.
>
> **Ce qui change pour vous** : une tentative de fusion ou de marquage rendra un
> refus — « Arbitragem reservada à coordenação » — et le geste ne sera pas fait.
>
> **Ce qui ne change pas** : cataloguer les périodiques reste identique. Créer
> une revue, modifier sa fiche, rattacher ou détacher des numéros, déclarer la
> filiation entre titres : tout cela reste le travail du catalogage, sans aucune
> restriction nouvelle. **Signaler** un doublon reste ouvert aussi — c'est la
> coordination qui tranche, mais c'est vous qui trouvez.
>
> Si cette limite gêne le travail de quelqu'un·e, dites-le : la décision est la
> nôtre et elle peut être revue. Ce que nous ne voulions pas, c'est garder deux
> règles différentes pour le même geste sans que personne le sache.

---

## Épreuve

Faite en production, en transaction annulée, avec un couple d'identifiants
identiques — le contrôle métier refuse ce couple de toute façon, donc **rien ne
pouvait être détruit**, et le message dit lequel des deux contrôles a parlé :

| Sous le JWT de… | Message rendu | Lecture |
|---|---|---|
| une bibliothécaire sans coordination | « Arbitragem reservada à coordenação. » | refusée **à la garde** |
| une coordination | « Par de periódicos inválido. » | garde **franchie**, contrôle métier atteint |

`DOC-MSG-1` respecté : `grep -rn "SQLERRM" tests/sql/` ne rend aucune assertion
sur les trois libellés remplacés.

## Suivi

- Migration : `supabase/migrations/20260901110559_arbitrer_une_revue_comme_on_arbitre_un_livre.sql`
  — **écrite, éprouvée, non poussée** en attente du préavis.
- Suite de garde : `tests/sql/arbitrage_periodiques_tests.sql`. Son `T3` tient
  l'autre moitié de la décision (le catalogage reste ouvert), et son `T4` garde
  que les deux familles refusent dans les mêmes termes — deux refus qui disent
  la même chose de deux façons finissent par diverger.
- Audit d'origine : `docs/journal/audits/AUDIT_execute_authenticated_2026-09-01.md`,
  paquet 5 du lot `public`.
