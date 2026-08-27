-- =========================================================================
-- Paquet PÉRIODIQUES P1 — L'autorité de titre de périodique
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §3 et §9)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI. AnarBib porte déjà des champs de périodique sur public.books
-- (issn, titulo_periodico, volume, numero, fasciculo, data_edicao,
-- periodicidade). Ce qui manque n'est pas un champ, c'est un OBJET : le titre
-- d'une revue est aujourd'hui une chaîne recopiée sur chaque fascicule
-- (titulo_periodico, texte libre, rempli sur 2 notices sur 7). Il n'est ni une
-- entité, ni une autorité, ni une cible de lien. Quatre conséquences vérifiées
-- en base : aucun regroupement fiable ; aucun état de collection (donc pas de
-- PEB éclairé) ; des faux positifs de dédoublonnage (les quatre
-- « Encontros com a Civilização brasileira », titre strictement identique, ne
-- diffèrent que par l'année) ; et le changement de titre ingérable, alors que
-- c'est la règle sur un fonds qui court de 1860 à aujourd'hui.
--
-- Deux dossiers d'adhésion l'imposent maintenant : Anarchief.org (~100 titres
-- depuis les années 1860) et Bibliothèque SOLIDAIRES (12 titres, 91 fascicules
-- déjà listés).
--
-- CE QUE CE PAQUET FAIT, ET CE QU'IL NE FAIT PAS.
--   1. public.serials — le titre devient une autorité de plein exercice, de la
--      même famille que authors / subjects / publishers.
--   2. books.serial_id — le fascicule RESTE une notice books. On n'invente pas
--      une table de fascicules : un numéro de revue est un document catalogué,
--      prêtable, numérisable, réservable, exactement comme un livre. Il hérite
--      donc de toute la machinerie existante et gagne seulement un lien.
--   3. books.issue_key — clé de désignation calculée, pour DISTINGUER deux
--      fascicules (et non pour les ordonner parfaitement, cf. plus bas).
--   4. Les gardes G1 (cycle de filiation), G2 (réciprocité) et G3 (serial_id
--      sur un non-fascicule) de la spec, en TRIGGERS et non en discipline.
--
-- Il ne crée AUCUNE RPC (c'est P2), aucun état de collection (P4), et ne
-- touche pas à la détection de doublons (P3).
--
-- RIEN N'EST DÉTRUIT. titulo_periodico est conservé tel quel et change de
-- rôle : il devient la forme TRANSCRITE (ce qui est imprimé sur le fascicule),
-- à côté de la forme d'autorité portée par serials. C'est une distinction
-- catalographique classique, et elle sert : un fascicule peut porter un titre
-- légèrement différent de la forme retenue.
--
-- ÉCART ASSUMÉ AVEC LA SPEC v0.1. La spec §3.1 annonce le vocabulaire de
-- statut ('proposto','aprovado','obsoleto') en disant « reprend celui de
-- subjects ». Vérification faite en base, subjects_status_check vaut en réalité
-- ('proposto','ativo','depreciado'). Le PRINCIPE (calquer subjects) l'emporte
-- sur la liste littérale : c'est celui-là qui est implémenté, sans quoi
-- l'Atelier aurait deux vocabulaires de statut à afficher au lieu d'un.
-- Conséquence inchangée : une revue importée en masse arrive PROPOSÉE, donc
-- invisible du public, et c'est l'Atelier qui la promeut. Aucune autorité ne
-- naît validée d'un import.
--
-- RENUMÉROTÉ LE 27/08/2026, ET POURQUOI C'EST NOTÉ ICI. Ce paquet et les sept
-- suivants portaient d'abord les horodatages 20260827120000…140000. Or une
-- session voisine a poussé, quelques minutes avant, une migration au MÊME
-- horodatage 20260827120000 (invitation_claims_lot1_schema).
--
-- CE QUI S'EST PASSÉ EXACTEMENT (run backend #9006392, 07:38 UTC) : `supabase
-- db push` n'a pas sauté ce fichier — il a exécuté tout son DDL SANS ERREUR,
-- puis a échoué au dernier geste, l'enregistrement de la version :
--   ERROR: duplicate key value violates unique constraint "schema_migrations_pkey"
--   Key (version)=(20260827120000) already exists.
--
-- ⚠️ ET LE DDL N'A **PAS** ÉTÉ ANNULÉ. C'est le point qui compte, et je l'ai
-- d'abord cru l'inverse. Ce fichier porte son propre `BEGIN;` / `COMMIT;` :
-- au moment où le CLI tente d'écrire la ligne de version, la transaction du
-- fichier est DÉJÀ validée. Constaté sur staging entre les deux runs :
-- public.serials, books.serial_id, books.issue_key et les quatre triggers
-- existaient bel et bien, **sans aucune ligne dans schema_migrations**. Les
-- sept paquets suivants, eux, n'ont pas tourné.
--
-- Une collision d'horodatage laisse donc la base dans un état à moitié
-- migré et NON enregistré. Si le rattrapage a été un simple renumérotage,
-- c'est uniquement parce que ce paquet est écrit intégralement en
-- `CREATE TABLE IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` /
-- `DROP TRIGGER IF EXISTS` + `CREATE TRIGGER` : rejoué sous le nouveau
-- numéro, il a été un quasi no-op et s'est enregistré normalement. Un paquet
-- écrit sans ces gardes aurait exigé une réparation manuelle.
--
-- POURQUOI LA CHAÎNE LOCALE NE POUVAIT PAS L'ATTRAPER : le runner sql-tests
-- applique les FICHIERS par ordre lexicographique et ne tient aucun registre de
-- versions ; deux fichiers de même horodatage y cohabitent sans se gêner. Seul
-- `db push` raisonne sur la version. Une collision d'horodatage est donc
-- invisible en local, par construction.
--
-- LA PARADE est en amont, et elle est bon marché : après tout `git fetch`, et
-- juste avant de nommer un fichier de migration,
--   ls supabase/migrations/ | grep <la date du jour>
-- La règle « strictement supérieur au max présent » ne suffit pas quand le max
-- bouge sous les pieds — ce qu'il fait dès que deux sessions travaillent le
-- même jour.
--
-- CHECKLIST DOCTRINE
--   [x] Table public : GRANT explicites, ENABLE RLS, policies nommées
--   [x] Écritures réservées aux RPC SECURITY DEFINER (aucune policy d'écriture)
--   [x] Triggers en SECURITY INVOKER (ils ne lisent que public.serials)
--   [x] DO block de vérification en fin de transaction
--   [x] NOTIFY pgrst en sortie (le schéma exposé change)
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. public.serials — l'autorité de titre
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.serials (
  id                bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,

  -- identité
  slug              text NOT NULL UNIQUE,
  uniform_title     text NOT NULL,                       -- forme retenue
  sort_title        text,                                -- forme de tri
  title_nonfiling   smallint NOT NULL DEFAULT 0,         -- initiales à ignorer
  alt_i18n          jsonb NOT NULL DEFAULT '{}'::jsonb,  -- formes parallèles
  hidden_i18n       jsonb NOT NULL DEFAULT '{}'::jsonb,  -- formes rejetées

  -- identifiants
  issn              text,
  issn_l            text,                                -- ISSN de liaison

  -- description
  publisher_id      bigint REFERENCES public.publishers(id) ON DELETE SET NULL,
  emitter_org       text,                                -- organisation éditrice
  place_publication text,
  country_code      text,
  language          text,                                -- ISO 639-1
  periodicidade     text,                                -- libre, cf. TODO 1
  start_year        text,                                -- « 1896 », « ca. 1902 »
  end_year          text,                                -- NULL = en cours
  is_continuing     boolean NOT NULL DEFAULT true,
  scope_note        text,

  -- filiation (changements de titre)
  predecessor_id    bigint REFERENCES public.serials(id) ON DELETE SET NULL,
  successor_id      bigint REFERENCES public.serials(id) ON DELETE SET NULL,

  -- gouvernance, calquée sur subjects
  status            text NOT NULL DEFAULT 'proposto',
  created_at        timestamptz NOT NULL DEFAULT now(),
  created_by        uuid,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  updated_by        uuid,

  CONSTRAINT serials_status_chk
    CHECK (status IN ('proposto','ativo','depreciado')),
  CONSTRAINT serials_slug_not_blank      CHECK (btrim(slug) <> ''),
  CONSTRAINT serials_title_not_blank     CHECK (btrim(uniform_title) <> ''),
  CONSTRAINT serials_nonfiling_sane      CHECK (title_nonfiling BETWEEN 0 AND 20),
  CONSTRAINT serials_no_self_predecessor CHECK (predecessor_id IS DISTINCT FROM id),
  CONSTRAINT serials_no_self_successor   CHECK (successor_id   IS DISTINCT FROM id)
);

COMMENT ON TABLE public.serials IS
  'Autorité de titre de périodique, de la même famille que authors / subjects / '
  'publishers : slug, statut, libellés i18n, formes rejetées, note d''application, '
  'et passage par l''Atelier autorités pour la création, la correction et la fusion. '
  'Un titre de revue est une autorité du RÉSEAU, pas d''une bibliothèque — d''où '
  'l''absence de library_id (spec §13 TODO 3). Créée par le paquet PÉRIODIQUES P1 '
  'du 27/08/2026.';

COMMENT ON COLUMN public.serials.uniform_title IS
  'Forme retenue du titre. La forme transcrite sur chaque fascicule reste dans '
  'books.titulo_periodico : les deux coexistent volontairement.';
COMMENT ON COLUMN public.serials.title_nonfiling IS
  'Nombre de caractères initiaux à ignorer au tri (article défini). Ex. 3 pour '
  '« Le Libertaire ». sort_title, s''il est rempli, l''emporte sur ce calcul.';
COMMENT ON COLUMN public.serials.alt_i18n IS
  'Formes parallèles et variantes par locale : {"fr": ["..."], "es": ["..."]}. '
  'Affichables. Même forme que subjects.alt_i18n.';
COMMENT ON COLUMN public.serials.hidden_i18n IS
  'Formes REJETÉES par locale, non affichées mais cherchables — c''est ce qui '
  'rattrape les graphies fautives d''un import de masse.';
COMMENT ON COLUMN public.serials.issn_l IS
  'ISSN de liaison : relie les supports d''un même titre (papier, en ligne). '
  'Distinct de l''ISSN du support décrit ici.';
COMMENT ON COLUMN public.serials.emitter_org IS
  'Organisation éditrice (syndicat, groupe, fédération). Souvent DIFFÉRENTE de '
  'l''éditeur commercial de publisher_id — sur nos fonds, c''est même le cas '
  'général, et c''est cette information-là qui identifie la revue.';
COMMENT ON COLUMN public.serials.periodicidade IS
  'Vocabulaire LIBRE en P1, aligné sur books.periodicidade. Une liste fermée '
  'aiderait l''affichage mais demande un travail de vocabulaire multilingue : '
  'reporté à P9 (spec §13 TODO 1).';
COMMENT ON COLUMN public.serials.start_year IS
  'Texte, pas un entier : « 1896 », « ca. 1902 », « [1936?] ». Nos fonds ne '
  'permettent pas toujours mieux, et forcer un entier ferait mentir la notice.';
COMMENT ON COLUMN public.serials.predecessor_id IS
  'Titre précédent (changement de nom). Deux liens simples plutôt qu''une table '
  'de relations n-n : une revue née d''une FUSION de deux titres se traite en '
  'chaînant, avec scope_note pour le dire en clair. À rouvrir seulement si le '
  'fonds Anarchief l''impose (spec §13 TODO 2). La réciprocité est tenue par '
  'le trigger serials_filiation_symmetry, pas par la discipline d''appel.';
COMMENT ON COLUMN public.serials.successor_id IS
  'Titre suivant (changement de nom). Voir predecessor_id.';
COMMENT ON COLUMN public.serials.status IS
  'proposto (défaut) / ativo / depreciado — MÊME vocabulaire que subjects.status, '
  'vérifié en base le 27/08/2026 (la spec v0.1 §3.1 annonçait par erreur '
  '« aprovado/obsoleto »). Seul ativo est visible du public : un import de masse '
  'ne publie donc rien tant que l''Atelier n''a pas promu les titres.';

CREATE INDEX IF NOT EXISTS serials_uniform_title_trgm
  ON public.serials USING gin (uniform_title extensions.gin_trgm_ops);
CREATE INDEX IF NOT EXISTS serials_issn_idx
  ON public.serials (issn) WHERE issn IS NOT NULL;
CREATE INDEX IF NOT EXISTS serials_status_idx
  ON public.serials (status);
CREATE INDEX IF NOT EXISTS serials_publisher_id_idx
  ON public.serials (publisher_id) WHERE publisher_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS serials_predecessor_id_idx
  ON public.serials (predecessor_id) WHERE predecessor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS serials_successor_id_idx
  ON public.serials (successor_id) WHERE successor_id IS NOT NULL;

-- -------------------------------------------------------------------------
-- 2. Slug automatique (calqué sur fn_subjects_autoslug)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_serials_autoslug()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $function$
DECLARE base text; cand text; i int := 2;
BEGIN
  IF NEW.slug IS NOT NULL AND btrim(NEW.slug) <> '' THEN RETURN NEW; END IF;
  base := btrim(regexp_replace(lower(public.f_normalize_search(NEW.uniform_title)),
                               '[^a-z0-9]+', '-', 'g'), '-');
  IF base IS NULL OR base = '' THEN base := 'periodico'; END IF;
  cand := base;
  WHILE EXISTS (SELECT 1 FROM public.serials WHERE slug = cand) LOOP
    cand := base || '-' || i; i := i + 1;
  END LOOP;
  NEW.slug := cand;
  RETURN NEW;
END $function$;

COMMENT ON FUNCTION public.fn_serials_autoslug() IS
  'Slug automatique depuis uniform_title si aucun n''est fourni, avec suffixe '
  'numérique en cas de collision. Calqué sur fn_subjects_autoslug.';

DROP TRIGGER IF EXISTS serials_autoslug ON public.serials;
CREATE TRIGGER serials_autoslug
  BEFORE INSERT ON public.serials
  FOR EACH ROW EXECUTE FUNCTION public.fn_serials_autoslug();

DROP TRIGGER IF EXISTS serials_set_updated_at ON public.serials;
CREATE TRIGGER serials_set_updated_at
  BEFORE UPDATE ON public.serials
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -------------------------------------------------------------------------
-- 3. G1 — la filiation refuse un cycle
-- -------------------------------------------------------------------------
-- Parcours borné à 20 sauts, exception au-delà. Le garde est un TRIGGER et non
-- une vérification dans la RPC : une garde d'intégrité qui ne vaut que pour un
-- chemin d'écriture n'en est pas une (import, correction en SQL, fusion).
CREATE OR REPLACE FUNCTION public.fn_serials_filiation_no_cycle()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_cur  bigint;
  v_hops int := 0;
BEGIN
  -- Chaîne des successeurs : A -> successeur -> ... doit ne jamais revenir à A.
  v_cur := NEW.successor_id;
  WHILE v_cur IS NOT NULL AND v_hops < 20 LOOP
    IF v_cur = NEW.id THEN
      RAISE EXCEPTION 'Filiation circulaire refusée sur le périodique %.', NEW.id
        USING ERRCODE = 'P0001', HINT = 'error.serial.filiation.cycle';
    END IF;
    SELECT s.successor_id INTO v_cur FROM public.serials s WHERE s.id = v_cur;
    v_hops := v_hops + 1;
  END LOOP;
  IF v_hops >= 20 THEN
    RAISE EXCEPTION 'Chaîne de filiation trop longue (>20) au départ du périodique %.', NEW.id
      USING ERRCODE = 'P0001', HINT = 'error.serial.filiation.tooLong';
  END IF;

  -- Chaîne des prédécesseurs, symétriquement.
  v_cur := NEW.predecessor_id;
  v_hops := 0;
  WHILE v_cur IS NOT NULL AND v_hops < 20 LOOP
    IF v_cur = NEW.id THEN
      RAISE EXCEPTION 'Filiation circulaire refusée sur le périodique %.', NEW.id
        USING ERRCODE = 'P0001', HINT = 'error.serial.filiation.cycle';
    END IF;
    SELECT s.predecessor_id INTO v_cur FROM public.serials s WHERE s.id = v_cur;
    v_hops := v_hops + 1;
  END LOOP;
  IF v_hops >= 20 THEN
    RAISE EXCEPTION 'Chaîne de filiation trop longue (>20) au départ du périodique %.', NEW.id
      USING ERRCODE = 'P0001', HINT = 'error.serial.filiation.tooLong';
  END IF;

  RETURN NEW;
END $function$;

COMMENT ON FUNCTION public.fn_serials_filiation_no_cycle() IS
  'Garde G1 de la spec périodiques : refuse un cycle de filiation, parcours '
  'borné à 20 sauts dans chaque sens.';

DROP TRIGGER IF EXISTS serials_filiation_no_cycle ON public.serials;
CREATE TRIGGER serials_filiation_no_cycle
  BEFORE INSERT OR UPDATE OF predecessor_id, successor_id ON public.serials
  FOR EACH ROW EXECUTE FUNCTION public.fn_serials_filiation_no_cycle();

-- -------------------------------------------------------------------------
-- 4. G2 — la filiation pose bien les DEUX côtés
-- -------------------------------------------------------------------------
-- Poser A.successor_id = B ne pose pas B.predecessor_id = A. La spec laissait
-- le choix entre un trigger et « la discipline dans la RPC », en recommandant
-- le trigger : la discipline ne survit pas à six mois. Retenu.
--
-- TERMINAISON. Chaque UPDATE imbriqué est conditionné par « la réciproque
-- n'est pas déjà posée » : la première passe corrige, la seconde ne trouve
-- rien à faire et la récursion s'arrête. Pas besoin de pg_trigger_depth().
CREATE OR REPLACE FUNCTION public.fn_serials_filiation_symmetry()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- Successeur posé -> le successeur me reconnaît pour prédécesseur.
  IF NEW.successor_id IS NOT NULL THEN
    UPDATE public.serials s
       SET predecessor_id = NEW.id
     WHERE s.id = NEW.successor_id
       AND s.predecessor_id IS DISTINCT FROM NEW.id;
  END IF;

  -- Successeur abandonné -> retirer la réciproque devenue fausse.
  IF TG_OP = 'UPDATE'
     AND OLD.successor_id IS NOT NULL
     AND OLD.successor_id IS DISTINCT FROM NEW.successor_id THEN
    UPDATE public.serials s
       SET predecessor_id = NULL
     WHERE s.id = OLD.successor_id
       AND s.predecessor_id = NEW.id;
  END IF;

  -- Prédécesseur posé -> le prédécesseur me reconnaît pour successeur.
  IF NEW.predecessor_id IS NOT NULL THEN
    UPDATE public.serials s
       SET successor_id = NEW.id
     WHERE s.id = NEW.predecessor_id
       AND s.successor_id IS DISTINCT FROM NEW.id;
  END IF;

  -- Prédécesseur abandonné -> retirer la réciproque devenue fausse.
  IF TG_OP = 'UPDATE'
     AND OLD.predecessor_id IS NOT NULL
     AND OLD.predecessor_id IS DISTINCT FROM NEW.predecessor_id THEN
    UPDATE public.serials s
       SET successor_id = NULL
     WHERE s.id = OLD.predecessor_id
       AND s.successor_id = NEW.id;
  END IF;

  RETURN NULL;
END $function$;

COMMENT ON FUNCTION public.fn_serials_filiation_symmetry() IS
  'Garde G2 de la spec périodiques : pose et retire la réciproque de la '
  'filiation (predecessor_id <-> successor_id). Trigger et non discipline '
  'd''appel — la discipline ne survit pas à six mois.';

DROP TRIGGER IF EXISTS serials_filiation_symmetry ON public.serials;
CREATE TRIGGER serials_filiation_symmetry
  AFTER INSERT OR UPDATE OF predecessor_id, successor_id ON public.serials
  FOR EACH ROW EXECUTE FUNCTION public.fn_serials_filiation_symmetry();

-- -------------------------------------------------------------------------
-- 5. GRANTs et RLS
-- -------------------------------------------------------------------------
-- Scénario A du template : autorité publique, lisible par anon quand elle est
-- promue. AUCUN droit d'écriture : tout passe par les RPC SECURITY DEFINER
-- de P2, qui portent le contrôle de rôle.
--
-- LE REVOKE N'EST PAS DÉCORATIF. Supabase pose des ALTER DEFAULT PRIVILEGES sur
-- le schéma public : une table fraîchement créée arrive avec INSERT/UPDATE/
-- DELETE déjà accordés à anon et authenticated. Ne rien écrire ici ne veut donc
-- pas dire « pas de droits », mais « tous les droits ». Vérifié le 27/08/2026 :
-- sans ces deux lignes, n'importe quel compte authentifié pouvait écrire
-- directement dans l'autorité, court-circuitant toutes les gardes de rôle.
REVOKE ALL ON public.serials FROM anon, authenticated;
GRANT SELECT ON public.serials TO anon, authenticated;
GRANT ALL    ON public.serials TO service_role;

ALTER TABLE public.serials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS serials_select_public ON public.serials;
CREATE POLICY serials_select_public
  ON public.serials FOR SELECT
  TO anon, authenticated
  USING (status = 'ativo');

DROP POLICY IF EXISTS serials_select_staff ON public.serials;
CREATE POLICY serials_select_staff
  ON public.serials FOR SELECT
  TO authenticated
  USING (public.fn_caller_is_staff());

COMMENT ON POLICY serials_select_public ON public.serials IS
  'Le public ne voit que les titres promus. Conséquence assumée : un import de '
  'masse ne publie rien tant que l''Atelier n''a pas statué.';
COMMENT ON POLICY serials_select_staff ON public.serials IS
  'Le staff de catalogage voit tout, y compris les titres proposés — sans quoi '
  'il ne pourrait pas les instruire.';

-- -------------------------------------------------------------------------
-- 6. Lien fascicule -> titre
-- -------------------------------------------------------------------------
ALTER TABLE public.books
  ADD COLUMN IF NOT EXISTS serial_id bigint
    REFERENCES public.serials(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS books_serial_id_idx
  ON public.books (serial_id) WHERE serial_id IS NOT NULL;

COMMENT ON COLUMN public.books.titulo_periodico IS
  'Titre de périodique TEL QUE TRANSCRIT sur le fascicule. La forme d''autorité '
  'est portée par serials via books.serial_id. Les deux coexistent volontairement : '
  'un fascicule peut porter un titre légèrement différent de la forme retenue, et '
  'c''est une information catalographique, pas une erreur à corriger.';

COMMENT ON COLUMN public.books.serial_id IS
  'Titre de périodique en forme d''autorité (public.serials). NULL pour tout ce '
  'qui n''est pas un fascicule. Le fascicule reste une notice books de plein '
  'exercice : prêtable, réservable, numérisable — il gagne seulement ce lien.';

-- -------------------------------------------------------------------------
-- 7. Clé de désignation du fascicule
-- -------------------------------------------------------------------------
-- Le tri « n°1, n°2, n°10 » ne se fait pas alphabétiquement, et l'égalité de
-- deux fascicules ne se juge pas sur le titre. On calcule une clé.
--
-- POURQUOI PAS UN TRI NUMÉRIQUE PUR : les fascicules militants portent des
-- désignations impossibles à normaliser (« n° spécial », « été 1936 »,
-- « 12/13 »). La clé mélange donc chiffres et date, et sert à DISTINGUER, pas
-- à ordonner parfaitement. L'ordre d'affichage se fait sur (ano, issue_key)
-- avec repli sur le titre (garde G6).
CREATE OR REPLACE FUNCTION public.fn_serial_issue_key(
  p_volume text, p_numero text, p_fasciculo text, p_data_edicao text, p_ano text)
RETURNS text
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT nullif(btrim(concat_ws('|',
    nullif(regexp_replace(coalesce(p_volume,''),    '\D', '', 'g'), ''),
    nullif(regexp_replace(coalesce(p_numero,''),    '\D', '', 'g'), ''),
    nullif(regexp_replace(coalesce(p_fasciculo,''), '\D', '', 'g'), ''),
    nullif(btrim(lower(coalesce(p_data_edicao,''))), ''),
    nullif(btrim(coalesce(p_ano,'')), '')
  )), '');
$function$;

COMMENT ON FUNCTION public.fn_serial_issue_key(text, text, text, text, text) IS
  'Clé de désignation d''un fascicule (volume|numero|fasciculo|date|année, '
  'chiffres seuls pour les trois premiers). Sert à DISTINGUER deux fascicules, '
  'pas à les ordonner. IMMUTABLE : elle alimente une colonne générée — la '
  'modifier ne recalcule PAS books.issue_key, il faudrait un UPDATE explicite.';

ALTER TABLE public.books
  ADD COLUMN IF NOT EXISTS issue_key text GENERATED ALWAYS AS (
    public.fn_serial_issue_key(volume, numero, fasciculo, data_edicao, ano)
  ) STORED;

CREATE INDEX IF NOT EXISTS books_serial_issue_idx
  ON public.books (serial_id, issue_key) WHERE serial_id IS NOT NULL;

COMMENT ON COLUMN public.books.issue_key IS
  'Désignation normalisée du fascicule, calculée (GENERATED ALWAYS ... STORED) '
  'depuis volume/numero/fasciculo/data_edicao/ano. Garde G4 de la spec : tout '
  'INSERT ou UPDATE qui tenterait de l''écrire ÉCHOUE — les pipelines d''import '
  'ne doivent jamais la nommer, en particulier pas via un SELECT * suivi d''un '
  'INSERT symétrique.';

-- -------------------------------------------------------------------------
-- 8. G3 — serial_id sur un non-fascicule
-- -------------------------------------------------------------------------
-- Rien n'empêche techniquement de poser serial_id sur un livre. Le lien n'a de
-- sens que pour un fascicule ('periodico') ou, le jour venu, un article
-- ('artigo' — point d'accroche prévu, rien d'implémenté, spec §12).
CREATE OR REPLACE FUNCTION public.fn_books_serial_id_requires_periodico()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.serial_id IS NOT NULL
     AND NEW.tipo_material NOT IN ('periodico','artigo') THEN
    RAISE EXCEPTION
      'Un titre de périodique ne peut être rattaché qu''à un fascicule ou un article (tipo_material=%).',
      NEW.tipo_material
      USING ERRCODE = 'P0001', HINT = 'error.serial.attach.wrongMaterial';
  END IF;
  RETURN NEW;
END $function$;

COMMENT ON FUNCTION public.fn_books_serial_id_requires_periodico() IS
  'Garde G3 de la spec périodiques : serial_id non nul exige '
  'tipo_material IN (''periodico'',''artigo'').';

DROP TRIGGER IF EXISTS books_serial_id_requires_periodico ON public.books;
CREATE TRIGGER books_serial_id_requires_periodico
  BEFORE INSERT OR UPDATE OF serial_id, tipo_material ON public.books
  FOR EACH ROW EXECUTE FUNCTION public.fn_books_serial_id_requires_periodico();

-- -------------------------------------------------------------------------
-- 9. Vérification automatique
-- -------------------------------------------------------------------------
-- Vérifications STRUCTURELLES uniquement. Une migration ne crée ni ne détruit
-- de données de catalogue pour se tester elle-même : sur la base réelle, ces
-- lignes témoins consommeraient des identifiants de notices et feraient tourner
-- les triggers métier pour rien. Les vérifications FONCTIONNELLES (G1, G2, G3,
-- G4, autoslug, fusion, état de collection) vivent dans la suite d'acceptation
-- tests/sql/periodiques_tests.sql, exécutée par le job CI « sql-tests » sur une
-- base reconstruite AVEC son seed — ce que ce bloc-ci ne peut pas faire,
-- puisque les migrations s'appliquent AVANT le seed.
DO $verif$
DECLARE
  v_manque text[];
BEGIN
  -- 1. La clé de désignation, sur trois formes réelles de nos fonds. Fonction
  --    pure : aucune donnée touchée.
  IF public.fn_serial_issue_key(NULL, 'n° 12', NULL, 'Maio de 1997', '1997')
     IS DISTINCT FROM '12|maio de 1997|1997' THEN
    RAISE EXCEPTION 'fn_serial_issue_key : forme numérotée inattendue (%).',
      public.fn_serial_issue_key(NULL, 'n° 12', NULL, 'Maio de 1997', '1997');
  END IF;
  IF public.fn_serial_issue_key(NULL, NULL, NULL, NULL, '1978') IS DISTINCT FROM '1978' THEN
    RAISE EXCEPTION 'fn_serial_issue_key : année seule inattendue.';
  END IF;
  IF public.fn_serial_issue_key(NULL, NULL, NULL, NULL, NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'fn_serial_issue_key : le vide doit rendre NULL.';
  END IF;

  -- 2. issue_key est bien une colonne GÉNÉRÉE (garde G4 : inécrivable).
  IF NOT EXISTS (
    SELECT 1 FROM pg_attribute
     WHERE attrelid = 'public.books'::regclass
       AND attname = 'issue_key' AND attgenerated = 's') THEN
    RAISE EXCEPTION 'G4 : books.issue_key n''est pas une colonne générée stockée.';
  END IF;

  -- 3. Les quatre triggers de garde sont en place.
  SELECT array_agg(t) INTO v_manque FROM (
    SELECT t FROM unnest(ARRAY['serials_autoslug','serials_filiation_no_cycle',
                               'serials_filiation_symmetry']) AS t
    WHERE NOT EXISTS (SELECT 1 FROM pg_trigger
                       WHERE tgrelid = 'public.serials'::regclass AND tgname = t)
  ) q;
  IF v_manque IS NOT NULL THEN
    RAISE EXCEPTION 'Triggers de serials manquants : %.', array_to_string(v_manque, ', ');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = 'public.books'::regclass
                    AND tgname = 'books_serial_id_requires_periodico') THEN
    RAISE EXCEPTION 'G3 : le trigger books_serial_id_requires_periodico est absent.';
  END IF;

  -- 4. RLS active, et les deux policies de lecture présentes.
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.serials'::regclass) THEN
    RAISE EXCEPTION 'public.serials : RLS non activée.';
  END IF;
  IF (SELECT count(*) FROM pg_policies
       WHERE schemaname = 'public' AND tablename = 'serials') <> 2 THEN
    RAISE EXCEPTION 'public.serials : nombre de policies inattendu.';
  END IF;

  -- 5. Aucun droit d'écriture direct : tout doit passer par les RPC de P2.
  IF has_table_privilege('anon', 'public.serials', 'INSERT')
     OR has_table_privilege('authenticated', 'public.serials', 'INSERT')
     OR has_table_privilege('authenticated', 'public.serials', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.serials', 'DELETE') THEN
    RAISE EXCEPTION 'public.serials : des droits d''écriture directs subsistent.';
  END IF;
  IF NOT has_table_privilege('anon', 'public.serials', 'SELECT') THEN
    RAISE EXCEPTION 'public.serials : anon ne peut pas lire (la RLS filtrera, pas le GRANT).';
  END IF;

  RAISE NOTICE 'Paquet PÉRIODIQUES P1 : vérifications structurelles OK (clé, colonne générée, 4 triggers, RLS, droits).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé en cas de régression post-déploiement :
-- =========================================================================
-- BEGIN;
--   DROP TRIGGER IF EXISTS books_serial_id_requires_periodico ON public.books;
--   DROP FUNCTION IF EXISTS public.fn_books_serial_id_requires_periodico();
--   ALTER TABLE public.books DROP COLUMN IF EXISTS issue_key;
--   ALTER TABLE public.books DROP COLUMN IF EXISTS serial_id;
--   DROP FUNCTION IF EXISTS public.fn_serial_issue_key(text, text, text, text, text);
--   DROP TABLE IF EXISTS public.serials;
--   DROP FUNCTION IF EXISTS public.fn_serials_filiation_symmetry();
--   DROP FUNCTION IF EXISTS public.fn_serials_filiation_no_cycle();
--   DROP FUNCTION IF EXISTS public.fn_serials_autoslug();
-- COMMIT;
-- =========================================================================
