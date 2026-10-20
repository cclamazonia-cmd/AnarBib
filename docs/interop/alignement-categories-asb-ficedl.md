# Les catégories d'AnarcosyndicalismeBOOK face au thésaurus FICEDL — proposition d'alignement

> **Brouillon du 20/10/2026 (backlog H6), à discuter avec le camarade (ASR2026) avant tout usage.**
> Rien n'est poussé chez lui, rien n'est écrit en base : c'est une table de travail. La collaboration
> se discute d'abord avec lui, jamais par une PR surprise (fiche H6).

## Pourquoi commencer par là

H6 veut aligner des vocabulaires militants qui ne se connaissent pas. Le plus petit pas faisable est
celui-ci : les catégories d'AnarcosyndicalismeBOOK (ASB) sont peu nombreuses, et le thésaurus FICEDL
qu'AnarBib porte est déjà dans les onze langues de l'application. Un alignement vaut donc pour toutes
les langues à la fois. Il servira à la moisson réciproque ASB ↔ AnarBib (H35) : une catégorie ASB
deviendra un ou plusieurs descripteurs FICEDL à l'import, et l'inverse à l'export.

## Les sources

- **ASB** : les catégories semées par `sql/database_numerique.sql` du dépôt
  `codeberg.org/Anarcosyndicalismebook/anarcosyndicalismebook` (lu le 20/10/2026 à `480f898`).
  Elles sont **douze**, et non onze comme le disait la fiche. Une instance peut en ajouter d'autres ;
  la liste réelle d'une instance se lit dans sa table `categorie`.
- **FICEDL** : la table `ficedl_thesaurus_terms` de la production d'AnarBib, lue le 20/10/2026
  (623 descripteurs ; facettes sujets, géographie, dates). Les identifiants `motN` sont ceux du
  site de la FICEDL.

## La table

Relations au sens de SKOS : **exacte** (`exactMatch`), **proche** (`closeMatch`), **plus large côté
FICEDL** (`broadMatch` : le terme FICEDL englobe la catégorie), **associée** (`relatedMatch`).

| Catégorie ASB (slug) | Description ASB | FICEDL proposé | Relation | Remarque |
|---|---|---|---|---|
| Anarchisme (`anarchisme`) | Textes fondamentaux de la pensée anarchiste | `mot8` anarchisme | exacte | — |
| Anarcho-syndicalisme (`anarcho-syndicalisme`) | L'anarcho-syndicalisme et l'action directe | `mot272` syndicalisme : anarchosyndicalisme | exacte | associée : `mot286` syndicalisme : syndicalisme révolutionnaire |
| Histoire ouvrière (`histoire-ouvriere`) | Histoire du mouvement ouvrier et des luttes sociales | `mot202` mouvement ouvrier | proche | associées : `mot203` luttes sociales (mouvement social), `mot190` luttes ouvrières. FICEDL date l'histoire par pays (facette géographique) : la période ne se déduit pas de la catégorie |
| Autogestion (`autogestion`) | Expériences autogestionnaires et coopératives | `mot36` autogestion | exacte | associée : `mot67` coopération |
| Critique du capitalisme (`critique-capitalisme`) | Analyses et critiques du système capitaliste | `mot44` capitalisme et anticapitalisme | proche | FICEDL ne distingue pas critique et objet ; la sous-facette « économie : … » reste au choix de qui catalogue |
| Critique de l'État (`critique-etat`) | L'État, le pouvoir et la domination | `mot113` État et étatisme | proche | associée : `mot230` pouvoir |
| Féminisme libertaire (`feminisme-libertaire`) | Féminisme et anarchisme | `mot122` féminisme | plus large côté FICEDL | la nuance « libertaire » se rend par la paire `mot122` + `mot8` |
| Écologie sociale (`ecologie-sociale`) | Écologie, décroissance et municipalisme libertaire | `mot87` écologie | plus large côté FICEDL | ni « décroissance » ni « municipalisme libertaire » dans FICEDL : à signaler à la FICEDL plutôt qu'à inventer ici |
| Internationalisme (`internationalisme`) | Solidarité internationale et anti-impérialisme | `mot157` internationalisme | exacte | associées : `mot152` impérialisme, `mot265` solidarité |
| Théorie (`theorie`) | Textes théoriques et philosophiques | `mot222` philosophie | associée | aucun « théorie » dans FICEDL : la catégorie dit un registre d'écriture plus qu'un sujet |
| Témoignages (`temoignages`) | Récits, mémoires et témoignages militants | `mot174` littérature : Mémoires | proche | associées : `mot169` littérature : biographies, `mot512` histoire : histoire orale |
| Brochures (`brochures`) | Brochures et textes courts | — | aucune | **une forme, pas un sujet** : elle ne va pas au thésaurus. Côté AnarBib, rien ne la porte encore (types de document : `livro`, `tract`, `periodico`…) ; la règle documentaire usuelle (moins de 49 pages) se tirerait du nombre de pages |

## Ce qui reste à décider, avec lui

1. **Le sens de la moisson.** À l'import, une catégorie ASB deviendrait-elle un sujet FICEDL posé
   d'office, ou une proposition à valider par la bibliothèque qui importe (comme les rapprochements
   d'autorités) ? La seconde voie est celle d'AnarBib pour tout ce qui vient d'ailleurs.
2. **Les relations « proches » et « plus larges ».** Les accepter en un seul sujet, ou poser aussi les
   associées ? Poser trop de sujets dilue la recherche.
3. **Les trous de FICEDL** (décroissance, municipalisme libertaire, théorie) : les signaler à la
   FICEDL, qui tranche son vocabulaire, plutôt que de les créer dans AnarBib.
4. **Les « Brochures »** : faut-il à AnarBib un type de document « brochure », ou un critère tiré du
   nombre de pages ?
5. **Les catégories propres à chaque instance** d'ASB : la table ci-dessus ne couvre que celles du
   semis initial.
