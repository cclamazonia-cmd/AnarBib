-- ============================================================================
-- 20260524080000_tasks_suggestion_catalog.sql
-- ----------------------------------------------------------------------------
-- Chantier #TASKS — etape 5 : catalogue de suggestions.
-- Dossier d'ouverture : module des taches, v0.1 (23/05/2026).
-- Pre-requis : 20260524040000 a 20260524070000.
--
-- OBJET
--   Une banque d'idees de taches bibliotheconomiques courantes, NON
--   imposee, ou chaque bibliotheque pioche pour constituer ses taches-types
--   locales (dossier sec. 3.4). La suggestion eclaire sans contraindre.
--
-- CONCEPTION (arbitrages 24/05)
--   - Catalogue GLOBAL : table sans library_id, contenu commun a tout le
--     reseau, alimente PAR MIGRATION (pas d'ecriture applicative). C'est le
--     catalogue *fourni* par le projet.
--   - Texte multilingue porte par la donnee : colonnes title_i18n /
--     description_i18n en jsonb { "pt-BR": ..., "fr": ..., 8 langues }.
--     Convention reprise de library_notification_profiles.signature_short_i18n.
--     Choisi pour que tout ajout ulterieur soit un simple INSERT autonome,
--     sans toucher 8 fichiers de locales.
--   - RLS : lecture reservee au staff (de n'importe quelle bibliotheque) —
--     coherent avec painel_internal_tasks, outil interne de l'equipe.
--     Aucune ecriture applicative.
--   - fn_task_adopt_suggestion : copie une suggestion en tache-type LOCALE
--     (INSERT dans painel_recurring_task_rules avec le library_id de la
--     bibliotheque). Le catalogue global suggere ; le local decide.
--
-- ELARGISSEMENT — le dossier (sec. 5) a pense le catalogue comme du travail
--   bibliotheconomique materiel. Cette migration ajoute une categorie « vie
--   collective et gouvernance » (AG, reunions, tresorerie, adhesions) et
--   « administratif » : une bibliotheque militante cadence aussi sa vie
--   collective. Elargissement a documenter dans le bilan #TASKS (apres
--   etape 6).
--
-- CATALOGUE PARTAGE ENTRE BIBLIOTHEQUES — le dossier (sec. 3.4) l'evoque
--   comme evolution future, hors perimetre. A noter pour ce chantier
--   ulterieur : il devra adopter un modele « texte libre dans la langue de
--   l'autrice », et non l'approche editoriale du present catalogue fourni.
-- ============================================================================


-- ─── Table du catalogue de suggestions (globale) ────────────────────────────
CREATE TABLE IF NOT EXISTS public.painel_task_suggestion_catalog (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                     text NOT NULL UNIQUE,
  category                 text NOT NULL,
  title_i18n               jsonb NOT NULL,
  description_i18n         jsonb NOT NULL,
  suggested_interval_count integer,
  suggested_interval_unit  text,
  display_order            integer NOT NULL DEFAULT 0,
  is_active                boolean NOT NULL DEFAULT true,
  created_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT painel_task_suggestion_catalog_cadence_coherence_chk
    CHECK (
      (suggested_interval_count IS NULL AND suggested_interval_unit IS NULL)
      OR (suggested_interval_count IS NOT NULL AND suggested_interval_unit IS NOT NULL)
    ),
  CONSTRAINT painel_task_suggestion_catalog_interval_count_chk
    CHECK (suggested_interval_count IS NULL OR suggested_interval_count > 0),
  CONSTRAINT painel_task_suggestion_catalog_interval_unit_chk
    CHECK (suggested_interval_unit IS NULL OR suggested_interval_unit IN ('dia','semana','mes'))
);

COMMENT ON TABLE public.painel_task_suggestion_catalog IS
  'Catalogue GLOBAL de suggestions de taches (#TASKS, etape 5). Banque '
  'd''idees non imposee, commune au reseau, alimentee par migration. Chaque '
  'bibliotheque y pioche pour constituer ses taches-types locales via '
  'fn_task_adopt_suggestion. title_i18n / description_i18n : texte porte par '
  'la donnee, 8 langues. Cadence suggeree optionnelle (NULL = idee de tache '
  'ponctuelle).';

-- RLS : lecture pour le staff de n'importe quelle bibliotheque ; aucune
-- ecriture applicative (le catalogue est alimente par migration).
ALTER TABLE public.painel_task_suggestion_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS painel_task_suggestion_catalog_select_staff
  ON public.painel_task_suggestion_catalog;
CREATE POLICY painel_task_suggestion_catalog_select_staff
  ON public.painel_task_suggestion_catalog
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.user_id = auth.uid()
        AND m.role IN ('librarian', 'coordenador')
        AND m.status = 'active'
    )
  );

