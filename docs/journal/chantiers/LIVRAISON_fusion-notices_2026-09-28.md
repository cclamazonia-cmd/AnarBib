# Livraison — la fusion de notices ne perd plus rien, et la référence d'un exemplaire suit son fonds

**Date** : 2026-09-28
**Auteur** : Xavier (session avec Claude)
**Session** : Couvertures → doublon non détecté (BTL-TL-000880/881) → outil de fusion
**Commits** : `911ad1db` (27/09 : suggestion d'éditions réparée, paire BTL fusionnée par
migration) ; `11da0df8` (fusion complète, invariant, 43 exemplaires, formulaire) ;
`40cb978f` (« Même édition : fusionner dans cette notice »)
**Migrations** : `20260927194141_fusion_btl_tl_000880_dans_000881_et_suggestion_d_editions`,
`20260928100501_la_fusion_de_notices_ne_perd_plus_rien`
**Suites CI** : `tests/sql/editions_suggerees_tests.sql` (4), `tests/sql/fusion_notices_complete_tests.sql` (15)
**Registre** : `DEDUP-11`, `DEDUP-12`, `DEDUP-13` (§40)

## Pourquoi

Le 27/09 au soir, Xavier ne parvient pas à retirer un doublon : *Da Escravidão nos
Estados Unidos* (Élisée Reclus) existe deux fois à la BTL, 000880 (2ª edição, 2011)
et 000881 (1ª edição, 2010) — deux éditions successives du même éditeur, que la
coordination choisit de réunir sous une notice, l'édition notée sur chaque
exemplaire. Trois choses se révèlent.

1. **La suggestion d'éditions n'a jamais répondu.** `suggest_editions_for_book`
   plantait à chaque appel depuis sa création le 20/06 (« column reference book_id is
   ambiguous », 42702) : aucun test ne l'appelait. Un chemin jamais exécuté n'est pas
   un chemin qui marche.
2. **La détection écarte la paire par construction** : deux notices de la même œuvre
   dont un champ d'édition diffère (`fn_editions_distinctes` : ISBN, année, éditeur,
   mention) ne sont jamais proposées comme doublon — et l'écran n'offrait aucun chemin
   pour une paire non détectée.
