# Les sept ressources restreintes au regard de `NUMDIF` : classement proposé (D18)

> **Date** : 2026-10-15
> **Auteur** : Claude (assistant·e), pour la coordination
> **Session** : D17 lien vers la page source
> **Statut** : 🟡 **proposition, rien n'est appliqué.** Les décisions reviennent
> aux bibliothèques détentrices (doctrine du 20/08 : la responsabilité reste
> celle de la bibliothèque qui verse).
> **Référence** : REGISTRE §47 (`NUMDIF-1` à `NUMDIF-3`) ; backlog v34 `D18`, `D17` ;
> [cadrage du 15/10](../cadrages/CADRAGE_pdf-sous-droits-diffuses_2026-10-15.md) §2.

---

## En une page

`D17` ajoute la colonne `source_page_url` : l'adresse de la **page** qui présente
la copie trouvée ailleurs, la seule que voit qui lit une copie restreinte
(« aussi en ligne »). L'adresse du **fichier** (`source_url`) reste en base comme
provenance et ne sort plus pour une ressource restreinte.

Sur les sept ressources restreintes actives :

- **une** reçoit sa page automatiquement par la migration de `D17` (74, Archive.org) ;
- **quatre** ont une page trouvée et vérifiée le 15/10, à poser si la bibliothèque
  détentrice l'accepte (70, 72, 73, 76) ;
- **deux** n'ont pas de page publique trouvable (62, 66) : elles restent sans
  « aussi en ligne » ;
- **la 62** est à signaler à BTL : elle est **non conforme à `NUMDIF-1`**
  (`bibliographic_match_validated = false`, aucun `rights_status`). Rien n'est
  corrigé d'office.

Ce que ce classement **ne fait pas** : la vérification de l'édition sur la page de
titre de chaque PDF (`NUMDIF-1`), qui demande d'ouvrir les fichiers et revient à la
bibliothèque détentrice.

## Le classement

Mesures en production le 15/10 (lecture seule). Pages vérifiées le 15/10 par une
recherche web, sans contourner aucune protection.

