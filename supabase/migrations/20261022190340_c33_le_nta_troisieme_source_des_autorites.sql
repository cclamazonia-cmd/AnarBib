-- C33 (22/10/2026) — une troisième source pour les autorités d'Anarchief : le
-- thésaurus des noms d'auteurs de la Bibliothèque royale des Pays-Bas (NTA).
--
-- La passe D7 du 19/10 (Wikidata, IdRef) a laissé 214 des 308 autorités
-- d'Anarchief sans identifiant. Le NTA (`data.bibliotheken.nl`, SPARQL, CC0) est
-- la source naturelle d'un fonds néerlandais : nom, prénoms, dates, nationalité,
-- liens Wikidata, VIAF, ISNI, et les titres de la personne au catalogue national
-- (NBT). Règle de C4 tenue : nom identique (nom de famille exact, prénoms
-- compatibles) ET un titre de nos notices parmi ses titres à la KB — deux
-- signaux, un seul candidat. Sur 114 personnes : 24 à deux signaux, relues une à
-- une ; 24 à un seul signal et 9 homonymes, NON appliqués (dans la file de
-- revue, C33) ; 57 sans correspondance. Les collectifs ne sont pas au NTA.
--
-- 1. `private.fn_enrichir_autorites` apprend la source `nta` : identifiant NTA
--    `p` + 8 chiffres + chiffre ou X ; une fiche peut n'avoir que lui comme
--    source ; un NTA déjà posé et différent est un conflit ; trace
--    `nta_releve { nta, date, lot, preuve, champs }` et `external_ids.nta`.
--    Quand la source est le NTA, TOUS les champs lui sont attribués (le Wikidata
--    vient de ses liens, Wikidata n'a pas été consulté) : pas de trace
--    `wikidata_releve`. Patch par remplacement exact dans la définition réelle,
--    une occurrence exigée par motif.
-- 2. L'appel pour les 24 fiches (le vide seulement, tout ou rien).
--
-- Outil et relevé : docs/journal/operations/enrichissement-autorites-2026-09-26/
-- anarchief-nta-2026-10-22/. Sur une base sans ces fiches (banc, rejeu), la
-- fonction rend « presentes 0 » et n'écrit rien.

DO $c33nta$
DECLARE
  v text;
  r record;
BEGIN
  v := pg_get_functiondef('private.fn_enrichir_autorites(jsonb,date,text)'::regprocedure);
  FOR r IN SELECT * FROM (VALUES
    ('decl',
     E'  v_qid text; v_viaf text; v_isni text; v_ppn text;\n',
     E'  v_qid text; v_viaf text; v_isni text; v_ppn text; v_nta text;\n'),
    ('valid',
     E'       OR (v_e->>''idref'') !~ ''^[0-9]{8}[0-9X]$''\n',
     E'       OR (v_e->>''idref'') !~ ''^[0-9]{8}[0-9X]$''\n       OR (v_e->>''nta'') !~ ''^p[0-9]{8}[0-9X]$''\n'),
    ('source',
     E'    IF NOT (v_e ? ''qid'') AND NOT (v_e ? ''idref'') THEN\n      RAISE EXCEPTION ''fn_enrichir_autorites : fiche % sans source (ni Wikidata ni IdRef)'', v_e->>''id'';\n',
     E'    IF NOT (v_e ? ''qid'') AND NOT (v_e ? ''idref'') AND NOT (v_e ? ''nta'') THEN\n      RAISE EXCEPTION ''fn_enrichir_autorites : fiche % sans source (ni Wikidata, ni IdRef, ni NTA)'', v_e->>''id'';\n'),
    ('conflit',
     E'    -- Un Wikidata déjà porté par une AUTRE fiche : un doublon à fusionner, pas à écrire\n',
     E'    IF v_a.external_ids ? ''nta'' AND v_e ? ''nta'' AND v_a.external_ids->>''nta'' <> v_e->>''nta'' THEN\n      v_conflits := v_conflits || format(''%s : NTA %s ≠ %s'', v_a.id, v_a.external_ids->>''nta'', v_e->>''nta'');\n    END IF;\n    -- Un Wikidata déjà porté par une AUTRE fiche : un doublon à fusionner, pas à écrire\n'),
    ('lecture',
     E'    v_ppn    := v_e->>''idref'';\n',
     E'    v_ppn    := v_e->>''idref'';\n    v_nta    := v_e->>''nta'';\n'),
    ('trace',
     E'    IF v_qid IS NOT NULL THEN\n      v_cle := ''wikidata_releve'';\n',
     E'    -- C33 (22/10/2026) : source NTA (KB) — tous les champs lui reviennent\n    IF v_nta IS NOT NULL THEN\n      IF NOT (v_ext ? ''nta'') THEN v_ext := v_ext || jsonb_build_object(''nta'', v_nta); v_trace := true; END IF;\n      v_cle := ''nta_releve'';\n      IF v_ext ? v_cle AND v_ext->v_cle->>''lot'' IS DISTINCT FROM p_lot THEN\n        v_cle := ''nta_releve_'' || to_char(p_date, ''YYYYMMDD'');\n      END IF;\n      IF NOT (v_ext ? v_cle) THEN\n        v_ext := v_ext || jsonb_build_object(v_cle, jsonb_build_object(\n                   ''nta'', v_nta, ''date'', p_date, ''lot'', p_lot, ''preuve'', v_e->>''preuve_nta'',\n                   ''champs'', to_jsonb(v_cw)));\n        v_trace := true;\n      END IF;\n    END IF;\n    IF v_qid IS NOT NULL AND v_nta IS NULL THEN\n      v_cle := ''wikidata_releve'';\n')
  ) AS t(nom, avant, apres) LOOP
    IF (length(v) - length(replace(v, r.avant, ''))) / length(r.avant) <> 1 THEN
      RAISE EXCEPTION 'C33 : motif « % » introuvable ou multiple dans fn_enrichir_autorites — repartir de la définition réelle', r.nom;
    END IF;
    v := replace(v, r.avant, r.apres);
  END LOOP;
  EXECUTE v;
END
$c33nta$;

REVOKE ALL ON FUNCTION private.fn_enrichir_autorites(jsonb, date, text) FROM PUBLIC, anon, authenticated;

DO $c33appel$
DECLARE v_res jsonb;
BEGIN
  v_res := private.fn_enrichir_autorites($liste$[
 {
  "id": 11586,
  "nom": "Boudewijn Chorus",
  "decision": "nta_deux_signaux",
  "nta": "p068716184",
  "preuve_nta": "titre « de colonne eenmaal in beweging »",
  "viaf": "280922533"
 },
 {
  "id": 11591,
  "nom": "Alexander Schapiro",
  "decision": "nta_deux_signaux",
  "nta": "p07157767X",
  "preuve_nta": "titre « waarom verloren wij de revolutie »",
  "viaf": "3763731",
  "qid": "Q821655",
  "isni": "0000000030094248"
 },
 {
  "id": 11617,
  "nom": "John M. Swomley Jr.",
  "decision": "nta_deux_signaux",
  "nta": "p067861512",
  "preuve_nta": "titre « bevrijdend geweld bevrijdt niet »",
  "viaf": "6175292",
  "qid": "Q55721058",
  "isni": "0000000084203219",
  "naissance": 1915
 },
 {
  "id": 11618,
  "nom": "H. Kolthek Jr.",
  "decision": "nta_deux_signaux",
  "nta": "p069240620",
  "preuve_nta": "titre « de opruier »",
  "viaf": "80752006",
  "qid": "Q13654577",
  "isni": "0000000114619961",
  "naissance": 1872,
  "mort": 1946,
  "pays": "NL"
 },
 {
  "id": 11625,
  "nom": "Ruud Uittenhout",
  "decision": "nta_deux_signaux",
  "nta": "p069625492",
  "preuve_nta": "titre « gustav landauer »",
  "viaf": "280497931",
  "isni": "0000000387512334"
 },
 {
  "id": 11630,
  "nom": "Johny Lenaerts",
  "decision": "nta_deux_signaux",
  "nta": "p089885872",
  "preuve_nta": "titre « libertair municipalisme »",
  "viaf": "289336058",
  "isni": "0000000394732191"
 },
 {
  "id": 11632,
  "nom": "Simon Radius",
  "decision": "nta_deux_signaux",
  "nta": "p071922369",
  "preuve_nta": "titre « proudhon over kerk en samenleving »",
  "viaf": "289223848",
  "isni": "000000039463433X"
 },
 {
  "id": 11634,
  "nom": "André Bons",
  "decision": "nta_deux_signaux",
  "nta": "p073364460",
  "preuve_nta": "titre « niet alleen vrijheid »",
  "viaf": "286110660",
  "isni": "000000039214533X"
 },
 {
  "id": 11662,
  "nom": "B. Damme",
  "decision": "nta_deux_signaux",
  "nta": "p069820082",
  "preuve_nta": "titre « al zaaiende voorwaarts »",
  "viaf": "280468722",
  "isni": "0000000387496768"
 },
 {
  "id": 11664,
  "nom": "Bas Moreel",
  "decision": "nta_deux_signaux",
  "nta": "p070247587",
  "preuve_nta": "titre « Zelfbestuur : theorieen en praktijken »",
  "viaf": "289567003",
  "isni": "0000000394919095"
 },
 {
  "id": 11672,
  "nom": "C. Drossaart van Dusseldorp",
  "decision": "nta_deux_signaux",
  "nta": "p072778644",
  "preuve_nta": "titre « Peter Kropotkin : grepen uit denken en werken »",
  "viaf": "207630361",
  "isni": "0000000393529810"
 },
 {
  "id": 11684,
  "nom": "E. Zandstra",
  "decision": "nta_deux_signaux",
  "nta": "p070259496",
  "preuve_nta": "titre « vrijheid het leven van f domela nieuwenhuis »",
  "viaf": "194171011",
  "qid": "Q5709162",
  "isni": "0000000140712238",
  "naissance": 1897,
  "mort": 1974,
  "pays": "NL"
 },
 {
  "id": 11692,
  "nom": "F. Boenders",
  "decision": "nta_deux_signaux",
  "nta": "p068631340",
  "preuve_nta": "titre « de volle vrijheid »",
  "qid": "Q2548537",
  "isni": "0000000107823649",
  "naissance": 1942
 },
 {
  "id": 11709,
  "nom": "Han Kuysten",
  "decision": "nta_deux_signaux",
  "nta": "p097044032",
  "preuve_nta": "titre « eerst kanonnen dan boter »",
  "viaf": "280076680",
  "isni": "0000000387213908"
 },
 {
  "id": 11711,
  "nom": "Hans Jar",
  "decision": "nta_deux_signaux",
  "nta": "p079276083",
  "preuve_nta": "titre « Fascisme : grondslagen en kenmerken »",
  "viaf": "211630410",
  "isni": "0000000391396129"
 },
 {
  "id": 11713,
  "nom": "Harmen van Houten",
  "decision": "nta_deux_signaux",
  "nta": "p071337490",
  "preuve_nta": "titre « anarchisme in drenthe »",
  "viaf": "16232165",
  "isni": "0000000028285619",
  "naissance": 1900,
  "pays": "NL"
 },
 {
  "id": 11714,
  "nom": "Henri Haenen",
  "decision": "nta_deux_signaux",
  "nta": "p070888248",
  "preuve_nta": "titre « stemmen is toestemmen »",
  "viaf": "206700628",
  "isni": "0000000393226772"
 },
 {
  "id": 11722,
  "nom": "J. H. Mackay",
  "decision": "nta_deux_signaux",
  "nta": "p071119396",
  "preuve_nta": "titre « De anarchisten : een tafereel uit het eind van de 19e eeuw »",
  "viaf": "50017706",
  "naissance": 1864,
  "mort": 1933
 },
 {
  "id": 11725,
  "nom": "Jane Meyerding",
  "decision": "nta_deux_signaux",
  "nta": "p072951354",
  "preuve_nta": "titre « geweldloosheid opnieuw opeisen »",
  "viaf": "274792219",
  "isni": "0000000067314574",
  "naissance": 1950
 },
 {
  "id": 11730,
  "nom": "Jeanne Duprat",
  "decision": "nta_deux_signaux",
  "nta": "p112487106",
  "preuve_nta": "titre « over oorlog en vrede in den geest van proudhon »",
  "viaf": "291559146",
  "isni": "0000000396600184"
 },
 {
  "id": 11742,
  "nom": "L. J. Bot",
  "decision": "nta_deux_signaux",
  "nta": "p370677978",
  "preuve_nta": "titre « nederland in de mist »",
  "viaf": "309883408",
  "qid": "Q1801443",
  "naissance": 1897,
  "mort": 1988
 },
 {
  "id": 11743,
  "nom": "L. Lichtveld",
  "decision": "nta_deux_signaux",
  "nta": "p068332629",
  "preuve_nta": "titre « de sfinx van spanje »",
  "viaf": "24146284474415332263",
  "qid": "Q436463",
  "isni": "0000000449436294",
  "naissance": 1903,
  "mort": 1996,
  "pays": "NL"
 },
 {
  "id": 11750,
  "nom": "Louis Sinner",
  "decision": "nta_deux_signaux",
  "nta": "p069958688",
  "preuve_nta": "titre « provo s en justitie »",
  "viaf": "189232670",
  "isni": "0000000398062500",
  "naissance": 1926
 },
 {
  "id": 11775,
  "nom": "S. M. Sheehan",
  "decision": "nta_deux_signaux",
  "nta": "p11443834X",
  "preuve_nta": "titre « Anarchisme, een reisgids »",
  "viaf": "98208283",
  "qid": "Q93238332",
  "isni": "0000000114628040",
  "naissance": 1951
 }
]$liste$::jsonb, date '2026-10-22', 'C33 · NTA (KB) · Anarchief');
  RAISE NOTICE 'C33 : %', v_res;
END
$c33appel$;

DO $c33verif$
DECLARE v_e text := '';
BEGIN
  IF pg_get_functiondef('private.fn_enrichir_autorites(jsonb,date,text)'::regprocedure) NOT LIKE '%nta_releve%' THEN v_e := v_e || ' fonction'; END IF;
  IF has_function_privilege('authenticated', 'private.fn_enrichir_autorites(jsonb,date,text)', 'EXECUTE') THEN v_e := v_e || ' ouverte'; END IF;
  IF EXISTS (SELECT 1 FROM public.authors WHERE source_label = 'Anarchief.org · import 2026-10')
     AND (SELECT count(*) FROM public.authors WHERE source_label = 'Anarchief.org · import 2026-10' AND external_ids ? 'nta_releve') <> 24 THEN
    v_e := v_e || ' vingt-quatre';
  END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'C33 : vérification en échec :%', v_e; END IF;
END
$c33verif$;