3. **`merge_book` perdait.** Sujets et contributeur·rices du doublon partaient en
   cascade ; ses brouillons ouverts étaient rattachés à la survivante (publiés, ils
   l'écrasaient) ; partages numériques, pistes audio, titres d'œuvre et lignes d'import
   restaient orphelins ; `merge_log` ne gardait que le titre. Lancée du formulaire, la
   fusion était défaite au clic suivant : le brouillon ouvert — celui qu'on édite —
   réécrit chaque champ, les sujets et les contributeur·rices à la publication. Et la
   référence d'un exemplaire (`exemplares.bib_ref`) ne suivait ni son fonds ni sa
   notice : sur 2 760 exemplaires, 43 portaient une référence qui ne désignait plus
   rien (BTL 25, MLEG 16, BLMF 2) — les 32 autres des « 75 » annoncés portaient la
   référence locale de leur fonds, à bon droit.

## Ce qui est livré

### La paire BTL et la suggestion réparée (`911ad1db`, 27/09)

000880 fusionnée dans 000881 par migration, sans rien perdre (année 2010 et ISBN
gardés, couverture et sujet repris, trois exemplaires sous la survivante, brouillon
ouvert écarté, instantané complet dans `merge_log` 149). `suggest_editions_for_book`
réparée et testée.

### La fusion complète (`11da0df8`)

- **Un invariant, trois déclencheurs** : `exemplares.bib_ref = coalesce(référence
  locale du fonds, référence de la notice)` — la règle de
  `resolve_library_holding_bridge`, clé du rattachement d'un exemplaire neuf et de la
  conversion réservation → prêt. Exemplaire créé ou déplacé, fonds modifié, notice
  renommée : la référence suit, lignes de circulation comprises. Une référence écrite
  à la main hors de la règle est ramenée.
- **`fn_fusion_notices`**, une fonction pour deux appelants : `merge_book` reprend en
  plus les champs vides de la survivante (ce bouton n'a pas d'aperçu) ;
  `merge_book_with_fields` ne reprend que les champs cochés. Doublon entier dans
  `merge_log.details` ; sujets et contributeur·rices manquants repris sur la notice et
  sur ses brouillons ouverts ; brouillons ouverts du doublon écartés ; fonds de même
  bibliothèque fusionnés (référence locale et notes reportées) ; exemplaires, lignes de
  circulation, exemplaires à créer, partages, pistes, titres d'œuvre, lignes d'import,
  proposition de couverture et contexte de catalogage rattachés. Signatures, droits et
  messages de refus inchangés.
- **Les 43 exemplaires** reprennent la référence de leur fonds ; aucune ligne de
  circulation active n'en dépendait.
- **Formulaire** : la fusion refuse de partir d'un brouillon non enregistré
  (`catalogacao.dedup.saveBeforeMerge`, dix locales) et recharge le brouillon après —
  sujets compris (`SubjectAuthorityPicker` reçoit `reloadKey`).

Vérifié au banc : suite 15/15, trois mutations rouges (reprise des champs vides,
déclencheur de l'exemplaire, écartement des brouillons), doublons P4/P6/P7, arbitrage
des périodiques, gardes de droits, import des exemplaires, brouillons par
bibliothèque ; vitest 1356/1356. Vérifié en production le 28/09 à 10:49 UTC :
migration appliquée par la CI, déclencheurs présents, 0 exemplaire décalé.

### « Même édition : fusionner dans cette notice » (arbitrage Xavier, 28/09)

La détection garde sa règle stricte (`DEDUP-13`). La faute de saisie a son chemin :
dans la liste des éditions suggérées du formulaire, la coordination trouve « Même
édition : fusionner dans cette notice » — l'aperçu de l'assistant (`ApercuFusion`,
temps 3 : pertes sèches cochées d'office, divergences, exemplaires, confirmation par
la référence de la fiche supprimée), la survivante étant la notice éditée ; puis
`merge_book_with_fields` et le rechargement du brouillon.

### Correction sur BTL-TL-000881 (28/09, migrations `20260928111729` et `20260928114148`)

La notice réunit deux éditions successives du même éditeur, par décision de la
coordination : elle garde la première (2010), et chaque exemplaire BTL porte son
édition en note interne, en portugais — BTL-TL-EX-000881 « 1ª edição, 2010 »,
BTL-TL-EX-000880 « 2ª edição, 2011 » (venu de la notice BTL-TL-000880). Le
troisième exemplaire, CCLA.2026.93 (BLMF), avait été créé le 27/09 à 19:18 UTC
depuis un poste BLMF pendant que le doublon résistait à l'écran : la BLMF ne
détient pas ce titre ; l'exemplaire et son fonds vide sont retirés, le brouillon
d'exemplaire 39 est écarté avec la raison. Les deux brouillons de reprise ouverts
par la vérification à l'écran de l'action « Même édition » (6276, 6277) sont
écartés, sans modification.

Vérifié à l'écran le 28/09 (session de Xavier) : sur BTL-TL-000181, « Suggérer des
éditions » répond « Aucune édition à regrouper. » — seule notice de ce titre, et son
autorité « Cristina Escrivá » (10551) était distincte de « Cristina Escrivá Moscardó »
(10059), sous laquelle sont ses quatre autres livres — réunies le 28/09 à 12:11 UTC
par l'écran du catalogue publié (`merge_log` 150, cinq livres sous 10059) ; sur BTL-TL-000881, la
suggestion *Estados Unidos do Brasil (1900)* porte bien « Regrouper » et « Même
édition : fusionner dans cette notice ».

### Découvert en chemin : la reprise effaçait les sujets (`20260928133838`, `THES-5`)

En ajoutant la mention d'édition à BTL-TL-000881 par « Éditer → Publier », la notice
a perdu son sujet. Cause générale : le brouillon de reprise ne reprenait pas les
sujets de la notice (`create_book_draft_from_book` ne touche pas
`book_draft_subjects`), et la publication remplace les sujets de la notice par ceux
du brouillon — vides. **136 brouillons de reprise publiés sans sujet depuis juin ;
20 notices sans sujet aujourd'hui.** Correctif : semis des sujets à la création du
brouillon (`trg_seed_draft_subjects`), garde à la publication (un brouillon sans
aucun sujet n'efface rien), brouillons ouverts semés, sept notices réindexées
(BTL-TL-000103, 000181, 000491, MLEG-0145/0146/0147 d'après la liste C7 ;
BTL-TL-000881 : anarquismo). Les treize autres n'avaient reçu de sujet par aucun
chemin tracé : la sauvegarde #BG2 a tranché (flux long, `restic dump --no-lock`
d'un instantané par notice — celui qui précède sa première publication sans sujet —,
bloc `COPY public.book_subjects`). **Six en avaient**, tous posés le 8 juin :
BTL-TL-000029 (feminismo), BTL-TL-000447/000448/000449 (revolucao-espanhola),
BTL-TL-001992 et 002335 (anarquismo) — restaurés par `20260928155533`. **Sept n'en
ont dans aucun instantané** depuis le 30/06 (BTL-TL-000252, 000260, 000357,
001242, 001635 ; BLMF 0000261, 0000264) : rien à restaurer.

### Découvert en chemin, bis : l'ISBN comparé chiffre à chiffre (`20260928163920`, `DEDUP-14`)

BTL-TL-000504 et BTL-TL-000727 (*Anarquistas*, Suriano, Manantial, 2001), même édition
de la même œuvre, n'étaient jamais proposées comme doublon : `987-500-069-8` (ISBN-10)
et `978-987-500-069-8` (ISBN-13) passaient pour deux ISBN, donc deux éditions ; et
« Manantial » / « Ediciones Manantial » pour deux éditeurs (similarité 0,5). Quatre
paires masquées ainsi (000504~000727 ; 000301~BLMF 0000054 ; 001525~BLMF 0000258 ;
001808~BLMF 0000060). Correctif : `fn_isbn_coeur` (douze chiffres sans clé), deux ISBN
présents décident seuls, éditeurs comparés sans mots génériques (`fn_meme_editeur`),
trois détecteurs alignés ; suite `editions_distinctes_tests` (8) — il n'y en avait
aucune.

## Ce qui reste

Rien d'ouvert côté outil de fusion. Les rééditions réelles sont des éditions de la
même œuvre (« Regrouper ») ; la règle des années ne se rouvre que par une décision
au registre. Côté sujets : les sept notices sans sujet dans aucune sauvegarde ont
été arbitrées le 28/09 au soir, dans le vocabulaire existant — six indexées
(BTL-TL-000252 et 000260 → ficcao ; 000357 → marxismo, socialismo ; 001635 →
anarquismo ; BLMF 0000261 et 0000264 → ditadura), une laissée sans matière
(BTL-TL-001242, souvenirs d'école : aucune matière du thésaurus ne convient).
