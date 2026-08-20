-- =========================================================================
-- Paquet DOUBLONS P4 — l'arbitrage destructeur passe à la coordination
-- =========================================================================
-- Date     : 2026-08-20
-- Chantier : catalogage / dédoublonnage (lot 1 du plan « Dédoublonner sans casser »)
-- Auteur   : Xavier (+ Claude)
-- Session  : Dédoublonnage & arbitrage
--
-- POURQUOI. Trois gestes du catalogage détruisent des données sans retour
-- arrière — merge_book, merge_author, et l'arbitrage « pas un doublon » — et
-- tous trois sont aujourd'hui ouverts à n'importe quel membre du staff, y
-- compris un·e catalogueur·se militant·e moyennement formé·e, sous la même
-- apparence que des actions inoffensives posées juste à côté. La fusion ne
-- conserve que les métadonnées de la notice survivante : choisir la mauvaise
-- fait disparaître une attribution bibliographique pour toujours.
--
-- Le relevé du 20/08/2026 le rend concret : sur 266 paires détectées, 254 sont
-- des rapprochements de titre où la bonne action est « Même œuvre » et non la
-- fusion. On expose donc un bouton destructeur sur une liste dont 95 % des
-- lignes n'appellent pas de destruction.
--
-- CE QUE FAIT CE PAQUET.
--   1. fn_is_dedup_arbiter() — un seul endroit où se définit « qui peut
--      arbitrer » : coordination active d'une bibliothèque, ou administration
--      réseau active. Les quatre fonctions destructrices s'y réfèrent, pour
--      qu'aucune ne puisse dériver.
--   2. merge_book, merge_author, mark_books_not_duplicate et
--      unmark_books_not_duplicate exigent désormais ce niveau. Écarter et
--      rétablir sont relevés ENSEMBLE (cf. paquet P3) : il ne doit jamais
--      exister d'état où l'on peut écarter sans pouvoir rétablir.
--   3. catalog_duplicate_reports — le signalement, qui rend au poste de
--      catalogage un geste utile et sans danger. Le catalogueur a le livre en
--      main : il est le seul à savoir que MLEG-0016 et MLEG-0017 sont deux
--      VOLUMES et pas un doublon. On lui retire le pouvoir de détruire, pas sa
--      connaissance du terrain.
--
-- DEUX TROUS REFERMÉS AU PASSAGE.
--   • merge_author ne vérifiait pas status = 'active' : un rattachement révoqué
--     continuait d'autoriser la fusion d'autorités.
--   • La garde de rattachement de merge_book (20/08) acceptait toute ligne de
--     network_administrators, sans filtrer status = 'active' — contrairement à
--     la convention suivie partout ailleurs. Un·e admin réseau retiré·e gardait
--     donc le droit de fusionner.
--
-- CE QUE CE PAQUET NE TOUCHE PAS. La fusion de BROUILLONS
-- (merge_book_drafts, merge_draft_into_book) reste ouverte au staff : un
-- brouillon en double part à la corbeille, c'est réversible, et c'est le
-- travail quotidien de la file. La restreindre coûterait beaucoup sans rien
-- protéger. Les détections (suggest_*) et la lecture des paires écartées
-- restent elles aussi au niveau staff : lire n'a jamais rien cassé.
--
-- CHECKLIST DOCTRINE :
--   [x] Fonctions SECURITY DEFINER : SET search_path, REVOKE FROM PUBLIC/anon,
--       GRANT TO authenticated, garde interne
--   [x] Table dans public : GRANT explicites, RLS activée, une policy par
--       opération autorisée, GRANT ALL TO service_role
--   [x] DO block de vérification (la migration touche des droits)
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Qui peut arbitrer ? Une seule définition.
-- -------------------------------------------------------------------------
-- Volontairement STABLE et sans effet de bord : c'est un prédicat, appelé au
-- début de chaque fonction destructrice. Le jour où le périmètre change, il
-- change ici et nulle part ailleurs — c'est tout l'intérêt.
CREATE OR REPLACE FUNCTION public.fn_is_dedup_arbiter()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT EXISTS (
           SELECT 1 FROM public.network_administrators na
            WHERE na.user_id = auth.uid() AND na.status = 'active'
         )
      OR EXISTS (
           SELECT 1 FROM public.user_library_memberships m
            WHERE m.user_id = auth.uid()
              AND m.role = 'coordenador'
              AND m.status = 'active'
         );