-- GRANT explicites (doctrine Template 2). Lecture seule cote applicatif.
GRANT SELECT ON TABLE public.painel_task_suggestion_catalog TO authenticated, service_role;


-- ─── Contenu du catalogue — 15 suggestions, 7 categories ────────────────────
INSERT INTO public.painel_task_suggestion_catalog
  (code, category, title_i18n, description_i18n,
   suggested_interval_count, suggested_interval_unit, display_order)
VALUES
-- Entretien materiel des documents
('dust_shelves', 'entretien_documents',
 '{"pt-BR":"Espanar as estantes","fr":"Dépoussiérage des rayonnages","es":"Desempolvado de las estanterías","en":"Dusting the shelves","it":"Spolveratura degli scaffali","de":"Abstauben der Regale","ca":"Espolsar les prestatgeries","eo":"Senpolvigo de la bretaroj"}',
 '{"pt-BR":"Limpeza das estantes e dos documentos, seção por seção.","fr":"Nettoyage des rayonnages et des documents, section par section.","es":"Limpieza de las estanterías y los documentos, sección por sección.","en":"Cleaning shelves and documents, section by section.","it":"Pulizia degli scaffali e dei documenti, sezione per sezione.","de":"Reinigung der Regale und Dokumente, Abschnitt für Abschnitt.","ca":"Neteja de les prestatgeries i els documents, secció per secció.","eo":"Purigado de la bretaroj kaj dokumentoj, sekcio post sekcio."}',
 1, 'mes', 10),

('check_on_return', 'entretien_documents',
 '{"pt-BR":"Verificação de estado após devolução","fr":"Contrôle d''état après retour","es":"Control de estado tras la devolución","en":"Condition check after return","it":"Controllo dello stato dopo la restituzione","de":"Zustandskontrolle nach Rückgabe","ca":"Control d''estat després de la devolució","eo":"Stata kontrolo post redono"}',
 '{"pt-BR":"Verificação do estado de um documento a cada devolução de empréstimo.","fr":"Vérification de l''état d''un document à chaque retour de prêt.","es":"Verificación del estado de un documento en cada devolución de préstamo.","en":"Checking a document''s condition on each loan return.","it":"Verifica dello stato di un documento a ogni restituzione del prestito.","de":"Prüfung des Zustands eines Dokuments bei jeder Rückgabe.","ca":"Verificació de l''estat d''un document a cada retorn de préstec.","eo":"Kontrolo de la stato de dokumento ĉe ĉiu redono de prunto."}',
 NULL, NULL, 20),

('antifungal', 'entretien_documents',
 '{"pt-BR":"Defungização e combate ao mofo","fr":"Défongisation et lutte contre les moisissures","es":"Defungización y lucha contra el moho","en":"Antifungal treatment and mould control","it":"Defungazione e lotta alle muffe","de":"Pilzbekämpfung und Schimmelkontrolle","ca":"Defungització i lluita contra la floridura","eo":"Kontraŭfunga traktado kaj batalo kontraŭ ŝimo"}',
 '{"pt-BR":"Tratamento antifúngico das encadernações e do papel; vital em clima quente e úmido.","fr":"Traitement anti-moisissure des reliures et du papier ; vital en climat chaud et humide.","es":"Tratamiento antimoho de las encuadernaciones y el papel; vital en clima cálido y húmedo.","en":"Anti-mould treatment of bindings and paper; vital in hot, humid climates.","it":"Trattamento antimuffa delle rilegature e della carta; vitale in clima caldo e umido.","de":"Schimmelschutzbehandlung von Einbänden und Papier; unverzichtbar in heißem, feuchtem Klima.","ca":"Tractament antifloridura de les enquadernacions i el paper; vital en clima càlid i humit.","eo":"Kontraŭŝima traktado de bindaĵoj kaj papero; esenca en varma kaj humida klimato."}',
 1, 'mes', 30),

