-- ============================================================================
-- 20260524010000_consulta_item_id_schema.sql
-- ----------------------------------------------------------------------------
-- Chantier #MODEL-item-grain — volet A : schema et donnees.
-- Specification : docs/specs/spec-granularite-item.md
--
-- OBJET
--   consulta_linhas_v2 raisonne au holding_id ; l'emprunt et la reservation
--   raisonnent a l'item_id (l'exemplaire). Ce volet dote consulta_linhas_v2
--   d'un item_id, en suivant le patron emprestimo_itens_v2 :
--     item_id   -> exemplares(id)     ON DELETE RESTRICT  (reference forte)
--     holding_id-> book_holdings(id)  ON DELETE SET NULL   (reference confort)
--
-- ORDRE IMPERATIF (spec sec. 5)
--   1. colonne item_id NULLABLE
--   2. remplissage des lignes existantes (resolution holding -> item)
--   3. controle : aucune ligne NULL
--   4. NOT NULL + FK
--   Poser NOT NULL avant le remplissage ferait echouer la migration.
--
-- MIGRATION DES DONNEES
--   Au 24/05, les 30 lignes de consulta_linhas_v2 (2 actives, 28 closes)
--   pointent TOUTES vers des holdings mono-exemplaire. La resolution
--   holding -> item est donc deterministe : un seul exemplaire candidat
--   par holding. Aucun cas ambigu. Le bloc DO le verifie avant le NOT NULL.
--
-- Le volet B (fonctions : resolution d'exemplaire, adaptation de
-- fn_v2_create_consulta_local_by_holdings, resserrement de
-- fn_peb_search_exemplares) est dans la migration 20260524020000.
-- ============================================================================


-- ─── Etape 1 — colonne item_id, nullable ────────────────────────────────────
ALTER TABLE public.consulta_linhas_v2
  ADD COLUMN IF NOT EXISTS item_id bigint;

COMMENT ON COLUMN public.consulta_linhas_v2.item_id IS
  'Exemplaire precis vise par la ligne de consultation (#MODEL-item-grain). '
  'Reference forte. holding_id est conserve comme reference de confort.';


-- ─── Etape 2 — remplissage des lignes existantes ────────────────────────────
-- Resolution holding -> item. Les holdings concernes sont tous mono-exemplaire
-- (verifie au cadrage) : le SELECT ... LIMIT 1 est donc deterministe.
-- On ne remplit que les lignes encore NULL (idempotence si re-execution).
UPDATE public.consulta_linhas_v2 cl
SET item_id = (
  SELECT e.id FROM public.exemplares e
  WHERE e.holding_id = cl.holding_id
  ORDER BY e.id
  LIMIT 1
)
WHERE cl.item_id IS NULL
  AND cl.holding_id IS NOT NULL;


-- ─── Etape 3 + 4 — controle puis NOT NULL + FK ──────────────────────────────
DO $verif$
declare
  v_null_count integer;
  v_orphan_count integer;
begin
  -- (3) Aucune ligne ne doit rester sans item_id.
  select count(*) into v_null_count
  from public.consulta_linhas_v2
  where item_id is null;

  if v_null_count <> 0 then
    raise exception
      'Verification echouee : % ligne(s) de consultation sans item_id resolu. '
      'Resolution holding->item impossible (holding sans exemplaire ?). '
      'Migration interrompue avant la pose du NOT NULL.', v_null_count;
  end if;

  -- Coherence : chaque item_id resolu appartient bien au holding de la ligne.
  select count(*) into v_orphan_count
  from public.consulta_linhas_v2 cl
  join public.exemplares e on e.id = cl.item_id
  where cl.holding_id is not null
    and e.holding_id is distinct from cl.holding_id;

  if v_orphan_count <> 0 then
    raise exception
      'Verification echouee : % ligne(s) avec item_id n''appartenant pas '
      'au holding de la ligne.', v_orphan_count;
  end if;

  raise notice 'Migration 20260524010000 : remplissage OK, aucune ligne NULL, aucun item_id incoherent. Pose du NOT NULL et de la FK.';
end;
$verif$;

-- FK item_id -> exemplares (patron emprestimo_itens_v2 : RESTRICT).
ALTER TABLE public.consulta_linhas_v2
  DROP CONSTRAINT IF EXISTS consulta_linhas_v2_item_id_fkey;
ALTER TABLE public.consulta_linhas_v2
  ADD CONSTRAINT consulta_linhas_v2_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES public.exemplares(id) ON DELETE RESTRICT;

-- NOT NULL, pose APRES le remplissage et le controle.
ALTER TABLE public.consulta_linhas_v2
  ALTER COLUMN item_id SET NOT NULL;

-- Index sur la nouvelle FK (les jointures et la regle de disponibilite
-- #ILL-availability resserree, volet B, filtreront sur item_id).
CREATE INDEX IF NOT EXISTS idx_consulta_linhas_v2_item_id
  ON public.consulta_linhas_v2 (item_id);


-- ─── Verification finale ────────────────────────────────────────────────────
DO $verif$
declare
  v_col_notnull boolean;
  v_fk_exists boolean;
begin
  -- La colonne item_id est bien NOT NULL.
  select (a.attnotnull) into v_col_notnull
  from pg_attribute a
  where a.attrelid = 'public.consulta_linhas_v2'::regclass
    and a.attname = 'item_id';

  if not coalesce(v_col_notnull, false) then
    raise exception 'Verification echouee : consulta_linhas_v2.item_id n''est pas NOT NULL.';
  end if;

  -- La FK existe.
  select exists (
    select 1 from pg_constraint
    where conname = 'consulta_linhas_v2_item_id_fkey'
      and conrelid = 'public.consulta_linhas_v2'::regclass
  ) into v_fk_exists;

  if not v_fk_exists then
    raise exception 'Verification echouee : FK consulta_linhas_v2_item_id_fkey absente.';
  end if;

  raise notice 'Migration 20260524010000 : verification OK (item_id NOT NULL + FK RESTRICT en place).';
end;
$verif$;
