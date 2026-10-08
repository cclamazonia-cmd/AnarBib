# Signalement à PMB Services — l'origine des autorités choisie dans « Exemplaires UNIMARC » n'est pas transmise (PMB 8.1.1.1)

*Rédigé le 08/10/2026 pour Xavier, qui l'enverra (forge publique de PMB
Services ou liste des utilisateur·rices de PMB, à son choix). Item **H32** du
backlog v34 ; constat de **H25** (28-29/09/2026), banc `tests/pmb/`. Le texte
ci-dessous est au « je » : une personne écrit, pas un collectif.*

---

**Objet : Import « Exemplaires UNIMARC » — l'origine des autorités choisie dans le formulaire n'arrive jamais au script d'import (PMB 8.1.1.1)**

Bonjour,

En important dans PMB 8.1.1 (patch 1) des notices UNIMARC dont les zones 7XX
portent un `$3` vers des autorités importées auparavant (Autorités > Import,
origine « AnarBib »), j'ai constaté que l'option « Tenir compte des notices
d'autorités : Oui » de l'onglet **Administration > Imports > Exemplaires
UNIMARC** ne retrouve jamais les autorités, quelle que soit l'origine choisie
dans la liste du formulaire.

**La cause, dans le code.** Le formulaire de cet onglet est le gabarit
`$tpl_beforeupload_expl` (`admin/import/import_func.inc.php`, affiché par
`admin/import/iimport_expl.php`, ligne 150). Sa liste des origines est
engendrée ligne 95 par :

```php
".origin::gen_combo_box("authorities")."
```

Sans second argument, `gen_combo_box` nomme le champ `authorities_origin`.
Or le script d'import lit une autre variable : `import_func.inc.php`,
ligne 911, `global $authorities_default_origin;`, puis ligne 924,
`$origin_authority = $authorities_default_origin;`. La valeur choisie à
l'écran part donc sous un nom que personne ne lit ; `$authorities_default_origin`
reste vide, et `keep_authority_infos` cherche les fiches dans une origine qui
n'existe pas.

Le libellé juste au-dessus (ligne 94) porte déjà
`for='authorities_default_origin'` : le nom attendu était bien celui-là. Les
trois autres formulaires du même module le passent d'ailleurs explicitement —
`import_func.inc.php` ligne 245 (gabarit des « Notices UNIMARC ») et
`iimport_expl.php` lignes 275 et 451 :

```php
".origin::gen_combo_box("authorities","authorities_default_origin")."
```

**Le correctif tient en une ligne** (`admin/import/import_func.inc.php`,
ligne 95) :

```php
".origin::gen_combo_box("authorities","authorities_default_origin")."
```

**Ce que ça change, mesuré.** Sur un jeu de 64 notices et leurs autorités,
dans un PMB 8.1.1.1 propre (une seule base, un seul thésaurus) :

- avec « Oui » et le formulaire tel qu'il est : aucune autorité retrouvée ;
  les liens notice → source d'autorité écrits par l'import pointent sur une
  origine absente (44 liens sur ce jeu), et les auteurs sont rapprochés par la
  forme du nom comme si l'option était à « Non » ;
- avec « Oui » et le champ transmis sous le nom attendu (ce que fait le
  correctif d'une ligne) : les 61 responsabilités du jeu sont liées à leur
  fiche d'autorité par le `$3`, aucun auteur n'est recréé.

Je peux fournir le jeu de test (fichier ISO 2709 des notices et fichier des
autorités) si c'est utile.

Merci pour PMB,

[signature de Xavier]

---

## Pièces (pour qui vérifie)

- Lignes citées, lues dans l'archive `pmb8.1.1.1.zip` (SHA256 dans
  `tests/pmb/banc/pmb.env`) : `admin/import/import_func.inc.php` 28 (début
  de `$tpl_beforeupload_expl`), 94-95, 245, 911, 924 ;
  `admin/import/iimport_expl.php` 150, 275, 451.
- Mesures : `tests/pmb/bilans/h25-comme-le-navigateur.json` (origine non
  transmise) et `tests/pmb/bilans/h25-origine-transmise.json` (origine
  transmise sous le nom attendu — l'outil du banc envoie
  `authorities_default_origin`, ce qu'enverrait un formulaire corrigé) ;
  tableau au § 3 de `docs/interop/couverture-pmb.md`.
- La marche à suivre pour une bibliothèque qui veut corriger son PMB sans
  attendre la version suivante : `tests/pmb/README.md`, section « Pour DIRA ».
