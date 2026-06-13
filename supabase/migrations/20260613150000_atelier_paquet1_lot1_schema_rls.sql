-- =====================================================================
-- ATELIER AUTORITÉS — Paquet 1, lot 1 : schéma + RLS
-- spec-atelier-autorites §5 ; REGISTRE §28 (ATE-1..4, ATE-O1/O2 tranchés)
-- =====================================================================
-- Validé BEGIN/ROLLBACK contre la prod le 13/06 (zéro persistance).
--
-- ATE-O1 : network_contributors = TABLE dédiée (calquée sur network_administrators),
--          pas un rôle user_library_memberships (FED-3 : axes décollés).
-- ATE-O2 : fenêtres opt-out fixées par la RPC (lot 2) : 7 j création/édition/
--          traduction, 14 j fusion. La colonne `deadline` les matérialise.
-- ATE-3  : propose = contributeur + staff ; objecte = coordenador biblio
--          utilisatrice + coord atelier. Écritures par RPC SECURITY DEFINER
--          (lot 2) ; les RLS ici = lecture de base des participants (DOC-RPC-3).
-- target_id/merge_into_id en bigint couvrent author (personnes+collectivités)
-- ET subject (matières) — exécution via merge_author / merge_subject (ATE-O3).
-- Ordre : TABLES -> HELPERS (qui les référencent) -> RLS/policies -> grants.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1) network_contributors — 4e cercle de contribution (compte réseau)
-- ---------------------------------------------------------------------
CREATE TABLE public.network_contributors (
  user_id      uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  status       text NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended','left')),
  display_name text,                                    -- attribution publique (optionnel)
  sponsored_by uuid REFERENCES public.profiles(id),     -- parrainage/cooptation (optionnel)
  joined_at    timestamptz NOT NULL DEFAULT now(),
  notes        text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.network_contributors IS
  'ATE-O1 : compte réseau contributeur d''autorités (4e cercle, non rattaché à une biblio). Calqué sur network_administrators. Droit = proposer (jamais éditer directement). Écritures via RPC.';

-- ---------------------------------------------------------------------
-- 2) authority_proposals — propositions (création/édition/fusion/traduction)
-- ---------------------------------------------------------------------
CREATE TABLE public.authority_proposals (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind          text NOT NULL CHECK (kind IN ('creation','edition','fusion','traduction')),
  target_kind   text NOT NULL CHECK (target_kind IN ('author','subject')),
  target_id     bigint,           -- authors.id / subjects.id ; NULL si création
  merge_into_id bigint,           -- fusion : id canonique (target_id = doublon)
  payload       jsonb NOT NULL DEFAULT '{}'::jsonb,   -- diff / données création / traduction
  rationale     text,             -- motivation de la proposition
  status        text NOT NULL DEFAULT 'open'
                CHECK (status IN ('open','contested','resolved_consent','applied','refused','withdrawn')),
  deadline      timestamptz NOT NULL,                 -- fenêtre opt-out (ATE-O2)
  proposed_by   uuid NOT NULL REFERENCES public.profiles(id),
  resolved_at   timestamptz,
  applied_at    timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  -- cohérence kind <-> colonnes
  CONSTRAINT authority_proposals_creation_no_target  CHECK ((kind = 'creation') = (target_id IS NULL)),
  CONSTRAINT authority_proposals_fusion_has_canonical CHECK ((kind = 'fusion') = (merge_into_id IS NOT NULL))
);
COMMENT ON TABLE public.authority_proposals IS
  'Atelier autorités : file de propositions de contribution. kind=creation/edition/fusion/traduction ; target_kind=author/subject (bigint). Consentement opt-out (FED-O5) ; exécution via merge_author/merge_subject ou écriture directe à la résolution. Écritures via RPC.';

CREATE INDEX idx_authority_proposals_status_deadline ON public.authority_proposals (status, deadline);
CREATE INDEX idx_authority_proposals_target          ON public.authority_proposals (target_kind, target_id);

