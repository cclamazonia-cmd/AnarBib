-- =========================================================================
-- L'import reconnaît l'introduction et l'avant-propos comme des rôles à part
-- entière, à côté de la préface
-- =========================================================================
-- Date     : 2026-10-17
-- Chantier : catalogage — panneau des responsabilités (refonte du 17/10/2026)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Mode de sélection des autorités
-- Ref      : src/lib/catalogacao/bookDraft.js (ROLE_KEYS_TEXT) ;
--            supabase/functions/_shared/marc/correspondance.ts (win →
--            introdutor, wfw → prologuista) ; migration 20261005172708 (la
--            définition de ingest.fn_import_row_as_book patchée ici)
--
-- POURQUOI
--   Deux rôles rejoignent « prefaciador » au menu du catalogage le 17/10/2026,
--   à la demande de Xavier : « introdutor » (introduction, MARC21 win) et
--   « prologuista » (avant-propos, MARC21 wfw). La lecture MARC
--   (correspondance.ts) les produit désormais. Mais ingest.fn_import_row_as_book
--   ne garde un rôle que s'il figure dans une liste fermée, et rabat tout autre
--   code sur « outro » (contributeurs) ou « autor » (auteurs) : sans ce paquet,
--   une introduction importée deviendrait « outro » — pire qu'avant, où elle
--   restait une préface.
--
-- CE QUE FAIT LE PAQUET
--   Les deux listes fermées de la fonction reçoivent 'introdutor' et
--   'prologuista', juste après 'prefaciador'. Le corps est patché depuis sa
--   définition RÉELLE (pg_get_functiondef, idiome de B33 :
--   20260927193314) : l'ancre « 'prefaciador','coordenador' » doit s'y trouver
--   exactement deux fois ; propriétaire, SECURITY INVOKER, search_path et
--   droits sont gardés (les droits sont vérifiés). Rejouer le paquet ne fait
--   rien (la fonction connaît déjà 'introdutor').
--
--   ingest.fn_h18_contributeurs_des_brouillons_importes porte la même liste,
--   mais c'est le rattrapage ponctuel de H18 (28/09) : laissé tel quel.
--
-- Aucun objet créé ; aucun droit modifié.
-- =========================================================================

BEGIN;

DO $liminaires$
DECLARE
  v_fn    regprocedure := 'ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows,jsonb)'::regprocedure;
  v_def   text := pg_get_functiondef(v_fn);
  v_acl   text := (SELECT proacl::text FROM pg_proc WHERE oid = v_fn);
  v_anc   text := $a$'prefaciador','coordenador'$a$;
  v_new   text := $n$'prefaciador','introdutor','prologuista','coordenador'$n$;
  v_occ   int;
BEGIN
  IF position($m$'introdutor'$m$ IN v_def) > 0 THEN
    RAISE NOTICE 'liminaires : % connaît déjà introdutor (rejeu), sans effet.', v_fn;
    RETURN;
  END IF;

  v_occ := (length(v_def) - length(replace(v_def, v_anc, ''))) / length(v_anc);
  IF v_occ <> 2 THEN
    RAISE EXCEPTION 'liminaires : ancre trouvée % fois dans % (2 attendues) — relire la définition réelle', v_occ, v_fn;
  END IF;

  EXECUTE replace(v_def, v_anc, v_new);

  IF (SELECT proacl::text FROM pg_proc WHERE oid = v_fn) IS DISTINCT FROM v_acl THEN
    RAISE EXCEPTION 'liminaires : les droits de % ont changé', v_fn;
  END IF;
  IF (length(pg_get_functiondef(v_fn)) - length(replace(pg_get_functiondef(v_fn), v_new, ''))) / length(v_new) <> 2 THEN
    RAISE EXCEPTION 'liminaires : % n''a pas les deux listes attendues après réécriture', v_fn;
  END IF;

  RAISE NOTICE 'liminaires : % — les deux listes de rôles connaissent introdutor et prologuista.', v_fn;
END
$liminaires$;

COMMIT;
