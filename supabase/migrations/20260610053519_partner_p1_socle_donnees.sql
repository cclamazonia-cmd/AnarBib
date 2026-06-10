-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — P1 : socle de données du partenariat stabilisé
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
-- Registre: §21 PARTNER (PARTNER-D1..D9) ; spec docs/specs/spec-partenariat-biblios.md v0.3
--
-- OBJET : couche sémantique au-dessus de l'infra déclarative #PARTNERS (24/05).
-- Conforme à la décision FIGÉE de la spec §10/§13 : ENRICHIR library_partnerships
-- (pas de nouvelle table de partenariat) + trigger de symétrie ; les droits et le
-- consentement vivent dans des tables de jonction dédiées (D9/D8).
--
-- P1 livre : statut de cycle de vie + champs d'acteurs ; table partnership_rights
-- (D9) ; journal de rupture immuable (D5) ; trigger de symétrie garantissant
-- l'ÉGALITÉ des deux directions {A→B} / {B→A} (statut + droits) — chaque ligne
-- directionnelle devient ainsi auto-suffisante pour la future RLS de transparence.
--
-- HORS P1 (sous-lots suivants) : RPC propose/accept/break (P2), consentement
-- lectrice reader_partnership_consent (P3), RLS de transparence conditionnée (P4),
-- frontends (P5/P6).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Enrichir library_partnerships : cycle de vie stabilisé ───────────────
ALTER TABLE public.library_partnerships
  ADD COLUMN IF NOT EXISTS status         text        NOT NULL DEFAULT 'declared',
  ADD COLUMN IF NOT EXISTS proposed_by    uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS proposed_at    timestamptz,
  ADD COLUMN IF NOT EXISTS responded_by   uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS responded_at   timestamptz,
  ADD COLUMN IF NOT EXISTS broken_by      uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS broken_at      timestamptz,
  ADD COLUMN IF NOT EXISTS broken_reason  text,
  ADD COLUMN IF NOT EXISTS config_version integer     NOT NULL DEFAULT 1;

ALTER TABLE public.library_partnerships
  DROP CONSTRAINT IF EXISTS library_partnerships_status_chk,
  DROP CONSTRAINT IF EXISTS library_partnerships_lifecycle_biblio_chk;
ALTER TABLE public.library_partnerships
  -- statut valide
  ADD CONSTRAINT library_partnerships_status_chk
      CHECK (status IN ('declared','proposed','active','refused','broken')),
  -- cycle de vie réservé aux partenariats biblio↔biblio (D6 : les collectifs
  -- catalog_partners restent purement déclaratifs = 'declared')
  ADD CONSTRAINT library_partnerships_lifecycle_biblio_chk
      CHECK (status = 'declared' OR partner_library_id IS NOT NULL);

COMMENT ON COLUMN public.library_partnerships.status IS
  'Cycle de vie du partenariat stabilisé (PARTNER-D7) : declared (déclaration #PARTNERS, '
  'défaut, seul état permis pour un catalog_partner) | proposed | active | refused | broken. '
  'Activation bilatérale, rupture unilatérale.';
COMMENT ON COLUMN public.library_partnerships.config_version IS
  'Version de la configuration de droits (PARTNER-D8) : incrémentée à chaque AJOUT de droit, '
  'invalide le consentement lectrice (re-sollicitation vers le haut).';

-- ── 2. partnership_rights — droits actifs portés par la relation (D9) ───────
CREATE TABLE IF NOT EXISTS public.partnership_rights (
  partnership_id uuid        NOT NULL REFERENCES public.library_partnerships (id) ON DELETE CASCADE,
  right_key      text        NOT NULL,
  granted_at     timestamptz NOT NULL DEFAULT now(),
  granted_by     uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
  CONSTRAINT partnership_rights_pkey PRIMARY KEY (partnership_id, right_key),
  -- ajouter un droit futur = une valeur ici, pas une migration de structure (D9)
  CONSTRAINT partnership_rights_key_chk
      CHECK (right_key IN ('transparence','digital_share','mutualisation','peb'))
);

COMMENT ON TABLE public.partnership_rights IS
  'Droits actifs d''un partenariat stabilisé (PARTNER-D9). Réciproques par construction '
  '(trigger de symétrie). right_key sous CHECK : transparence, digital_share, mutualisation, peb.';

REVOKE ALL ON TABLE public.partnership_rights FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.partnership_rights TO authenticated;  -- écritures via RPC DEFINER (P2)
GRANT ALL ON TABLE public.partnership_rights TO service_role;

ALTER TABLE public.partnership_rights ENABLE ROW LEVEL SECURITY;
-- Lecture : visible si la biblio propriétaire du partenariat est visible au caller.
CREATE POLICY partnership_rights_select ON public.partnership_rights
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.library_partnerships lp
            WHERE lp.id = partnership_rights.partnership_id
              AND public.fn_library_visible_to_caller(lp.library_id))
  );
-- Pas de policy d'écriture : INSERT/UPDATE/DELETE réservés aux fonctions DEFINER.

-- ── 3. partnership_break_log — journal de rupture immuable (D5) ─────────────
CREATE TABLE IF NOT EXISTS public.partnership_break_log (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  partnership_id     uuid,                       -- pas de FK : la ligne peut être supprimée après
  library_id         uuid        NOT NULL,
  partner_library_id uuid        NOT NULL,
  broken_by          uuid        REFERENCES public.profiles (id) ON DELETE SET NULL,
  broken_at          timestamptz NOT NULL DEFAULT now(),
  reason             text
);

COMMENT ON TABLE public.partnership_break_log IS
  'Journal immuable des ruptures de partenariat (PARTNER-D5 : qui, quand). '
  'Aucune policy UPDATE/DELETE : trace inaltérable. Écriture via RPC DEFINER (P2).';

