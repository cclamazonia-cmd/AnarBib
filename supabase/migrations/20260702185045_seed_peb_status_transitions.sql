-- ===========================================================================
-- 20260702185045_seed_peb_status_transitions.sql
-- ---------------------------------------------------------------------------
-- Chantier : #ILL-lifecycle / #ILL-overdue (cf. docs/specs/spec-cycle-vie-peb.md)
--
-- Peuple la table de configuration public.interlibrary_loan_status_transitions
-- (couples licites from_status -> to_status), lue par le trigger
-- fn_peb_validate_status_transition() (BEFORE UPDATE sur interlibrary_loans_v2)
-- pour verrouiller la machine a etats du PEB.
--
-- Pourquoi cette migration : la table existe dans le schema baseline mais
-- n'etait peuplee NULLE PART (ni migration, ni supabase/seed.sql). Les 18 lignes
-- ont ete inserees a la main en prod, jamais capturees en repo. Consequence :
-- un deploiement neuf ou une restauration schema-only (base reconstruite depuis
-- template0, comme en CI) a la table VIDE -> le trigger n'a aucune cible licite
-- et rejette TOUTE transition de statut PEB (« aucune cible licite »), cassant
-- l'avancement de tout pret (preparacao -> aguardando_saida deja refuse).
-- Decouvert le 2026-07-02 en montant tests/sql/paquet_peb_ill_lifecycle_tests.sql.
--
-- Les 18 couples ci-dessous sont la copie conforme de l'etat prod (SELECT
-- from_status, to_status FROM public.interlibrary_loan_status_transitions).
-- Ils correspondent au graphe du spec-cycle-vie-peb.md §2.2 (16 transitions)
-- + les 2 aller/retour du retard livres avec #ILL-overdue (§7) :
--   emprestado <-> atrasado etant deja couvert, s'ajoutent
--   atrasado -> emprestado (sortie auto du retard, due_date repoussee) et
--   parcialmente_devolvido -> atrasado (un pret partiellement rendu peut virer
--   en retard). Les etats terminaux devolvido et cancelado n'ont aucune sortie.
--
-- IDEMPOTENT : ON CONFLICT DO NOTHING sur la PK (from_status, to_status)
--   -> strict no-op en prod (les 18 lignes y sont deja),
--   -> repeuple une base fraiche / restauree schema-only.
-- Reversible : rollback = DELETE des 18 couples (voir bas de fichier).
-- Deploiement : commit -> push -> CI Forgejo (supabase db push).
-- ===========================================================================

BEGIN;

INSERT INTO public.interlibrary_loan_status_transitions (from_status, to_status) VALUES
  ('aguardando_saida',       'cancelado'),
  ('aguardando_saida',       'emprestado'),
  ('aguardando_saida',       'preparacao'),
  ('atrasado',               'devolvido'),
  ('atrasado',               'em_devolucao'),
  ('atrasado',               'emprestado'),
  ('atrasado',               'parcialmente_devolvido'),
  ('em_devolucao',           'devolvido'),
  ('em_devolucao',           'parcialmente_devolvido'),
  ('emprestado',             'atrasado'),
  ('emprestado',             'devolvido'),
  ('emprestado',             'em_devolucao'),
  ('emprestado',             'parcialmente_devolvido'),
  ('parcialmente_devolvido', 'atrasado'),
  ('parcialmente_devolvido', 'devolvido'),
  ('parcialmente_devolvido', 'emprestado'),
  ('preparacao',             'aguardando_saida'),
  ('preparacao',             'cancelado')
ON CONFLICT (from_status, to_status) DO NOTHING;

-- Verification : les 18 cibles licites sont bien presentes (garde-fou contre
-- une faute de frappe dans la liste ci-dessus). RAISE EXCEPTION -> rollback.
DO $$
DECLARE
  v_missing int;
BEGIN
  SELECT count(*) INTO v_missing
  FROM (VALUES
    ('aguardando_saida',       'cancelado'),
    ('aguardando_saida',       'emprestado'),
    ('aguardando_saida',       'preparacao'),
    ('atrasado',               'devolvido'),
    ('atrasado',               'em_devolucao'),
    ('atrasado',               'emprestado'),
    ('atrasado',               'parcialmente_devolvido'),
    ('em_devolucao',           'devolvido'),
    ('em_devolucao',           'parcialmente_devolvido'),
    ('emprestado',             'atrasado'),
    ('emprestado',             'devolvido'),
    ('emprestado',             'em_devolucao'),
    ('emprestado',             'parcialmente_devolvido'),
    ('parcialmente_devolvido', 'atrasado'),
    ('parcialmente_devolvido', 'devolvido'),
    ('parcialmente_devolvido', 'emprestado'),
    ('preparacao',             'aguardando_saida'),
    ('preparacao',             'cancelado')
  ) AS want(f, t)
  WHERE NOT EXISTS (
    SELECT 1 FROM public.interlibrary_loan_status_transitions x
    WHERE x.from_status = want.f AND x.to_status = want.t
  );

  IF v_missing > 0 THEN
    RAISE EXCEPTION
      'Seed transitions PEB incomplet : % cible(s) licite(s) manquante(s). Rollback automatique.',
      v_missing;
  END IF;

  RAISE NOTICE 'Seed transitions PEB OK : 18/18 transitions licites presentes.';
END $$;

COMMIT;

-- ===========================================================================
-- Rollback cible (a n'appliquer que sur une base ou ces couples sont parasites) :
-- ===========================================================================
-- BEGIN;
--   DELETE FROM public.interlibrary_loan_status_transitions
--   WHERE (from_status, to_status) IN (
--     ('aguardando_saida','cancelado'),('aguardando_saida','emprestado'),
--     ('aguardando_saida','preparacao'),('atrasado','devolvido'),
--     ('atrasado','em_devolucao'),('atrasado','emprestado'),
--     ('atrasado','parcialmente_devolvido'),('em_devolucao','devolvido'),
--     ('em_devolucao','parcialmente_devolvido'),('emprestado','atrasado'),
--     ('emprestado','devolvido'),('emprestado','em_devolucao'),
--     ('emprestado','parcialmente_devolvido'),('parcialmente_devolvido','atrasado'),
--     ('parcialmente_devolvido','devolvido'),('parcialmente_devolvido','emprestado'),
--     ('preparacao','aguardando_saida'),('preparacao','cancelado')
--   );
-- COMMIT;
-- ===========================================================================