$function$;

REVOKE ALL ON FUNCTION public.fn_is_dedup_arbiter() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_is_dedup_arbiter() TO authenticated;

COMMENT ON FUNCTION public.fn_is_dedup_arbiter() IS
  'Vrai si le compte courant peut arbitrer un doublon de façon destructrice : coordination '
  'active d''une bibliothèque, ou administration réseau active. Définition unique, partagée '
  'par merge_book, merge_author, mark_books_not_duplicate et unmark_books_not_duplicate. '
  'Paquet DOUBLONS P4 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 2. Le signalement : ce qui reste au poste de catalogage
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.catalog_duplicate_reports (
  id          bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  book_id_a   bigint NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  book_id_b   bigint NOT NULL REFERENCES public.books(id) ON DELETE CASCADE,
  note        text,
  reported_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  status      text NOT NULL DEFAULT 'open',
  closed_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  closed_at   timestamptz,
  CONSTRAINT catalog_duplicate_reports_ordered CHECK (book_id_a < book_id_b),
  CONSTRAINT catalog_duplicate_reports_status  CHECK (status IN ('open', 'closed'))
);

-- Un seul signalement OUVERT par paire : sans cela, cinq bibliothécaires
-- tombant sur le même doublon noieraient la file de la coordination.
CREATE UNIQUE INDEX IF NOT EXISTS catalog_duplicate_reports_open_uniq
  ON public.catalog_duplicate_reports (book_id_a, book_id_b)
  WHERE status = 'open';

CREATE INDEX IF NOT EXISTS catalog_duplicate_reports_status_idx
  ON public.catalog_duplicate_reports (status, created_at DESC);

-- Écriture par RPC uniquement (les gardes y sont) ; lecture directe interdite,
-- list_duplicate_reports sert les titres que la table ne stocke pas.
REVOKE ALL ON public.catalog_duplicate_reports FROM anon, authenticated;
GRANT ALL ON public.catalog_duplicate_reports TO service_role;

ALTER TABLE public.catalog_duplicate_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies
                  WHERE schemaname = 'public' AND tablename = 'catalog_duplicate_reports'
                    AND policyname = 'catalog_duplicate_reports_staff_select') THEN
    CREATE POLICY catalog_duplicate_reports_staff_select
      ON public.catalog_duplicate_reports
      FOR SELECT TO authenticated
      USING (EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = auth.uid()
                        AND m.role = ANY (ARRAY['librarian','coordenador'])
                        AND m.status = 'active'));
  END IF;
END $$;

COMMENT ON TABLE public.catalog_duplicate_reports IS
  'Doublons signalés par le staff de catalogage à la coordination. Le signalement est le '
  'geste non destructeur laissé au poste de catalogage depuis le paquet DOUBLONS P4 '
  '(21/08/2026), en échange des boutons de fusion. Un seul signalement ouvert par paire.';