REVOKE ALL ON TABLE public.partnership_break_log FROM PUBLIC, anon;
GRANT SELECT ON TABLE public.partnership_break_log TO authenticated;
GRANT ALL ON TABLE public.partnership_break_log TO service_role;

ALTER TABLE public.partnership_break_log ENABLE ROW LEVEL SECURITY;
-- Lecture : staff de coordination de l'une OU l'autre biblio de la paire.
CREATE POLICY partnership_break_log_select ON public.partnership_break_log
  FOR SELECT USING (
    public.user_can_engage_library(library_id)
    OR public.user_can_engage_library(partner_library_id)
  );
-- Immuable : aucune policy INSERT/UPDATE/DELETE (insertion par RPC DEFINER P2).

-- ── 4. Helper : id de la ligne réciproque {B→A} d'un partenariat biblio ─────
CREATE OR REPLACE FUNCTION public.fn_partnership_reciprocal_id(p_partnership_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT r.id
  FROM public.library_partnerships src
  JOIN public.library_partnerships r
    ON r.library_id = src.partner_library_id
   AND r.partner_library_id = src.library_id
  WHERE src.id = p_partnership_id
    AND src.partner_library_id IS NOT NULL
  LIMIT 1;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_reciprocal_id(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_partnership_reciprocal_id(uuid) TO authenticated;

-- ── 5. Trigger de symétrie — statut (D4 : égalité des deux directions) ──────
CREATE OR REPLACE FUNCTION public.fn_partnership_sync_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- Seuls les partenariats biblio↔biblio sont symétrisés ; on ne propage que les
  -- états bilatéraux (active/broken/refused). 'proposed' reste unilatéral (P2 crée
  -- la réciproque à l'acceptation). Garde anti-récursion : WHERE status DISTINCT.
  IF NEW.partner_library_id IS NOT NULL
     AND NEW.status IS DISTINCT FROM OLD.status
     AND NEW.status IN ('active','broken','refused') THEN
    UPDATE public.library_partnerships r
       SET status = NEW.status
     WHERE r.library_id = NEW.partner_library_id
       AND r.partner_library_id = NEW.library_id
       AND r.status IS DISTINCT FROM NEW.status;
  END IF;
  RETURN NULL;  -- AFTER trigger
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_sync_status() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_partnership_sync_status ON public.library_partnerships;
CREATE TRIGGER trg_partnership_sync_status
  AFTER UPDATE OF status ON public.library_partnerships
  FOR EACH ROW EXECUTE FUNCTION public.fn_partnership_sync_status();

-- ── 6. Trigger de symétrie — droits (D9 : jeux égaux des deux côtés) ────────
CREATE OR REPLACE FUNCTION public.fn_partnership_sync_rights()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_recip uuid;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_recip := public.fn_partnership_reciprocal_id(NEW.partnership_id);
    IF v_recip IS NOT NULL THEN
      -- ON CONFLICT DO NOTHING : si déjà présent, aucune ligne insérée donc
      -- l'AFTER INSERT ne re-déclenche pas → terminaison de la récursion.
      INSERT INTO public.partnership_rights (partnership_id, right_key, granted_by)
        VALUES (v_recip, NEW.right_key, NEW.granted_by)
      ON CONFLICT (partnership_id, right_key) DO NOTHING;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    v_recip := public.fn_partnership_reciprocal_id(OLD.partnership_id);
    IF v_recip IS NOT NULL THEN
      -- suppression idempotente : 0 ligne supprimée → pas de re-déclenchement.
      DELETE FROM public.partnership_rights
       WHERE partnership_id = v_recip AND right_key = OLD.right_key;
    END IF;
  END IF;
  RETURN NULL;  -- AFTER trigger
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_partnership_sync_rights() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_partnership_sync_rights ON public.partnership_rights;
CREATE TRIGGER trg_partnership_sync_rights
  AFTER INSERT OR DELETE ON public.partnership_rights
  FOR EACH ROW EXECUTE FUNCTION public.fn_partnership_sync_rights();

-- ── 7. Vérification des invariants ──────────────────────────────────────────
DO $verify$
DECLARE v int;
BEGIN
  SELECT count(*) INTO v FROM information_schema.columns
   WHERE table_schema='public' AND table_name='library_partnerships'
     AND column_name IN ('status','proposed_by','responded_by','broken_by','config_version');
  IF v <> 5 THEN RAISE EXCEPTION 'VERIFY FAILED: colonnes de cycle de vie manquantes (% / 5)', v; END IF;

  SELECT count(*) INTO v FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname IN ('partnership_rights','partnership_break_log')
     AND c.relrowsecurity = true;
  IF v <> 2 THEN RAISE EXCEPTION 'VERIFY FAILED: RLS non activée sur les 2 tables (% / 2)', v; END IF;

  SELECT count(*) INTO v FROM pg_trigger
   WHERE tgname IN ('trg_partnership_sync_status','trg_partnership_sync_rights') AND NOT tgisinternal;
  IF v <> 2 THEN RAISE EXCEPTION 'VERIFY FAILED: triggers de symétrie absents (% / 2)', v; END IF;

  -- anon ne doit avoir aucun droit sur les nouvelles tables
  IF has_table_privilege('anon','public.partnership_rights','SELECT')
     OR has_table_privilege('anon','public.partnership_break_log','SELECT') THEN
    RAISE EXCEPTION 'VERIFY FAILED: anon détient un droit sur une table partenariat';
  END IF;

  RAISE NOTICE 'VERIFY OK: PARTNER P1 — cycle de vie, partnership_rights, break_log, 2 triggers symétrie.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;
