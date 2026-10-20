-- =====================================================================
-- AnarBib — Tests d'acceptation : les autorités d'Anarchief entrent en revue
-- Date    : 2026-10-20
-- Ref     : migration 20261020194156_c33_les_autorites_d_anarchief_entrent_en_revue
--
-- Fixture : quatre autorités de la source « Anarchief.org · import 2026-10 »
-- (une personne en forme inversée avec Wikidata, une en forme directe, une
-- collectivité, une personne déjà en file au lot `autorite_forme`), et une
-- autorité d'une autre source. La migration est jouée deux fois (\ir).
-- T1 chaque autorité de la source a sa ligne : personnes au lot
--    `autorite_forme`, collectivité au lot `autorite_collectivite` ; l'autre
--    source n'entre pas ; « à revoir », contexte « Anarchief ».
-- T2 propositions : la forme inversée reste elle-même, la forme directe est
--    retournée (« Jansen, Jan ») ; la note dit le Wikidata ou son absence.
-- T3 la ligne déjà en file ne bouge pas ; le second passage n'ajoute rien.
-- T4 valider puis appliquer (coordination) : la forme confirmée reste, la
--    ligne est marquée appliquée ; corriger écrit la forme retenue.
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'C33-ANARCHIEF-REVUE OK : N/N'
-- =====================================================================
BEGIN;

CREATE TEMP TABLE c33_ids (cle text PRIMARY KEY, id bigint) ON COMMIT DROP;

DO $$
DECLARE v_id bigint;
BEGIN
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, source_label, wikidata_id)
  VALUES ('Bankema, Piet', 'Piet Bankema', 'person', 'Anarchief.org · import 2026-10', 'Q999999901') RETURNING id INTO v_id;
  INSERT INTO c33_ids VALUES ('inversee', v_id);
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, source_label)
  VALUES ('Jan Jansen', 'Jan Jansen', 'person', 'Anarchief.org · import 2026-10') RETURNING id INTO v_id;
  INSERT INTO c33_ids VALUES ('directe', v_id);
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, source_label)
  VALUES ('Vrije Bankgroep', 'Vrije Bankgroep', 'collective', 'Anarchief.org · import 2026-10') RETURNING id INTO v_id;
  INSERT INTO c33_ids VALUES ('collectivite', v_id);
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, source_label)
  VALUES ('Deja, Klaas', 'Klaas Deja', 'person', 'Anarchief.org · import 2026-10') RETURNING id INTO v_id;
  INSERT INTO c33_ids VALUES ('deja', v_id);
  INSERT INTO public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose, decision, note)
  VALUES ('autorite_forme', 'author', v_id, 'Deja, Klaas', 'Deja, Klaas', 'valide', 'ligne d''avant');
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, source_label)
  VALUES ('Autre, Source', 'Source Autre', 'person', 'Banc C33 · autre') RETURNING id INTO v_id;
  INSERT INTO c33_ids VALUES ('autre', v_id);
END $$;

\ir ../../supabase/migrations/20261020194156_c33_les_autorites_d_anarchief_entrent_en_revue.sql
CREATE TEMP TABLE c33_compte ON COMMIT DROP AS SELECT count(*) AS n FROM public.catalog_review_queue;
\ir ../../supabase/migrations/20261020194156_c33_les_autorites_d_anarchief_entrent_en_revue.sql

DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_x text;
  f_id bigint; f_dir bigint; f_col bigint; f_deja bigint; f_autre bigint;
BEGIN
  SELECT id INTO f_id FROM c33_ids WHERE cle = 'inversee';
  SELECT id INTO f_dir FROM c33_ids WHERE cle = 'directe';
  SELECT id INTO f_col FROM c33_ids WHERE cle = 'collectivite';
  SELECT id INTO f_deja FROM c33_ids WHERE cle = 'deja';
  SELECT id INTO f_autre FROM c33_ids WHERE cle = 'autre';

  v_t := 'T1 chaque autorité de la source a sa ligne, au bon lot';
  SELECT string_agg(c.cle || '=' || q.lot || '/' || q.decision || '/' || coalesce(q.contexte, '∅'), ',' ORDER BY c.cle) INTO v_x
    FROM c33_ids c JOIN public.catalog_review_queue q ON q.entity_kind = 'author' AND q.entity_id = c.id;
  IF v_x = 'collectivite=autorite_collectivite/a_revoir/Anarchief,deja=autorite_forme/valide/∅,directe=autorite_forme/a_revoir/Anarchief,inversee=autorite_forme/a_revoir/Anarchief'
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_x,'∅')); END IF;

  v_t := 'T2 propositions et notes';
  IF (SELECT apres_propose FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = f_id) = 'Bankema, Piet'
     AND (SELECT apres_propose FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = f_dir) = 'Jansen, Jan'
     AND (SELECT apres_propose FROM public.catalog_review_queue WHERE lot = 'autorite_collectivite' AND entity_id = f_col) = 'Vrije Bankgroep'
     AND (SELECT note FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = f_id) LIKE '%Wikidata Q999999901 à confirmer%'
     AND (SELECT note FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = f_dir) LIKE '%sans identifiant externe%'
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  v_t := 'T3 la ligne d''avant ne bouge pas ; le second passage n''ajoute rien';
  IF (SELECT note FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id = f_deja) = 'ligne d''avant'
     AND (SELECT count(*) FROM public.catalog_review_queue) = (SELECT n FROM c33_compte)
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  v_t := 'T4 valider ou corriger, puis appliquer';
  BEGIN
    UPDATE public.catalog_review_queue SET decision = 'valide' WHERE lot = 'autorite_forme' AND entity_id = f_id;
    UPDATE public.catalog_review_queue SET decision = 'corrige', valeur_retenue = 'Jansen, Jan Willem'
     WHERE lot = 'autorite_forme' AND entity_id = f_dir;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated', 'aal', 'aal2')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM api.conv_revue_appliquer('autorite_forme');
    EXECUTE 'RESET ROLE';
    SELECT (SELECT sort_name FROM public.authors WHERE id = f_id) || '|'
        || (SELECT sort_name FROM public.authors WHERE id = f_dir) || '|'
        || (SELECT count(*) FROM public.catalog_review_queue WHERE lot = 'autorite_forme' AND entity_id IN (f_id, f_dir) AND applique_le IS NOT NULL)
      INTO v_x;
    IF v_x = 'Bankema, Piet|Jansen, Jan Willem|2' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_x,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF NOT EXISTS (SELECT 1 FROM public.catalog_review_queue WHERE entity_kind = 'author' AND entity_id = f_autre) THEN NULL;
  ELSE v_failed := v_failed+1; v_failures := v_failures||'T1 bis : une autorité d''une autre source est entrée'; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'C33-ANARCHIEF-REVUE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'C33-ANARCHIEF-REVUE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;

ROLLBACK;