-- Rangement et ordre des collections
('inventory_check', 'rangement_collections',
 '{"pt-BR":"Recolagem (inventário)","fr":"Récolement","es":"Recuento (inventario)","en":"Stock inventory check","it":"Ricognizione inventariale","de":"Bestandsinventur","ca":"Recompte (inventari)","eo":"Stokinventaro"}',
 '{"pt-BR":"Verificação de que cada documento está em seu lugar e de que o catálogo corresponde à estante real.","fr":"Vérification que chaque document est à sa place et que le catalogue correspond au rayon réel.","es":"Verificación de que cada documento está en su sitio y de que el catálogo corresponde al estante real.","en":"Checking that every document is in place and the catalogue matches the actual shelf.","it":"Verifica che ogni documento sia al suo posto e che il catalogo corrisponda allo scaffale reale.","de":"Prüfung, ob jedes Dokument an seinem Platz ist und der Katalog dem realen Regal entspricht.","ca":"Verificació que cada document és al seu lloc i que el catàleg correspon a la prestatgeria real.","eo":"Kontrolo ke ĉiu dokumento estas ĉe sia loko kaj ke la katalogo respondas al la reala breto."}',
 6, 'mes', 40),

('reshelving', 'rangement_collections',
 '{"pt-BR":"Arrumação das devoluções","fr":"Rangement des retours","es":"Colocación de las devoluciones","en":"Reshelving returns","it":"Ricollocazione delle restituzioni","de":"Einordnen der Rückgaben","ca":"Endreça de les devolucions","eo":"Reordigo de la redonoj"}',
 '{"pt-BR":"Recolocação dos documentos devolvidos e correção dos documentos mal colocados.","fr":"Reclassement des documents revenus de prêt et correction des documents mal placés.","es":"Recolocación de los documentos devueltos y corrección de los documentos mal colocados.","en":"Reshelving returned documents and correcting misplaced ones.","it":"Ricollocazione dei documenti restituiti e correzione di quelli mal collocati.","de":"Einordnen zurückgegebener Dokumente und Korrektur falsch eingestellter Dokumente.","ca":"Recol·locació dels documents retornats i correcció dels documents mal col·locats.","eo":"Reordigo de la redonitaj dokumentoj kaj korektado de la mislokitaj dokumentoj."}',
 1, 'semana', 50),

-- Gestion de la collection
('weeding', 'gestion_collection',
 '{"pt-BR":"Descarte (desbaste do acervo)","fr":"Désherbage","es":"Expurgo","en":"Weeding","it":"Sfoltimento","de":"Aussonderung","ca":"Esporgada","eo":"Sarkado de la kolekto"}',
 '{"pt-BR":"Retirada criteriosa de documentos obsoletos; os critérios cabem a uma decisão coletiva.","fr":"Retrait raisonné des documents obsolètes ; les critères relèvent d''une décision collective.","es":"Retirada razonada de documentos obsoletos; los criterios competen a una decisión colectiva.","en":"Considered removal of obsolete documents; the criteria are a collective decision.","it":"Rimozione ragionata dei documenti obsoleti; i criteri spettano a una decisione collettiva.","de":"Überlegte Entfernung veralteter Dokumente; die Kriterien sind eine kollektive Entscheidung.","ca":"Retirada raonada de documents obsolets; els criteris depenen d''una decisió col·lectiva.","eo":"Pripensita forigo de malaktualaj dokumentoj; la kriterioj apartenas al kolektiva decido."}',
 12, 'mes', 60),

('donations', 'gestion_collection',
 '{"pt-BR":"Tratamento das doações recebidas","fr":"Traitement des dons reçus","es":"Tratamiento de las donaciones recibidas","en":"Processing received donations","it":"Trattamento delle donazioni ricevute","de":"Bearbeitung erhaltener Spenden","ca":"Tractament de les donacions rebudes","eo":"Traktado de la ricevitaj donacoj"}',
 '{"pt-BR":"Triagem, integração ou recusa dos documentos recebidos em doação.","fr":"Tri, intégration ou refus des documents reçus en don.","es":"Selección, integración o rechazo de los documentos recibidos en donación.","en":"Sorting, integrating or declining documents received as donations.","it":"Selezione, integrazione o rifiuto dei documenti ricevuti in dono.","de":"Sichten, Aufnehmen oder Ablehnen von Dokumenten aus Spenden.","ca":"Triatge, integració o rebuig dels documents rebuts en donació.","eo":"Ordigo, integrigo aŭ rifuzo de la dokumentoj ricevitaj kiel donacoj."}',
 NULL, NULL, 70),

