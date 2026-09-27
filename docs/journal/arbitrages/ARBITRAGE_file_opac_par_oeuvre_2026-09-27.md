# Arbitrage de la file de l'OPAC par œuvre — 27/09/2026 (C11)

**Relevé** (production, 27/09 au matin, fonctions de l'assistant de dédoublonnage appelées en lecture seule) : 9 groupes de tomes (30 notices), 90 paires d'œuvres scindées, 10 paires « à décider » (205 autres « à rapprocher », titre seul, hors C11), 175 notices MLEG « Assuntos importados » sans matière, 1 452 titres automatiques « corrige-moi » sur 162 œuvres.

**Fiche** proposée par l'assistant de session, **validée en bloc par Xavier le 27/09**, puis appliquée en deux temps :

1. **par Xavier, dans l'assistant de dédoublonnage** — toutes les fusions (irréversibles) et les réunions de tomes, sous son nom. Une première version appliquait toute la fiche par migration **sous l'identité de Xavier** ; elle a été refusée par le garde-fou de l'environnement (un verdict ne porte le nom de quelqu'un que si c'est lui qui l'a posé), et le partage des gestes a été décidé avec lui ;
2. **par la migration** `supabase/migrations/20260927112143_c11_verdicts_et_matieres_mleg.sql` — ce qui ne détruit rien, en son propre nom (auteur vide, motif « arbitrage C11 du 27/09, validé par Xavier, appliqué par migration »).

## V. Groupes de tomes — faits par Xavier

Réunis et numérotés : *A Classe Operária no Brasil* (224 → 1, 218 → 2), *A Revolução Desconhecida* (771, 776 → 1 : deux notices du même tome), *Acción directa anarquista* (**369 → 1, 368 → 2** — Xavier a corrigé la proposition : *La Fundación* est le premier tome —, 370 → 3), *História do Anarquismo no Brasil* (1395, 2442 → 2), *Os Companheiros* (2 à 5), *Rebeldias* (tomes 2 et 3, deux doublons chacun), *Sobre Educação, Política e Sindicalismo* (2258 → 1, **2086 → 3**, numéro posé par Xavier), *Um século de história político-social* (39 → 1, 40 → 2). *O Capital* : « ce ne sont pas des tomes » (quatre éditions), posé par la migration.

## S. Œuvres scindées — faites par Xavier

L'onglet est vide. Xavier a tranché plusieurs paires autrement que la proposition — ses décisions font foi :

- **fusionnées alors que la proposition les séparait** : *Antologia do Socialismo Libertário* avec *Socialismo Libertário*, *O Princípio do Estado* (et ses essais), *O indivíduo, a sociedade e o Estado* (et ses essais), les deux livres de Maria Nazareth Ferreira sur la presse ouvrière, *São Paulo de meus amores*, *O Homem e a Terra* avec son volume *O Estado Moderno*, *Essência da Religião* ;
- **séparées alors que la proposition les fusionnait** : Guérin *El / O Anarquismo*, *Nem pátria, nem patrão*, *Jaime Cubero, Seleção de textos* ;
- **les cas « à voir »** : Armand, Kropotkine *Anarquismo*, Liarte, *Anarquismo es movimiento* séparés ; *O Princípio anarquista* fusionné ;
- **les familles de tomes** (*Novísima Geografía Universal*, *Living my Life*, *Minha Desilusão na Rússia*, *Les Fils de la nuit*, *Obras Seletas*, *La FORA*, *El Hombre y la Tierra*) : **« garder séparées »**, là où la proposition les réunissait — question posée à Xavier le 27/09, en attente.

## D. À décider — faites par Xavier

Fusionnées : *Alexandra David-Neel*, *O Racionalismo Combatente*, *Trabajan para la Eternidad*, *Entre la Revolución y las Trincheras* (notice gardée : 991), *La Educación y la Herencia*. Peirats 1290 / 1291 : non fusionnés, la paire a quitté la file — question posée à Xavier le 27/09. Les trois paires entre bibliothèques (*Colônia Cecília*, *Socialismo Libertário*, *Sindicalismo revolucionario*) ont quitté la file avec les fusions d'œuvres.

## O Homem e a Terra — demande de Xavier, appliquée par la migration

« Doit passer dans les livres en volumes », le thème comme volume. Les six volumes thématiques de l'édition Imaginário (2010-2011), éclatés entre quatre œuvres, rejoignent l'œuvre 880, renommée « O Homem e a Terra » : 1510 *Progresso*, 1511 *Internacionais*, 1512 *O Estado Moderno*, 1515 *Educação*, 1516 *A Indústria e o Comércio*, 1517 *A Cultura e a Propriedade*. Le regroupement suit pas à pas `merge_works`. Restent à part l'édition espagnole de 1986 (Fondo de Cultura Económica) et l'anthologie *Textos escolhidos* (Intermezzo, 2015).

**Correction du 27/09, après déploiement** : l'en-tête de la migration affirme que la paire 1510 / 1511 quitte « À décider » une fois les volumes posés. C'est faux, constaté en production — la règle « un tome n'est jamais un doublon » ne joue pas sur des volumes nommés par leur thème ; l'affirmation avait été écrite sans être éprouvée. Et le renommage de l'œuvre fait apparaître une paire nouvelle dans « Œuvres scindées » : *O Homem e a Terra* / *Textos escolhidos* (l'ancien verdict « séparées » est parti avec l'œuvre 25, absorbée). Les deux verdicts sont laissés à Xavier dans l'assistant (« Pas un doublon », « Garder séparées »).

## M. Notes MLEG — appliquées par la migration

Une matière **existante** par catégorie (THES-4 : aucune matière créée) ; aucune note effacée.

| Catégorie | Notices | Décision |
|---|---|---|
| Anarquismo no Brasil | 49 | Anarchisme |
| Anarquismo Internacional | 42 | Anarchisme |
| Clássicos Anarquistas | 35 | Anarchisme |
| Coletâneas | 3 | Anarchisme |
| Edgar Rodrigues | 5 | Histoire de l'anarchisme |
| Literatura Libertária | 6 | Ficção |
| Transversais | 21 | note seule — trop hétérogène (Crass, situationnistes, Clastres) |
| Ciências Humanas | 14 | note seule — Foucault surtout, aucune matière proche |

## Hors de cette fiche

Les 1 452 titres automatiques « corrige-moi » se relisent dans la fiche de l'œuvre, à son ouverture (critère 2 de C11), pas en lot.