| Ressource | Notice (détentrices) | Fichier (`source_url`) | Page proposée (`source_page_url`) | Confiance | Remarque |
|---|---|---|---|---|---|
| **62** | *Gli Anarchici nella rivoluzione messicana*, livre 1434 (BTL) | `https://lemaquis.noblogs.org/` (page d'accueil du blog) | **aucune** | — | Le blog Le Maquis ne répond plus (le domaine `noblogs.org` non plus, 15/10). **Non conforme à `NUMDIF-1`** : à signaler à BTL (voir plus bas). |
| **66** | *História da anarquia* (Nettlau), livre 2287 (BLMF, BTL) | `we.riseup.net/assets/177483/…` (**fichier**, servi encore le 15/10) | **aucune** | — | Le site Crabgrass de riseup fonctionne, mais aucune page publique ne présente cet asset (page de groupe sans doute réservée aux membres). `source_name` vide. |
| **70** | *El Congreso confederal de Zaragoza, 1936*, livre 1077 (BTL) | `dokumen.pub/el-congreso-confederal-de-zaragoza-1936-8431704462.html` | la même adresse | haute | C'est déjà une page de présentation (titre, description, lien de téléchargement distinct vers `/download/…`). `source_name` vide → l'écran affichera « dokumen.pub ». |
| **72** | *A Anarquia perante os tribunais* (Gori), livre 232 (BTL) | `pdfcoffee.com/qdownload/…-pdf-free.html` (**téléchargement**) | `https://pdfcoffee.com/a-anarquia-perante-os-tribunais-pdf-free.html` | haute | Page chargée (titre, extrait, bouton de téléchargement). Le nom « Eduardo Medeiros » qui y figure est celui de la personne qui a déposé le fichier, pas l'auteur. `source_name` vide → « pdfcoffee.com ». |
| **73** | *Ajuda mútua* (Kropotkine), livre 2513 (BTL, MLEG) | `anarquista.net/wp-content/uploads/2013/04/…pdf` (**fichier**) | `https://www.anarquista.net/ajuda-mutua-um-fator-de-evolucao-de-piotr-kropotkin-livro/` | haute | Article du 30/04/2013 qui présente le livre et pointe vers ce PDF (trad. Waldyr Azevedo Jr., A Senhora Editora, 2009). |
| **74** | *El Apoyo mutuo* (Kropotkine), livre 2384 (BLMF) | `dn720005.ca.archive.org/0/items/…/….pdf` (**fichier**) | `https://archive.org/details/kropotkin-piotr.-el-apoyo-mutuo.-un-factor-de-evolucion-ocr-2020` | haute | **Posée par la migration `20261015180042`** (déduite du fichier). Item librement téléchargeable, pas en prêt contrôlé ; licence affichée CC BY-ND 4.0. **Même édition, vérifiée le 16/10** sur la page de crédits du PDF (texte OCR d'Archive.org) : même ISBN 978-84-15862-72-7, Pepitas de calabaza, traduction Luis Orsetti ; le « [2020] » est le troisième tirage (question 3, résolue). Vue par un compte membre de BLMF le 16/10 : « aussi en ligne » s'affiche. |
| **76** | *Sociedade sem Escolas* (Illich), livre 2703 (MLEG) | `colectivolibertarioevora.wordpress.com/wp-content/uploads/2013/11/…pdf` (**fichier**) | `https://colectivolibertarioevora.wordpress.com/livros-digitais/` | moyenne-haute | Page « Livros e textos digitais » : à la rubrique Ivan Illich, le lien pointe exactement vers ce PDF. C'est une liste, pas un article dédié (aucun article dédié trouvé). |

### Trois questions pour la coordination

1. **Les agrégateurs.** dokumen.pub (70) et pdfcoffee (72) sont des sites qui
   republient des PDF déposés par des tiers, sans éditeur identifiable. `NUMDIF-3`
   montre la page pour créditer qui a numérisé ; sur ces deux sites, la page
   crédite au mieux un pseudonyme de dépôt. Faut-il quand même l'afficher, ou
   laisser ces deux ressources sans « aussi en ligne » ?
2. **Les noms manquants.** 66, 70 et 72 n'ont pas de `source_name`. L'écran
   affiche à défaut l'hôte de la page (`dokumen.pub`, `pdfcoffee.com`). Saisir un
   nom au catalogage reste possible.
3. **L'édition de la 74** (relevé du 16/10). La notice 2384 décrit *El apoyo
   mutuo : un factor de evolución*, Pepitas de calabaza, Logroño, **2019** ; le
   PDF versé vient d'un item Archive.org nommé « … [ocr] [2020] ». Réimpression
   de la même édition, ou autre édition ?
   ✅ **Résolue le 16/10 : même édition.** La page de crédits du PDF (lue dans le
   texte OCR que publie Archive.org) donne Pepitas de calabaza, Logroño,
   traduction de Luis Orsetti revue par Julio Monteverde et Maila Lema, **ISBN
   978-84-15862-72-7** — celui de la notice —, dépôt légal Lr-1126-2016, et trois
   tirages sous ce même ISBN : novembre 2016, avril 2018, août 2020. Le « 2020 »
   du fichier est le troisième tirage : la concordance de `NUMDIF-1` tient, la
   ressource reste active. **Reste un point de catalogage** (pas de droits) :
   l'année **2019** de la notice ne correspond à aucun des trois tirages ;
   l'exemplaire de BLMF est peut-être celui d'avril 2018, ou l'année est à
   corriger — à voir sur l'exemplaire.

## La ressource 62 — à signaler à BTL, pas à corriger

- Notice 1434, *Gli Anarchici nella rivoluzione messicana*, détenue par BTL seule.
- `bibliographic_match_validated = false` : l'édition n'a pas été rapprochée.
  `NUMDIF-1` : une ressource active porte `true`.
- `rights_status` vide : ni cas de source (`NUMDIF-2`) ni justification.
- Source : la page d'accueil d'un blog aujourd'hui hors ligne. Aucune page
  précise n'a pu être retrouvée.
- Pas de brouillon lié (`published_resource_id = 62` : aucun).

Ce que BTL peut décider : vérifier la page de titre et poser `sob_direitos` et
`bibliographic_match_validated = true` (mise en conformité), ou retirer la
ressource. `D18` le prévoit : « mise en conformité ou retirée, par décision de la
bibliothèque détentrice ».

## Le SQL préparé (non appliqué)

À jouer **après** le déploiement de la migration `20261015180042` (sans la colonne,
il échoue), et seulement pour les lignes que les bibliothèques détentrices
acceptent. Le brouillon lié est mis à jour avec le publié : la publication
recopie le brouillon vers le publié, et un brouillon resté sans page effacerait
celle du publié à sa prochaine publication.

```sql
-- D18 — pages des sources acceptées par les bibliothèques détentrices.
-- Proposé le 15/10/2026 (session D17 lien vers la page source), NON APPLIQUÉ.
BEGIN;
SELECT set_config('anarbib.retake_oubli', 'on', true);  -- ne pas marquer les reprises « touchées »

WITH pages(resource_id, page) AS (VALUES
  (70, 'https://dokumen.pub/el-congreso-confederal-de-zaragoza-1936-8431704462.html'),
  (72, 'https://pdfcoffee.com/a-anarquia-perante-os-tribunais-pdf-free.html'),
  (73, 'https://www.anarquista.net/ajuda-mutua-um-fator-de-evolucao-de-piotr-kropotkin-livro/'),
  (76, 'https://colectivolibertarioevora.wordpress.com/livros-digitais/')
), pub AS (
  UPDATE public.book_digital_resources r
     SET source_page_url = p.page
    FROM pages p
   WHERE r.id = p.resource_id AND r.source_page_url IS NULL
  RETURNING r.id
)
UPDATE public.book_draft_digital_resources d
   SET source_page_url = p.page
  FROM pages p
 WHERE d.published_resource_id = p.resource_id AND d.source_page_url IS NULL;

SELECT id, source_page_url FROM public.book_digital_resources WHERE id IN (70, 72, 73, 74, 76) ORDER BY id;
-- attendu : cinq lignes avec une page (74 posée par la migration)
COMMIT;
```

Comme il touche des données et non le schéma, ce SQL n'est pas une migration : il
se joue une fois, à la main, par la coordination ou à sa demande.

## Après

- ✅ **16/10 — contrôle fait par Xavier sous un compte membre de BLMF** sur le
  livre 2384 (ressource 74) : la fiche montre « aussi en ligne : Internet
  Archive » vers la page `archive.org/details/…`. `D17` est vérifié en production.
- Contrôle sous un compte membre de BTL, une fois le SQL ci-dessus joué : la fiche du livre 1077 montre « aussi en
  ligne : dokumen.pub », et la réponse de `read-digital-asset` porte
  `source_page_url` mais `source_url: null`.
- `D18` reste ouvert jusqu'à la décision sur la 62 et la vérification des pages
  de titre.