-- Entretien des espaces
('climate_control', 'entretien_espaces',
 '{"pt-BR":"Controle climático","fr":"Contrôle climatique","es":"Control climático","en":"Climate control","it":"Controllo climatico","de":"Klimakontrolle","ca":"Control climàtic","eo":"Klimata kontrolo"}',
 '{"pt-BR":"Vigilância da umidade e da temperatura; a adaptar ao território (geada, ar salino…).","fr":"Surveillance de l''humidité et de la température ; à adapter au territoire (gel, air salin…).","es":"Vigilancia de la humedad y la temperatura; adaptable al territorio (heladas, aire salino…).","en":"Monitoring humidity and temperature; to adapt to the territory (frost, salt air…).","it":"Monitoraggio di umidità e temperatura; da adattare al territorio (gelo, aria salina…).","de":"Überwachung von Feuchtigkeit und Temperatur; an das Gebiet anzupassen (Frost, Salzluft…).","ca":"Vigilància de la humitat i la temperatura; adaptable al territori (gelada, aire salí…).","eo":"Kontrolado de humideco kaj temperaturo; adaptenda al la teritorio (frosto, sala aero…)."}',
 1, 'mes', 80),

('cleaning', 'entretien_espaces',
 '{"pt-BR":"Limpeza dos locais","fr":"Ménage des locaux","es":"Limpieza de los locales","en":"Cleaning the premises","it":"Pulizia dei locali","de":"Reinigung der Räume","ca":"Neteja dels locals","eo":"Purigado de la ejoj"}',
 '{"pt-BR":"Manutenção dos espaços e do mobiliário da biblioteca.","fr":"Entretien des espaces et du mobilier de la bibliothèque.","es":"Mantenimiento de los espacios y el mobiliario de la biblioteca.","en":"Upkeep of the library''s spaces and furniture.","it":"Manutenzione degli spazi e degli arredi della biblioteca.","de":"Pflege der Räume und Möbel der Bibliothek.","ca":"Manteniment dels espais i el mobiliari de la biblioteca.","eo":"Prizorgado de la spacoj kaj mebloj de la biblioteko."}',
 2, 'semana', 90),

-- Traitement des nouveaux documents
('intake_chain', 'nouveaux_documents',
 '{"pt-BR":"Cadeia de entrada de um documento","fr":"Chaîne d''entrée d''un document","es":"Cadena de entrada de un documento","en":"Document intake chain","it":"Catena di ingresso di un documento","de":"Eingangskette eines Dokuments","ca":"Cadena d''entrada d''un document","eo":"Enirĉeno de dokumento"}',
 '{"pt-BR":"Recepção, carimbo, equipamento, catalogação e colocação na estante de um novo documento.","fr":"Réception, estampillage, équipement, catalogage et mise en rayon d''un nouveau document.","es":"Recepción, sellado, equipamiento, catalogación y colocación de un nuevo documento.","en":"Receiving, stamping, equipping, cataloguing and shelving a new document.","it":"Ricezione, timbratura, attrezzatura, catalogazione e collocazione di un nuovo documento.","de":"Annahme, Stempelung, Ausstattung, Katalogisierung und Einstellung eines neuen Dokuments.","ca":"Recepció, segellat, equipament, catalogació i col·locació d''un nou document.","eo":"Ricevo, stampado, ekipado, katalogado kaj enbretigo de nova dokumento."}',
 NULL, NULL, 100),

