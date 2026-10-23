-- =========================================================================
-- C31 — l'import garde la postface comme un rôle à part entière
-- =========================================================================
-- Date     : 2026-10-23
-- Chantier : catalogage — rôles des textes liminaires
-- Auteur   : Claude (assistant·e), pour la coordination
-- Ref      : 20261017203335_import_introduction_et_avant_propos (même geste) ;
--            src/lib/catalogacao/bookDraft.js (ROLE_KEYS_TEXT) ;
--            supabase/functions/_shared/marc/correspondance.ts (waw, aft →
--            posfaciador ; UNIMARC 075)
--
-- POURQUOI
--   Décision de Xavier du 23/10/2026 (C31) : la postface, jusqu'ici rangée en
--   préface, a son rôle — « posfaciador » (MARC21 waw, auteur d'une postface
--   aft ; UNIMARC 075). La lecture MARC le produit désormais ; mais
--   ingest.fn_import_row_as_book ne garde un rôle que s'il figure dans une
--   liste fermée, et rabat tout autre code sur « outro » (contributeurs) ou
--   « autor » (auteurs) : sans ce paquet, une postface importée deviendrait
--   « outro ».
--
-- CE QUE FAIT LE PAQUET
--   Les deux listes fermées reçoivent 'posfaciador' juste après 'prologuista'.
--   Corps patché depuis sa définition RÉELLE (pg_get_functiondef) : l'ancre
--   « 'prologuista','coordenador' » doit s'y trouver exactement deux fois
--   (vérifié en production le 23/10) ; droits vérifiés inchangés ; rejouer ne
--   fait rien. Les notices existantes ne changent pas : une postface déjà
--   rangée en préface le reste, jusqu'à ce qu'une personne la reprenne.
-- =========================================================================

BEGIN;

DO $postface$
DECLARE
  v_fn    regprocedure := 'ingest.fn_import_row_as_book(ingest.partner_catalog_staging_rows,jsonb)'::regprocedure;
  v_def   text := pg_get_functiondef(v_fn);
  v_acl   text := (SELECT proacl::text FROM pg_proc WHERE oid = v_fn);
  v_anc   text := $a$'prologuista','coordenador'$a$;
  v_new   text := $n$'prologuista','posfaciador','coordenador'$n$;
  v_occ   int;
BEGIN
  IF position($m$'posfaciador'$m$ IN v_def) > 0 THEN
    RAISE NOTICE 'postface : % connaît déjà posfaciador (rejeu), sans effet.', v_fn;
    RETURN;
  END IF;

  v_occ := (length(v_def) - length(replace(v_def, v_anc, ''))) / length(v_anc);
  IF v_occ <> 2 THEN
    RAISE EXCEPTION 'postface : ancre trouvée % fois dans % (2 attendues) — relire la définition réelle', v_occ, v_fn;
  END IF;

  EXECUTE replace(v_def, v_anc, v_new);

  IF (SELECT proacl::text FROM pg_proc WHERE oid = v_fn) IS DISTINCT FROM v_acl THEN
    RAISE EXCEPTION 'postface : les droits de % ont changé', v_fn;
  END IF;
  IF (length(pg_get_functiondef(v_fn)) - length(replace(pg_get_functiondef(v_fn), v_new, ''))) / length(v_new) <> 2 THEN
    RAISE EXCEPTION 'postface : % n''a pas les deux listes attendues après réécriture', v_fn;
  END IF;

  RAISE NOTICE 'postface : % — les deux listes de rôles connaissent posfaciador.', v_fn;
END
$postface$;

COMMIT;