-- ---------------------------------------------------------------------
-- 3) authority_proposal_objections — objections motivées (FED-O5 anti-blackball)
-- ---------------------------------------------------------------------
CREATE TABLE public.authority_proposal_objections (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id          uuid NOT NULL REFERENCES public.authority_proposals(id) ON DELETE CASCADE,
  objecting_library_id uuid REFERENCES public.libraries(id),  -- biblio utilisatrice
  objecting_by         uuid NOT NULL REFERENCES public.profiles(id),
  reason               text NOT NULL CHECK (char_length(btrim(reason)) >= 20),  -- motivation oblig. (cf. cercles >=20)
  created_at           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT authority_proposal_objections_one_per_library UNIQUE (proposal_id, objecting_library_id)
);
COMMENT ON TABLE public.authority_proposal_objections IS
  'Objections motivées à une proposition (FED-O5 anti-blackball : une objection isolée suspend+ouvre ; refus si >=2 biblios utilisatrices distinctes). Une objection par biblio par proposition.';

CREATE INDEX idx_authority_proposal_objections_proposal ON public.authority_proposal_objections (proposal_id);

-- ---------------------------------------------------------------------
-- 4) Helpers RLS (après les tables qu'ils référencent ; check_function_bodies)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_caller_is_network_contributor()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $$ SELECT EXISTS (
  SELECT 1 FROM public.network_contributors c
  WHERE c.user_id = auth.uid() AND c.status = 'active'
); $$;
REVOKE EXECUTE ON FUNCTION public.fn_caller_is_network_contributor() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_caller_is_network_contributor() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_caller_is_staff()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $$ SELECT EXISTS (
  SELECT 1 FROM public.user_library_memberships m
  WHERE m.user_id = auth.uid() AND m.status = 'active'
    AND m.role IN ('librarian','coordenador')
); $$;
REVOKE EXECUTE ON FUNCTION public.fn_caller_is_staff() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_caller_is_staff() TO authenticated;

-- ---------------------------------------------------------------------
-- 5) RLS — lecture de base des participants ; écritures via RPC (lot 2)
-- ---------------------------------------------------------------------
ALTER TABLE public.network_contributors          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.authority_proposals           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.authority_proposal_objections ENABLE ROW LEVEL SECURITY;

-- network_contributors : self + network admin (gestion = cooptation, par RPC)
CREATE POLICY nc_read ON public.network_contributors
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.fn_caller_is_network_admin());

-- proposals + objections : lisibles par les participants de l'atelier
-- (contributeurs, staff biblio, admins réseau). La portée fine « parties
-- prenantes » (ATE-1) et « qui peut objecter » (ATE-3) est enforce dans les RPC.
CREATE POLICY ap_read ON public.authority_proposals
  FOR SELECT TO authenticated
  USING (public.fn_caller_is_network_contributor() OR public.fn_caller_is_staff() OR public.fn_caller_is_network_admin());

CREATE POLICY apo_read ON public.authority_proposal_objections
  FOR SELECT TO authenticated
  USING (public.fn_caller_is_network_contributor() OR public.fn_caller_is_staff() OR public.fn_caller_is_network_admin());

-- Aucune policy INSERT/UPDATE/DELETE : toutes les écritures passent par les
-- RPC SECURITY DEFINER du lot 2 (DOC-RPC-3).

-- ---------------------------------------------------------------------
-- 6) Grants tables : SELECT à authenticated (RLS filtre) ; pas d'écriture directe
-- ---------------------------------------------------------------------
GRANT SELECT ON public.network_contributors          TO authenticated;
GRANT SELECT ON public.authority_proposals           TO authenticated;
GRANT SELECT ON public.authority_proposal_objections TO authenticated;

COMMIT;

-- Rollback manuel :
--   DROP TABLE IF EXISTS public.authority_proposal_objections;
--   DROP TABLE IF EXISTS public.authority_proposals;
--   DROP TABLE IF EXISTS public.network_contributors;
--   DROP FUNCTION IF EXISTS public.fn_caller_is_staff();
--   DROP FUNCTION IF EXISTS public.fn_caller_is_network_contributor();
