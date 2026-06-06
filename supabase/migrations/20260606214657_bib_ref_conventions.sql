-- =========================================================================
-- Paquet feat — conventions de reference bibliographique par bibliotheque
-- =========================================================================
-- Session  : Exemplaires & nettoyage catalogue
-- Auteur   : Xavier + Claude
-- Chantier : Catalogage / coherence des bib_ref par biblio (#3b)
--
-- OBJET
-- -----
-- Chaque bibliotheque a sa propre convention de bib_ref (BLMF = 0000NNN sur 7
-- chiffres ; BTL = BTL-TL-NNNNNN sur 6). Jusqu'ici la saisie etait libre ->
-- incoherences. On stocke la convention sur `libraries` (prefixe + largeur de
-- zero-padding + actif) et on fournit next_bib_ref(library) qui calcule la
-- prochaine reference par incrementation logique (max existant + 1, formate).
--
-- Enforcement SOUPLE (choix utilisateur) : la fonction sert a PRE-REMPLIR /
-- suggerer cote formulaire ; aucune contrainte dure ici (pas de trigger
-- bloquant). La saisie manuelle reste possible.
-- =========================================================================

BEGIN;

ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS bib_ref_prefix text,
  ADD COLUMN IF NOT EXISTS bib_ref_pad smallint,
  ADD COLUMN IF NOT EXISTS bib_ref_auto boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.libraries.bib_ref_prefix IS 'Prefixe de la convention bib_ref (ex. '''' pour BLMF, ''BTL-TL-'' pour BTL).';
COMMENT ON COLUMN public.libraries.bib_ref_pad IS 'Largeur de zero-padding de la partie numerique (ex. 7 pour BLMF, 6 pour BTL).';
COMMENT ON COLUMN public.libraries.bib_ref_auto IS 'Si vrai : next_bib_ref suggere une reference selon la convention.';

-- Peuplement des deux conventions connues.
UPDATE public.libraries SET bib_ref_prefix = '', bib_ref_pad = 7, bib_ref_auto = true
  WHERE name ILIKE '%Maxwell Ferreira%';
UPDATE public.libraries SET bib_ref_prefix = 'BTL-TL-', bib_ref_pad = 6, bib_ref_auto = true
  WHERE name ILIKE '%Terra Livre%';

-- Fonction : prochaine bib_ref pour une bibliotheque (max existant + 1, formate).
CREATE OR REPLACE FUNCTION public.next_bib_ref(p_library_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_prefix text;
  v_pad    int;
  v_auto   boolean;
  v_max    bigint;
BEGIN
  IF NOT public.user_has_library_staff_role(auth.uid(), p_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff da biblioteca.' USING errcode = '42501';
  END IF;

  SELECT bib_ref_prefix, bib_ref_pad, bib_ref_auto
    INTO v_prefix, v_pad, v_auto
    FROM public.libraries WHERE id = p_library_id;

  IF NOT COALESCE(v_auto, false) THEN
    RETURN NULL;   -- pas de convention active -> rien a suggerer
  END IF;
  v_prefix := COALESCE(v_prefix, '');
  v_pad := GREATEST(COALESCE(v_pad, 1), 1);

  -- Max de la partie numerique des references existantes de la biblio
  -- (local_bib_ref du holding sinon bib_ref de la notice).
  -- Largeur >= pad : exclut les refs courtes hors-convention (ex. l'intrus
  -- "2453" a 4 chiffres ne pollue pas le max BLMF qui est sur 7 chiffres).
  SELECT max((substring(ref FROM ('^' || v_prefix || '([0-9]{' || v_pad || ',})$')))::bigint)
    INTO v_max
  FROM (
    SELECT COALESCE(NULLIF(h.local_bib_ref, ''), b.bib_ref) AS ref
    FROM public.book_holdings h
    JOIN public.books b ON b.id = h.book_id
    WHERE h.library_id = p_library_id
  ) x
  WHERE ref ~ ('^' || v_prefix || '[0-9]{' || v_pad || ',}$');

  RETURN v_prefix || lpad((COALESCE(v_max, 0) + 1)::text, v_pad, '0');
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.next_bib_ref(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.next_bib_ref(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : DROP FUNCTION public.next_bib_ref(uuid);
--            ALTER TABLE public.libraries DROP COLUMN bib_ref_prefix,
--            DROP COLUMN bib_ref_pad, DROP COLUMN bib_ref_auto;
-- =========================================================================