-- -------------------------------------------------------------------------
-- 3. Signaler — ouvert à tout le staff de catalogage
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.report_duplicate_pair(
  p_a    bigint,
  p_b    bigint,
  p_note text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_lo bigint;
  v_hi bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_a)
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_b) THEN
    RAISE EXCEPTION 'Documento inexistente.'
      USING ERRCODE = 'P0002', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  -- Signaler deux fois la même paire n'est pas une erreur : c'est le même
  -- constat, fait par deux personnes. On ne crée pas de doublon de signalement.
  INSERT INTO public.catalog_duplicate_reports (book_id_a, book_id_b, note, reported_by)
  SELECT v_lo, v_hi, nullif(btrim(coalesce(p_note, '')), ''), auth.uid()
  WHERE NOT EXISTS (
    SELECT 1 FROM public.catalog_duplicate_reports r
     WHERE r.book_id_a = v_lo AND r.book_id_b = v_hi AND r.status = 'open'
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.report_duplicate_pair(bigint, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.report_duplicate_pair(bigint, bigint, text) TO authenticated;

COMMENT ON FUNCTION public.report_duplicate_pair(bigint, bigint, text) IS
  'Signale une paire de documents à la coordination, sans rien modifier au catalogue. '
  'Ouvert à tout le staff de catalogage. Idempotent tant qu''un signalement reste ouvert.';

-- -------------------------------------------------------------------------
-- 4. Lire et clore les signalements — coordination
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_duplicate_reports(p_max integer DEFAULT 200)
RETURNS TABLE (
  book_id_a        bigint,
  ref_a            text,
  titulo_a         text,
  autor_a          text,
  ano_a            text,
  book_id_b        bigint,
  ref_b            text,
  titulo_b         text,
  autor_b          text,
  ano_b            text,
  note             text,
  created_at       timestamptz,
  reported_by_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- Lecture au niveau staff : un·e bibliothécaire doit pouvoir vérifier que son
  -- signalement est bien parti, sinon il signalera de nouveau.
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian','coordenador'])
                   AND m.status = 'active') THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  RETURN QUERY
  SELECT
    ba.id, ba.bib_ref, ba.titulo, ba.autor, ba.ano,
    bb.id, bb.bib_ref, bb.titulo, bb.autor, bb.ano,
    r.note,
    r.created_at,
    nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
  FROM public.catalog_duplicate_reports r
  JOIN public.books ba ON ba.id = r.book_id_a
  JOIN public.books bb ON bb.id = r.book_id_b
  LEFT JOIN public.profiles p ON p.id = r.reported_by
  WHERE r.status = 'open'
  ORDER BY r.created_at ASC   -- le plus ancien d'abord : rien ne doit pourrir en file
  LIMIT greatest(1, coalesce(p_max, 200));
END;
$function$;

REVOKE ALL ON FUNCTION public.list_duplicate_reports(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_duplicate_reports(integer) TO authenticated;

COMMENT ON FUNCTION public.list_duplicate_reports(integer) IS
  'Signalements de doublons encore ouverts, le plus ancien d''abord, avec titres et '
  'personne ayant signalé. Staff de catalogage. Paquet DOUBLONS P4 du 21/08/2026.';

CREATE OR REPLACE FUNCTION public.close_duplicate_report(p_a bigint, p_b bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  UPDATE public.catalog_duplicate_reports
     SET status = 'closed', closed_by = auth.uid(), closed_at = now()
   WHERE book_id_a = least(p_a, p_b)
     AND book_id_b = greatest(p_a, p_b)
     AND status = 'open';
END;
$function$;

REVOKE ALL ON FUNCTION public.close_duplicate_report(bigint, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_duplicate_report(bigint, bigint) TO authenticated;

COMMENT ON FUNCTION public.close_duplicate_report(bigint, bigint) IS
  'Clôt le signalement ouvert d''une paire, une fois la décision prise. Coordination '
  'uniquement. Paquet DOUBLONS P4 du 21/08/2026.';

-- -------------------------------------------------------------------------
-- 5. Les quatre gestes destructeurs passent à la coordination
-- -------------------------------------------------------------------------

-- 5a. Écarter une paire — corps du paquet P3, seule la garde change.
CREATE OR REPLACE FUNCTION public.mark_books_not_duplicate(
  p_a      bigint,
  p_b      bigint,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_lo bigint;
  v_hi bigint;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_a)
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_b) THEN
    RAISE EXCEPTION 'Documento inexistente.'
      USING ERRCODE = 'P0002', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  INSERT INTO public.book_not_duplicate (book_id_a, book_id_b, created_by, reason)
  VALUES (v_lo, v_hi, auth.uid(), nullif(btrim(coalesce(p_reason, '')), ''))
  ON CONFLICT (book_id_a, book_id_b) DO NOTHING;

  -- Arbitrer une paire signalée répond au signalement : le laisser ouvert
  -- ferait revenir la coordination sur une décision déjà prise.
  UPDATE public.catalog_duplicate_reports
     SET status = 'closed', closed_by = auth.uid(), closed_at = now()
   WHERE book_id_a = v_lo AND book_id_b = v_hi AND status = 'open';
END;
$function$;

COMMENT ON FUNCTION public.mark_books_not_duplicate(bigint, bigint, text) IS
  'Écarte définitivement une paire de documents des détections de doublons, avec motif '
  'facultatif, et clôt le signalement éventuel. Réversible via unmark_books_not_duplicate. '
  'Coordination uniquement depuis le paquet DOUBLONS P4 (21/08/2026).';

-- 5b. Rétablir — relevé EN MÊME TEMPS qu'écarter, jamais séparément.
CREATE OR REPLACE FUNCTION public.unmark_books_not_duplicate(
  p_a bigint,
  p_b bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_lo bigint;
  v_hi bigint;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Par de documentos inválido.'
      USING ERRCODE = 'P0001', HINT = 'error.catalog.notDuplicate.invalidPair';
  END IF;

  v_lo := least(p_a, p_b);
  v_hi := greatest(p_a, p_b);

  DELETE FROM public.book_not_duplicate
  WHERE book_id_a = v_lo AND book_id_b = v_hi;
END;
$function$;

COMMENT ON FUNCTION public.unmark_books_not_duplicate(bigint, bigint) IS
  'Rétablit une paire écartée : elle réapparaît dans les détections. Aucun document n''est '
  'modifié. Coordination uniquement depuis le paquet DOUBLONS P4 (21/08/2026) — relevé en '
  'même temps que mark_books_not_duplicate, pour qu''on ne puisse jamais écarter sans '
  'pouvoir rétablir.';

-- 5c. Fusion d'autorités — garde relevée, et status = 'active' enfin vérifié.
CREATE OR REPLACE FUNCTION public.merge_author(p_canonical_id bigint, p_duplicate_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_dup_name text;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;
  SELECT preferred_name INTO v_dup_name FROM public.authors WHERE id = p_duplicate_id;
  IF v_dup_name IS NULL THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id = p_canonical_id) THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  UPDATE public.book_contributors SET author_id = p_canonical_id WHERE author_id = p_duplicate_id;
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
    SELECT book_id, p_canonical_id, role, ord FROM public.book_authors WHERE author_id = p_duplicate_id
    ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;
  DELETE FROM public.book_authors WHERE author_id = p_duplicate_id;
  UPDATE public.author_translations t SET author_id = p_canonical_id
    WHERE t.author_id = p_duplicate_id
      AND NOT EXISTS (SELECT 1 FROM public.author_translations c
                       WHERE c.author_id = p_canonical_id AND c.lang = t.lang);
  UPDATE public.author_name_aliases SET author_id = p_canonical_id WHERE author_id = p_duplicate_id;
  UPDATE public.author_drafts SET published_author_id = p_canonical_id WHERE published_author_id = p_duplicate_id;
  UPDATE public.book_draft_contributors SET author_id = p_canonical_id WHERE author_id = p_duplicate_id;
  UPDATE public.works SET primary_author_id = p_canonical_id WHERE primary_author_id = p_duplicate_id;

  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('author', p_canonical_id, p_duplicate_id,
          jsonb_build_object('duplicate_preferred_name', v_dup_name), auth.uid());

  DELETE FROM public.authors WHERE id = p_duplicate_id;
END;
$function$;

COMMENT ON FUNCTION public.merge_author(bigint, bigint) IS
  'Fusionne deux autorités : le doublon est rattaché à la canonique puis supprimé. '
  'Coordination uniquement depuis le paquet DOUBLONS P4 (21/08/2026), qui vérifie enfin '
  'status = ''active'' — un rattachement révoqué autorisait la fusion jusque-là.';

-- 5d. Fusion de notices — garde relevée, corps repris à l'identique du 20/08.
--     La garde de rattachement est conservée ET durcie : elle exige maintenant
--     la coordination de l'une des bibliothèques détentrices, et ne reconnaît
--     plus qu'une administration réseau ACTIVE.
CREATE OR REPLACE FUNCTION public.merge_book(p_canonical_id bigint, p_duplicate_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $fn$
DECLARE
  v_dup_titulo text;
  dh           record;
  v_ch_id      bigint;
BEGIN
  IF NOT public.fn_is_dedup_arbiter() THEN
    RAISE EXCEPTION 'Arbitragem reservada à coordenação.'
      USING ERRCODE = '42501', HINT = 'error.catalog.arbiter_only';
  END IF;

  -- Garde de rattachement (2026-08-20, durcie le 2026-08-21). Fusionner deux
  -- notices qui appartiennent à d'autres bibliothèques que la sienne engage des
  -- collectifs dont on n'est pas membre.
  IF NOT EXISTS (SELECT 1 FROM public.network_administrators na
                  WHERE na.user_id = auth.uid() AND na.status = 'active')
     AND EXISTS (SELECT 1 FROM public.book_holdings h
                 WHERE h.book_id IN (p_canonical_id, p_duplicate_id))
     AND NOT EXISTS (
       SELECT 1
       FROM public.book_holdings h
       JOIN public.user_library_memberships m
         ON m.library_id = h.library_id
        AND m.user_id = auth.uid()
        AND m.status = 'active'
        AND m.role = 'coordenador'
       WHERE h.book_id IN (p_canonical_id, p_duplicate_id)
     ) THEN
    RAISE EXCEPTION 'Fusao restrita a coordenacao de uma das bibliotecas detentoras (ou a administracao da rede).'
      USING ERRCODE = '42501', HINT = 'error.catalog.merge_not_related';
  END IF;

  IF p_canonical_id = p_duplicate_id THEN
    RAISE EXCEPTION 'Canonico e duplicado identicos.';
  END IF;
  SELECT titulo INTO v_dup_titulo FROM public.books WHERE id = p_duplicate_id;
  IF v_dup_titulo IS NULL THEN
    RAISE EXCEPTION 'Duplicado % inexistente.', p_duplicate_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = p_canonical_id) THEN
    RAISE EXCEPTION 'Canonico % inexistente.', p_canonical_id;
  END IF;

  -- 1. Holdings : fusionner (meme bibliotheque) ou repointer.
  FOR dh IN SELECT * FROM public.book_holdings WHERE book_id = p_duplicate_id LOOP
    SELECT id INTO v_ch_id
      FROM public.book_holdings
      WHERE book_id = p_canonical_id AND library_id = dh.library_id
      LIMIT 1;

    IF v_ch_id IS NOT NULL THEN
      -- Fusion : tout ce qui pointe vers le holding doublon bascule sur le canonique.
      UPDATE public.exemplares                 SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.emprestimo_itens_v2        SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.reserva_linhas_v2          SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.interlibrary_loan_items_v2 SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.consulta_linhas_v2         SET holding_id = v_ch_id WHERE holding_id = dh.id;
      UPDATE public.exemplar_drafts            SET target_holding_id = v_ch_id WHERE target_holding_id = dh.id;
      DELETE FROM public.book_holdings WHERE id = dh.id;
    ELSE
      -- Repoint : le holding (avec ses exemplaires et refs) bascule sur le canonique.
      UPDATE public.book_holdings SET book_id = p_canonical_id WHERE id = dh.id;
    END IF;
  END LOOP;

  -- 2. Circulation au niveau livre : repoint book_id (caches/FK).
  UPDATE public.emprestimo_itens_v2        SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.reserva_linhas_v2          SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.interlibrary_loan_items_v2 SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;
  UPDATE public.consulta_linhas_v2         SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 3. Ressources numeriques.
  UPDATE public.digital_assets SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 4. Wishlist : dedupe (UNIQUE user_id,book_id) puis repoint.
  DELETE FROM public.user_wishlist w
    WHERE w.book_id = p_duplicate_id
      AND EXISTS (SELECT 1 FROM public.user_wishlist w2
                  WHERE w2.user_id = w.user_id AND w2.book_id = p_canonical_id);
  UPDATE public.user_wishlist SET book_id = p_canonical_id WHERE book_id = p_duplicate_id;

  -- 5. Brouillons pointant vers le doublon.
  UPDATE public.book_drafts SET published_book_id = p_canonical_id WHERE published_book_id = p_duplicate_id;

  -- 6. Journaliser.
  INSERT INTO public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  VALUES ('book', p_canonical_id, p_duplicate_id,
          jsonb_build_object('duplicate_titulo', v_dup_titulo), auth.uid());

  -- 7. Supprimer le doublon (cascade : book_authors/contributors/catalog_context,
  --    et le signalement eventuel, qui n'a plus d'objet).
  DELETE FROM public.books WHERE id = p_duplicate_id;

  -- 8. Recalcul des compteurs de disponibilite du canonique.
  PERFORM public.fn_v2_recompute_holdings_availability(NULL, ARRAY[p_canonical_id]);
END;
$fn$;

COMMENT ON FUNCTION public.merge_book(bigint, bigint) IS
  'Fusionne deux notices. Coordination uniquement depuis le paquet DOUBLONS P4 '
  '(21/08/2026), et coordination d''une des bibliothèques détentrices — ou administration '
  'réseau ACTIVE. Corps inchangé depuis le 20/08/2026.';

-- -------------------------------------------------------------------------
-- 6. Vérification (rollback automatique en cas d'échec)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_n    int;
  v_lack text;
BEGIN
  -- Les quatre gestes destructeurs doivent TOUS passer par le prédicat unique.
  -- Une garde oubliée ici, c'est le trou que ce paquet est censé fermer.
  SELECT string_agg(pr.proname, ', ') INTO v_lack
  FROM pg_proc pr
  JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public'
    AND pr.proname IN ('merge_book', 'merge_author',
                       'mark_books_not_duplicate', 'unmark_books_not_duplicate')
    AND pg_get_functiondef(pr.oid) NOT LIKE '%fn_is_dedup_arbiter()%';

  IF v_lack IS NOT NULL THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P4 : % n''appelle(nt) pas fn_is_dedup_arbiter. Rollback.', v_lack;
  END IF;

  -- Rien de tout cela ne doit être exécutable par anon.
  SELECT count(*) INTO v_n
  FROM pg_proc pr
  JOIN pg_namespace ns ON ns.oid = pr.pronamespace
  WHERE ns.nspname = 'public'
    AND pr.proname IN ('fn_is_dedup_arbiter', 'report_duplicate_pair',
                       'list_duplicate_reports', 'close_duplicate_report')
    AND has_function_privilege('anon', pr.oid, 'EXECUTE');

  IF v_n > 0 THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P4 : % fonction(s) exécutables par anon. Rollback.', v_n;
  END IF;

  -- La table des signalements ne doit pas être écrivable en direct.
  IF has_table_privilege('authenticated', 'public.catalog_duplicate_reports', 'INSERT') THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P4 : catalog_duplicate_reports est insérable en direct. Rollback.';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_tables
                  WHERE schemaname = 'public' AND tablename = 'catalog_duplicate_reports'
                    AND rowsecurity) THEN
    RAISE EXCEPTION 'Paquet DOUBLONS P4 : RLS absente sur catalog_duplicate_reports. Rollback.';
  END IF;

  RAISE NOTICE 'Paquet DOUBLONS P4 : vérifications OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé : reprendre les corps du paquet DOUBLONS P3
-- (20260821020001) pour mark/unmark, du 20260819222838 pour merge_book et du
-- 20260620090724 pour merge_author, puis :
--   BEGIN;
--     DROP FUNCTION IF EXISTS public.close_duplicate_report(bigint, bigint);
--     DROP FUNCTION IF EXISTS public.list_duplicate_reports(integer);
--     DROP FUNCTION IF EXISTS public.report_duplicate_pair(bigint, bigint, text);
--     DROP TABLE IF EXISTS public.catalog_duplicate_reports;
--     DROP FUNCTION IF EXISTS public.fn_is_dedup_arbiter();
--   COMMIT;
-- =========================================================================
