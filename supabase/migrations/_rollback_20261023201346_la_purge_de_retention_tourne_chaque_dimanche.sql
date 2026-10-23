-- ═══════════════════════════════════════════════════════════════════════════
-- RETOUR ARRIÈRE de 20261023201346_la_purge_de_retention_tourne_chaque_dimanche
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- À NE PAS appliquer par `db push` (le préfixe « _ » l'en écarte). À passer à
-- la main, puis à suivre d'une migration qui fixe le même état dans le dépôt,
-- sans quoi crons_planifies et la garde de 20261023201346 rougiront.
-- Remet la commande hebdomadaire sur fn_purge_expired_data ; ne touche ni aux
-- plafonds de RET-2 ni à fn_purge_retention, qui restent en base.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

SELECT cron.schedule(
  'anarbib-rgpd-purge-weekly',
  '0 3 * * 0',
  ' SELECT public.fn_purge_expired_data(p_dry_run := false); '
);

DO $mig$
DECLARE
  v_def   text;
  v_n     int;
  v_ancre text := $a$    ('anarbib-rgpd-purge-weekly', '0 3 * * 0', $c$ SELECT public.fn_purge_retention(p_dry_run := false); $c$, true),$a$;
  v_ligne text := $b$    ('anarbib-rgpd-purge-weekly', '0 3 * * 0', $c$ SELECT public.fn_purge_expired_data(p_dry_run := false); $c$, true),$b$;
BEGIN
  v_def := replace(pg_get_functiondef('private.fn_crons_attendus()'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN RAISE EXCEPTION 'Retour arrière : ancre trouvée % fois (1 attendue)', v_n; END IF;
  EXECUTE replace(v_def, v_ancre, v_ligne);
END
$mig$;

COMMIT;