-- Vie collective et gouvernance
('general_assembly', 'vie_collective',
 '{"pt-BR":"Assembleia geral","fr":"Assemblée générale","es":"Asamblea general","en":"General assembly","it":"Assemblea generale","de":"Vollversammlung","ca":"Assemblea general","eo":"Ĝenerala asembleo"}',
 '{"pt-BR":"Preparação e realização da assembleia geral do coletivo.","fr":"Préparation et tenue de l''assemblée générale du collectif.","es":"Preparación y celebración de la asamblea general del colectivo.","en":"Preparing and holding the collective''s general assembly.","it":"Preparazione e svolgimento dell''assemblea generale del collettivo.","de":"Vorbereitung und Durchführung der Vollversammlung des Kollektivs.","ca":"Preparació i realització de l''assemblea general del col·lectiu.","eo":"Preparado kaj okazigo de la ĝenerala asembleo de la kolektivo."}',
 6, 'mes', 110),

('collective_meeting', 'vie_collective',
 '{"pt-BR":"Reunião do coletivo","fr":"Réunion de collectif","es":"Reunión del colectivo","en":"Collective meeting","it":"Riunione del collettivo","de":"Kollektivtreffen","ca":"Reunió del col·lectiu","eo":"Kunsido de la kolektivo"}',
 '{"pt-BR":"Reunião de coordenação da equipe da biblioteca.","fr":"Réunion de coordination de l''équipe de la bibliothèque.","es":"Reunión de coordinación del equipo de la biblioteca.","en":"Coordination meeting of the library team.","it":"Riunione di coordinamento della squadra della biblioteca.","de":"Koordinationstreffen des Bibliotheksteams.","ca":"Reunió de coordinació de l''equip de la biblioteca.","eo":"Kunordiga kunsido de la teamo de la biblioteko."}',
 1, 'mes', 120),

('treasury_review', 'vie_collective',
 '{"pt-BR":"Ponto de tesouraria","fr":"Point trésorerie","es":"Revisión de tesorería","en":"Treasury review","it":"Punto di tesoreria","de":"Kassenbericht","ca":"Revisió de tresoreria","eo":"Kasa revizio"}',
 '{"pt-BR":"Acompanhamento das cotizações, das despesas e do estado das contas.","fr":"Suivi des cotisations, des dépenses et de l''état des comptes.","es":"Seguimiento de las cuotas, los gastos y el estado de las cuentas.","en":"Tracking dues, expenses and the state of the accounts.","it":"Monitoraggio delle quote, delle spese e dello stato dei conti.","de":"Verfolgung von Beiträgen, Ausgaben und Kontostand.","ca":"Seguiment de les quotes, les despeses i l''estat dels comptes.","eo":"Sekvado de la kotizoj, elspezoj kaj stato de la kontoj."}',
 3, 'mes', 130),

('membership_review', 'vie_collective',
 '{"pt-BR":"Acompanhamento das adesões","fr":"Suivi des adhésions","es":"Seguimiento de las afiliaciones","en":"Membership review","it":"Monitoraggio delle adesioni","de":"Mitgliederpflege","ca":"Seguiment de les adhesions","eo":"Sekvado de la aliĝoj"}',
 '{"pt-BR":"Atualização das adesões e eventuais lembretes.","fr":"Mise à jour des adhésions et relances éventuelles.","es":"Actualización de las afiliaciones y recordatorios eventuales.","en":"Updating memberships and sending reminders as needed.","it":"Aggiornamento delle adesioni ed eventuali solleciti.","de":"Aktualisierung der Mitgliedschaften und ggf. Erinnerungen.","ca":"Actualització de les adhesions i recordatoris eventuals.","eo":"Ĝisdatigo de la aliĝoj kaj eventualaj memorigoj."}',
 3, 'mes', 140),

-- Administratif
('admin_routine', 'administratif',
 '{"pt-BR":"Tarefas administrativas correntes","fr":"Tâches administratives courantes","es":"Tareas administrativas corrientes","en":"Routine administrative tasks","it":"Compiti amministrativi correnti","de":"Laufende Verwaltungsaufgaben","ca":"Tasques administratives corrents","eo":"Kurantaj administraj taskoj"}',
 '{"pt-BR":"Declarações, correspondência e relações com as outras estruturas da rede.","fr":"Déclarations, courriers et relations avec les autres structures du réseau.","es":"Declaraciones, correspondencia y relaciones con las demás estructuras de la red.","en":"Filings, correspondence and relations with the network''s other structures.","it":"Dichiarazioni, corrispondenza e rapporti con le altre strutture della rete.","de":"Meldungen, Schriftverkehr und Beziehungen zu den anderen Strukturen des Netzwerks.","ca":"Declaracions, correspondència i relacions amb les altres estructures de la xarxa.","eo":"Deklaroj, korespondado kaj rilatoj kun la aliaj strukturoj de la reto."}',
 NULL, NULL, 150);


