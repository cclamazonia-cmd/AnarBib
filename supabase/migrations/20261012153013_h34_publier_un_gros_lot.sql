-- =====================================================================
-- H34 — publier un gros lot importé : la disponibilité recomptée une fois
-- par fonds touché, le numéro d'inventaire suivant lu par index
--
-- ── Le constat (banc privé, 12/10/2026, scratchpad h34) ──
-- Banc aux volumes de la production (2 703 notices, 2 703 fonds, 2 705
-- exemplaires, 2 705 numéros au registre ; production le 12/10 : 2 567,
-- 2 659, 2 762, 2 771), statistiques analysées, publication d'un lot importé
-- (public.publish_catalog_batch) sous le jeton de la coordination :
--     500 exemplaires (20 notices x 25)  :  10,0 s
--   2 000 exemplaires (80 x 25)          :  43,6 s
--   5 000 exemplaires (200 x 25)         : 132,0 s, dont
--     public.fn_v2_recompute_holdings_availability  60,1 s (5 400 appels) ;
--     public.fn_next_tombo                          49,4 s (5 000 appels) ;
--     le reste (gardes, pont du fonds, bases H21, déclencheurs) 22,5 s,
--     LINÉAIRE : ~4,5 ms par exemplaire publié, à 500 comme à 5 000.
-- Deux défauts quadratiques :
--   1. le déclencheur trg_exemplar_recompute_availability recompte, pour
--      CHAQUE exemplaire posé, son fonds — et fn_v2_recompute_holdings_availability
--      compte pour cela les exemplaires, prêts, réservations et PEB de TOUT le
--      réseau (agrégats sans filtre, joints ensuite aux fonds visés), deux fois
--      (fonds, puis notices) : une table qui grossit pendant l'appel, relue
--      en entier 5 400 fois ;
--   2. fn_next_tombo relit tous les numéros du préfixe (exemplaires présents
--      ET registre C17, parcours complet : LIKE sans index utilisable sous la
--      collation de la base) pour en prendre le plus grand, à chaque exemplaire.
--
-- ── Le correctif (aucune règle neuve) ──
--   1. fn_v2_recompute_holdings_availability : chaque agrégat ne lit que les
--      fonds visés (« IN (SELECT id FROM target_holdings) », même instantané
--      que la cible) ; sans argument, tous les fonds, comme avant. Mêmes
--      comptes, même rendu. La circulation (prêt, retour, réservation, PEB) y
--      gagne aussi, et garde son recompte immédiat.
--   2. Pendant la publication d'un lot, le déclencheur de l'exemplaire NOTE le
--      fonds touché (private.fn_h34_noter_fonds, liste locale à la
--      transaction, dans l'ordre du dernier geste) au lieu de le recompter ;
--      publish_book_draft note de même son recompte explicite ;
--      publish_catalog_batch recompte à la fin chaque fonds noté, une fois
--      (private.fn_h34_recompter_fonds_notes) — le compte d'un fonds ne dépend
--      que de ses lignes à la fin ; celui d'une notice est, comme avant, la
--      somme des fonds recomptés ENSEMBLE, donc celui du dernier fonds
--      recompté : un seul appel quand chaque notice n'a qu'un fonds noté (le
--      cas d'un lot, qui a une bibliothèque), sinon un appel par fonds dans
--      l'ordre du dernier geste. Hors d'une publication de lot (circulation,
--      édition, publication d'une notice seule), rien ne change : recompte
--      immédiat.
--   3. fn_next_tombo : quand le préfixe finit par autre chose qu'un chiffre
--      (tous ceux de la production : BTL-TL-EX-, CCLA.2026., MLEG-2026-,
--      SOL-2026-) et ne contient ni % ni _ ni \, « préfixe + chiffres » est
--      exactement « la partie avant les chiffres finaux = préfixe » : le plus
--      grand numéro se lit par deux index d'expression (exemplaires et registre,
--      (partie avant les chiffres finaux, valeur des chiffres finaux)), un
--      parcours arrière d'une ligne. Sinon, la lecture d'avant, inchangée.
--      Le verrou d'avis par préfixe (#fix-tombo-global) et le registre C17
--      restent : jamais un doublon, jamais un numéro rendu, y compris sous deux
--      publications concurrentes de la même bibliothèque (la seconde attend le
--      verrou, puis lit le maximum validé par la première).
-- Après (même banc, même fond) :
--     500 exemplaires (20 x 25)   :  1,7 s  (avant 10,0 s)
--   2 000 exemplaires (80 x 25)   :  6,7 s  (avant 43,6 s)
--   5 000 exemplaires (200 x 25)  : 18,5 s  (avant 132,0 s) ; fn_next_tombo
--     0,6 s pour 5 000 numéros, la disponibilité 0,09 s (un appel, 200 fonds).
-- Le reste est LINÉAIRE et ne relève pas de ce correctif : ~3,4 ms par
-- exemplaire (gardes de publish_exemplar_draft, pont du fonds, base H21,
-- déclencheurs) et ~15 ms par notice (bases H20/H21, contexte, auteurs) —
-- 500 notices x 1 exemplaire : 7,8 s. 5 000 exemplaires, ou un run de DIRA
-- (plus de 3 000 notices), ne tiennent donc pas en un appel de 8 s : point 5
-- de la spécification, décision de Xavier (aucune publication par pages, aucun
-- travail de fond n'est inventé ici). Mesures dans
-- tests/sql/h34_publier_un_gros_lot_tests.sql (T01, T07).
--
-- Définitions de départ : production (projet uflwmikiyjfnikiphtcp, lues le
-- 12/10/2026 par pg_get_functiondef), identiques au banc :
--   public.fn_v2_recompute_holdings_availability     c33cfe1c2642ca5c636c94d1644d7f19
--   public.fn_recompute_holdings_on_exemplar_change  c7d214369ef2c820742e61651063f9ac
--   public.fn_next_tombo                             145929f849ed529fb7cb03084899a131
--   public.publish_catalog_batch                     52bfe412194226cc7a688cce78bd9ff9
--   public.publish_book_draft                        163e2ca49afe50379a955aa6205ff27e
--   lue, inchangée : public.publish_exemplar_draft   39694e0ac10ed1910b4c7012f5b0c02e
-- Droits : CREATE OR REPLACE garde ceux des fonctions modifiées (vérifiés à la
-- fin) ; les deux aides neuves sont INVOKER, dans private, fermées à l'API.
-- Suite : tests/sql/h34_publier_un_gros_lot_tests.sql.
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.h34_remplacer(p_quoi text, p_def text, p_old text, p_new text, p_n int DEFAULT 1)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H34 — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> p_n THEN
    RAISE EXCEPTION 'H34 — % : ancre trouvée % fois (attendu %) — relire la définition réelle', p_quoi, v_n, p_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

-- Remplace le texte compris entre deux ancres (la première incluse, la
-- seconde exclue), chacune trouvée une fois, la première avant la seconde.
CREATE OR REPLACE FUNCTION pg_temp.h34_entre(p_quoi text, p_def text, p_debut text, p_fin text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_d int; v_f int;
BEGIN
  IF coalesce(p_debut, '') = '' OR coalesce(p_fin, '') = '' THEN
    RAISE EXCEPTION 'H34 — % : ancre vide', p_quoi;
  END IF;
  IF (length(p_def) - length(replace(p_def, p_debut, ''))) / length(p_debut) <> 1
     OR (length(p_def) - length(replace(p_def, p_fin, ''))) / length(p_fin) <> 1 THEN
    RAISE EXCEPTION 'H34 — % : ancres non uniques — relire la définition réelle', p_quoi;
  END IF;
  v_d := position(p_debut IN p_def);
  v_f := position(p_fin IN p_def);
  IF v_d >= v_f THEN
    RAISE EXCEPTION 'H34 — % : ancres dans le désordre', p_quoi;
  END IF;
  RETURN left(p_def, v_d - 1) || p_new || substr(p_def, v_f);
END
$f$;

CREATE OR REPLACE FUNCTION pg_temp.h34_def(p_fn regprocedure, p_md5 text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v text := replace(pg_get_functiondef(p_fn), E'\r', '');
BEGIN
  IF md5(pg_get_functiondef(p_fn)) <> p_md5 THEN
    RAISE EXCEPTION 'H34 — % n''est pas la définition attendue (md5 %, attendu %) — repartir de la définition réelle',
      p_fn, md5(pg_get_functiondef(p_fn)), p_md5;
  END IF;
  RETURN v;
END
$f$;


-- ─────────────────────────────────────────────────────────────────────
-- 1. Les fonds notés pendant la publication d'un lot
-- ─────────────────────────────────────────────────────────────────────
-- Deux réglages locaux à la transaction (set_config(…, true)) : le drapeau
-- anarbib.h34_disponibilite_differee, posé par publish_catalog_batch le temps
-- de ses boucles, et la liste anarbib.h34_fonds_notes (« ,12,34, »), dans
-- l'ordre du dernier geste sur chaque fonds. Un sous-bloc annulé (le rejeu
-- du tombo de publish_exemplar_draft) annule aussi ce qu'il a noté, comme
-- l'écriture qu'il annule.
CREATE OR REPLACE FUNCTION private.fn_h34_noter_fonds(p_fonds bigint[])
RETURNS boolean
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_liste text;
  v_id bigint;
  v_cle text;
BEGIN
  IF coalesce(current_setting('anarbib.h34_disponibilite_differee', true), '') <> 'on' THEN
    RETURN false;   -- hors d'une publication de lot : à l'appelant de recompter
  END IF;
  v_liste := coalesce(nullif(current_setting('anarbib.h34_fonds_notes', true), ''), ',');
  FOREACH v_id IN ARRAY coalesce(p_fonds, '{}'::bigint[]) LOOP
    CONTINUE WHEN v_id IS NULL;
    v_cle := ',' || v_id || ',';
    CONTINUE WHEN right(v_liste, length(v_cle)) = v_cle;   -- déjà le dernier geste
    IF strpos(v_liste, v_cle) > 0 THEN
      v_liste := replace(v_liste, v_cle, ',');             -- passe en dernier
    END IF;
    v_liste := v_liste || v_id || ',';
  END LOOP;
  PERFORM set_config('anarbib.h34_fonds_notes', v_liste, true);
  RETURN true;
END
$function$;
REVOKE ALL ON FUNCTION private.fn_h34_noter_fonds(bigint[]) FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_h34_noter_fonds(bigint[]) IS
  'H34 (12/10/2026) : pendant la publication d''un lot (drapeau anarbib.h34_disponibilite_differee), note les fonds dont '
  'la disponibilité est à recompter, dans l''ordre du dernier geste, et rend true ; sinon rend false (recompte immédiat '
  'à la charge de l''appelant). Appelée par le déclencheur de l''exemplaire et par publish_book_draft.';

CREATE OR REPLACE FUNCTION private.fn_h34_recompter_fonds_notes()
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_liste text := coalesce(current_setting('anarbib.h34_fonds_notes', true), '');
  v_ids bigint[];
  v_id bigint;
BEGIN
  -- le drapeau tombe d'abord : les recomptes ci-dessous et tout ce qui suit
  -- dans la transaction recomptent tout de suite
  PERFORM set_config('anarbib.h34_disponibilite_differee', '', true);
  PERFORM set_config('anarbib.h34_fonds_notes', '', true);
  SELECT coalesce(array_agg(x::bigint ORDER BY o), '{}'::bigint[]) INTO v_ids
    FROM unnest(string_to_array(btrim(v_liste, ','), ',')) WITH ORDINALITY AS u(x, o)
   WHERE x <> '';
  IF cardinality(v_ids) = 0 THEN
    RETURN 0;
  END IF;
  -- Le compte d'une notice est la somme des fonds RECOMPTÉS ENSEMBLE
  -- (fn_v2_recompute_holdings_availability) : un fonds par notice parmi les
  -- notés (le cas d'un lot, qui a une bibliothèque) — un seul appel, même
  -- résultat qu'un appel par fonds ; sinon un appel par fonds, dans l'ordre du
  -- dernier geste, comme le recompte par exemplaire.
  IF EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.id = ANY (v_ids)
              GROUP BY h.book_id HAVING count(*) > 1) THEN
    FOREACH v_id IN ARRAY v_ids LOOP
      PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_id]);
    END LOOP;
  ELSE
    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := v_ids);
  END IF;
  RETURN cardinality(v_ids);
END
$function$;
REVOKE ALL ON FUNCTION private.fn_h34_recompter_fonds_notes() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_h34_recompter_fonds_notes() IS
  'H34 (12/10/2026) : fin de la publication d''un lot — lève le drapeau anarbib.h34_disponibilite_differee et recompte '
  'une fois chaque fonds noté : en un appel quand chaque notice n''a qu''un fonds noté, sinon un appel par fonds dans '
  'l''ordre du dernier geste (le compte d''une notice est celui du dernier fonds recompté, comme avec le recompte par '
  'exemplaire). Rend le nombre de fonds recomptés.';


-- ─────────────────────────────────────────────────────────────────────
-- 2. fn_v2_recompute_holdings_availability : les agrégats ne lisent que
--    les fonds visés
-- ─────────────────────────────────────────────────────────────────────
DO $h34_recompte$
DECLARE
  v_def text;
BEGIN
  v_def := pg_temp.h34_def('public.fn_v2_recompute_holdings_availability(bigint[], bigint[])'::regprocedure,
                           'c33cfe1c2642ca5c636c94d1644d7f19');
  -- exemplaires (deux blocs : fonds, puis notices)
  v_def := pg_temp.h34_remplacer('recompte (exemplaires)', v_def,
$a$      and e.retire_at is null       -- H21 lot 7 : un retiré ne compte pas
    group by e.holding_id
  ),
  open_loans as ($a$,
$b$      and e.retire_at is null       -- H21 lot 7 : un retiré ne compte pas
      and e.holding_id in (select th.id from target_holdings th)   -- H34 : les fonds visés seulement
    group by e.holding_id
  ),
  open_loans as ($b$, 2);
  -- prêts ouverts
  v_def := pg_temp.h34_remplacer('recompte (prêts)', v_def,
$a$      and e.retire_at is null       -- H21 lot 7 : un retiré ne compte pas
    group by e.holding_id
  ),
  active_reservas as ($a$,
$b$      and e.retire_at is null       -- H21 lot 7 : un retiré ne compte pas
      and e.holding_id in (select th.id from target_holdings th)   -- H34
    group by e.holding_id
  ),
  active_reservas as ($b$, 2);
  -- réservations actives
  v_def := pg_temp.h34_remplacer('recompte (réservations)', v_def,
$a$      and rl.holding_id is not null
    group by rl.holding_id$a$,
$b$      and rl.holding_id is not null
      and rl.holding_id in (select th.id from target_holdings th)   -- H34
    group by rl.holding_id$b$, 2);
  -- PEB ouverts
  v_def := pg_temp.h34_remplacer('recompte (PEB)', v_def,
$a$      and coalesce(e.holding_id, il.holding_id) is not null
    group by coalesce(e.holding_id, il.holding_id)$a$,
$b$      and coalesce(e.holding_id, il.holding_id) is not null
      and coalesce(e.holding_id, il.holding_id) in (select th.id from target_holdings th)   -- H34
    group by coalesce(e.holding_id, il.holding_id)$b$, 2);
  EXECUTE v_def;
END
$h34_recompte$;


-- ─────────────────────────────────────────────────────────────────────
-- 3. Le déclencheur de l'exemplaire : noter pendant la publication d'un lot
-- ─────────────────────────────────────────────────────────────────────
DO $h34_declencheur$
DECLARE
  v_def text;
BEGIN
  v_def := pg_temp.h34_def('public.fn_recompute_holdings_on_exemplar_change()'::regprocedure,
                           'c7d214369ef2c820742e61651063f9ac');
  v_def := pg_temp.h34_remplacer('déclencheur (tête)', v_def,
$a$BEGIN
  IF TG_OP = 'DELETE' THEN
$a$,
$b$BEGIN
  -- H34 (12/10/2026) : pendant la publication d'un lot, les fonds touchés sont
  -- notés (même choix de fonds que ci-dessous) et recomptés une fois, à la fin
  -- de publish_catalog_batch ; partout ailleurs, recompte immédiat.
  IF TG_OP = 'DELETE' THEN
    IF private.fn_h34_noter_fonds(ARRAY[OLD.holding_id]) THEN
      RETURN OLD;
    END IF;
  ELSIF private.fn_h34_noter_fonds(
          CASE WHEN TG_OP = 'UPDATE' AND OLD.holding_id IS DISTINCT FROM NEW.holding_id
               THEN ARRAY[NEW.holding_id, OLD.holding_id]
               ELSE ARRAY[NEW.holding_id] END) THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'DELETE' THEN
$b$);
  EXECUTE v_def;
END
$h34_declencheur$;


-- ─────────────────────────────────────────────────────────────────────
-- 4. publish_book_draft : son recompte explicite est noté, lui aussi
-- ─────────────────────────────────────────────────────────────────────
DO $h34_notice$
DECLARE
  v_def text;
BEGIN
  v_def := pg_temp.h34_def('public.publish_book_draft(bigint)'::regprocedure, '163e2ca49afe50379a955aa6205ff27e');
  -- deux occurrences : après les exemplaires automatiques, après les importés
  v_def := pg_temp.h34_remplacer('notice (recomptes)', v_def,
$a$perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);$a$,
$b$if not private.fn_h34_noter_fonds(ARRAY[v_holding_id]) then   -- H34 : noté pendant un lot
      perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
    end if;$b$, 2);
  EXECUTE v_def;
