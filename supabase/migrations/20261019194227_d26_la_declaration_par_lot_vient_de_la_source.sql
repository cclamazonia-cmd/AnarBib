-- D26 (19/10/2026) : la référence d'une déclaration de droits par lot vient de
-- la SOURCE, plus du code.
--
-- NUMDIF-6 (16/10, `ef3eb581`) a fait écrire par le versement d'un candidat
-- validé par lot une note et une justification qui citaient EN DUR la règle et
-- la lettre d'Anarchief (« Rechtenregeling v0.1, carta de 15/10/2026 ») et la
-- délégation de validation (« delegação escrita de 15/10/2026 ») ; le
-- réalignement d'une ressource (`fn_digital_resource_realign_record`) citait de
-- même « (Rechtenregeling v0.1) ». Une deuxième source déclarée par lot aurait
-- reçu une référence fausse.
--
-- Désormais :
--   * la référence vit dans `ingest.partner_catalog_sources.meta` de la source
--     qui alimente la bibliothèque détentrice — clés `declaracao_lote` (la
--     déclaration de l'archiviste) et `delegacao_validacao` (la délégation de
--     validation) ; posées ici pour Anarchief.org (source 33), à l'identique du
--     texte jusqu'ici en dur ;
--   * `ingest.fn_declaration_par_lot(bibliothèque, clé)` la lit ;
--   * les deux fonctions, patchées sur leur définition RÉELLE (remplacement
--     exact, une occurrence exigée par motif), l'écrivent entre parenthèses —
--     et, faute de déclaration posée, s'en tiennent à la phrase sans référence
--     plutôt qu'à une date fausse.
-- Les 1 470 ressources déjà versées ne sont pas touchées.

CREATE OR REPLACE FUNCTION ingest.fn_declaration_par_lot(p_library_id uuid, p_cle text)
RETURNS text
LANGUAGE sql
STABLE
SET search_path = ''
AS $function$
  SELECT nullif(btrim(s.meta->>p_cle), '')
    FROM ingest.partner_catalog_sources s
   WHERE p_library_id IS NOT NULL
     AND (s.destination_library_id = p_library_id
          OR (s.destination_library_id IS NULL AND s.library_id = p_library_id))
     AND nullif(btrim(s.meta->>p_cle), '') IS NOT NULL
   ORDER BY s.id
   LIMIT 1
$function$;

REVOKE ALL ON FUNCTION ingest.fn_declaration_par_lot(uuid, text) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION ingest.fn_declaration_par_lot(uuid, text) IS
  'D26 (19/10/2026) : la référence d''une déclaration par lot (meta.declaracao_lote, meta.delegacao_validacao) de la source qui alimente la bibliothèque détentrice.';

-- La référence d'Anarchief.org, à l'identique du texte jusqu'ici en dur.
UPDATE ingest.partner_catalog_sources s
   SET meta = coalesce(s.meta, '{}'::jsonb)
              || jsonb_build_object('declaracao_lote', 'Rechtenregeling v0.1, carta de 15/10/2026',
                                    'delegacao_validacao', 'delegação escrita de 15/10/2026')
 WHERE s.id = 33
   AND s.partner_name ILIKE 'anarchief%'
   AND NOT (coalesce(s.meta, '{}'::jsonb) ? 'declaracao_lote');

DO $$
DECLARE
  v_def text;
  v_n   int;
  c_decl_old  constant text := $s$' Declaração de direitos por lote do arquivista (Rechtenregeling v0.1, carta de 15/10/2026).'$s$;
  c_deleg_old constant text := $s$', validado em lote pela administração da rede, por delegação escrita de 15/10/2026.'$s$;
  c_real_old  constant text := $s$' Declaração de direitos por lote do arquivista (Rechtenregeling v0.1).'$s$;
  c_decl_new  constant text := $s$' Declaração de direitos por lote do arquivista' || coalesce(' (' || ingest.fn_declaration_par_lot(v_c.library_id, 'declaracao_lote') || ')', '') || '.'$s$;
  c_deleg_new constant text := $s$', validado em lote pela administração da rede' || coalesce(', por ' || ingest.fn_declaration_par_lot(v_c.library_id, 'delegacao_validacao'), '') || '.'$s$;
BEGIN
  -- Le versement
  v_def := pg_get_functiondef('ingest.fn_digital_candidate_deposit_record(bigint, uuid, text, text, text, text, bigint)'::regprocedure);
  v_n := (length(v_def) - length(replace(v_def, c_decl_old, ''))) / length(c_decl_old);
  IF v_n <> 1 THEN RAISE EXCEPTION 'D26 : la déclaration en dur apparaît % fois dans le versement (1 attendue).', v_n; END IF;
  v_n := (length(v_def) - length(replace(v_def, c_deleg_old, ''))) / length(c_deleg_old);
  IF v_n <> 1 THEN RAISE EXCEPTION 'D26 : la délégation en dur apparaît % fois dans le versement (1 attendue).', v_n; END IF;
  EXECUTE replace(replace(v_def, c_decl_old, c_decl_new), c_deleg_old, c_deleg_new);

  -- Le réalignement
  v_def := pg_get_functiondef('ingest.fn_digital_resource_realign_record'::regproc);
  v_n := (length(v_def) - length(replace(v_def, c_real_old, ''))) / length(c_real_old);
  IF v_n <> 1 THEN RAISE EXCEPTION 'D26 : la déclaration en dur apparaît % fois dans le réalignement (1 attendue).', v_n; END IF;
  EXECUTE replace(v_def, c_real_old, c_decl_new);
END $$;
