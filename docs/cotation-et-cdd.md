# Cotation BLMF — norme de tombo + grille CDD anarchiste

> Document de travail catalogage. Source CDD : sommaires Dewey publics
> (10 classes / 100 divisions), adaptés aux rayons réels de la collection.

## 1. Norme de tombo (numéro d'inventaire)

**Format : `CCLA.{ANNÉE}.{N}`**

- **ANNÉE** = année de catalogage (millésime).
- **N** = compteur d'acquisition, **réinitialisé chaque année**, **unique par
  exemplaire physique** (deux exemplaires d'un même titre = deux N distincts).
- **Casse** : `CCLA` en majuscules. Séparateur : point. Pas de zéros de
  remplissage, pas de suffixe de copie (`-01`, `-02`).

**Règle pour bibliothécaire débutant·e :**
> « Nouveau livre catalogué en {année} → je prends le plus grand N existant
> pour `CCLA.{année}.*`, et j'ajoute 1. »

**État au 2026-06-07 (après unification des 246 exemplaires BLMF) :**

| Millésime | Plage utilisée | Prochain N libre |
|---|---|---|
| 2023 | 1 → 222 (legacy) | (clos) |
| 2024 | 1 → 53 (legacy) | (clos) |
| **2026** | 1 → 76 | **77** |

→ La reprise de catalogage 2026 continue donc à `CCLA.2026.77`.

*Note historique : en 2023, N suivait souvent le numéro de référence biblio ;
en 2024/2026, N est un compteur d'acquisition. Les millésimes étant distincts,
aucune collision n'est possible. Seul le millésime courant suit la règle « max+1 ».*

## 2. Grille CDD ciblée (rayons anarchistes)

La cote anarchiste de référence en Dewey est **335.83 (Anarquismo)**. La plupart
des ouvrages de théorie y vont ; le reste se ventile par **thème** (éducation,
travail, terre, histoire d'une révolution donnée, biographie).

### Cœur politique — 300

| CDD | Intitulé (pt-BR) | Pour quoi / exemples |
|---|---|---|
| 303.6 | Conflito social, revolução | théorie de la révolution, violence/non-violence |
| 305.42 | Mulheres, feminismo | « Mulher, Vida, Liberdade », féminisme libertaire |
| 305.5 / 305.8 | Classes sociais / grupos étnicos | classe, race |
| 320.5 | Ideologias políticas | panoramas d'idéologies |
| 321.07 | Anarquia (ausência de governo) | théorie de l'État/non-État (variante de 335.83) |
| 322.42 | Movimentos revolucionários | mouvements, organisations de lutte |
| 323.044 | Ação direta, desobediência civil | action directe, résistance |
| 324.2 | Partidos / eleições | « Os Anarquistas e as Eleições » |
| 331.88 | Sindicalismo, sindicatos | syndicalisme, « imprensa operária » |
| 333.3 | Posse da terra | MST, luta pela terra, agrário |
| 334 | Cooperativas, autogestão | « Autogestão », coopérativisme |
| **335.83** | **Anarquismo** | **théorie anarchiste (cote par défaut)** |
| 335.4 | Marxismo | marxisme, comparaisons |
| 355 | Ciência militar, militarismo | « Militarismo na América latina » |
| 365 | Prisões | prison, abolition |
| 370.1 / 371.04 | Filosofia da educação / escolas alternativas | Escola Moderna, Ferrer, « Educar para emancipar » |

### Autres classes utiles

| CDD | Intitulé | Pour quoi / exemples |
|---|---|---|
| 070.4 | Imprensa, jornalismo | « A imprensa libertária do Ceará » |
| 170 / 171 | Ética | éthique, anarchisme moral |
| 211 | Ateísmo, agnosticismo | « Deus e o Estado » (anticléricalisme) |
| 335.83 ↔ 304.5 | (Kropotkin) | « Apoio mútuo » : selon l'angle, 335.83 (social) |
| 741.5 / 760 | HQ / gravura | fanzines illustrés, gravure militante |
| 791.43 | Cinema | « Viva Zapata! » et films |
| 860 / 869 | Lit. hispano-am. / brasileira | romans, « Amor e anarquia » |
| 840 | Literatura francesa | « Tout pour tous », etc. |
| 920 (ou B) | Biografia | Emma Goldman, Durruti, Bakunin |

### Histoire par région — 900

| CDD | Région | Exemples |
|---|---|---|
| 909 | História mundial | panoramas |
| 944.081 | França (Comuna de Paris) | Commune, mouvement français |
| 946.081 | Espanha (Guerra Civil) | Durruti, « Revolução e Guerra civil na Espanha » |
| 972.08 | México (Revolução) | Zapata, Flores Magón, « México insurgente » |
| 980 / 981 | América do Sul / Brasil | « História do Anarquismo no Brasil » |

### Heuristique de décision

1. **Théorie anarchiste générale** → `335.83`.
2. Thème dominant identifiable → cote du thème (éducation `370.1`,
   syndicalisme `331.88`, terre `333.3`, féminisme `305.42`…).
3. **Histoire** d'un événement/pays → `9xx` régional.
4. **Biographie** d'un·e militant·e → `920`.
5. **Fiction/poésie** → `8xx` selon la langue.
6. En cas de doute entre théorie et thème : privilégier `335.83` si l'ouvrage
   est explicitement anarchiste ; sinon le thème.
