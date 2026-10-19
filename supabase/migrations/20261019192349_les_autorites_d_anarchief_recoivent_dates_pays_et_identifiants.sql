-- =========================================================================
-- Les autorités créées depuis Anarchief.org reçoivent dates, pays, langue
-- et identifiants (Wikidata, VIAF, ISNI, IdRef) — décision D7
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : sources partenaires — Anarchief.org (autorités)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — enrichissement des autorités (D7)
-- Ref      : migration 20261019160041 (les 308 autorités créées, étiquette
--            « Anarchief.org · import 2026-10 ») ;
--            PROPOSITION_enrichissement_autorites_anarchief_2026-10-19.md
--            (hors dépôt, dossier de la coordination) ; décision de Xavier du
--            19/10/2026 (« A, B, K, C et KC validés ; migration, pays
--            compris ») ; outils et tableurs :
--            docs/journal/operations/enrichissement-autorites-2026-09-26/anarchief-2026-10-19/ ;
--            tests/sql/enrichir_autorites_tests.sql
--
-- POURQUOI
--   Les 308 autorités créées le 19/10 depuis les notices d'Anarchief.org
--   (197 personnes, 111 collectifs) n'ont ni dates, ni pays, ni identifiant
--   externe : pas de rapprochement possible avec les autres sources, pages
--   d'auteur·rice nues. La décision D7 voulait les enrichir après coup.
--
-- MÉTHODE (recette du 26-27/09, docs/journal/operations/enrichissement-autorites-2026-09-26/README.md)
--   Wikidata puis IdRef, lecture seule ; nom identique (ordre des mots près,
--   formes variantes de la fiche comprises), aucune contradiction, et DATES
--   CONCORDANTES OU DEUX SIGNAUX (identifiant de bibliothèque nationale,
--   métier d'écriture, anarchisme déclaré ; pour IdRef, un titre de la fiche
--   parmi les documents SUDOC liés). Ces fiches n'avaient aucune date : seule
--   la voie « deux signaux » était ouverte. Relu ligne à ligne et validé par
--   Xavier le 19/10 :
--     A  58 personnes acceptées par la règle ;
--     B  22 personnes relues à la main, deux sources concordantes ;
--     C   3 personnes à un signal, confirmées par Xavier ;
--     K   9 collectifs relus un par un (Wikidata, VIAF, pays seulement) ;
--     KC  2 collectifs douteux, confirmés par Xavier.
--   94 fiches sur 308 ; les 214 autres n'ont aucune correspondance sûre.
--   Pays laissés vides quand deux sources se contredisent (Clara Wichmann,
--   Louis Adamic) ; langue laissée vide pour Thom Holterman (Wikidata dit
--   l'anglais).
--
-- CE QUE FAIT LE PAQUET
--   1. private.fn_enrichir_autorites(liste, date, lot) : pour chaque fiche
--      d'une LISTE FERMÉE, retrouvée par son id ET sa forme retenue, remplit
--      ce qui est VIDE — naissance, mort (jamais avant la naissance), pays,
--      langue d'écriture, wikidata_id, viaf_id, isni, external_ids.idref —
--      et laisse la trace dans external_ids : wikidata_releve { qid, date,
--      lot, decision, champs } et idref_releve { ppn, date, lot, preuve,
--      champs }, chaque champ attribué à la source qui l'a donné. Jamais :
--      un nom (forme retenue, forme de tri, alias, variantes), un champ déjà
--      rempli, le type. Tout ou rien : une fiche absente ou renommée depuis le
--      relevé, un identifiant déjà posé et différent, un Wikidata déjà porté
--      par une autre fiche, une valeur mal formée → rien n'est écrit. Aucune
--      fiche de la liste dans la base (banc) → rien, sans erreur. Rejouable :
--      un second passage n'écrit rien. SECURITY INVOKER, EXECUTE retiré à
--      PUBLIC, anon, authenticated.
--   2. L'appel pour les 94 fiches validées.
--
--   La note de relecture des 308 (« À relire : ni dates… ») est effacée par
--   la migration voisine 20261019190327 (même décision de Xavier) : rien ici.
--
-- CHECKLIST DOCTRINE
--   - Une fonction INVOKER dans `private`, EXECUTE retiré (grants_herites T12).
--   - Aucune table, aucun index, aucune policy neuve ; écritures de lignes.
--   - Garde finale : chaque valeur de la liste est en place.
-- =========================================================================

CREATE OR REPLACE FUNCTION private.fn_enrichir_autorites(
  p_liste jsonb,
  p_date  date,
  p_lot   text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $fn$
DECLARE
  v_e jsonb;
  v_a public.authors%rowtype;
  v_total int;
  v_presents int := 0;
  v_absents text[] := ARRAY[]::text[];
  v_conflits text[] := ARRAY[]::text[];
  v_enrichies int := 0;
  v_n jsonb := '{}'::jsonb;
  v_ci text[];
  v_cw text[];
  v_cr text[];
  v_naiss int; v_mort int; v_pays text; v_langue text;
  v_qid text; v_viaf text; v_isni text; v_ppn text;
  f_naiss boolean; f_mort boolean; f_pays boolean; f_langue boolean;
  f_qid boolean; f_viaf boolean; f_isni boolean; f_ppn boolean;
  v_ext jsonb;
  v_cle text;
  v_trace boolean;
  v_x text;
BEGIN
  IF p_liste IS NULL OR jsonb_typeof(p_liste) <> 'array' THEN
    RAISE EXCEPTION 'fn_enrichir_autorites : la liste doit être un tableau';
  END IF;
  IF p_date IS NULL OR p_date > current_date THEN
    RAISE EXCEPTION 'fn_enrichir_autorites : date du relevé absente ou dans le futur';
  END IF;
  IF coalesce(btrim(p_lot), '') = '' THEN
    RAISE EXCEPTION 'fn_enrichir_autorites : lot vide';
  END IF;
  v_total := jsonb_array_length(p_liste);
  IF (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(p_liste) x) <> v_total THEN
    RAISE EXCEPTION 'fn_enrichir_autorites : une fiche figure deux fois dans la liste';
  END IF;

  -- 1. Validation de toute la liste AVANT la moindre écriture
  FOR v_e IN SELECT x FROM jsonb_array_elements(p_liste) x LOOP
    IF jsonb_typeof(v_e->'id') IS DISTINCT FROM 'number' OR coalesce(v_e->>'nom', '') = '' THEN
      RAISE EXCEPTION 'fn_enrichir_autorites : élément sans id ou sans nom : %', v_e;
    END IF;
    IF (v_e->>'qid') !~ '^Q[1-9][0-9]*$'
       OR (v_e->>'pays') !~ '^[A-Z]{2}$'
       OR (v_e->>'langue') !~ '^[a-z]{2}(-[A-Z]{2})?$'
       OR (v_e->>'viaf') !~ '^[0-9]{1,22}$'
       OR (v_e->>'isni') !~ '^[0-9]{15}[0-9X]$'
       OR (v_e->>'idref') !~ '^[0-9]{8}[0-9X]$'
       OR (v_e ? 'naissance' AND jsonb_typeof(v_e->'naissance') <> 'number')
       OR (v_e ? 'mort' AND jsonb_typeof(v_e->'mort') <> 'number')
       OR (v_e->>'naissance')::int NOT BETWEEN 1 AND extract(year FROM p_date)::int
       OR (v_e->>'mort')::int NOT BETWEEN 1 AND extract(year FROM p_date)::int
       OR (v_e->>'mort')::int < (v_e->>'naissance')::int THEN
      RAISE EXCEPTION 'fn_enrichir_autorites : valeur mal formée pour la fiche % : %', v_e->>'id', v_e;
    END IF;
    IF v_e ? 'champs_idref' THEN
      IF NOT (v_e ? 'idref') THEN
        RAISE EXCEPTION 'fn_enrichir_autorites : fiche % — champs attribués à IdRef sans identifiant IdRef', v_e->>'id';
      END IF;
      IF EXISTS (SELECT 1 FROM jsonb_array_elements_text(v_e->'champs_idref') c
                  WHERE c NOT IN ('naissance', 'mort', 'pays', 'langue')) THEN
        RAISE EXCEPTION 'fn_enrichir_autorites : fiche % — champ IdRef inconnu : %', v_e->>'id', v_e->'champs_idref';
      END IF;
    END IF;
    IF NOT (v_e ? 'qid') AND NOT (v_e ? 'idref') THEN
      RAISE EXCEPTION 'fn_enrichir_autorites : fiche % sans source (ni Wikidata ni IdRef)', v_e->>'id';
    END IF;

    SELECT * INTO v_a FROM public.authors
     WHERE id = (v_e->>'id')::bigint AND preferred_name = v_e->>'nom';
    IF NOT FOUND THEN
      v_absents := v_absents || (v_e->>'id' || ' ' || (v_e->>'nom'));
      CONTINUE;
    END IF;
    v_presents := v_presents + 1;

    -- Un identifiant déjà posé et différent : ce n'est plus « remplir le vide »
    IF v_a.wikidata_id IS NOT NULL AND v_e ? 'qid' AND v_a.wikidata_id <> v_e->>'qid' THEN
      v_conflits := v_conflits || format('%s : Wikidata %s ≠ %s', v_a.id, v_a.wikidata_id, v_e->>'qid');
    END IF;
    IF v_a.viaf_id IS NOT NULL AND v_e ? 'viaf' AND v_a.viaf_id <> v_e->>'viaf' THEN
      v_conflits := v_conflits || format('%s : VIAF %s ≠ %s', v_a.id, v_a.viaf_id, v_e->>'viaf');
    END IF;
    IF v_a.isni IS NOT NULL AND v_e ? 'isni' AND v_a.isni <> v_e->>'isni' THEN
      v_conflits := v_conflits || format('%s : ISNI %s ≠ %s', v_a.id, v_a.isni, v_e->>'isni');
    END IF;
    IF v_a.external_ids ? 'idref' AND v_e ? 'idref' AND v_a.external_ids->>'idref' <> v_e->>'idref' THEN
      v_conflits := v_conflits || format('%s : IdRef %s ≠ %s', v_a.id, v_a.external_ids->>'idref', v_e->>'idref');
    END IF;
    -- Un Wikidata déjà porté par une AUTRE fiche : un doublon à fusionner, pas à écrire
    SELECT string_agg(o.id::text, ', ') INTO v_x FROM public.authors o
     WHERE o.wikidata_id = v_e->>'qid' AND o.id <> v_a.id;
    IF v_x IS NOT NULL THEN
      v_conflits := v_conflits || format('%s : Wikidata %s déjà porté par %s', v_a.id, v_e->>'qid', v_x);
    END IF;
  END LOOP;

  IF v_presents = 0 THEN
    RETURN jsonb_build_object('lot', p_lot, 'liste', v_total, 'presentes', 0, 'enrichies', 0);
  END IF;
  IF v_presents < v_total THEN
    RAISE EXCEPTION 'fn_enrichir_autorites : % fiche(s) sur % retrouvée(s) (id + forme retenue) — absentes ou renommées : % — on n''applique pas à moitié',
      v_presents, v_total, left(array_to_string(v_absents, ' | '), 600);
  END IF;
  IF cardinality(v_conflits) > 0 THEN
    RAISE EXCEPTION 'fn_enrichir_autorites : % conflit(s) : %', cardinality(v_conflits), left(array_to_string(v_conflits, ' | '), 600);
  END IF;

  -- 2. Écriture : le vide seulement, et la trace
  FOR v_e IN SELECT x FROM jsonb_array_elements(p_liste) x LOOP
    SELECT * INTO v_a FROM public.authors WHERE id = (v_e->>'id')::bigint FOR UPDATE;
    v_naiss  := (v_e->>'naissance')::int;
    v_mort   := (v_e->>'mort')::int;
    v_pays   := v_e->>'pays';
    v_langue := v_e->>'langue';
    v_qid    := v_e->>'qid';
    v_viaf   := v_e->>'viaf';
    v_isni   := v_e->>'isni';
    v_ppn    := v_e->>'idref';
    v_ci     := coalesce(ARRAY(SELECT jsonb_array_elements_text(v_e->'champs_idref')), ARRAY[]::text[]);

    f_naiss  := v_a.birth_year IS NULL AND v_naiss IS NOT NULL;
    f_mort   := v_a.death_year IS NULL AND v_mort IS NOT NULL
                AND v_mort >= coalesce(v_a.birth_year, v_naiss, v_mort);
    f_pays   := v_a.country IS NULL AND v_pays IS NOT NULL;
    f_langue := v_a.writing_language IS NULL AND v_langue IS NOT NULL;
    f_qid    := v_a.wikidata_id IS NULL AND v_qid IS NOT NULL;
    f_viaf   := v_a.viaf_id IS NULL AND v_viaf IS NOT NULL;
    f_isni   := v_a.isni IS NULL AND v_isni IS NOT NULL;
    f_ppn    := NOT (coalesce(v_a.external_ids, '{}'::jsonb) ? 'idref') AND v_ppn IS NOT NULL;

    -- Chaque champ rempli est attribué à sa source
    v_cw := ARRAY[]::text[]; v_cr := ARRAY[]::text[];
    IF f_naiss  THEN IF 'naissance' = ANY (v_ci) THEN v_cr := v_cr || 'birth_year'::text;       ELSE v_cw := v_cw || 'birth_year'::text;       END IF; END IF;
    IF f_mort   THEN IF 'mort'      = ANY (v_ci) THEN v_cr := v_cr || 'death_year'::text;       ELSE v_cw := v_cw || 'death_year'::text;       END IF; END IF;
    IF f_pays   THEN IF 'pays'      = ANY (v_ci) THEN v_cr := v_cr || 'country'::text;          ELSE v_cw := v_cw || 'country'::text;          END IF; END IF;
    IF f_langue THEN IF 'langue'    = ANY (v_ci) THEN v_cr := v_cr || 'writing_language'::text; ELSE v_cw := v_cw || 'writing_language'::text; END IF; END IF;
    IF f_qid  THEN v_cw := v_cw || 'wikidata_id'::text; END IF;
    IF f_viaf THEN v_cw := v_cw || 'viaf_id'::text;     END IF;
    IF f_isni THEN v_cw := v_cw || 'isni'::text;        END IF;
    IF f_ppn  THEN v_cr := v_cr || 'idref'::text;       END IF;

    v_ext := coalesce(v_a.external_ids, '{}'::jsonb);
    v_trace := false;
    IF f_ppn THEN v_ext := v_ext || jsonb_build_object('idref', v_ppn); END IF;
    -- Trace Wikidata : posée une fois par lot ; une trace d'un autre lot est gardée
    IF v_qid IS NOT NULL THEN
      v_cle := 'wikidata_releve';
      IF v_ext ? v_cle AND v_ext->v_cle->>'lot' IS DISTINCT FROM p_lot THEN
        v_cle := 'wikidata_releve_' || to_char(p_date, 'YYYYMMDD');
      END IF;
      IF NOT (v_ext ? v_cle) THEN
        v_ext := v_ext || jsonb_build_object(v_cle, jsonb_build_object(
                   'qid', v_qid, 'date', p_date, 'lot', p_lot, 'decision', v_e->>'decision',
                   'champs', to_jsonb(v_cw)));
        v_trace := true;
      END IF;
    END IF;
    IF v_ppn IS NOT NULL THEN
      v_cle := 'idref_releve';
      IF v_ext ? v_cle AND v_ext->v_cle->>'lot' IS DISTINCT FROM p_lot THEN
        v_cle := 'idref_releve_' || to_char(p_date, 'YYYYMMDD');
      END IF;
      IF NOT (v_ext ? v_cle) THEN
        v_ext := v_ext || jsonb_build_object(v_cle, jsonb_build_object(
                   'ppn', v_ppn, 'date', p_date, 'lot', p_lot, 'preuve', v_e->>'preuve_idref',
                   'champs', to_jsonb(v_cr)));
        v_trace := true;
      END IF;
    END IF;

    IF NOT (f_naiss OR f_mort OR f_pays OR f_langue OR f_qid OR f_viaf OR f_isni OR f_ppn OR v_trace) THEN
      CONTINUE;
    END IF;

    UPDATE public.authors
       SET birth_year       = CASE WHEN f_naiss  THEN v_naiss  ELSE birth_year END,
           death_year       = CASE WHEN f_mort   THEN v_mort   ELSE death_year END,
           country          = CASE WHEN f_pays   THEN v_pays   ELSE country END,
           writing_language = CASE WHEN f_langue THEN v_langue ELSE writing_language END,
           wikidata_id      = CASE WHEN f_qid    THEN v_qid    ELSE wikidata_id END,
           viaf_id          = CASE WHEN f_viaf   THEN v_viaf   ELSE viaf_id END,
           isni             = CASE WHEN f_isni   THEN v_isni   ELSE isni END,
           external_ids     = v_ext,
           updated_at       = now()
     WHERE id = v_a.id;

    v_enrichies := v_enrichies + 1;
    FOREACH v_x IN ARRAY v_cw || v_cr LOOP
      v_n := v_n || jsonb_build_object(v_x, coalesce((v_n->>v_x)::int, 0) + 1);
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object('lot', p_lot, 'liste', v_total, 'presentes', v_presents,
                            'enrichies', v_enrichies, 'champs', v_n);
END
$fn$;

REVOKE ALL ON FUNCTION private.fn_enrichir_autorites(jsonb, date, text) FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.fn_enrichir_autorites(jsonb, date, text) IS
  'Remplit le vide (dates, pays, langue, Wikidata, VIAF, ISNI, IdRef) des autorités d''une liste fermée retrouvées par id + forme retenue ; trace dans external_ids ; tout ou rien ; rejouable. Migration 20261019192349.';

-- ── L'appel pour les 94 fiches validées (production seulement) ─────────
DO $anarchief_d7$
DECLARE
  v_res jsonb;
  v_ecarts text;
  v_liste jsonb := $liste$[
  {"id": 11578, "nom": "Anton Constandse", "decision": "A", "qid": "Q591526", "naissance": 1899, "mort": 1985, "pays": "NL", "langue": "nl", "viaf": "66774055", "isni": "0000000120276555"},
  {"id": 11579, "nom": "Bart de Ligt", "decision": "A", "qid": "Q809218", "naissance": 1883, "mort": 1938, "pays": "NL", "langue": "nl", "viaf": "74651548", "isni": "0000000081553520", "idref": "113365624", "preuve_idref": "dates"},
  {"id": 11580, "nom": "Ferdinand Domela Nieuwenhuis", "decision": "B", "qid": "Q1374710", "naissance": 1846, "mort": 1919, "pays": "NL", "langue": "nl", "viaf": "73852650", "isni": "0000000109151049", "idref": "02683409X", "preuve_idref": "titre « van christen tot anarchist »"},
  {"id": 11581, "nom": "Hem Day", "decision": "A", "qid": "Q15407596", "naissance": 1902, "mort": 1969, "pays": "BE", "langue": "fr", "viaf": "66508265", "isni": "0000000063059377"},
  {"id": 11582, "nom": "Ravachol", "decision": "A", "qid": "Q558456", "naissance": 1859, "mort": 1892, "pays": "FR", "langue": "fr", "viaf": "29646854", "isni": "0000000098397288"},
  {"id": 11584, "nom": "Kreszentia Mühsam", "decision": "B", "qid": "Q191318", "naissance": 1884, "mort": 1962, "viaf": "64808827", "isni": "0000000054913164"},
  {"id": 11585, "nom": "Hans Ramaer", "decision": "A", "qid": "Q59479639", "naissance": 1941, "mort": 2015, "pays": "NL", "langue": "nl", "viaf": "192011710", "isni": "0000000140693751"},
  {"id": 11588, "nom": "Albert de Jong", "decision": "B", "qid": "Q2639107", "naissance": 1891, "mort": 1970, "pays": "NL", "langue": "nl", "viaf": "14900459", "isni": "0000000020450712"},
  {"id": 11589, "nom": "Léo Campion", "decision": "B", "qid": "Q3270448", "naissance": 1905, "mort": 1992, "pays": "FR", "langue": "fr", "viaf": "51686699", "isni": "0000000027120441", "idref": "026764466", "preuve_idref": "titre « le drapeau noir l equerre et le compas »"},
  {"id": 11593, "nom": "De Vieze Gasten", "decision": "K", "qid": "Q2490855", "pays": "BE", "viaf": "171899123"},
  {"id": 11604, "nom": "Situationistische Internationale", "decision": "K", "qid": "Q850181", "viaf": "137856251"},
  {"id": 11606, "nom": "Vrije Bond", "decision": "K", "qid": "Q2693521"},
  {"id": 11607, "nom": "IWW", "decision": "K", "qid": "Q1046722", "viaf": "135585641"},
  {"id": 11611, "nom": "Bertolt Brecht", "decision": "A", "qid": "Q38757", "naissance": 1898, "mort": 1956, "pays": "DE", "langue": "de", "viaf": "2467372", "isni": "0000000368636577", "idref": "028208617", "preuve_idref": "dates", "champs_idref": ["pays"]},
  {"id": 11612, "nom": "Brian A. Dominick", "decision": "A", "qid": "Q130442036", "pays": "US", "viaf": "17165392158321250319"},
  {"id": 11613, "nom": "Gustave Hervé", "decision": "A", "qid": "Q764182", "naissance": 1871, "mort": 1944, "pays": "FR", "langue": "fr", "viaf": "71434123", "isni": "0000000109137474", "idref": "031440126", "preuve_idref": "dates"},
  {"id": 11614, "nom": "Attila Kotányi", "decision": "A", "qid": "Q315836", "naissance": 1924, "mort": 2003, "pays": "HU", "langue": "hu", "viaf": "35689850", "isni": "0000000021032504", "idref": "256981876", "preuve_idref": "dates", "champs_idref": ["langue"]},
  {"id": 11616, "nom": "Amory B. Lovins", "decision": "A", "qid": "Q474194", "naissance": 1947, "pays": "US", "viaf": "108190727", "isni": "0000000121468444"},
  {"id": 11621, "nom": "Étienne de La Boétie", "decision": "A", "qid": "Q290227", "naissance": 1530, "mort": 1563, "pays": "FR", "langue": "fr", "viaf": "4931874", "isni": "0000000121184839", "idref": "026955776", "preuve_idref": "dates", "champs_idref": ["langue"]},
  {"id": 11622, "nom": "Thom Holterman", "decision": "B", "qid": "Q3146126", "naissance": 1942, "pays": "NL", "viaf": "109156359", "isni": "0000000082939484", "idref": "079242669", "preuve_idref": "dates"},
  {"id": 11623, "nom": "Clara Wichmann", "decision": "A", "qid": "Q1095182", "naissance": 1885, "mort": 1922, "langue": "nl", "viaf": "62348342", "isni": "0000000034059829", "idref": "19788296X", "preuve_idref": "dates"},
  {"id": 11624, "nom": "Jan Moulaert", "decision": "B", "qid": "Q133727959", "naissance": 1956, "pays": "BE", "langue": "nl", "viaf": "267590871", "isni": "000000007834754X", "idref": "035018925", "preuve_idref": "dates", "champs_idref": ["pays", "langue"]},
  {"id": 11627, "nom": "Denise De Weerdt", "decision": "B", "qid": "Q21539795", "naissance": 1930, "mort": 2015, "pays": "BE", "viaf": "64014266", "isni": "0000000079765970", "idref": "027952231", "preuve_idref": "titre « de commune van parijs 1871 »"},
  {"id": 11628, "nom": "Gene Sharp", "decision": "A", "qid": "Q263681", "naissance": 1928, "mort": 2018, "pays": "US", "langue": "en", "viaf": "79096275", "isni": "0000000083968041", "idref": "032582242", "preuve_idref": "dates"},
  {"id": 11629, "nom": "Herman Gorter", "decision": "A", "qid": "Q325191", "naissance": 1864, "mort": 1927, "pays": "NL", "langue": "nl", "viaf": "17329233", "isni": "0000000108751018", "idref": "034346287", "preuve_idref": "dates"},
  {"id": 11631, "nom": "Otto Rühle", "decision": "B", "qid": "Q215955", "naissance": 1874, "mort": 1943, "pays": "DE", "langue": "de", "viaf": "76322003", "isni": "0000000109169409", "idref": "027097536", "preuve_idref": "titre « la revolution n est pas une affaire de parti »", "champs_idref": ["langue"]},
  {"id": 11633, "nom": "Steven De Batselier", "decision": "C", "qid": "Q2064594", "naissance": 1932, "mort": 2007, "pays": "BE"},
  {"id": 11635, "nom": "Antoon Roosens", "decision": "C", "qid": "Q1981186", "naissance": 1929, "mort": 2003, "pays": "BE", "langue": "nl", "viaf": "45685387", "isni": "0000000026959106", "idref": "150390149", "preuve_idref": "dates"},
  {"id": 11636, "nom": "Brian Martin", "decision": "B", "qid": "Q3644481", "naissance": 1947, "pays": "AU", "langue": "en", "viaf": "110230099", "isni": "0000000081759721", "idref": "270023569", "preuve_idref": "dates", "champs_idref": ["langue"]},
  {"id": 11637, "nom": "César De Paepe", "decision": "A", "qid": "Q1150699", "naissance": 1841, "mort": 1890, "pays": "BE", "langue": "fr", "viaf": "85155535", "isni": "0000000084849490", "idref": "030539552", "preuve_idref": "dates"},
  {"id": 11640, "nom": "Gabriel Kuhn", "decision": "B", "qid": "Q1489361", "naissance": 1972, "pays": "AT", "viaf": "27763346", "isni": "0000000040580047", "idref": "158635450", "preuve_idref": "dates"},
  {"id": 11641, "nom": "Henk Eikeboom", "decision": "A", "qid": "Q94532201", "naissance": 1898, "mort": 1945, "pays": "NL", "langue": "nl", "viaf": "42637504", "isni": "0000000083770000"},
  {"id": 11643, "nom": "Jean-François Füeg", "decision": "B", "qid": "Q112527931", "naissance": 1965, "pays": "BE", "langue": "fr", "viaf": "1209154381065730292161", "isni": "000000003316888X", "idref": "034360794", "preuve_idref": "titre « le rouge et le noir la tribune bruxelloise non conformiste des annees 30 »", "champs_idref": ["langue"]},
  {"id": 11644, "nom": "Mark Barnsley", "decision": "B", "qid": "Q127692402", "pays": "GB", "viaf": "51209006"},
  {"id": 11654, "nom": "André Prudhommeaux", "decision": "A", "qid": "Q2848487", "naissance": 1902, "mort": 1968, "pays": "FR", "viaf": "32118862", "isni": "0000000121268186", "idref": "059554037", "preuve_idref": "dates"},
  {"id": 11657, "nom": "Arnold Roller", "decision": "A", "qid": "Q79769427", "mort": 1956, "pays": "AT", "viaf": "79505100", "isni": "0000000110727842"},
  {"id": 11660, "nom": "August Vermeylen", "decision": "A", "qid": "Q764378", "naissance": 1872, "mort": 1945, "pays": "BE", "langue": "nl", "viaf": "22946210", "isni": "0000000120998654", "idref": "095074716", "preuve_idref": "dates"},
  {"id": 11663, "nom": "Bao Jingyan", "decision": "B", "qid": "Q6656001"},
  {"id": 11665, "nom": "Bas van der Plas", "decision": "A", "qid": "Q2544900", "naissance": 1947, "pays": "NL", "langue": "nl", "viaf": "12563272", "isni": "0000000030335312"},
  {"id": 11666, "nom": "Benjamin Tucker", "decision": "B", "qid": "Q505871", "naissance": 1854, "mort": 1939, "pays": "US", "langue": "en", "viaf": "67365108", "isni": "0000000082548037"},
  {"id": 11668, "nom": "Bert Altena", "decision": "A", "qid": "Q57457025", "naissance": 1950, "mort": 2018, "pays": "NL", "langue": "nl", "viaf": "51928533", "isni": "0000000109714120", "idref": "076318338", "preuve_idref": "dates"},
  {"id": 11674, "nom": "Chaz Bufe", "decision": "A", "qid": "Q5088654", "pays": "US", "viaf": "43408073", "isni": "0000000028943247"},
  {"id": 11675, "nom": "Chuck Morse", "decision": "B", "qid": "Q5115823", "naissance": 1969, "viaf": "5343154137644315370004", "isni": "0000000499728842"},
  {"id": 11678, "nom": "D. H. Lawrence", "decision": "A", "qid": "Q34970", "naissance": 1885, "mort": 1930, "pays": "GB", "langue": "en", "viaf": "95150359", "isni": "000000012144117X"},
  {"id": 11681, "nom": "Deric Shannon", "decision": "A", "qid": "Q92319485", "pays": "US", "viaf": "150341203", "isni": "0000000101003260"},
  {"id": 11686, "nom": "Émile Chapelier", "decision": "B", "qid": "Q16220699", "naissance": 1870, "mort": 1933, "pays": "BE", "langue": "fr", "viaf": "56218180", "isni": "0000000041556903", "idref": "28578725X", "preuve_idref": "dates", "champs_idref": ["langue"]},
  {"id": 11687, "nom": "Emile Vandervelde", "decision": "A", "qid": "Q286556", "naissance": 1866, "mort": 1938, "pays": "BE", "langue": "fr", "viaf": "18578", "isni": "0000000120954133", "idref": "027176851", "preuve_idref": "dates"},
  {"id": 11688, "nom": "Eric Duivenvoorden", "decision": "A", "qid": "Q19587577", "naissance": 1962, "pays": "NL", "viaf": "1244078", "isni": "0000000078823550"},
  {"id": 11696, "nom": "Frans Masereel", "decision": "A", "qid": "Q559297", "naissance": 1889, "mort": 1972, "pays": "BE", "langue": "fr", "viaf": "51693032", "isni": "000000012132650X", "idref": "027014878", "preuve_idref": "titre « de opstand der machines »"},
  {"id": 11697, "nom": "Fredy Perlman", "decision": "A", "qid": "Q2458048", "naissance": 1934, "mort": 1985, "pays": "US", "langue": "en", "viaf": "77692761", "isni": "0000000023817700", "idref": "074459651", "preuve_idref": "dates"},
  {"id": 11700, "nom": "George Katsiaficas", "decision": "A", "qid": "Q18275311", "naissance": 1949, "pays": "US", "viaf": "22181747", "isni": "0000000083634199"},
  {"id": 11701, "nom": "George Lakey", "decision": "A", "qid": "Q27948866", "naissance": 1937, "pays": "US", "viaf": "32079203", "isni": "0000000081112012"},
  {"id": 11702, "nom": "Gerhard Rijnders", "decision": "A", "qid": "Q3485290", "naissance": 1876, "mort": 1950, "pays": "NL", "viaf": "241641275", "isni": "0000000370200043"},
  {"id": 11703, "nom": "Gernot Jochheim", "decision": "A", "qid": "Q1514404", "naissance": 1942, "pays": "DE", "langue": "de", "viaf": "68971359", "isni": "000000008148318X", "idref": "077755650", "preuve_idref": "dates", "champs_idref": ["langue"]},
  {"id": 11704, "nom": "Gustave Dache", "decision": "B", "qid": "Q133622813", "naissance": 1936, "pays": "BE", "langue": "fr", "viaf": "217481950", "isni": "0000000359357832", "idref": "151362343", "preuve_idref": "dates", "champs_idref": ["pays", "langue"]},
  {"id": 11705, "nom": "Guy Debord", "decision": "A", "qid": "Q298075", "naissance": 1931, "mort": 1994, "pays": "FR", "langue": "fr", "viaf": "44297675", "isni": "0000000121302372", "idref": "026815672", "preuve_idref": "dates"},
  {"id": 11706, "nom": "H. G. Wells", "decision": "B", "qid": "Q42511", "naissance": 1866, "mort": 1946, "pays": "GB", "langue": "en", "viaf": "97006424", "isni": "0000000122832703"},
  {"id": 11707, "nom": "H. P. G. Quack", "decision": "A", "qid": "Q2629919", "naissance": 1834, "mort": 1917, "pays": "NL", "langue": "nl", "viaf": "60164953", "isni": "0000000073601350"},
  {"id": 11712, "nom": "Hans Krikke", "decision": "C", "qid": "Q13653599", "naissance": 1958, "pays": "NL", "langue": "nl", "viaf": "51290457", "isni": "0000000041394158"},
  {"id": 11715, "nom": "Henriëtte Roland Holst", "decision": "A", "qid": "Q441439", "naissance": 1869, "mort": 1952, "pays": "NL", "langue": "nl", "viaf": "12324221", "isni": "0000000120210169"},
  {"id": 11717, "nom": "Hubert van den Berg", "decision": "A", "qid": "Q64666669", "naissance": 1963, "langue": "nl", "viaf": "66627490", "isni": "0000000116622902", "idref": "050531492", "preuve_idref": "dates"},
  {"id": 11720, "nom": "J. Rogue", "decision": "A", "qid": "Q125352761", "pays": "US", "viaf": "24152380055701760186"},
  {"id": 11723, "nom": "Jacob Kats", "decision": "A", "qid": "Q2442614", "naissance": 1804, "mort": 1886, "pays": "BE", "langue": "nl", "viaf": "171433310", "isni": "0000000120498799"},
  {"id": 11724, "nom": "Jacques J. Giele", "decision": "A", "qid": "Q108784124", "naissance": 1942, "mort": 2012, "pays": "NL", "viaf": "40659495", "isni": "0000000024883240"},
  {"id": 11726, "nom": "Jean Barrot", "decision": "A", "qid": "Q2033010", "naissance": 1947, "pays": "FR", "langue": "fr", "viaf": "19698378", "isni": "0000000107781223", "idref": "026706962", "preuve_idref": "titre « pour une critique de l ideologie anti militariste »"},
  {"id": 11728, "nom": "Jean De Boë", "decision": "A", "qid": "Q10306538", "naissance": 1889, "mort": 1974, "pays": "BE", "langue": "fr", "viaf": "204832009", "isni": "0000000358282146", "idref": "084578165", "preuve_idref": "titre « propos subversifs »", "champs_idref": ["langue"]},
  {"id": 11733, "nom": "Jessica Mitford", "decision": "A", "qid": "Q457856", "naissance": 1917, "mort": 1996, "pays": "GB", "langue": "en", "viaf": "108936233", "isni": "0000000110815148", "idref": "030410843", "preuve_idref": "dates", "champs_idref": ["langue"]},
  {"id": 11735, "nom": "Johan Anthierens", "decision": "A", "qid": "Q2360102", "naissance": 1937, "mort": 2000, "pays": "BE", "langue": "nl", "viaf": "231186418", "isni": "0000000366066689", "idref": "034120068", "preuve_idref": "dates"},
  {"id": 11737, "nom": "Jules Vallès", "decision": "A", "qid": "Q551597", "naissance": 1832, "mort": 1885, "pays": "FR", "langue": "fr", "viaf": "4937548", "isni": "0000000123197502"},
  {"id": 11740, "nom": "Ken Knabb", "decision": "A", "qid": "Q6387959", "naissance": 1945, "pays": "US", "langue": "en", "viaf": "66586071", "isni": "0000000063079298"},
  {"id": 11745, "nom": "Lao Tsu", "decision": "A", "qid": "Q9333", "viaf": "101089774", "isni": "0000000121017619"},
  {"id": 11746, "nom": "Louis Adamic", "decision": "A", "qid": "Q713658", "naissance": 1898, "mort": 1951, "langue": "en", "viaf": "57408177", "isni": "0000000121345444", "idref": "029157323", "preuve_idref": "dates"},
  {"id": 11748, "nom": "Louis Paul Boon", "decision": "A", "qid": "Q469627", "naissance": 1912, "mort": 1979, "pays": "BE", "langue": "nl", "viaf": "66482586", "isni": "0000000368643347", "idref": "028491777", "preuve_idref": "dates"},
  {"id": 11749, "nom": "Louis Simon", "decision": "B", "qid": "Q109857576", "naissance": 1900, "mort": 1980, "pays": "FR", "viaf": "7397106", "isni": "0000000020248282"},
  {"id": 11752, "nom": "Ludo Abicht", "decision": "A", "qid": "Q4730107", "naissance": 1936, "pays": "BE", "langue": "nl", "viaf": "265875616", "isni": "0000000066456001", "idref": "030595150", "preuve_idref": "dates"},
  {"id": 11759, "nom": "Oscar Testut", "decision": "A", "qid": "Q139061844", "naissance": 1845, "pays": "FR", "langue": "fr", "viaf": "209145542501996641072", "isni": "0000000354680892", "idref": "056982224", "preuve_idref": "dates", "champs_idref": ["pays", "langue"]},
  {"id": 11762, "nom": "Patrick Pasture", "decision": "A", "qid": "Q93239186", "naissance": 1961, "pays": "BE", "langue": "nl", "viaf": "115857086", "isni": "000000011580566X", "idref": "050725254", "preuve_idref": "dates", "champs_idref": ["pays", "langue"]},
  {"id": 11763, "nom": "Peggy Kornegger", "decision": "B", "qid": "Q1891328", "pays": "US", "viaf": "21156268", "isni": "0000000028422812"},
  {"id": 11764, "nom": "Peter Marshall", "decision": "B", "qid": "Q1549072", "naissance": 1946, "pays": "GB", "viaf": "109204885", "isni": "0000000081743631"},
  {"id": 11772, "nom": "Roel van Duyn", "decision": "A", "qid": "Q2161427", "naissance": 1943, "pays": "NL", "langue": "nl", "viaf": "91353447", "isni": "0000000118794556"},
  {"id": 11773, "nom": "Romain Rolland", "decision": "A", "qid": "Q47162", "naissance": 1866, "mort": 1944, "pays": "FR", "langue": "fr", "viaf": "71397100", "isni": "0000000121386406", "idref": "027106861", "preuve_idref": "titre « de opstand der machines »"},
  {"id": 11778, "nom": "Stijn Vanclooster", "decision": "A", "qid": "Q133028941", "naissance": 1974, "viaf": "161504456", "isni": "0000000118855064"},
  {"id": 11781, "nom": "Thomas Meyer-Falk", "decision": "A", "qid": "Q122168283", "naissance": 1971, "pays": "DE", "viaf": "26155224384784371374"},
  {"id": 11783, "nom": "Toni Negri", "decision": "A", "qid": "Q310341", "naissance": 1933, "mort": 2023, "pays": "IT", "langue": "it", "viaf": "108238827", "isni": "000000012146876X"},
  {"id": 11786, "nom": "Upton Sinclair", "decision": "A", "qid": "Q216134", "naissance": 1878, "mort": 1968, "pays": "US", "langue": "en", "viaf": "32002923", "isni": "000000036865058X", "idref": "027139913", "preuve_idref": "dates"},
  {"id": 11790, "nom": "Willi Schlamm", "decision": "B", "qid": "Q603522", "naissance": 1904, "mort": 1978, "viaf": "111865339", "isni": "0000000110051723"},
  {"id": 11792, "nom": "Wolfgang Sternstein", "decision": "A", "qid": "Q18917973", "naissance": 1939, "pays": "DE", "langue": "de", "viaf": "35008051", "isni": "0000000109641160", "idref": "094220239", "preuve_idref": "dates", "champs_idref": ["langue"]},
  {"id": 11797, "nom": "Nederlands Syndicalistisch Vakverbond", "decision": "KC", "qid": "Q97704882"},
  {"id": 11800, "nom": "IAMV", "decision": "K", "qid": "Q2867806", "viaf": "137303167"},
  {"id": 11831, "nom": "De Nieuwe Komedie", "decision": "KC", "qid": "Q54860250"},
  {"id": 11833, "nom": "De Vrije Gedachte", "decision": "K", "qid": "Q2783365"},
  {"id": 11867, "nom": "Workers Solidarity Movement", "decision": "K", "qid": "Q8034816"},
  {"id": 11876, "nom": "EuroDusnie", "decision": "K", "qid": "Q1374966", "viaf": "286407189"},
  {"id": 11883, "nom": "Wereldscholen", "decision": "K", "qid": "Q47458246", "pays": "BE"}
]$liste$::jsonb;
BEGIN
  v_res := private.fn_enrichir_autorites(v_liste, date '2026-10-19', 'Anarchief.org · D7 (Wikidata, IdRef)');

  IF (v_res->>'presentes')::int = 0 THEN
    RAISE NOTICE 'Autorités d''Anarchief absentes (banc) : rien d''écrit';
    RETURN;
  END IF;

  -- Garde : chaque valeur de la liste est en place (posée ici, ou déjà là)
  SELECT string_agg(a.id::text, ', ') INTO v_ecarts
    FROM jsonb_array_elements(v_liste) e
    JOIN public.authors a ON a.id = (e->>'id')::bigint
   WHERE a.source_label IS DISTINCT FROM 'Anarchief.org · import 2026-10'
      OR a.wikidata_id IS DISTINCT FROM e->>'qid'
      OR (e ? 'idref'     AND a.external_ids->>'idref' IS DISTINCT FROM e->>'idref')
      OR (e ? 'naissance' AND a.birth_year IS DISTINCT FROM (e->>'naissance')::int)
      OR (e ? 'mort'      AND a.death_year IS DISTINCT FROM (e->>'mort')::int)
      OR (e ? 'pays'      AND a.country IS DISTINCT FROM e->>'pays')
      OR (e ? 'langue'    AND a.writing_language IS DISTINCT FROM e->>'langue')
      OR (e ? 'viaf'      AND a.viaf_id IS DISTINCT FROM e->>'viaf')
      OR (e ? 'isni'      AND a.isni IS DISTINCT FROM e->>'isni')
      OR NOT (a.external_ids ? 'wikidata_releve');
  IF v_ecarts IS NOT NULL THEN
    RAISE EXCEPTION 'Anarchief D7 : fiches incomplètes après application : %', v_ecarts;
  END IF;

  RAISE NOTICE 'Anarchief D7 : %', v_res;
END
$anarchief_d7$;
