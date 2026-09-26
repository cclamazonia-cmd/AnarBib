# Relecture des alignements FICEDL — 26/09/2026 (H10)

**Décision :** Xavier, 26/09/2026, fiche validée en bloc.
**Appliquée par :** `supabase/migrations/20260926182521_h10_relecture_des_alignements_ficedl.sql` (clé : slug du sujet + `mot_id` ; chaque ligne numérotée ici y figure sous le même numéro).
**Relevé de départ :** production, 26/09 au matin — 99 liens : 44 `exact`, 54 `close`, 1 `broad` (posé à l'écran le 25/09 pour éprouver H9), **0** vers la facette `dates`.
**Doctrine :** `CONV-EXEC-3` — fiche par fiche, jamais par passe automatique. REGISTRE §30 `THES-FIC4` pour le sens : la relation va **du sujet AnarBib vers le descripteur FICEDL** ; « plus large » (`broad`) = le descripteur englobe le sujet.

Pourquoi relire : jusqu'au 07/09 le domaine n'avait que `exact`/`close`, et tout ce qui était plus large, plus étroit ou seulement voisin avait été tassé en `close` — « presque le même concept », publié tel quel dans l'export SKOS.

## A. Les 54 `close`

### Devenir « plus large » (19) — le sujet est un cas particulier du descripteur

| # | Sujet AnarBib | Descripteur FICEDL |
|---|---|---|
| 1 | Anarcha-féminisme | féminisme |
| 2 | Anarchisme social | anarchisme |
| 3 | Anarco-Punk | art : musique |
| 4 | Antifascisme | fascisme et antifascisme |
| 5 | Art et militantisme | art (généralités) |
| 6 | Cabanagem | Brésil : histoire |
| 7 | Communisme libertaire | anarchisme |
| 8 | Contre-culture | culture |
| 9 | Écologie sociale | écologie |
| 10 | Éducation libertaire | éducation |
| 11 | Especifismo | mouvement anarchiste (généralités) |
| 12 | Femmes anarchistes | femmes |
| 13 | Ficção | littérature (généralités) |
| 14 | Makhnovtchina | Ukraine |
| 15 | Mouvement de quartier | luttes urbaines |
| 16 | Revolução sexual | sexualité et genre |
| 17 | Amérique du nord (Solidaires) | Amérique |
| 18 | Homosexualités, LGBTQI (Solidaires) | sexualité et genre |
| 19 | Mai-Juin 1936 (Solidaires) | France : histoire : 1919-1939 |

### Devenir « plus étroit » (21) — rubriques composites de Solidaires, plus larges que chaque descripteur

| # | Sujet AnarBib | Descripteur FICEDL |
|---|---|---|
| 20-22 | Anticolonialisme, antiracisme, migrations | colonialisme · racisme et antiracisme · émigration et immigration |
| 23 | Antifascisme, extrême droite | extrême-droite |
| 24-26 | Bandes dessinées, affiches, photos | littérature : bande dessinée · art : affiches · art : photographie |
| 27 | Histoire du mouvement ouvrier, syndicalisme | syndicalisme |
| 28-29 | Moyen-Orient, Proche-Orient, Palestine | Israël · Palestine |
| 30-32 | Répression - Justice - Prison | prison · justice · répression |
| 33-34 | Révolution espagnole, exil, antifranquisme | Espagne : histoire : 1936-1939 · 1939-1975 |
| 35-37 | Romans, nouvelles, essais | littérature : romans · nouvelles · essais |
| 38-39 | URSS - Pays de l'Est | URSS · URSS : histoire |
| 40 | Yiddishland - Mouvements juifs | Juifs : juifs anarchistes |

### Devenir « associé » (5) — lien réel, sans hiérarchie

| # | Sujet AnarBib | Descripteur FICEDL | Raison |
|---|---|---|---|
| 41 | Abolitionnisme pénal | prison | une position sur la prison, pas une sorte de prison |
| 42 | Anticléricalisme | libre-pensée | recouvrement partiel |
| 43 | Question agraire | luttes rurales et paysannes | une question, pas une lutte |
| 44 | Réforme urbaine | urbanisme | un mouvement, pas une discipline |
| 45 | Révolution allemande - Conseillisme | Allemagne : histoire : 1914-1918 | la révolution déborde la guerre (voir D2) |

### Rester « proche » (9) — confirmés

| # | Sujet AnarBib | Descripteur FICEDL | Note |
|---|---|---|---|
| 46 | Anarchisme individualiste | individualisme | dans un thésaurus libertaire, sans doute le courant lui-même — `exact` possible à une prochaine relecture |
| 47 | Mouvement étudiant | étudiants | |
| 48 | Resistência ao Governo | désobéissance civile | le titre de Thoreau |
| 49 | Amériques latine et centrale | Amérique Latine | |
| 50 | Antifascisme, extrême droite | fascisme et antifascisme | |
| 51 | Libertaires | anarchisme | |
| 52 | Mai 1968, années 68 | France : histoire : 1968 | |
| 53 | Révolution 1789 - Juin 1848 | France : histoire : 1789-1848 | |
| 54 | Yiddishland - Mouvements juifs | Juifs | |

## B. Les 44 `exact`

### Trop affirmés (6)

| # | Sujet AnarBib | Descripteur FICEDL | Devient | Raison |
|---|---|---|---|---|
| 55 | Antiracisme | racisme et antiracisme | plus large | le descripteur couvre les deux |
| 56 | Fascismo | fascisme et antifascisme | plus large | idem |
| 57 | Mutuellisme | mutualisme et mutuellisme | plus large | idem |
| 58 | Révolution espagnole | Espagne : histoire : 1936-1939 | proche | une révolution n'est pas une période |
| 59 | Révolution russe | Russie : histoire : 1917-1921 | proche | idem |
| 60 | Révolution russe (Solidaires) | Russie : histoire : 1917-1921 | proche | idem |

### Confirmés sans changement (38)

*Sujets actifs (23) :* Action directe · Anarchisme · Anarchosyndicalisme (→ syndicalisme : anarchosyndicalisme) · Antimilitarisme · Autogestion · Biographie (→ littérature : biographies) · Commune de Paris (→ France : histoire : 1871 (La Commune)) · Comunismo · Ditadura · Ecologia · Féminisme · Grève · Histoire de l'anarchisme (→ mouvement anarchiste : histoire) · Insurrecionalismo · Marxisme · Mexique · Mouvement ouvrier · Organisation · Peuples autochtones (→ populations autochtones) · Premier Mai · Repressão · Socialisme · Syndicalisme.

*Sujets proposés du lot Solidaires (15) :* Afrique · Antimilitarisme · Asie · Deuxième guerre mondiale (→ guerres : Guerre mondiale, 2) · Écologie · Économie (→ économie (généralités)) · Éducation · Europe · Féminisme · Jeunesse (→ jeunes et jeunesse) · La Commune 1871 (→ France : histoire : 1871 (La Commune)) · Marxisme · Religions (→ religion et spiritualité (en général)) · Sociologie · Sport.

Le détail (sujet, `mot_id`) est celui du relevé du 26/09, que la migration ne touche pas.

## C. Facette `dates` — 8 liens nouveaux

Les années FICEDL commencent en 1868 : 1789 et 1848 n'y existent pas.

| # | Sujet AnarBib | Année FICEDL | Relation |
|---|---|---|---|
| C1 | La Commune 1871 (Solidaires) · Commune de Paris | 1871 (`mot654`) | plus large |
| C2 | Mai-Juin 1936 (Solidaires) | 1936 (`mot571`) | plus large |
| C3 | Mai 1968, années 68 (Solidaires) | 1968 (`mot603`) | associé — « années 68 » déborde l'année |
| C4 | Révolution russe · Révolution russe (Solidaires) | 1917 (`mot552`) | associé |
| C5 | Révolution allemande - Conseillisme (Solidaires) | 1918 (`mot553`) · 1919 (`mot554`) | associé |

## D. Meilleures cibles trouvées en chemin — 3 liens nouveaux

| # | Sujet AnarBib | Descripteur FICEDL | Relation |
|---|---|---|---|
| D1 | Moyen-Orient, Proche-Orient, Palestine | Proche et Moyen-Orient (`mot387`) | proche |
| D2 | Révolution allemande - Conseillisme | Allemagne : histoire : 1917-1921 (`mot300`) | proche |
| D3 | Révolution allemande - Conseillisme | conseils ouvriers (`mot62`) | plus étroit |

## Résultat attendu en production

110 liens : 38 `exact`, 14 `close`, 26 `broad`, 22 `narrow`, 10 `related` ; 8 vers la facette `dates`.

## Éprouvé avant de pousser (26/09)

- En lecture seule contre la production : les 71 lignes trouvent leur sujet et leur descripteur, les 60 liens existants portent la relation « avant », les 11 nouveaux sont absents.
- Sur une copie jetable du banc (les 49 sujets et les 60 liens posés dans leur état du matin) : 71 décisions tenues, 8 vers `dates` ; rejouée, la migration ne change rien ; un lien modifié entre-temps la fait échouer en le nommant.
