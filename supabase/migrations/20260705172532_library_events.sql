-- 20260705120000_library_events.sql
-- Événements organisés par une bibliothèque : lectures publiques, débats,
-- ateliers, rencontres, projections…
--
-- • Définis par le staff COORDINATEUR sur la page de gestion /biblioteca
--   (nouvel onglet « Événements »), via supabase.from('library_events') (RLS staff).
-- • Présentés en LECTURE SEULE aux membres actifs dans le compte lecteur /conta
--   (nouvel onglet « Événements »), via la RPC api.fn_my_library_events()
--   (SECURITY DEFINER, filtrée sur auth.uid() + statut d'adhésion 'active').
--
-- Modèle calqué sur public.painel_internal_tasks (RLS via
-- user_can_act_as_staff_on_library) et api.fn_my_memberships_status (RPC lecteur).

BEGIN;

-- ── Table ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "public"."library_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "library_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "event_type" "text" DEFAULT 'autre'::"text" NOT NULL,
    "starts_at" timestamp with time zone NOT NULL,
    "ends_at" timestamp with time zone,
    "location" "text",
    "is_public" boolean DEFAULT true NOT NULL,
    "is_cancelled" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid" DEFAULT "auth"."uid"(),
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_by" "uuid" DEFAULT "auth"."uid"(),
    CONSTRAINT "library_events_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "library_events_library_id_fkey" FOREIGN KEY ("library_id")
        REFERENCES "public"."libraries"("id") ON DELETE CASCADE,
    CONSTRAINT "library_events_event_type_check" CHECK (
        "event_type" = ANY (ARRAY[
            'lecture_publique'::"text",
            'debat'::"text",
            'atelier'::"text",
            'rencontre'::"text",
            'projection'::"text",
            'autre'::"text"
        ])),
    CONSTRAINT "library_events_time_check" CHECK (
        "ends_at" IS NULL OR "ends_at" >= "starts_at")
);

ALTER TABLE "public"."library_events" OWNER TO "postgres";

COMMENT ON TABLE "public"."library_events" IS 'Événements organisés par une bibliothèque (lectures publiques, débats, ateliers…). Créés par le staff coordinateur (onglet Événements de /biblioteca), présentés en lecture aux membres actifs (/conta). Ajouté 2026-07-05.';
COMMENT ON COLUMN "public"."library_events"."event_type" IS 'lecture_publique | debat | atelier | rencontre | projection | autre.';
COMMENT ON COLUMN "public"."library_events"."is_public" IS 'true = visible par les membres de la biblio dans leur compte lecteur. false = brouillon interne.';
COMMENT ON COLUMN "public"."library_events"."is_cancelled" IS 'Annulation douce sans suppression (l''événement disparaît de la vue lecteur).';

CREATE INDEX "idx_library_events_library_starts" ON "public"."library_events" USING "btree" ("library_id", "starts_at");

-- ── Trigger touch (updated_at / updated_by) ──────────────────────────────
CREATE OR REPLACE FUNCTION "public"."trg_library_events_touch"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
BEGIN
  NEW.updated_at := pg_catalog.now();
  NEW.updated_by := auth.uid();
  RETURN NEW;
END;
$$;
ALTER FUNCTION "public"."trg_library_events_touch"() OWNER TO "postgres";

CREATE OR REPLACE TRIGGER "trg_library_events_touch" BEFORE UPDATE ON "public"."library_events"
    FOR EACH ROW EXECUTE FUNCTION "public"."trg_library_events_touch"();

-- ── RLS : CRUD réservé au staff de la biblio (ou admin réseau) ────────────
ALTER TABLE "public"."library_events" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "library_events_select_same_library_team" ON "public"."library_events"
    FOR SELECT USING ("public"."user_can_act_as_staff_on_library"("library_id"));
CREATE POLICY "library_events_insert_same_library_team" ON "public"."library_events"
    FOR INSERT WITH CHECK ("public"."user_can_act_as_staff_on_library"("library_id"));
CREATE POLICY "library_events_update_same_library_team" ON "public"."library_events"
    FOR UPDATE USING ("public"."user_can_act_as_staff_on_library"("library_id"))
    WITH CHECK ("public"."user_can_act_as_staff_on_library"("library_id"));
CREATE POLICY "library_events_delete_same_library_team" ON "public"."library_events"
    FOR DELETE USING ("public"."user_can_act_as_staff_on_library"("library_id"));

COMMENT ON POLICY "library_events_select_same_library_team" ON "public"."library_events" IS 'Lecture des événements : staff local ou admin réseau. La lecture côté lecteur passe par api.fn_my_library_events (SECURITY DEFINER).';

-- ── Grants (doctrine durcissement : anon sans verbes de données) ──────────
REVOKE ALL ON TABLE "public"."library_events" FROM PUBLIC;
REVOKE ALL ON TABLE "public"."library_events" FROM "anon";
GRANT ALL ON TABLE "public"."library_events" TO "authenticated";
GRANT ALL ON TABLE "public"."library_events" TO "service_role";

-- ── RPC lecteur : agenda à venir de ses biblios (membre actif) ────────────
-- La lecture lecteur ne repose PAS sur une policy RLS de la table mais sur
-- cette fonction SECURITY DEFINER, filtrée par auth.uid() + statut 'active'.
CREATE OR REPLACE FUNCTION "api"."fn_my_library_events"()
    RETURNS TABLE(
        "id" "uuid",
        "library_id" "uuid",
        "library_slug" "text",
        "library_name" "text",
        "title" "text",
        "description" "text",
        "event_type" "text",
        "starts_at" timestamp with time zone,
        "ends_at" timestamp with time zone,
        "location" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_catalog'
    AS $$
  SELECT
    e.id,
    e.library_id,
    l.slug,
    COALESCE(l.short_name, l.name),
    e.title,
    e.description,
    e.event_type,
    e.starts_at,
    e.ends_at,
    e.location
  FROM public.library_events e
  JOIN public.libraries l ON l.id = e.library_id
  JOIN public.user_library_memberships m
    ON m.library_id = e.library_id
   AND m.user_id = auth.uid()
  WHERE e.is_public = true
    AND e.is_cancelled = false
    AND m.status = 'active'
    AND COALESCE(e.ends_at, e.starts_at + interval '3 hours') >= now()
  ORDER BY e.starts_at ASC;
$$;

ALTER FUNCTION "api"."fn_my_library_events"() OWNER TO "postgres";
REVOKE ALL ON FUNCTION "api"."fn_my_library_events"() FROM PUBLIC;
GRANT ALL ON FUNCTION "api"."fn_my_library_events"() TO "authenticated";

COMMENT ON FUNCTION "api"."fn_my_library_events"() IS 'Agenda à venir (événements publics, non annulés, pas encore terminés) des bibliothèques où l''appelant est membre actif. Lecture seule pour le compte lecteur /conta. Ajouté 2026-07-05.';

COMMIT;
