-- =========================================================================
-- Route B — Backfill des notes système existantes vers les codes @@note:
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : i18n notes système (Route B) — sentinelles @@note:<clé>
-- Auteur   : AnarBib · Session : Notes système i18n (Route B)
--
-- Remplace, par ÉGALITÉ STRICTE, les libellés système figés (rendus dans
-- l'une des 10 locales OU les littéraux SQL par défaut) par le code @@note:
-- correspondant. Décodé à l'affichage (front + mail). Le TEXTE LIBRE humain
-- (motifs tapés, refus lecteur·rice, notes concaténées) ne matche aucun
-- littéral exact → laissé INTACT. schedule_reply_note (refus libre) n'est PAS
-- touché. Voir migration 20260618214814 (RPC) pour les nouveaux défauts.
--
-- Mapping généré depuis src/i18n/locales (5 clés réutilisées × 10 locales) +
-- littéraux SQL pt-BR (variantes « do(a/e) » slash et « do(a-e) » tiret) +
-- 4 clés systemNote.*. 56 littéraux, aucune collision (1 littéral → 1 code).
-- =========================================================================

BEGIN;

CREATE TEMP TABLE _note_backfill(lit text PRIMARY KEY, code text NOT NULL) ON COMMIT DROP;

INSERT INTO _note_backfill(lit, code) VALUES
  ('Sol·licitud de consulta creada des del compte de lector-a-e.', '@@note:account.reserve.noteConsult'),
  ('Reserva creada des del compte de lector-a-e.', '@@note:account.reserve.noteLoan'),
  ('Reserva creada des del catàleg.', '@@note:catalog.quickReserve.note'),
  ('Sol·licitud feta des de la cerca', '@@note:catalog.quickConsulta.note'),
  ('Sol·licitud feta des de la fitxa del document', '@@note:book.reserve.consult.note'),
  ('Einsichtnahme-Anfrage aus dem Leserkonto erstellt.', '@@note:account.reserve.noteConsult'),
  ('Vormerkung aus dem Leserkonto erstellt.', '@@note:account.reserve.noteLoan'),
  ('Reservierung aus dem Katalog erstellt.', '@@note:catalog.quickReserve.note'),
  ('Aus der Suche angefragt', '@@note:catalog.quickConsulta.note'),
  ('Über die Dokumentseite angefragt', '@@note:book.reserve.consult.note'),
  ('Αίτημα επιτόπιας μελέτης που δημιουργήθηκε από λογαριασμό αναγνώστη/στριας.', '@@note:account.reserve.noteConsult'),
  ('Κράτηση που δημιουργήθηκε από λογαριασμό αναγνώστη/στριας.', '@@note:account.reserve.noteLoan'),
  ('Η κράτηση δημιουργήθηκε από τον κατάλογο.', '@@note:catalog.quickReserve.note'),
  ('Ζητήθηκε από την αναζήτηση', '@@note:catalog.quickConsulta.note'),
  ('Ζητήθηκε από τη σελίδα του τεκμηρίου', '@@note:book.reserve.consult.note'),
  ('Local consultation request created from reader account.', '@@note:account.reserve.noteConsult'),
  ('Reservation created from reader account.', '@@note:account.reserve.noteLoan'),
  ('Reservation created from the catalog.', '@@note:catalog.quickReserve.note'),
  ('Requested from search', '@@note:catalog.quickConsulta.note'),
  ('Requested from the document page', '@@note:book.reserve.consult.note'),
  ('Konsultpeto kreita el la konto de legant-in-o.', '@@note:account.reserve.noteConsult'),
  ('Rezervo kreita el la konto de legant-in-o.', '@@note:account.reserve.noteLoan'),
  ('Rezervo kreita el la katalogo.', '@@note:catalog.quickReserve.note'),
  ('Peto farita el la serĉo', '@@note:catalog.quickConsulta.note'),
  ('Peto farita el la slipo de la dokumento', '@@note:book.reserve.consult.note'),
  ('Solicitud de consulta local creada desde la cuenta de le lectore.', '@@note:account.reserve.noteConsult'),
  ('Reserva creada desde la cuenta de le lectore.', '@@note:account.reserve.noteLoan'),
  ('Reserva creada desde el catálogo.', '@@note:catalog.quickReserve.note'),
  ('Pedido hecho desde la búsqueda', '@@note:catalog.quickConsulta.note'),
  ('Pedido hecho desde la página del documento', '@@note:book.reserve.consult.note'),
  ('Demande de consultation créée depuis le compte lecteur·rice.', '@@note:account.reserve.noteConsult'),
  ('Réservation créée depuis le compte lecteur·rice.', '@@note:account.reserve.noteLoan'),
  ('Réservation créée depuis le catalogue.', '@@note:catalog.quickReserve.note'),
  ('Demande faite depuis la recherche', '@@note:catalog.quickConsulta.note'),
  ('Demande faite depuis la fiche du document', '@@note:book.reserve.consult.note'),
  ('Richiesta di consultazione creata dall''account lettore/trice.', '@@note:account.reserve.noteConsult'),
  ('Prenotazione creata dall''account lettore/trice.', '@@note:account.reserve.noteLoan'),
  ('Prenotazione creata dal catalogo.', '@@note:catalog.quickReserve.note'),
  ('Richiesto dalla ricerca', '@@note:catalog.quickConsulta.note'),
  ('Richiesto dalla pagina del documento', '@@note:book.reserve.consult.note'),
  ('Aanvraag voor raadpleging ter plaatse aangemaakt vanuit het lezersaccount.', '@@note:account.reserve.noteConsult'),
  ('Reservering aangemaakt vanuit het lezersaccount.', '@@note:account.reserve.noteLoan'),
  ('Reservering aangemaakt vanuit de catalogus.', '@@note:catalog.quickReserve.note'),
  ('Aangevraagd vanuit de zoekopdracht', '@@note:catalog.quickConsulta.note'),
  ('Aangevraagd vanaf de documentpagina', '@@note:book.reserve.consult.note'),
  ('Pedido de consulta local criado pela conta do(a-e) leitor(a-e).', '@@note:account.reserve.noteConsult'),
  ('Reserva criada pela conta do(a-e) leitor(a-e).', '@@note:account.reserve.noteLoan'),
  ('Reserva criada a partir do catálogo.', '@@note:catalog.quickReserve.note'),
  ('Pedido feito desde a busca', '@@note:catalog.quickConsulta.note'),
  ('Pedido feito desde a página do documento', '@@note:book.reserve.consult.note'),
  ('Pedido de consulta local criado pela conta do(a/e) leitor(a/e).', '@@note:account.reserve.noteConsult'),
  ('Reserva criada pela conta do(a/e) leitor(a/e).', '@@note:account.reserve.noteLoan'),
  ('Pedido de consulta local recebido.', '@@note:systemNote.consultaReceived'),
  ('Reserva recebida.', '@@note:systemNote.reservaReceived'),
  ('Cancelamento solicitado pela conta do(a/e) leitor(a/e).', '@@note:systemNote.cancelRequestedByReader'),
  ('Cancelamento efetuado pela biblioteca.', '@@note:systemNote.cancelledByLibrary');

-- Consultas
UPDATE public.consultas_locais_v2      t SET notes         = m.code FROM _note_backfill m WHERE t.notes         = m.lit;
UPDATE public.consulta_linhas_v2       t SET notes         = m.code FROM _note_backfill m WHERE t.notes         = m.lit;
UPDATE public.consulta_item_workflow_v2 t SET workflow_note = m.code FROM _note_backfill m WHERE t.workflow_note = m.lit;

-- Réservations
UPDATE public.reservas_v2              t SET notes         = m.code FROM _note_backfill m WHERE t.notes         = m.lit;
UPDATE public.reserva_linhas_v2        t SET notes         = m.code FROM _note_backfill m WHERE t.notes         = m.lit;
UPDATE public.reserva_item_workflow_v2 t SET workflow_note = m.code FROM _note_backfill m WHERE t.workflow_note = m.lit;

COMMIT;