-- ─── fn_task_adopt_suggestion : adopter une suggestion en tache-type locale ─
-- Copie une entree du catalogue global en tache-type LOCALE de la
-- bibliotheque (painel_recurring_task_rules). Le catalogue suggere ; la
-- bibliotheque decide. INVOKER : l'INSERT passe par la RLS
-- painel_recurring_task_rules_insert (staff de la bibliotheque ciblee).
-- La langue du libelle/description copies est choisie par p_locale
-- (defaut pt-BR) ; la bibliotheque pourra ensuite tout editer.
CREATE OR REPLACE FUNCTION public.fn_task_adopt_suggestion(
  p_suggestion_code text,
  p_library_id      uuid,
  p_locale          text DEFAULT 'pt-BR'
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_sugg painel_task_suggestion_catalog%ROWTYPE;
  v_new  painel_recurring_task_rules%ROWTYPE;
  v_title text;
  v_desc  text;
BEGIN
  IF p_suggestion_code IS NULL OR p_library_id IS NULL THEN
    RAISE EXCEPTION 'fn_task_adopt_suggestion: p_suggestion_code et p_library_id obligatoires';
  END IF;

  -- La RLS painel_task_suggestion_catalog_select filtre l'acces (staff).
  SELECT * INTO v_sugg
  FROM painel_task_suggestion_catalog
  WHERE code = p_suggestion_code AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_task_adopt_suggestion: suggestion % introuvable ou inactive', p_suggestion_code;
  END IF;

  -- Libelle/description dans la locale demandee, repli sur pt-BR.
  v_title := COALESCE(v_sugg.title_i18n ->> p_locale, v_sugg.title_i18n ->> 'pt-BR');
  v_desc  := COALESCE(v_sugg.description_i18n ->> p_locale, v_sugg.description_i18n ->> 'pt-BR');

  -- INSERT de la tache-type locale. La RLS painel_recurring_task_rules_insert
  -- verifie user_can_act_as_staff_on_library(p_library_id).
  INSERT INTO painel_recurring_task_rules (
    library_id,
    interval_count,
    interval_unit,
    label,
    template_title,
    template_description,
    template_priority,
    template_tags
  )
  VALUES (
    p_library_id,
    v_sugg.suggested_interval_count,
    v_sugg.suggested_interval_unit,
    v_title,
    v_title,
    v_desc,
    'media',
    ARRAY[]::text[]
  )
  RETURNING * INTO v_new;

  RETURN to_jsonb(v_new) || jsonb_build_object('adopted_from_suggestion', v_sugg.code);
END;
$function$;


-- ─── Verification post-migration ────────────────────────────────────────────
DO $verif$
declare
  v_count integer;
begin
  -- (a) La table existe avec RLS activee.
  if not (select relrowsecurity from pg_class
          where oid = 'public.painel_task_suggestion_catalog'::regclass) then
    raise exception 'Verification echouee : RLS non activee sur painel_task_suggestion_catalog.';
  end if;

  -- (b) Les 15 suggestions sont chargees.
  select count(*) into v_count from public.painel_task_suggestion_catalog;
  if v_count <> 15 then
    raise exception 'Verification echouee : % suggestions chargees, 15 attendues.', v_count;
  end if;

  -- (c) Chaque suggestion a ses 8 langues dans title_i18n et description_i18n.
  if exists (
    select 1 from public.painel_task_suggestion_catalog
    where (select count(*) from jsonb_object_keys(title_i18n)) <> 8
       or (select count(*) from jsonb_object_keys(description_i18n)) <> 8
  ) then
    raise exception 'Verification echouee : une suggestion n''a pas ses 8 langues.';
  end if;

  -- (d) La fonction d'adoption existe.
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='public' and p.proname='fn_task_adopt_suggestion'
  ) then
    raise exception 'Verification echouee : fn_task_adopt_suggestion absente.';
  end if;

  raise notice 'Migration 20260524080000 : verification OK (catalogue 15 suggestions x 8 langues, RLS, fn_task_adopt_suggestion).';
end;
$verif$;