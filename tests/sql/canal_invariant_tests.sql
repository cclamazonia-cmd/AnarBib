-- =====================================================================
-- AnarBib — Tests : toute bibliothèque a sa ligne de canal
-- Date    : 2026-08-30
-- Ref     : 20260830203000 (toute_biblio_a_sa_ligne_de_canal)
--
-- `library_mail_channels` est depuis le 30/08 le SEUL commutateur d'envoi
-- d'une bibliothèque : `active` coupe, `delivery_mode` choisit le transport,
-- `admin_notification_email` porte le destinataire des avis. Rien ne
-- garantissait qu'une biblio ait sa ligne — CIRA Marseille n'en avait pas, et
-- sa coordination ne voyait donc AUCUN réglage de canal dans son écran, le
-- bloc entier étant conditionné à l'existence de la ligne.
--
-- La migration porte l'invariant par un trigger sur `libraries` plutôt qu'en
-- patchant le chemin de constitution : un trigger couvre tous les chemins de
-- création, un patch ne couvre que celui qu'on a en tête.
--
-- T3 est le test qui compte. T1 et T2 vérifient que l'objet existe et qu'il
-- est déclaré correctement ; T3 seul prouve qu'il FAIT quelque chose — et
-- prouve surtout que les valeurs posées sont exactement le repli que le code
-- appliquait déjà (fallbackLibraryNotificationContext : platform_shared,
-- active, e-mails à NULL). C'est ce qui autorise à dire que la migration ne
-- change le comportement d'aucun envoi.
--   Bilan OK : 'CANAL-INVARIANT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text; v_lib uuid; v_row public.library_mail_channels;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le trigger est pose sur libraries, AFTER INSERT FOR EACH ROW';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
     WHERE c.relname = 'libraries'
       AND t.tgname = 'trg_library_ensure_mail_channel'
       AND NOT t.tgisinternal
       AND pg_get_triggerdef(t.oid) ILIKE '%AFTER INSERT%'
       AND pg_get_triggerdef(t.oid) ILIKE '%FOR EACH ROW%';
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : trouve '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- SECURITY DEFINER n'est pas un confort : la table est sous RLS
  -- (user_can_manage_library_notifications) et la personne qui cree la biblio
  -- n'en est pas encore membre. En invoker, l'INSERT du trigger serait refuse
  -- et la creation de la bibliotheque echouerait avec lui.
  v_t := 'T2 la fonction du trigger est SECURITY DEFINER, search_path fige';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'fn_library_ensure_mail_channel'
       AND p.prosecdef
       AND array_to_string(coalesce(p.proconfig, ARRAY[]::text[]), ',') ILIKE '%search_path%';
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : trouve '||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 une biblio nouvellement creee recoit sa ligne, aux valeurs du repli';
  BEGIN
    INSERT INTO public.libraries (slug, name)
    VALUES ('zz-test-canal-invariant', 'Biblioteca de teste — canal')
    RETURNING id INTO v_lib;

    SELECT * INTO v_row FROM public.library_mail_channels WHERE library_id = v_lib;

    IF v_row.library_id IS NULL THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucune ligne creee');
    ELSIF v_row.delivery_mode <> 'platform_shared'
       OR v_row.active IS NOT TRUE
       OR v_row.transport_state <> 'not_tested'
       OR v_row.admin_notification_email IS NOT NULL
       OR v_row.weekly_report_email IS NOT NULL
       OR v_row.severe_alert_email IS NOT NULL THEN
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : valeurs inattendues -> mode='||coalesce(v_row.delivery_mode,'NULL')
        ||' active='||coalesce(v_row.active::text,'NULL')
        ||' admin='||coalesce(v_row.admin_notification_email,'NULL'));
    ELSE v_passed := v_passed+1;
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Vacuement vrai en CI (schema reconstruit sans donnees) ; en prod, c'est ce
  -- test qui dit que le rattrapage a bien eu lieu.
  v_t := 'T4 aucune bibliotheque ne reste sans ligne de canal';
  BEGIN
    SELECT count(*), coalesce(string_agg(l.slug, ', ' ORDER BY l.slug), '')
      INTO v_n, v_txt
      FROM public.libraries l
     WHERE NOT EXISTS (
       SELECT 1 FROM public.library_mail_channels c WHERE c.library_id = l.id
     );
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||v_txt); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le rattrapage de la migration doit pouvoir etre rejoue sans rien ecraser :
  -- une reprise de migration ne doit pas remettre a zero le canal d'une biblio
  -- qui a entre-temps saisi ses adresses.
  v_t := 'T5 le rattrapage est rejouable sans ecraser une ligne existante';
  BEGIN
    UPDATE public.library_mail_channels
       SET admin_notification_email = 'garde@exemple.org', active = false
     WHERE library_id = v_lib;

    INSERT INTO public.library_mail_channels (library_id)
    SELECT l.id FROM public.libraries l
    WHERE NOT EXISTS (SELECT 1 FROM public.library_mail_channels c WHERE c.library_id = l.id)
    ON CONFLICT (library_id) DO NOTHING;

    SELECT * INTO v_row FROM public.library_mail_channels WHERE library_id = v_lib;
    IF v_row.admin_notification_email = 'garde@exemple.org' AND v_row.active IS FALSE THEN
      v_passed := v_passed+1;
    ELSE
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : ligne ecrasee -> admin='||coalesce(v_row.admin_notification_email,'NULL'));
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Le RAISE final annule la transaction : la biblio de test ne survit pas.
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'CANAL-INVARIANT OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'CANAL-INVARIANT ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