END
$h34_notice$;


-- ─────────────────────────────────────────────────────────────────────
-- 5. publish_catalog_batch : différer pendant les boucles, recompter à la fin
-- ─────────────────────────────────────────────────────────────────────
DO $h34_lot$
DECLARE
  v_def text;
BEGIN
  v_def := pg_temp.h34_def('public.publish_catalog_batch(bigint)'::regprocedure, '52bfe412194226cc7a688cce78bd9ff9');
  v_def := pg_temp.h34_remplacer('lot (début des boucles)', v_def,
$a$  for r in
    select id
    from public.book_drafts
    where batch_id = p_batch_id$a$,
$b$  -- H34 (12/10/2026) : pendant les boucles, la disponibilité des fonds touchés
  -- est notée (déclencheur de l'exemplaire, publish_book_draft), puis recomptée
  -- une fois par fonds avant de fermer le lot.
  perform set_config('anarbib.h34_fonds_notes', '', true);
  perform set_config('anarbib.h34_disponibilite_differee', 'on', true);

  for r in
    select id
    from public.book_drafts
    where batch_id = p_batch_id$b$);
  v_def := pg_temp.h34_remplacer('lot (fin des boucles)', v_def,
$a$  update public.catalog_batches
  set
    status = 'published',$a$,
$b$  perform private.fn_h34_recompter_fonds_notes();   -- H34

  update public.catalog_batches
  set
    status = 'published',$b$);
  EXECUTE v_def;
END
$h34_lot$;


-- ─────────────────────────────────────────────────────────────────────
-- 6. fn_next_tombo : le plus grand numéro de la série lu par index
-- ─────────────────────────────────────────────────────────────────────
-- (partie avant les chiffres finaux, valeur des chiffres finaux), sur les
-- numéros qui finissent par un chiffre. Les expressions sont celles de
-- fn_next_tombo, au caractère près (l'index ne sert qu'à elles).
CREATE INDEX IF NOT EXISTS exemplares_tombo_serie_idx
  ON public.exemplares (regexp_replace(tombo, '[0-9]+$', ''), ((substring(tombo from '[0-9]+$'))::numeric))
  WHERE tombo ~ '[0-9]$';
CREATE INDEX IF NOT EXISTS tombos_attribues_serie_idx
  ON public.tombos_attribues (regexp_replace(tombo, '[0-9]+$', ''), ((substring(tombo from '[0-9]+$'))::numeric))
  WHERE tombo ~ '[0-9]$';
COMMENT ON INDEX public.exemplares_tombo_serie_idx IS
  'H34 (12/10/2026) : fn_next_tombo lit le plus grand numéro d''une série (préfixe + chiffres) par un parcours arrière d''une ligne.';
COMMENT ON INDEX public.tombos_attribues_serie_idx IS
  'H34 (12/10/2026) : fn_next_tombo lit le plus grand numéro jamais attribué d''une série (registre C17) par un parcours arrière d''une ligne.';

DO $h34_tombo$
DECLARE
  v_def text;
BEGIN
  v_def := pg_temp.h34_def('public.fn_next_tombo(uuid)'::regprocedure, '145929f849ed529fb7cb03084899a131');
  v_def := pg_temp.h34_entre('tombo (le plus grand)', v_def,
$a$  select coalesce(max(n), 0)
    into v_max$a$,
$a$  v_next := v_max + 1;$a$,
$b$  -- H34 (12/10/2026) : quand le préfixe finit par autre chose qu'un chiffre et
  -- ne porte ni % ni _ ni \ (tous ceux de la production), « préfixe + chiffres »
  -- est exactement « partie avant les chiffres finaux = préfixe » : le plus
  -- grand numéro se lit par index (exemplares_tombo_serie_idx,
  -- tombos_attribues_serie_idx), sans relire la série. Sinon, la lecture d'avant.
  if v_full_prefix !~ '[0-9%_\\]$' and v_full_prefix !~ '[%_\\]' then
    select greatest(
             coalesce((select (substring(e.tombo from '[0-9]+$'))::numeric
                         from public.exemplares e
                        where regexp_replace(e.tombo, '[0-9]+$', '') = v_full_prefix
                          and e.tombo ~ '[0-9]$'
                        order by (substring(e.tombo from '[0-9]+$'))::numeric desc
                        limit 1), 0),
             coalesce((select (substring(t.tombo from '[0-9]+$'))::numeric
                         from public.tombos_attribues t
                        where regexp_replace(t.tombo, '[0-9]+$', '') = v_full_prefix
                          and t.tombo ~ '[0-9]$'
                        order by (substring(t.tombo from '[0-9]+$'))::numeric desc
                        limit 1), 0))::bigint
      into v_max;
  else
  select coalesce(max(n), 0)
    into v_max
    from (
      select (substring(e.tombo from char_length(v_full_prefix) + 1))::bigint as n
        from public.exemplares e
       where e.tombo like v_full_prefix || '%'
         and substring(e.tombo from char_length(v_full_prefix) + 1) ~ '^[0-9]+$'
      union all
      select (substring(t.tombo from char_length(v_full_prefix) + 1))::bigint
        from public.tombos_attribues t
       where t.tombo like v_full_prefix || '%'
         and substring(t.tombo from char_length(v_full_prefix) + 1) ~ '^[0-9]+$'
    ) s;
  end if;

$b$);
  EXECUTE v_def;
END
$h34_tombo$;


-- ─────────────────────────────────────────────────────────────────────
-- 7. Vérification structurelle
-- ─────────────────────────────────────────────────────────────────────
DO $h34_verif$
DECLARE
  v_e text := '';
  v_f text;
  v_rec text := pg_get_functiondef('public.fn_v2_recompute_holdings_availability(bigint[], bigint[])'::regprocedure);
  v_tg  text := pg_get_functiondef('public.fn_recompute_holdings_on_exemplar_change()'::regprocedure);
  v_bk  text := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  v_lot text := pg_get_functiondef('public.publish_catalog_batch(bigint)'::regprocedure);
  v_tb  text := pg_get_functiondef('public.fn_next_tombo(uuid)'::regprocedure);
BEGIN
  IF (length(v_rec) - length(replace(v_rec, 'in (select th.id from target_holdings th)', ''))) / length('in (select th.id from target_holdings th)') <> 8 THEN
    v_e := v_e || ' recompte-filtres';
  END IF;
  IF position('private.fn_h34_noter_fonds(ARRAY[OLD.holding_id])' IN v_tg) = 0
     OR position('ARRAY[NEW.holding_id, OLD.holding_id]' IN v_tg) = 0
     OR position('PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[NEW.holding_id]);' IN v_tg) = 0 THEN
    v_e := v_e || ' declencheur';
  END IF;
  IF (length(v_bk) - length(replace(v_bk, 'if not private.fn_h34_noter_fonds(ARRAY[v_holding_id]) then', ''))) / length('if not private.fn_h34_noter_fonds(ARRAY[v_holding_id]) then') <> 2 THEN
    v_e := v_e || ' notice';
  END IF;
  IF position('anarbib.h34_disponibilite_differee' IN v_lot) = 0
     OR position('perform private.fn_h34_recompter_fonds_notes();' IN v_lot) = 0
     OR position('perform private.fn_h34_recompter_fonds_notes();' IN v_lot) > position('published_at = now()' IN v_lot)
     OR position('anarbib.h34_disponibilite_differee' IN v_lot) > position('from public.book_drafts' IN v_lot)
     OR position('error.batch.other_libraries' IN v_lot) = 0
     OR position('error.batch.other_authors' IN v_lot) = 0
     OR position('error.catalog.staff_only' IN v_lot) = 0 THEN
    v_e := v_e || ' lot';
  END IF;
  IF position('tombos_attribues_serie_idx' IN v_tb) = 0
     OR position('pg_advisory_xact_lock(hashtext(''tombo:'' || v_full_prefix))' IN v_tb) = 0
     OR position('from public.tombos_attribues t' IN v_tb) = 0
     OR position('42501' IN v_tb) = 0 THEN
    v_e := v_e || ' tombo';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_index WHERE indexrelid = 'public.exemplares_tombo_serie_idx'::regclass AND indisvalid)
     OR NOT EXISTS (SELECT 1 FROM pg_index WHERE indexrelid = 'public.tombos_attribues_serie_idx'::regclass AND indisvalid) THEN
    v_e := v_e || ' index';
  END IF;
  -- droits : les fonctions modifiées gardent leurs portes ; les aides fermées
  FOREACH v_f IN ARRAY ARRAY['public.fn_next_tombo(uuid)', 'public.publish_catalog_batch(bigint)', 'public.publish_book_draft(bigint)'] LOOP
    IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['public.fn_v2_recompute_holdings_availability(bigint[], bigint[])', 'public.fn_recompute_holdings_on_exemplar_change()'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits(' || v_f || ')';
    END IF;
  END LOOP;
  FOREACH v_f IN ARRAY ARRAY['private.fn_h34_noter_fonds(bigint[])', 'private.fn_h34_recompter_fonds_notes()'] LOOP
    IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
       OR EXISTS (SELECT 1 FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
                   WHERE p.oid = v_f::regprocedure AND a.grantee = 0)
       OR (SELECT p.prosecdef OR coalesce(p.proconfig::text, '') NOT LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
      v_e := v_e || ' droits-aides(' || v_f || ')';
    END IF;
  END LOOP;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'H34 : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H34 : vérifications OK';
END
$h34_verif$;

NOTIFY pgrst, 'reload schema';
