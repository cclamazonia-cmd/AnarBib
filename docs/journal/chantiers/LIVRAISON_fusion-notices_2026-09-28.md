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
Estados Unidos* (Élisée Reclus) existe deux fois à la BTL, 000880 (2011) et 000881
(2010), même édition, une année fautive. Trois choses se révèlent.

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

## Ce qui reste

Rien d'ouvert côté outil. Les rééditions réelles sont des éditions de la même œuvre
(« Regrouper ») ; la règle des années ne se rouvre que par une décision au registre.
