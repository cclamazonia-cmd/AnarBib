-- ════════════════════════════════════════════════════════════════════════════
-- Fix : ISBN malformés + CDD aberrants (anomalies d'audit qualité)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
--
-- OBJET : 4 corrections ponctuelles relevées par l'audit qualité catalogue.
--   - 2 ISBN malformés → valeurs corrigées RELEVÉES SUR COLOPHON par Xavier
--     (clés de contrôle ISBN-13 vérifiées valides).
--   - 2 CDD multi-valeurs → un seul Dewey retenu (décision catalogage Xavier).
--
-- Garde `WHERE ... = <ancienne valeur>` : idempotent + ne réécrit pas si une
-- autre session a déjà modifié la fiche entre-temps.
-- ════════════════════════════════════════════════════════════════════════════

-- #2368 « Amérique(s) Anarchiste(s) » : 97910922457070 (14 ch., « 2 » doublé)
--   → 9791092457070 (ISBN-13 valide, colophon)
UPDATE public.books SET isbn = '9791092457070'
 WHERE id = 2368 AND isbn = '97910922457070';

-- #2320 « O que todo Revolucionário deve saber sobre a Repressão » (Victor Serge)
--   978659905832 (12 ch.) → 9786599095832 (ISBN-13 valide, colophon)
UPDATE public.books SET isbn = '9786599095832'
 WHERE id = 2320 AND isbn = '978659905832';

-- #2258 « Sobre Educação, Política e Sindicalismo » (Tragtenberg)
--   CDD « 370 - 370.981 » → 370.981 (éducation au Brésil)
UPDATE public.books SET cdd = '370.981'
 WHERE id = 2258 AND cdd = '370 - 370.981';

-- #2259 « Bakunin » (biographie, S. A. Q. Norte)
--   CDD « 923.2 - 320.512 - 320.57 - 324.1 » → 335.83 (anarchisme)
UPDATE public.books SET cdd = '335.83'
 WHERE id = 2259 AND cdd = '923.2 - 320.512 - 320.57 - 324.1';

NOTIFY pgrst, 'reload schema';
