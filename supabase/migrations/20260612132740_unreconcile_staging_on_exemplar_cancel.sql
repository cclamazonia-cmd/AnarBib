-- Migration : annulation d'un brouillon d'exemplaire -> de-rapprochement de la ligne
-- Auteur  : Claude (Opus 4.8)
-- Session : Import/Export — fiabilisation matching & rapprochement
-- Date    : 2026-06-12 (UTC)
--
-- Boucle le cycle du rapprochement (chantier B). Quand le brouillon d'exemplaire
-- cree depuis la Fila est ANNULE en Catalogacao (exemplar_drafts.status =
-- 'cancelled') ou supprime, la ligne de staging d'origine restait marquee
-- created_exemplar_draft_id -> elle affichait encore « Exemplar criado » dans la
-- Fila et n'etait plus re-selectionnable. On remet desormais la ligne a zero
-- (re-rapprochable / re-rejetable). Le statut 'published' (exemplaire reel cree)
-- ne declenche PAS le reset : le rapprochement a abouti.

-- ──────────────────────────────────────────────────────────────────────────
-- Fonction trigger : remet la ligne de staging en attente
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ingest.fn_unreconcile_staging_on_exemplar_draft()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'ingest', 'public'
AS $function$
declare
  v_draft_id bigint;
begin
  if tg_op = 'DELETE' then
    v_draft_id := old.id;
  else
    -- UPDATE : agir uniquement a la transition vers 'cancelled'
    if new.status is distinct from 'cancelled' or old.status = 'cancelled' then
      return new;
    end if;
    v_draft_id := new.id;
  end if;

  update ingest.partner_catalog_staging_rows sr
     set created_exemplar_draft_id = null,
         editorial_decision = 'pending',
         editorial_note = null,
         editorial_decided_at = null,
         editorial_decided_by = null,
         review_status = 'pending',
         selected_for_draft = false
   where sr.created_exemplar_draft_id = v_draft_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

-- SECURITY DEFINER : verrouiller l'execution (doctrine .githooks). Fonction
-- trigger -> invoquee par le mecanisme de trigger, aucun GRANT requis.
REVOKE EXECUTE ON FUNCTION ingest.fn_unreconcile_staging_on_exemplar_draft() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_unreconcile_on_exemplar_cancel ON public.exemplar_drafts;
CREATE TRIGGER trg_unreconcile_on_exemplar_cancel
  AFTER UPDATE OF status ON public.exemplar_drafts
  FOR EACH ROW
  EXECUTE FUNCTION ingest.fn_unreconcile_staging_on_exemplar_draft();

DROP TRIGGER IF EXISTS trg_unreconcile_on_exemplar_delete ON public.exemplar_drafts;
CREATE TRIGGER trg_unreconcile_on_exemplar_delete
  BEFORE DELETE ON public.exemplar_drafts
  FOR EACH ROW
  EXECUTE FUNCTION ingest.fn_unreconcile_staging_on_exemplar_draft();

-- ──────────────────────────────────────────────────────────────────────────
-- Backfill : de-rapprocher les lignes liees a un brouillon DEJA annule
-- (idempotent ; corrige notamment la ligne du brouillon de test id 14)
-- ──────────────────────────────────────────────────────────────────────────
UPDATE ingest.partner_catalog_staging_rows sr
   SET created_exemplar_draft_id = null,
       editorial_decision = 'pending',
       editorial_note = null,
       editorial_decided_at = null,
       editorial_decided_by = null,
       review_status = 'pending',
       selected_for_draft = false
  FROM public.exemplar_drafts ed
 WHERE sr.created_exemplar_draft_id = ed.id
   AND ed.status = 'cancelled';
