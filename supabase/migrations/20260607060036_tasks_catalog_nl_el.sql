-- ════════════════════════════════════════════════════════════════════════════
-- Chantier #TASKS — completude i18n du catalogue : ajout nl + el
-- Auteur  : Claude (Opus)
-- Session : Taches internes — catalogue & e-mail i18n
-- Date    : 2026-06-07 (UTC)
--
-- Le catalogue (painel_task_suggestion_catalog) couvrait 8 locales
-- (ca, de, en, eo, es, fr, it, pt-BR). On ajoute nl (neerlandais) et el (grec)
-- aux title_i18n / description_i18n des 15 suggestions -> parite 10 locales.
--
-- Traductions nl/el NEUTRES (sans marqueur inclusif : nl "provisoire", el "à
-- définir" selon la charte). A FAIRE RELIRE par des personnes locutrices natives.
--
-- Puis resync : les modeles deja adoptes (non edites -> title_i18n NOT NULL) et
-- les taches recurrentes recoivent l'i18n rafraichi (donc nl/el aussi).
-- ════════════════════════════════════════════════════════════════════════════

-- 1) Catalogue : ajouter nl + el (merge jsonb || ) ────────────────────────────
UPDATE public.painel_task_suggestion_catalog c
SET
  title_i18n = c.title_i18n || jsonb_build_object('nl', v.title_nl, 'el', v.title_el),
  description_i18n = c.description_i18n || jsonb_build_object('nl', v.desc_nl, 'el', v.desc_el)
FROM (VALUES
  ('dust_shelves',
   'Rekken afstoffen', 'Ξεσκόνισμα των ραφιών',
   'Rekken en documenten reinigen, sectie per sectie.',
   'Καθαρισμός των ραφιών και των τεκμηρίων, τμήμα προς τμήμα.'),
  ('check_on_return',
   'Conditiecontrole na teruggave', 'Έλεγχος κατάστασης μετά την επιστροφή',
   'De staat van een document controleren bij elke teruggave van een uitlening.',
   'Έλεγχος της κατάστασης ενός τεκμηρίου σε κάθε επιστροφή δανεισμού.'),
  ('antifungal',
   'Schimmelbehandeling en -bestrijding', 'Αντιμυκητιακή αγωγή και καταπολέμηση μούχλας',
   'Anti-schimmelbehandeling van banden en papier; essentieel in een warm, vochtig klimaat.',
   'Αντιμυκητιακή αγωγή των βιβλιοδεσιών και του χαρτιού· ζωτικής σημασίας σε ζεστό, υγρό κλίμα.'),
  ('inventory_check',
   'Inventariscontrole', 'Καταμέτρηση αποθέματος',
   'Controleren of elk document op zijn plaats staat en of de catalogus overeenkomt met het werkelijke rek.',
   'Έλεγχος ότι κάθε τεκμήριο βρίσκεται στη θέση του και ότι ο κατάλογος αντιστοιχεί στο πραγματικό ράφι.'),
  ('reshelving',
   'Teruggebrachte documenten terugplaatsen', 'Επανατοποθέτηση επιστροφών',
   'Teruggebrachte documenten terugplaatsen en verkeerd geplaatste documenten corrigeren.',
   'Επανατοποθέτηση των επιστραφέντων τεκμηρίων και διόρθωση των λανθασμένα τοποθετημένων.'),
  ('weeding',
   'Collectie opschonen', 'Εκκαθάριση συλλογής',
   'Doordachte verwijdering van verouderde documenten; de criteria zijn een collectieve beslissing.',
   'Συνειδητή απόσυρση παρωχημένων τεκμηρίων· τα κριτήρια αποτελούν συλλογική απόφαση.'),
  ('donations',
   'Ontvangen schenkingen verwerken', 'Διαχείριση δωρεών',
   'Sorteren, integreren of weigeren van documenten die als schenking zijn ontvangen.',
   'Ταξινόμηση, ένταξη ή απόρριψη τεκμηρίων που ελήφθησαν ως δωρεά.'),
  ('climate_control',
   'Klimaatbeheersing', 'Έλεγχος κλίματος',
   'Toezicht op vochtigheid en temperatuur; aan te passen aan het gebied (vorst, zilte lucht…).',
   'Παρακολούθηση υγρασίας και θερμοκρασίας· προσαρμόζεται στην περιοχή (παγετός, αλμυρός αέρας…).'),
  ('cleaning',
   'Schoonmaak van de ruimte', 'Καθαριότητα του χώρου',
   'Onderhoud van de ruimtes en het meubilair van de bibliotheek.',
   'Συντήρηση των χώρων και του εξοπλισμού της βιβλιοθήκης.'),
  ('intake_chain',
   'Verwerkingsketen van een document', 'Αλυσίδα εισαγωγής τεκμηρίου',
   'Ontvangen, stempelen, uitrusten, catalogiseren en in het rek plaatsen van een nieuw document.',
   'Παραλαβή, σφράγιση, εξοπλισμός, καταλογογράφηση και τοποθέτηση στο ράφι ενός νέου τεκμηρίου.'),
  ('general_assembly',
   'Algemene vergadering', 'Γενική συνέλευση',
   'Voorbereiding en houden van de algemene vergadering van het collectief.',
   'Προετοιμασία και διεξαγωγή της γενικής συνέλευσης της συλλογικότητας.'),
  ('collective_meeting',
   'Collectiefoverleg', 'Συνάντηση της συλλογικότητας',
   'Coördinatievergadering van het bibliotheekteam.',
   'Συντονιστική συνάντηση της ομάδας της βιβλιοθήκης.'),
  ('treasury_review',
   'Financieel overzicht', 'Ταμειακή ενημέρωση',
   'Opvolging van bijdragen, uitgaven en de stand van de rekeningen.',
   'Παρακολούθηση των συνδρομών, των εξόδων και της κατάστασης των λογαριασμών.'),
  ('membership_review',
   'Opvolging van lidmaatschappen', 'Παρακολούθηση εγγραφών',
   'Lidmaatschappen bijwerken en zo nodig herinneringen sturen.',
   'Ενημέρωση των εγγραφών και αποστολή υπενθυμίσεων όπου χρειάζεται.'),
  ('admin_routine',
   'Lopende administratieve taken', 'Τρέχουσες διοικητικές εργασίες',
   'Aangiften, correspondentie en betrekkingen met de andere structuren van het netwerk.',
   'Δηλώσεις, αλληλογραφία και σχέσεις με τις άλλες δομές του δικτύου.')
) AS v(code, title_nl, title_el, desc_nl, desc_el)
WHERE c.code = v.code;

-- 2) Resync des modeles adoptes (non edites) depuis le catalogue ──────────────
UPDATE public.painel_recurring_task_rules r
SET title_i18n = s.title_i18n, description_i18n = s.description_i18n
FROM public.painel_task_suggestion_catalog s
WHERE r.adopted_from_suggestion_code = s.code
  AND r.title_i18n IS NOT NULL;

-- 3) Resync des taches recurrentes depuis leur modele ─────────────────────────
UPDATE public.painel_internal_tasks tk
SET title_i18n = r.title_i18n, description_i18n = r.description_i18n
FROM public.painel_recurring_task_rules r
WHERE tk.recurrence_rule_id = r.id
  AND r.title_i18n IS NOT NULL
  AND tk.title_i18n IS NOT NULL;
