-- =====================================================================
-- AnarBib — Tests : le thésaurus FICEDL rejoué depuis zéro est celui de la production
-- Date    : 2026-09-24  ·  item H11  ·  doctrines DOC-SILENCE-1, DOC-MIGR-1 (esprit)
-- Réf     : supabase/migrations/20260826191000 (462 termes, 30/06),
--           supabase/migrations/20260924*_donnees_ficedl_thesaurus_2026_09_03 (621, 03/09),
--           scripts/ficedl_thesaurus_sync.mjs (le mapping), docs/journal/ficedl/
--
-- CE QUE CETTE SUITE PROUVE.
--   Que le dépôt, appliqué de bout en bout sur une base neuve, produit la table
--   ficedl_thesaurus_terms de la production du 03/09/2026 : 621 termes, dont
--   159 dates, un seul horodatage d'aspiration, et la même EMPREINTE (md5 des
--   lignes dans l'ordre des mot_id). L'empreinte est IMPRIMÉE dans le bilan :
--   c'est ce qui permet, depuis le journal de la CI, de la comparer à celle
--   de la production sans rien lancer d'autre.
--   Et qu'un alignement vers un descripteur de la facette « dates » — ce que
--   H10 va poser — passe la clé étrangère de subject_ficedl_links.
--
-- CE QU'ELLE NE PROUVE PAS.
--   Rien sur la production elle-même. L'empreinte de référence ci-dessous est
--   celle du DÉPÔT rejoué (relevée le 24/09/2026 sur le rejeu local) ; la
--   production du 24/09 au matin en différait sur deux lignes (mot136, mot137 :
--   drapeau « hors_liste_cira » posé par la ré-aspiration de 13 h 17, après le
--   sync de 11 h 07) et la rejoint au déploiement de la migration. Le jour où
--   le sync sera rejoué là-bas, cette suite rougira — c'est voulu : il faudra
--   régénérer la migration de données (H11 dit comment), pas ajuster le test.
--   Les sujets n'existent pas en CI (migrations avant le seed) : T7 crée le
--   sien, dans la transaction annulée à la fin.
--
-- Convention : bilan « FICEDL-TERMES OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  ok int := 0; total int := 7;
  n int; d int; h int; empreinte text; sujet int; lien int;
  attendu_empreinte constant text := '8d1e585e67e3c5f7059532a41adabcd0';
  mot_date text;
BEGIN
  -- T1 : 621 termes
  SELECT count(*) INTO n FROM public.ficedl_thesaurus_terms;
  IF n = 621 THEN ok := ok + 1; ELSE RAISE WARNING 'T1 ficedl_thesaurus_terms : % termes, attendu 621', n; END IF;

  -- T2 : 159 dates, avec un libellé français chacune
  SELECT count(*) INTO d FROM public.ficedl_thesaurus_terms WHERE 'dates' = ANY(facet);
  IF d = 159 THEN ok := ok + 1; ELSE RAISE WARNING 'T2 dates : %, attendu 159', d; END IF;

  SELECT count(*) INTO n FROM public.ficedl_thesaurus_terms WHERE 'dates' = ANY(facet) AND coalesce(labels->>'fr', '') = '';
  IF n = 0 THEN ok := ok + 1; ELSE RAISE WARNING 'T3 % dates sans libellé fr', n; END IF;

  -- T4 : un seul horodatage d'aspiration, celui du 03/09
  SELECT count(DISTINCT harvested_at) INTO h FROM public.ficedl_thesaurus_terms;
  IF h = 1 AND (SELECT min(harvested_at) FROM public.ficedl_thesaurus_terms) = '2026-09-03 11:07:57.616+00'::timestamptz THEN ok := ok + 1;
  ELSE RAISE WARNING 'T4 harvested_at : % valeur(s), min %', h, (SELECT min(harvested_at) FROM public.ficedl_thesaurus_terms); END IF;

  -- T5 : les deux fiches de l'aspiration sans libellé ni H1 (mot532, mot538) ne sont pas
  --      entrées : aucune ligne sans libellé du tout
  SELECT count(*) INTO n FROM public.ficedl_thesaurus_terms WHERE labels = '{}'::jsonb OR labels IS NULL;
  IF n = 0 THEN ok := ok + 1; ELSE RAISE WARNING 'T5 % terme(s) sans aucun libellé', n; END IF;

  -- T6 : l'EMPREINTE de la table = celle du dépôt rejoué (= production après le déploiement du 24/09)
  SELECT md5(string_agg(mot_id||'|'||facet::text||'|'||labels::text||'|'||coalesce(el_roman,'')||'|'||hierarchy::text||'|'||coalesce(depth::text,'')||'|'||catalog_links::text||'|'||import_normalizations::text||'|'||import_flags::text||'|'||coalesce(source_url,'')||'|'||harvested_at::text, E'\n' ORDER BY mot_id))
    INTO empreinte FROM public.ficedl_thesaurus_terms;
  IF empreinte = attendu_empreinte THEN ok := ok + 1;
  ELSE RAISE WARNING 'T6 empreinte % ≠ attendue %', empreinte, attendu_empreinte; END IF;

  -- T7 : un alignement vers un descripteur « dates » passe la clé étrangère (H10).
  --      Aucun sujet n'existe en CI : on en crée un, annulé avec la transaction.
  INSERT INTO public.subjects (slug, label_i18n) VALUES ('h11-essai-date', '{"fr": "essai H11"}'::jsonb) RETURNING id INTO sujet;
  SELECT mot_id INTO mot_date FROM public.ficedl_thesaurus_terms WHERE 'dates' = ANY(facet) ORDER BY mot_id LIMIT 1;
  IF sujet IS NULL OR mot_date IS NULL THEN
    RAISE WARNING 'T7 pas de sujet ou pas de date pour l''essai';
  ELSE
    INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type) VALUES (sujet, mot_date, 'broad')
      ON CONFLICT (subject_id, mot_id) DO NOTHING;
    SELECT count(*) INTO lien FROM public.subject_ficedl_links WHERE subject_id = sujet AND mot_id = mot_date;
    IF lien = 1 THEN ok := ok + 1; ELSE RAISE WARNING 'T7 alignement vers % non posé', mot_date; END IF;
  END IF;

  IF ok = total THEN
    RAISE NOTICE 'FICEDL-TERMES OK : %/% tests passés — 621 termes, 159 dates, empreinte % (dépôt rejoué = production depuis le déploiement du 24/09/2026)', ok, total, empreinte;
  ELSE
    RAISE EXCEPTION 'FICEDL-TERMES ECHEC : %/% tests passés — empreinte %', ok, total, empreinte;
  END IF;
END $$;

ROLLBACK;
