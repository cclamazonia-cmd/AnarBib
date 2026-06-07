#!/usr/bin/env node
// ============================================================================
// Script  : add-i18n-keys.cjs
// Objet   : Add missing i18n keys to all 10 locale files for cataloging forms
// Session : Catalogacao authority metadata
// ============================================================================
const fs = require('fs');
const path = require('path');

const LOCALES_DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

// ── New keys: { key: { locale: translation } } ───────────────────────────
const NEW_KEYS = {
  // ── Statusbar ──
  "catalogacao.stats.publishedExemplars": {
    "pt-BR": "Exemplares publicados",
    "en": "Published copies",
    "fr": "Exemplaires publiés",
    "es": "Ejemplares publicados",
    "de": "Veröffentlichte Exemplare",
    "it": "Esemplari pubblicati",
    "ca": "Exemplars publicats",
    "eo": "Eldonitaj ekzempleroj",
    "nl": "Gepubliceerde exemplaren",
    "el": "Δημοσιευμένα αντίτυπα"
  },
  "catalogacao.stats.openBatchesTitle": {
    "pt-BR": "Ver lotes abertos",
    "en": "View open batches",
    "fr": "Voir les lots ouverts",
    "es": "Ver lotes abiertos",
    "de": "Offene Stapel anzeigen",
    "it": "Vedi lotti aperti",
    "ca": "Veure lots oberts",
    "eo": "Vidi malfermitajn arojn",
    "nl": "Open batches bekijken",
    "el": "Προβολή ανοιχτών παρτίδων"
  },
  "catalogacao.stats.activeDraftsTitle": {
    "pt-BR": "Ver rascunhos ativos",
    "en": "View active drafts",
    "fr": "Voir les brouillons actifs",
    "es": "Ver borradores activos",
    "de": "Aktive Entwürfe anzeigen",
    "it": "Vedi bozze attive",
    "ca": "Veure esborranys actius",
    "eo": "Vidi aktivajn malnetojn",
    "nl": "Actieve concepten bekijken",
    "el": "Προβολή ενεργών προσχεδίων"
  },
  "catalogacao.stats.publishedBooksTitle": {
    "pt-BR": "Ver livros publicados",
    "en": "View published books",
    "fr": "Voir les livres publiés",
    "es": "Ver libros publicados",
    "de": "Veröffentlichte Bücher anzeigen",
    "it": "Vedi libri pubblicati",
    "ca": "Veure llibres publicats",
    "eo": "Vidi eldonitajn librojn",
    "nl": "Gepubliceerde boeken bekijken",
    "el": "Προβολή δημοσιευμένων βιβλίων"
  },
  "catalogacao.stats.registeredAuthorsTitle": {
    "pt-BR": "Ver autores cadastrados",
    "en": "View registered authors",
    "fr": "Voir les auteur·rices enregistré·es",
    "es": "Ver autores registrades",
    "de": "Registrierte Autor*innen anzeigen",
    "it": "Vedi autor* registrat*",
    "ca": "Veure autor-a-es registrats",
    "eo": "Vidi registritajn aŭtor-in-ojn",
    "nl": "Geregistreerde auteurs bekijken",
    "el": "Προβολή εγγεγραμμένων συγγραφέων"
  },
  "catalogacao.stats.publishedExemplarsTitle": {
    "pt-BR": "Ver exemplares publicados",
    "en": "View published copies",
    "fr": "Voir les exemplaires publiés",
    "es": "Ver ejemplares publicados",
    "de": "Veröffentlichte Exemplare anzeigen",
    "it": "Vedi esemplari pubblicati",
    "ca": "Veure exemplars publicats",
    "eo": "Vidi eldonitajn ekzemplerojn",
    "nl": "Gepubliceerde exemplaren bekijken",
    "el": "Προβολή δημοσιευμένων αντιτύπων"
  },

  // ── Batch panel ──
  "catalogacao.batch.createTitle": {
    "pt-BR": "Criar novo lote",
    "en": "Create new batch",
    "fr": "Créer un nouveau lot",
    "es": "Crear nuevo lote",
    "de": "Neuen Stapel erstellen",
    "it": "Crea nuovo lotto",
    "ca": "Crear un nou lot",
    "eo": "Krei novan aron",
    "nl": "Nieuwe batch aanmaken",
    "el": "Δημιουργία νέας παρτίδας"
  },
  "catalogacao.batch.notesLabel": {
    "pt-BR": "Notas (opcional)",
    "en": "Notes (optional)",
    "fr": "Notes (facultatif)",
    "es": "Notas (opcional)",
    "de": "Notizen (optional)",
    "it": "Note (facoltativo)",
    "ca": "Notes (opcional)",
    "eo": "Notoj (nedeviga)",
    "nl": "Notities (optioneel)",
    "el": "Σημειώσεις (προαιρετικό)"
  },
  "catalogacao.batch.openBatchesCount": {
    "pt-BR": "Lotes abertos ({count})",
    "en": "Open batches ({count})",
    "fr": "Lots ouverts ({count})",
    "es": "Lotes abiertos ({count})",
    "de": "Offene Stapel ({count})",
    "it": "Lotti aperti ({count})",
    "ca": "Lots oberts ({count})",
    "eo": "Malfermitaj aroj ({count})",
    "nl": "Open batches ({count})",
    "el": "Ανοιχτές παρτίδες ({count})"
  },
  "catalogacao.batch.thName": {
    "pt-BR": "Nome",
    "en": "Name",
    "fr": "Nom",
    "es": "Nombre",
    "de": "Name",
    "it": "Nome",
    "ca": "Nom",
    "eo": "Nomo",
    "nl": "Naam",
    "el": "Όνομα"
  },
  "catalogacao.batch.thNotes": {
    "pt-BR": "Notas",
    "en": "Notes",
    "fr": "Notes",
    "es": "Notas",
    "de": "Notizen",
    "it": "Note",
    "ca": "Notes",
    "eo": "Notoj",
    "nl": "Notities",
    "el": "Σημειώσεις"
  },
  "catalogacao.batch.thCreatedAt": {
    "pt-BR": "Criado em",
    "en": "Created",
    "fr": "Créé le",
    "es": "Creado",
    "de": "Erstellt am",
    "it": "Creato il",
    "ca": "Creat el",
    "eo": "Kreita",
    "nl": "Aangemaakt",
    "el": "Δημιουργήθηκε"
  },
  "catalogacao.batch.thStatus": {
    "pt-BR": "Status",
    "en": "Status",
    "fr": "Statut",
    "es": "Estado",
    "de": "Status",
    "it": "Stato",
    "ca": "Estat",
    "eo": "Stato",
    "nl": "Status",
    "el": "Κατάσταση"
  },

  // ── BN lookup (BookDraftForm) ──
  "catalogacao.bn.searchFailed": {
    "pt-BR": "Busca na BN falhou.",
    "en": "BN search failed.",
    "fr": "Recherche BN échouée.",
    "es": "Busqueda en la BN fallida.",
    "de": "BN-Suche fehlgeschlagen.",
    "it": "Ricerca BN fallita.",
    "ca": "Cerca a la BN fallida.",
    "eo": "Serĉo ĉe BN malsukcesis.",
    "nl": "BN-zoekopdracht mislukt.",
    "el": "Η αναζήτηση BN απέτυχε."
  },
  "catalogacao.bn.resultsFound": {
    "pt-BR": "{total} resultado(s) encontrado(s) na Biblioteca Nacional do Brasil.",
    "en": "{total} result(s) found in the National Library of Brazil.",
    "fr": "{total} résultat(s) trouvé(s) dans la Bibliothèque nationale du Brésil.",
    "es": "{total} resultado(s) encontrado(s) en la Biblioteca Nacional de Brasil.",
    "de": "{total} Ergebnis(se) in der Nationalbibliothek Brasiliens gefunden.",
    "it": "{total} risultato/i trovato/i nella Biblioteca Nazionale del Brasile.",
    "ca": "{total} resultat(s) trobat(s) a la Biblioteca Nacional del Brasil.",
    "eo": "{total} rezulto(j) trovita(j) en la Nacia Biblioteko de Brazilo.",
    "nl": "{total} resultaat/resultaten gevonden in de Nationale Bibliotheek van Brazilië.",
    "el": "{total} αποτέλεσμα(τα) βρέθηκαν στην Εθνική Βιβλιοθήκη της Βραζιλίας."
  },
  "catalogacao.bn.noResults": {
    "pt-BR": "Nenhum resultado na Biblioteca Nacional para este ISBN.",
    "en": "No results in the National Library for this ISBN.",
    "fr": "Aucun résultat dans la Bibliothèque nationale pour cet ISBN.",
    "es": "Ningun resultado en la Biblioteca Nacional para este ISBN.",
    "de": "Keine Ergebnisse in der Nationalbibliothek für diese ISBN.",
    "it": "Nessun risultato nella Biblioteca Nazionale per questo ISBN.",
    "ca": "Cap resultat a la Biblioteca Nacional per a aquest ISBN.",
    "eo": "Neniu rezulto en la Nacia Biblioteko por ĉi tiu ISBN.",
    "nl": "Geen resultaten in de Nationale Bibliotheek voor dit ISBN.",
    "el": "Κανένα αποτέλεσμα στην Εθνική Βιβλιοθήκη για αυτό το ISBN."
  },

  // ── ISBD zone 0 content types ──
  "catalogacao.isbd.zone0.poster": {
    "pt-BR": "Imagem (fixa ; bidimensional ; visual) : imediato",
    "en": "Image (still ; 2-dimensional ; visual) : unmediated",
    "fr": "Image (fixe ; bidimensionnelle ; visuelle) : sans médiation",
    "es": "Imagen (fija ; bidimensional ; visual) : sin mediacion",
    "de": "Bild (unbewegt ; zweidimensional ; visuell) : ohne Hilfsmittel",
    "it": "Immagine (fissa ; bidimensionale ; visiva) : senza mediazione",
    "ca": "Imatge (fixa ; bidimensional ; visual) : sense mediació",
    "eo": "Bildo (senmova ; dudimensia ; vida) : senmediata",
    "nl": "Afbeelding (stilstaand ; tweedimensionaal ; visueel) : ongemedieerd",
    "el": "Εικόνα (στατική ; δισδιάστατη ; οπτική) : άμεση"
  },
  "catalogacao.isbd.zone0.program": {
    "pt-BR": "Programa : eletrônico",
    "en": "Computer program : electronic",
    "fr": "Programme informatique : électronique",
    "es": "Programa : electronico",
    "de": "Computerprogramm : elektronisch",
    "it": "Programma : elettronico",
    "ca": "Programa : electrònic",
    "eo": "Komputila programo : elektronika",
    "nl": "Computerprogramma : elektronisch",
    "el": "Πρόγραμμα : ηλεκτρονικό"
  },
  "catalogacao.isbd.zone0.data": {
    "pt-BR": "Dados : eletrônico",
    "en": "Data : electronic",
    "fr": "Données : électronique",
    "es": "Datos : electronico",
    "de": "Daten : elektronisch",
    "it": "Dati : elettronico",
    "ca": "Dades : electrònic",
    "eo": "Datenoj : elektronika",
    "nl": "Data : elektronisch",
    "el": "Δεδομένα : ηλεκτρονικό"
  },
  "catalogacao.isbd.zone0.videoDigital": {
    "pt-BR": "Imagem (animada ; bidimensional ; visual) : eletrônico",
    "en": "Image (moving ; 2-dimensional ; visual) : electronic",
    "fr": "Image (animée ; bidimensionnelle ; visuelle) : électronique",
    "es": "Imagen (animada ; bidimensional ; visual) : electronico",
    "de": "Bild (bewegt ; zweidimensional ; visuell) : elektronisch",
    "it": "Immagine (animata ; bidimensionale ; visiva) : elettronico",
    "ca": "Imatge (animada ; bidimensional ; visual) : electrònic",
    "eo": "Bildo (movanta ; dudimensia ; vida) : elektronika",
    "nl": "Afbeelding (bewegend ; tweedimensionaal ; visueel) : elektronisch",
    "el": "Εικόνα (κινούμενη ; δισδιάστατη ; οπτική) : ηλεκτρονικό"
  },
  "catalogacao.isbd.zone0.spokenWord": {
    "pt-BR": "Palavra falada : eletrônico",
    "en": "Spoken word : electronic",
    "fr": "Parole : électronique",
    "es": "Palabra hablada : electronico",
    "de": "Gesprochenes Wort : elektronisch",
    "it": "Parola parlata : elettronico",
    "ca": "Paraula parlada : electrònic",
    "eo": "Parolata vorto : elektronika",
    "nl": "Gesproken woord : elektronisch",
    "el": "Προφορικός λόγος : ηλεκτρονικό"
  },
  "catalogacao.isbd.zone0.textDigital": {
    "pt-BR": "Texto (visual) : eletrônico",
    "en": "Text (visual) : electronic",
    "fr": "Texte (visuel) : électronique",
    "es": "Texto (visual) : electronico",
    "de": "Text (visuell) : elektronisch",
    "it": "Testo (visivo) : elettronico",
    "ca": "Text (visual) : electrònic",
    "eo": "Teksto (vida) : elektronika",
    "nl": "Tekst (visueel) : elektronisch",
    "el": "Κείμενο (οπτικό) : ηλεκτρονικό"
  },
  "catalogacao.isbd.zone0.textImmediate": {
    "pt-BR": "Texto (visual) : imediato",
    "en": "Text (visual) : unmediated",
    "fr": "Texte (visuel) : sans médiation",
    "es": "Texto (visual) : sin mediacion",
    "de": "Text (visuell) : ohne Hilfsmittel",
    "it": "Testo (visivo) : senza mediazione",
    "ca": "Text (visual) : sense mediació",
    "eo": "Teksto (vida) : senmediata",
    "nl": "Tekst (visueel) : ongemedieerd",
    "el": "Κείμενο (οπτικό) : άμεσο"
  },

  // ── ISBD zone 5 extent ──
  "catalogacao.isbd.zone5.audioResource": {
    "pt-BR": "1 recurso sonoro",
    "en": "1 sound resource",
    "fr": "1 ressource sonore",
    "es": "1 recurso sonoro",
    "de": "1 Tonträger",
    "it": "1 risorsa sonora",
    "ca": "1 recurs sonor",
    "eo": "1 sona rimedo",
    "nl": "1 geluidsbron",
    "el": "1 ηχητικός πόρος"
  },
  "catalogacao.isbd.zone5.avResource": {
    "pt-BR": "1 recurso audiovisual",
    "en": "1 audiovisual resource",
    "fr": "1 ressource audiovisuelle",
    "es": "1 recurso audiovisual",
    "de": "1 audiovisueller Träger",
    "it": "1 risorsa audiovisiva",
    "ca": "1 recurs audiovisual",
    "eo": "1 aŭdvida rimedo",
    "nl": "1 audiovisuele bron",
    "el": "1 οπτικοακουστικός πόρος"
  },
  "catalogacao.isbd.zone5.digitalOnline": {
    "pt-BR": "1 recurso eletrônico online",
    "en": "1 online electronic resource",
    "fr": "1 ressource électronique en ligne",
    "es": "1 recurso electronico en linea",
    "de": "1 Online-Ressource",
    "it": "1 risorsa elettronica online",
    "ca": "1 recurs electrònic en línia",
    "eo": "1 reta elektronika rimedo",
    "nl": "1 online elektronische bron",
    "el": "1 ηλεκτρονικός πόρος διαδικτύου"
  },
  "catalogacao.isbd.zone5.singleItem": {
    "pt-BR": "1 item",
    "en": "1 item",
    "fr": "1 item",
    "es": "1 item",
    "de": "1 Einheit",
    "it": "1 item",
    "ca": "1 item",
    "eo": "1 ero",
    "nl": "1 item",
    "el": "1 αντικείμενο"
  },

  // ── ISBD annotations ──
  "catalogacao.isbd.provenance": {
    "pt-BR": "Proveniência:",
    "en": "Provenance:",
    "fr": "Provenance :",
    "es": "Procedencia:",
    "de": "Provenienz:",
    "it": "Provenienza:",
    "ca": "Provinença:",
    "eo": "Deveno:",
    "nl": "Herkomst:",
    "el": "Προέλευση:"
  },
  "catalogacao.isbd.accessNote": {
    "pt-BR": "Acesso:",
    "en": "Access:",
    "fr": "Accès :",
    "es": "Acceso:",
    "de": "Zugang:",
    "it": "Accesso:",
    "ca": "Accés:",
    "eo": "Aliro:",
    "nl": "Toegang:",
    "el": "Πρόσβαση:"
  },
  "catalogacao.isbd.acquisitionMode": {
    "pt-BR": "modalidade de aquisição:",
    "en": "acquisition mode:",
    "fr": "mode d’acquisition :",
    "es": "modalidad de adquisicion:",
    "de": "Erwerbungsart:",
    "it": "modalità di acquisizione:",
    "ca": "modalitat d’adquisició:",
    "eo": "akira maniero:",
    "nl": "verwervingswijze:",
    "el": "τρόπος απόκτησης:"
  },
  "catalogacao.isbd.immediateOrigin": {
    "pt-BR": "origem imediata:",
    "en": "immediate source:",
    "fr": "origine immédiate :",
    "es": "origen inmediato:",
    "de": "unmittelbare Quelle:",
    "it": "origine immediata:",
    "ca": "origen immediat:",
    "eo": "tuja fonto:",
    "nl": "directe bron:",
    "el": "άμεση πηγή:"
  },
  "catalogacao.isbd.hint": {
    "pt-BR": "O botão \"Preparar ISBD\" relê a ficha na ordem das zonas ISBD e grava no marc_json um pacote técnico para uso futuro na página de índice.",
    "en": "The \"Prepare ISBD\" button reads the record in ISBD zone order and saves a technical package in marc_json for future use in the index page.",
    "fr": "Le bouton « Préparer ISBD » relit la fiche dans l’ordre des zones ISBD et enregistre un paquet technique dans marc_json pour usage futur dans la page d’index.",
    "es": "El boton \"Preparar ISBD\" relee la ficha en el orden de las zonas ISBD y graba en marc_json un paquete tecnico para uso futuro en la pagina de indice.",
    "de": "Die Schaltfläche „ISBD vorbereiten“ liest den Datensatz in ISBD-Zonenreihenfolge und speichert ein technisches Paket in marc_json für spätere Nutzung auf der Indexseite.",
    "it": "Il pulsante \"Prepara ISBD\" rilegge la scheda nell'ordine delle zone ISBD e salva un pacchetto tecnico in marc_json per uso futuro nella pagina indice.",
    "ca": "El botó \"Preparar ISBD\" rellegeix la fitxa en l'ordre de les zones ISBD i desa al marc_json un paquet tècnic per a ús futur a la pàgina d'índex.",
    "eo": "La butono \"Prepari ISBD\" relegas la fiŝon laŭ la ISBD-zonordo kaj konservas teknikan pakon en marc_json por estonta uzo en la indeksa paĝo.",
    "nl": "De knop \"ISBD voorbereiden\" leest het record in ISBD-zonevolgorde en slaat een technisch pakket op in marc_json voor toekomstig gebruik op de indexpagina.",
    "el": "Το κουμπί \"Prepare ISBD\" διαβάζει την εγγραφή σε σειρά ζωνών ISBD και αποθηκεύει ένα τεχνικό πακέτο στο marc_json."
  },
  "catalogacao.isbd.zonesFilled": {
    "pt-BR": "{count} zona(s) preenchida(s).",
    "en": "{count} zone(s) filled.",
    "fr": "{count} zone(s) remplie(s).",
    "es": "{count} zona(s) completada(s).",
    "de": "{count} Zone(n) ausgefüllt.",
    "it": "{count} zona/e compilata/e.",
    "ca": "{count} zona/es completa/es.",
    "eo": "{count} zono(j) plenigita(j).",
    "nl": "{count} zone(s) ingevuld.",
    "el": "{count} ζώνε(ς) συμπληρωμένε(ς)."
  },
  "catalogacao.isbd.zonePrefix": {
    "pt-BR": "Zona {zone}",
    "en": "Zone {zone}",
    "fr": "Zone {zone}",
    "es": "Zona {zone}",
    "de": "Zone {zone}",
    "it": "Zona {zone}",
    "ca": "Zona {zone}",
    "eo": "Zono {zone}",
    "nl": "Zone {zone}",
    "el": "Ζώνη {zone}"
  },
  "catalogacao.isbd.notGenerated": {
    "pt-BR": "ISBD: ainda não gerado neste rascunho. Clique em \"Preparar ISBD\" acima.",
    "en": "ISBD: not yet generated for this draft. Click \"Prepare ISBD\" above.",
    "fr": "ISBD : pas encore généré pour ce brouillon. Cliquez sur « Préparer ISBD » ci-dessus.",
    "es": "ISBD: aun no generado para este borrador. Haga clic en \"Preparar ISBD\" arriba.",
    "de": "ISBD: für diesen Entwurf noch nicht erstellt. Klicken Sie oben auf „ISBD vorbereiten“.",
    "it": "ISBD: non ancora generato per questa bozza. Clicca su \"Prepara ISBD\" sopra.",
    "ca": "ISBD: encara no generat per a aquest esborrany. Feu clic a \"Preparar ISBD\" a dalt.",
    "eo": "ISBD: ankoray ne kreita por ĉi tiu malneto. Klaku \"Prepari ISBD\" supre.",
    "nl": "ISBD: nog niet gegenereerd voor dit concept. Klik hierboven op \"ISBD voorbereiden\".",
    "el": "ISBD: δεν έχει δημιουργηθεί ακόμα. Κάντε κλικ στο \"Prepare ISBD\" παραπάνω."
  },

  // ── Digital resources ──
  "catalogacao.digital.confirmDelete": {
    "pt-BR": "Apagar este recurso digital?",
    "en": "Delete this digital resource?",
    "fr": "Supprimer cette ressource numérique ?",
    "es": "Eliminar este recurso digital?",
    "de": "Diesen digitalen Bestand löschen?",
    "it": "Eliminare questa risorsa digitale?",
    "ca": "Eliminar aquest recurs digital?",
    "eo": "Forigi ĉi tiun ciferecan rimedojn?",
    "nl": "Deze digitale bron verwijderen?",
    "el": "Διαγραφή αυτού του ψηφιακού πόρου;"
  },

  // ── Draft state / messages ──
  "catalogacao.state.saved": {
    "pt-BR": "Rascunho salvo",
    "en": "Draft saved",
    "fr": "Brouillon enregistré",
    "es": "Borrador guardado",
    "de": "Entwurf gespeichert",
    "it": "Bozza salvata",
    "ca": "Esborrany desat",
    "eo": "Malneto konservita",
    "nl": "Concept opgeslagen",
    "el": "Προσχέδιο αποθηκεύτηκε"
  },
  "catalogacao.msg.contribWarning": {
    "pt-BR": "Autores múltiplos: {message}",
    "en": "Multiple contributors: {message}",
    "fr": "Contributeur·rices multiples : {message}",
    "es": "Contribuyentes multiples: {message}",
    "de": "Mehrere Beitragende: {message}",
    "it": "Contributori multipli: {message}",
    "ca": "Contribuïdors multiples: {message}",
    "eo": "Pluraj kontribuantoj: {message}",
    "nl": "Meerdere bijdragers: {message}",
    "el": "Πολλοί συνεισφέροντες: {message}"
  },
  "catalogacao.msg.draftSavedWithWarnings": {
    "pt-BR": "Rascunho salvo, mas {warnings}.",
    "en": "Draft saved, but {warnings}.",
    "fr": "Brouillon enregistré, mais {warnings}.",
    "es": "Borrador guardado, pero {warnings}.",
    "de": "Entwurf gespeichert, aber {warnings}.",
    "it": "Bozza salvata, ma {warnings}.",
    "ca": "Esborrany desat, però {warnings}.",
    "eo": "Malneto konservita, sed {warnings}.",
    "nl": "Concept opgeslagen, maar {warnings}.",
    "el": "Προσχέδιο αποθηκεύτηκε, αλλά {warnings}."
  },
  "catalogacao.msg.draftSaved": {
    "pt-BR": "Rascunho de livro salvo com sucesso.",
    "en": "Book draft saved successfully.",
    "fr": "Brouillon de livre enregistré avec succès.",
    "es": "Borrador del libro guardado con exito.",
    "de": "Buchentwurf erfolgreich gespeichert.",
    "it": "Bozza del libro salvata con successo.",
    "ca": "Esborrany del llibre desat amb èxit.",
    "eo": "Libra malneto sukcese konservita.",
    "nl": "Boekconcept succesvol opgeslagen.",
    "el": "Το προσχέδιο βιβλίου αποθηκεύτηκε επιτυχώς."
  },
  "catalogacao.msg.lookupFailed": {
    "pt-BR": "A busca assistida falhou.",
    "en": "Assisted search failed.",
    "fr": "La recherche assistée a échoué.",
    "es": "La busqueda asistida fallo.",
    "de": "Die unterstützte Suche ist fehlgeschlagen.",
    "it": "La ricerca assistita è fallita.",
    "ca": "La cerca assistida ha fallat.",
    "eo": "La helpata serĉo malsukcesis.",
    "nl": "Ondersteunde zoekopdracht mislukt.",
    "el": "Η υποβοηθούμενη αναζήτηση απέτυχε."
  },

  // ── UI elements ──
  "catalogacao.ui.draftId": {
    "pt-BR": "Rascunho #{id}",
    "en": "Draft #{id}",
    "fr": "Brouillon n°{id}",
    "es": "Borrador #{id}",
    "de": "Entwurf #{id}",
    "it": "Bozza #{id}",
    "ca": "Esborrany #{id}",
    "eo": "Malneto #{id}",
    "nl": "Concept #{id}",
    "el": "Προσχέδιο #{id}"
  },
  "catalogacao.ui.issnPortal": {
    "pt-BR": "Portal ISSN",
    "en": "ISSN Portal",
    "fr": "Portail ISSN",
    "es": "Portal ISSN",
    "de": "ISSN-Portal",
    "it": "Portale ISSN",
    "ca": "Portal ISSN",
    "eo": "ISSN-portalo",
    "nl": "ISSN-portaal",
    "el": "Πύλη ISSN"
  },
  "catalogacao.ui.clearIsbd": {
    "pt-BR": "Limpar ISBD",
    "en": "Clear ISBD",
    "fr": "Effacer ISBD",
    "es": "Limpiar ISBD",
    "de": "ISBD löschen",
    "it": "Pulisci ISBD",
    "ca": "Netejar ISBD",
    "eo": "Forviŝi ISBD",
    "nl": "ISBD wissen",
    "el": "Εκκαθάριση ISBD"
  },
  "catalogacao.ui.refreshing": {
    "pt-BR": "Atualizando…",
    "en": "Refreshing…",
    "fr": "Actualisation…",
    "es": "Actualizando…",
    "de": "Aktualisierung…",
    "it": "Aggiornamento…",
    "ca": "Actualitzant…",
    "eo": "Aŭdatigante…",
    "nl": "Bijwerken…",
    "el": "Ανανέωση…"
  },
  "catalogacao.ui.refreshList": {
    "pt-BR": "Atualizar lista",
    "en": "Refresh list",
    "fr": "Actualiser la liste",
    "es": "Actualizar lista",
    "de": "Liste aktualisieren",
    "it": "Aggiorna lista",
    "ca": "Actualitzar llista",
    "eo": "Aŭdatigi liston",
    "nl": "Lijst bijwerken",
    "el": "Ανανέωση λίστας"
  },

  // ── Lookup source status ──
  "catalogacao.lookup.results": {
    "pt-BR": "{count} resultado(s)",
    "en": "{count} result(s)",
    "fr": "{count} résultat(s)",
    "es": "{count} resultado(s)",
    "de": "{count} Ergebnis(se)",
    "it": "{count} risultato/i",
    "ca": "{count} resultat(s)",
    "eo": "{count} rezulto(j)",
    "nl": "{count} resultaat/resultaten",
    "el": "{count} αποτέλεσμα(τα)"
  },
  "catalogacao.lookup.empty": {
    "pt-BR": "vazio",
    "en": "empty",
    "fr": "vide",
    "es": "vacio",
    "de": "leer",
    "it": "vuoto",
    "ca": "buit",
    "eo": "malplena",
    "nl": "leeg",
    "el": "κενό"
  },
  "catalogacao.lookup.error": {
    "pt-BR": "erro",
    "en": "error",
    "fr": "erreur",
    "es": "error",
    "de": "Fehler",
    "it": "errore",
    "ca": "error",
    "eo": "eraro",
    "nl": "fout",
    "el": "σφάλμα"
  },

  // ── Shelf label preview ──
  "catalogacao.shelf.authorPrefix": {
    "pt-BR": "Autor:",
    "en": "Author:",
    "fr": "Auteur·rice :",
    "es": "Autore:",
    "de": "Autor*in:",
    "it": "Autor*:",
    "ca": "Autor-a-e:",
    "eo": "Aŭtor-in-o:",
    "nl": "Auteur:",
    "el": "Συγγραφέας:"
  },
  "catalogacao.shelf.cddPrefix": {
    "pt-BR": "CDD:",
    "en": "DDC:",
    "fr": "CDD :",
    "es": "CDD:",
    "de": "DDC:",
    "it": "CDD:",
    "ca": "CDD:",
    "eo": "CDD:",
    "nl": "DDC:",
    "el": "CDD:"
  },
  "catalogacao.shelf.cotePrefix": {
    "pt-BR": "Cote:",
    "en": "Call no.:",
    "fr": "Cote :",
    "es": "Signatura:",
    "de": "Signatur:",
    "it": "Segnatura:",
    "ca": "Cota:",
    "eo": "Signaro:",
    "nl": "Plaatsnr.:",
    "el": "Αριθ. θέσης:"
  },

  // ── Queue panel ──
  "catalogacao.queue.noTitle": {
    "pt-BR": "(sem título)",
    "en": "(no title)",
    "fr": "(sans titre)",
    "es": "(sin titulo)",
    "de": "(ohne Titel)",
    "it": "(senza titolo)",
    "ca": "(sense títol)",
    "eo": "(sen titolo)",
    "nl": "(geen titel)",
    "el": "(χωρίς τίτλο)"
  },
  "catalogacao.queue.noName": {
    "pt-BR": "(sem nome)",
    "en": "(no name)",
    "fr": "(sans nom)",
    "es": "(sin nombre)",
    "de": "(ohne Name)",
    "it": "(senza nome)",
    "ca": "(sense nom)",
    "eo": "(sen nomo)",
    "nl": "(geen naam)",
    "el": "(χωρίς όνομα)"
  },
  "catalogacao.queue.noTombo": {
    "pt-BR": "(sem tombo)",
    "en": "(no accession no.)",
    "fr": "(sans cote)",
    "es": "(sin registro)",
    "de": "(ohne Inventarnr.)",
    "it": "(senza collocazione)",
    "ca": "(sense registre)",
    "eo": "(sen numero)",
    "nl": "(geen inventarisnr.)",
    "el": "(χωρίς αριθμό)"
  },
  "catalogacao.queue.selectAtLeast": {
    "pt-BR": "Selecione ao menos um item.",
    "en": "Select at least one item.",
    "fr": "Sélectionnez au moins un élément.",
    "es": "Seleccione al menos un item.",
    "de": "Wählen Sie mindestens ein Element aus.",
    "it": "Seleziona almeno un elemento.",
    "ca": "Seleccioneu almenys un element.",
    "eo": "Elektu almenaŭ unu eron.",
    "nl": "Selecteer ten minste één item.",
    "el": "Επιλέξτε τουλάχιστον ένα στοιχείο."
  },
  "catalogacao.queue.publishConfirm": {
    "pt-BR": "Publicar {count} rascunho(s) selecionado(s)?",
    "en": "Publish {count} selected draft(s)?",
    "fr": "Publier {count} brouillon(s) sélectionné(s) ?",
    "es": "Publicar {count} borrador(es) seleccionado(s)?",
    "de": "{count} ausgewählte(n) Entwurf/Entwürfe veröffentlichen?",
    "it": "Pubblicare {count} bozza/e selezionata/e?",
    "ca": "Publicar {count} esborrany(s) seleccionat(s)?",
    "eo": "Ĉu publikigi {count} elektita(j)n malneto(j)n?",
    "nl": "{count} geselecteerd(e) concept(en) publiceren?",
    "el": "Δημοσίευση {count} επιλεγμένων προσχεδίων;"
  },
  "catalogacao.queue.publishResult": {
    "pt-BR": "{ok} publicado(s){fail, select, 0 {} other {, {fail} com erro}}.",
    "en": "{ok} published{fail, select, 0 {} other {, {fail} with errors}}.",
    "fr": "{ok} publié(s){fail, select, 0 {} other {, {fail} avec erreur(s)}}.",
    "es": "{ok} publicado(s){fail, select, 0 {} other {, {fail} con error(es)}}.",
    "de": "{ok} veröffentlicht{fail, select, 0 {} other {, {fail} mit Fehler(n)}}.",
    "it": "{ok} pubblicat*{fail, select, 0 {} other {, {fail} con errore/i}}.",
    "ca": "{ok} publicat(s){fail, select, 0 {} other {, {fail} amb error(s)}}.",
    "eo": "{ok} publikigita(j){fail, select, 0 {} other {, {fail} kun eraro(j)}}.",
    "nl": "{ok} gepubliceerd{fail, select, 0 {} other {, {fail} met fout(en)}}.",
    "el": "{ok} δημοσιεύτηκαν{fail, select, 0 {} other {, {fail} με σφάλμα(τα)}}."
  },
  "catalogacao.queue.discardConfirm": {
    "pt-BR": "Descartar {count} rascunho(s)? Eles irão para a lixeira.",
    "en": "Discard {count} draft(s)? They will be moved to trash.",
    "fr": "Mettre {count} brouillon(s) au rebut ? Ils seront déplacés dans la corbeille.",
    "es": "Descartar {count} borrador(es)? Seran movidos a la papelera.",
    "de": "{count} Entwurf/Entwürfe verwerfen? Sie werden in den Papierkorb verschoben.",
    "it": "Scartare {count} bozza/e? Verranno spostate nel cestino.",
    "ca": "Descartar {count} esborrany(s)? Seran moguts a la paperera.",
    "eo": "Ĉu foriĝi {count} malneto(j)n? Ili estos movitaj al la rubujeto.",
    "nl": "{count} concept(en) verwijderen? Ze worden naar de prullenbak verplaatst.",
    "el": "Απόρριψη {count} προσχεδίων; Θα μετακινηθούν στον κάδο."
  },
  "catalogacao.queue.discardResult": {
    "pt-BR": "{count} rascunho(s) descartado(s).",
    "en": "{count} draft(s) discarded.",
    "fr": "{count} brouillon(s) mis au rebut.",
    "es": "{count} borrador(es) descartado(s).",
    "de": "{count} Entwurf/Entwürfe verworfen.",
    "it": "{count} bozza/e scartata/e.",
    "ca": "{count} esborrany(s) descartat(s).",
    "eo": "{count} malneto(j) foriĝita(j).",
    "nl": "{count} concept(en) verwijderd.",
    "el": "{count} προσχέδια απορρίφθηκαν."
  },
  "catalogacao.queue.markedReadyResult": {
    "pt-BR": "{count} marcado(s) como pronto(s).",
    "en": "{count} marked as ready.",
    "fr": "{count} marqué(s) comme prêt(s).",
    "es": "{count} marcado(s) como listo(s).",
    "de": "{count} als bereit markiert.",
    "it": "{count} contrassegnat* come pront*.",
    "ca": "{count} marcat(s) com a preparat(s).",
    "eo": "{count} markita(j) kiel preta(j).",
    "nl": "{count} gemarkeerd als gereed.",
    "el": "{count} σημειώθηκαν ως έτοιμα."
  },
  "catalogacao.queue.batchAssignResult": {
    "pt-BR": "{count} item(ns) atribuído(s) ao lote.",
    "en": "{count} item(s) assigned to batch.",
    "fr": "{count} élément(s) attribué(s) au lot.",
    "es": "{count} item(s) asignado(s) al lote.",
    "de": "{count} Element(e) dem Stapel zugewiesen.",
    "it": "{count} elemento/i assegnato/i al lotto.",
    "ca": "{count} element(s) assignat(s) al lot.",
    "eo": "{count} ero(j) asignita(j) al la aro.",
    "nl": "{count} item(s) toegewezen aan batch.",
    "el": "{count} στοιχείο(α) ανατέθηκαν στην παρτίδα."
  },
  "catalogacao.queue.restoreResult": {
    "pt-BR": "{count} restaurado(s).",
    "en": "{count} restored.",
    "fr": "{count} restauré(s).",
    "es": "{count} restaurado(s).",
    "de": "{count} wiederhergestellt.",
    "it": "{count} ripristinat*.",
    "ca": "{count} restaurat(s).",
    "eo": "{count} reaŭdikigita(j).",
    "nl": "{count} hersteld.",
    "el": "{count} αποκαταστάθηκαν."
  },
  "catalogacao.queue.deleteConfirm": {
    "pt-BR": "Apagar este rascunho de forma irreversível?",
    "en": "Delete this draft permanently?",
    "fr": "Supprimer définitivement ce brouillon ?",
    "es": "Eliminar este borrador de forma irreversible?",
    "de": "Diesen Entwurf endgültig löschen?",
    "it": "Eliminare questa bozza in modo irreversibile?",
    "ca": "Eliminar aquest esborrany de forma irreversible?",
    "eo": "Ĉu definitive forigi ĉi tiun malneton?",
    "nl": "Dit concept definitief verwijderen?",
    "el": "Οριστική διαγραφή αυτού του προσχεδίου;"
  },
  "catalogacao.queue.emptyTrashConfirm": {
    "pt-BR": "Esvaziar a lixeira? {count} rascunho(s) serão apagados de forma irreversível.",
    "en": "Empty the trash? {count} draft(s) will be permanently deleted.",
    "fr": "Vider la corbeille ? {count} brouillon(s) seront définitivement supprimé(s).",
    "es": "Vaciar la papelera? {count} borrador(es) seran eliminados de forma irreversible.",
    "de": "Papierkorb leeren? {count} Entwurf/Entwürfe werden endgültig gelöscht.",
    "it": "Svuotare il cestino? {count} bozza/e verranno eliminate in modo irreversibile.",
    "ca": "Buidar la paperera? {count} esborrany(s) seran eliminats de forma irreversible.",
    "eo": "Ĉu malplenigi la rubujon? {count} malneto(j) estos definitive forigita(j).",
    "nl": "Prullenbak legen? {count} concept(en) worden definitief verwijderd.",
    "el": "Άδειασμα κάδου; {count} προσχέδια θα διαγραφούν οριστικά."
  },
  "catalogacao.queue.emptyTrashResult": {
    "pt-BR": "{count} rascunho(s) apagado(s) definitivamente.",
    "en": "{count} draft(s) permanently deleted.",
    "fr": "{count} brouillon(s) définitivement supprimé(s).",
    "es": "{count} borrador(es) eliminado(s) definitivamente.",
    "de": "{count} Entwurf/Entwürfe endgültig gelöscht.",
    "it": "{count} bozza/e eliminata/e definitivamente.",
    "ca": "{count} esborrany(s) eliminat(s) definitivament.",
    "eo": "{count} malneto(j) definitive forigita(j).",
    "nl": "{count} concept(en) definitief verwijderd.",
    "el": "{count} προσχέδια διαγράφηκαν οριστικά."
  },
  "catalogacao.queue.description": {
    "pt-BR": "Rascunhos ativos de documentos, autoridades e exemplares. Gerencie o ciclo de vida: edite, marque como pronto, publique ou descarte.",
    "en": "Active drafts of documents, authorities and copies. Manage the lifecycle: edit, mark ready, publish or discard.",
    "fr": "Brouillons actifs de documents, autorités et exemplaires. Gérez le cycle de vie : éditez, marquez comme prêt, publiez ou mettez au rebut.",
    "es": "Borradores activos de documentos, autoridades y ejemplares. Gestione el ciclo de vida: edite, marque como listo, publique o descarte.",
    "de": "Aktive Entwürfe von Dokumenten, Autoritäten und Exemplaren. Verwalten Sie den Lebenszyklus: bearbeiten, als bereit markieren, veröffentlichen oder verwerfen.",
    "it": "Bozze attive di documenti, autorità e esemplari. Gestisci il ciclo di vita: modifica, segna come pronto, pubblica o scarta.",
    "ca": "Esborranys actius de documents, autoritats i exemplars. Gestioneu el cicle de vida: editeu, marqueu com a preparat, publiqueu o descarteu.",
    "eo": "Aktivaj malnetoj de dokumentoj, aŭtorecoj kaj ekzempleroj. Administru la vivociklon: redaktu, marku kiel pretan, publikigi aŭ foriĝi.",
    "nl": "Actieve concepten van documenten, autoriteiten en exemplaren. Beheer de levenscyclus: bewerk, markeer als gereed, publiceer of verwijder.",
    "el": "Ενεργά προσχέδια εγγράφων, αρχείων και αντιτύπων."
  },
  "catalogacao.queue.refresh": {
    "pt-BR": "Atualizar fila",
    "en": "Refresh queue",
    "fr": "Actualiser la file",
    "es": "Actualizar cola",
    "de": "Warteschlange aktualisieren",
    "it": "Aggiorna coda",
    "ca": "Actualitzar cua",
    "eo": "Aŭdatigi vicon",
    "nl": "Wachtrij bijwerken",
    "el": "Ανανέωση ουράς"
  },
  "catalogacao.queue.layerLabel": {
    "pt-BR": "Camada",
    "en": "Layer",
    "fr": "Couche",
    "es": "Capa",
    "de": "Ebene",
    "it": "Livello",
    "ca": "Capa",
    "eo": "Tavolo",
    "nl": "Laag",
    "el": "Επίπεδο"
  },
  "catalogacao.queue.allTypes": {
    "pt-BR": "Todas",
    "en": "All",
    "fr": "Toutes",
    "es": "Todas",
    "de": "Alle",
    "it": "Tutte",
    "ca": "Totes",
    "eo": "Ĉiuj",
    "nl": "Alle",
    "el": "Όλα"
  },
  "catalogacao.queue.statusLabel": {
    "pt-BR": "Situação",
    "en": "Status",
    "fr": "Situation",
    "es": "Situacion",
    "de": "Status",
    "it": "Stato",
    "ca": "Situació",
    "eo": "Stato",
    "nl": "Status",
    "el": "Κατάσταση"
  },
  "catalogacao.queue.allActive": {
    "pt-BR": "Todas ativas",
    "en": "All active",
    "fr": "Toutes actives",
    "es": "Todas activas",
    "de": "Alle aktiven",
    "it": "Tutte attive",
    "ca": "Totes actives",
    "eo": "Ĉiuj aktivaj",
    "nl": "Alle actieve",
    "el": "Όλες οι ενεργές"
  },
  "catalogacao.queue.actionLabel": {
    "pt-BR": "Gesto editorial",
    "en": "Editorial action",
    "fr": "Geste éditorial",
    "es": "Gesto editorial",
    "de": "Redaktionelle Aktion",
    "it": "Gesto editoriale",
    "ca": "Gest editorial",
    "eo": "Redaktora ago",
    "nl": "Redactionele actie",
    "el": "Εκδοτική ενέργεια"
  },
  "catalogacao.queue.allActions": {
    "pt-BR": "Todos",
    "en": "All",
    "fr": "Tous",
    "es": "Todos",
    "de": "Alle",
    "it": "Tutt*",
    "ca": "Tots",
    "eo": "Ĉiuj",
    "nl": "Alle",
    "el": "Όλες"
  },
  "catalogacao.queue.actionCreate": {
    "pt-BR": "Novo",
    "en": "New",
    "fr": "Nouveau",
    "es": "Nuevo",
    "de": "Neu",
    "it": "Nuovo",
    "ca": "Nou",
    "eo": "Nova",
    "nl": "Nieuw",
    "el": "Νέο"
  },
  "catalogacao.queue.actionUpdate": {
    "pt-BR": "Retomada",
    "en": "Update",
    "fr": "Reprise",
    "es": "Retomada",
    "de": "Wiederaufnahme",
    "it": "Ripresa",
    "ca": "Represa",
    "eo": "Aŭdatigo",
    "nl": "Hervatting",
    "el": "Επανάληψη"
  },
  "catalogacao.queue.searchLabel": {
    "pt-BR": "Buscar na fila",
    "en": "Search queue",
    "fr": "Rechercher dans la file",
    "es": "Buscar en la cola",
    "de": "In der Warteschlange suchen",
    "it": "Cerca nella coda",
    "ca": "Cercar a la cua",
    "eo": "Serĉi en la vico",
    "nl": "Zoeken in wachtrij",
    "el": "Αναζήτηση στην ουρά"
  },
  "catalogacao.queue.deselectAll": {
    "pt-BR": "Desmarcar tudo",
    "en": "Deselect all",
    "fr": "Tout désélectionner",
    "es": "Desmarcar todo",
    "de": "Auswahl aufheben",
    "it": "Deseleziona tutto",
    "ca": "Desmarcar-ho tot",
    "eo": "Malelekti ĉion",
    "nl": "Alles deselecteren",
    "el": "Αποεπιλογή όλων"
  },
  "catalogacao.queue.selectAllCount": {
    "pt-BR": "Selecionar tudo ({count})",
    "en": "Select all ({count})",
    "fr": "Tout sélectionner ({count})",
    "es": "Seleccionar todo ({count})",
    "de": "Alle auswählen ({count})",
    "it": "Seleziona tutto ({count})",
    "ca": "Seleccionar-ho tot ({count})",
    "eo": "Elekti ĉion ({count})",
    "nl": "Alles selecteren ({count})",
    "el": "Επιλογή όλων ({count})"
  },
  "catalogacao.queue.selectedCount": {
    "pt-BR": "{count} selecionado(s)",
    "en": "{count} selected",
    "fr": "{count} sélectionné(s)",
    "es": "{count} seleccionado(s)",
    "de": "{count} ausgewählt",
    "it": "{count} selezionat*",
    "ca": "{count} seleccionat(s)",
    "eo": "{count} elektita(j)",
    "nl": "{count} geselecteerd",
    "el": "{count} επιλεγμένα"
  },
  "catalogacao.queue.empty": {
    "pt-BR": "Nenhum rascunho ativo neste recorte.",
    "en": "No active drafts in this filter.",
    "fr": "Aucun brouillon actif dans ce filtre.",
    "es": "Ningun borrador activo en este filtro.",
    "de": "Keine aktiven Entwürfe in diesem Filter.",
    "it": "Nessuna bozza attiva in questo filtro.",
    "ca": "Cap esborrany actiu en aquest filtre.",
    "eo": "Neniu aktiva malneto en ĉi tiu filtrilo.",
    "nl": "Geen actieve concepten in dit filter.",
    "el": "Κανένα ενεργό προσχέδιο σε αυτό το φίλτρο."
  },
  "catalogacao.queue.paginationInfo": {
    "pt-BR": "{total} rascunho(s) no recorte — mostrando {showing} — página {page} de {pages}",
    "en": "{total} draft(s) in filter — showing {showing} — page {page} of {pages}",
    "fr": "{total} brouillon(s) dans le filtre — affichage de {showing} — page {page} sur {pages}",
    "es": "{total} borrador(es) en el filtro — mostrando {showing} — pagina {page} de {pages}",
    "de": "{total} Entwurf/Entwürfe im Filter — Anzeige von {showing} — Seite {page} von {pages}",
    "it": "{total} bozza/e nel filtro — visualizzazione di {showing} — pagina {page} di {pages}",
    "ca": "{total} esborrany(s) en el filtre — mostrant {showing} — pàgina {page} de {pages}",
    "eo": "{total} malneto(j) en la filtrilo — montras {showing} — paĝo {page} el {pages}",
    "nl": "{total} concept(en) in filter — toont {showing} — pagina {page} van {pages}",
    "el": "{total} προσχέδια στο φίλτρο — εμφάνιση {showing} — σελίδα {page} από {pages}"
  },
  "catalogacao.queue.prevPage": {
    "pt-BR": "← Anterior",
    "en": "← Previous",
    "fr": "← Précédent",
    "es": "← Anterior",
    "de": "← Vorherige",
    "it": "← Precedente",
    "ca": "← Anterior",
    "eo": "← Antaŭa",
    "nl": "← Vorige",
    "el": "← Προηγούμενη"
  },
  "catalogacao.queue.nextPage": {
    "pt-BR": "Próxima →",
    "en": "Next →",
    "fr": "Suivant →",
    "es": "Siguiente →",
    "de": "Nächste →",
    "it": "Successiva →",
    "ca": "Següent →",
    "eo": "Sekva →",
    "nl": "Volgende →",
    "el": "Επόμενη →"
  },
  "catalogacao.queue.trashTitle": {
    "pt-BR": "Lixeira de rascunhos",
    "en": "Draft trash",
    "fr": "Corbeille de brouillons",
    "es": "Papelera de borradores",
    "de": "Papierkorb für Entwürfe",
    "it": "Cestino delle bozze",
    "ca": "Paperera d'esborranys",
    "eo": "Malnetuja rubujeto",
    "nl": "Prullenbak voor concepten",
    "el": "Κάδος προσχεδίων"
  },
  "catalogacao.queue.trashDescription": {
    "pt-BR": "Rascunhos descartados. Você pode restaurar ou apagar definitivamente.",
    "en": "Discarded drafts. You can restore or permanently delete.",
    "fr": "Brouillons mis au rebut. Vous pouvez restaurer ou supprimer définitivement.",
    "es": "Borradores descartados. Puede restaurar o eliminar definitivamente.",
    "de": "Verworfene Entwürfe. Sie können wiederherstellen oder endgültig löschen.",
    "it": "Bozze scartate. Puoi ripristinare o eliminare definitivamente.",
    "ca": "Esborranys descartats. Podeu restaurar o eliminar definitivament.",
    "eo": "Foriĝitaj malnetoj. Vi povas reaŭdikigi aŭ definitive forigi.",
    "nl": "Verwijderde concepten. U kunt herstellen of definitief verwijderen.",
    "el": "Απορριφθέντα προσχέδια. Μπορείτε να επαναφέρετε ή να διαγράψετε οριστικά."
  },
  "catalogacao.queue.restoreSelected": {
    "pt-BR": "Restaurar selecionados ({count})",
    "en": "Restore selected ({count})",
    "fr": "Restaurer la sélection ({count})",
    "es": "Restaurar seleccionados ({count})",
    "de": "Ausgewählte wiederherstellen ({count})",
    "it": "Ripristina selezionat* ({count})",
    "ca": "Restaurar seleccionats ({count})",
    "eo": "Reaŭdikigi elektita(j)n ({count})",
    "nl": "Geselecteerde herstellen ({count})",
    "el": "Επαναφορά επιλεγμένων ({count})"
  },
  "catalogacao.queue.trashEmpty": {
    "pt-BR": "Lixeira vazia.",
    "en": "Trash is empty.",
    "fr": "La corbeille est vide.",
    "es": "Papelera vacia.",
    "de": "Papierkorb ist leer.",
    "it": "Cestino vuoto.",
    "ca": "Paperera buida.",
    "eo": "Rubujeto malplena.",
    "nl": "Prullenbak is leeg.",
    "el": "Ο κάδος είναι άδειος."
  },
  "catalogacao.queue.trashWarning": {
    "pt-BR": "Atenção: ao esvaziar a lixeira, os rascunhos descartados serão apagados de forma irreversível.",
    "en": "Warning: emptying the trash permanently deletes discarded drafts.",
    "fr": "Attention : vider la corbeille supprime définitivement les brouillons mis au rebut.",
    "es": "Atencion: al vaciar la papelera, los borradores descartados seran eliminados de forma irreversible.",
    "de": "Achtung: Beim Leeren des Papierkorbs werden verworfene Entwürfe endgültig gelöscht.",
    "it": "Attenzione: svuotando il cestino, le bozze scartate verranno eliminate in modo irreversibile.",
    "ca": "Atenció: en buidar la paperera, els esborranys descartats seran eliminats de forma irreversible.",
    "eo": "Atentu: malplenigi la rubujon definitive forigas la foriĝitajn malnetojn.",
    "nl": "Let op: bij het legen van de prullenbak worden verwijderde concepten definitief gewist.",
    "el": "Προσοχή: το άδειασμα του κάδου διαγράφει οριστικά τα απορριφθέντα προσχέδια."
  },

  // ── Catalog types & statuses ──
  "catalogacao.type.book": {
    "pt-BR": "Documento",
    "en": "Document",
    "fr": "Document",
    "es": "Documento",
    "de": "Dokument",
    "it": "Documento",
    "ca": "Document",
    "eo": "Dokumento",
    "nl": "Document",
    "el": "Έγγραφο"
  },
  "catalogacao.type.author": {
    "pt-BR": "Autoridade",
    "en": "Authority",
    "fr": "Autorité",
    "es": "Autoridad",
    "de": "Autorität",
    "it": "Autorità",
    "ca": "Autoritat",
    "eo": "Aŭtoritato",
    "nl": "Autoriteit",
    "el": "Αρχείο καθιερωμένων"
  },
  "catalogacao.type.exemplar": {
    "pt-BR": "Exemplar",
    "en": "Copy",
    "fr": "Exemplaire",
    "es": "Ejemplar",
    "de": "Exemplar",
    "it": "Esemplare",
    "ca": "Exemplar",
    "eo": "Ekzemplero",
    "nl": "Exemplaar",
    "el": "Αντίτυπο"
  },
  "catalogacao.status.draft": {
    "pt-BR": "Rascunho",
    "en": "Draft",
    "fr": "Brouillon",
    "es": "Borrador",
    "de": "Entwurf",
    "it": "Bozza",
    "ca": "Esborrany",
    "eo": "Malneto",
    "nl": "Concept",
    "el": "Προσχέδιο"
  },
  "catalogacao.status.ready": {
    "pt-BR": "Pronto",
    "en": "Ready",
    "fr": "Prêt",
    "es": "Listo",
    "de": "Bereit",
    "it": "Pronto",
    "ca": "Preparat",
    "eo": "Preta",
    "nl": "Gereed",
    "el": "Έτοιμο"
  },
  "catalogacao.status.published": {
    "pt-BR": "Publicado",
    "en": "Published",
    "fr": "Publié",
    "es": "Publicado",
    "de": "Veröffentlicht",
    "it": "Pubblicato",
    "ca": "Publicat",
    "eo": "Publikigita",
    "nl": "Gepubliceerd",
    "el": "Δημοσιευμένο"
  },
  "catalogacao.status.cancelled": {
    "pt-BR": "Descartado",
    "en": "Discarded",
    "fr": "Mis au rebut",
    "es": "Descartado",
    "de": "Verworfen",
    "it": "Scartato",
    "ca": "Descartat",
    "eo": "Foriĝita",
    "nl": "Verwijderd",
    "el": "Απορριφθέν"
  },
  "catalogacao.status.new": {
    "pt-BR": "novo",
    "en": "new",
    "fr": "nouveau",
    "es": "nuevo",
    "de": "neu",
    "it": "nuovo",
    "ca": "nou",
    "eo": "nova",
    "nl": "nieuw",
    "el": "νέο"
  },
  "catalogacao.status.retake": {
    "pt-BR": "retomada",
    "en": "update",
    "fr": "reprise",
    "es": "retomada",
    "de": "Wiederaufnahme",
    "it": "ripresa",
    "ca": "represa",
    "eo": "aŭdatigo",
    "nl": "hervatting",
    "el": "επανάληψη"
  },

  // ── Catalog panel ──
  "catalogacao.catalog.title": {
    "pt-BR": "Catálogo(s) já publicado(s)",
    "en": "Published catalog(s)",
    "fr": "Catalogue(s) publié(s)",
    "es": "Catalogo(s) publicado(s)",
    "de": "Veröffentlichte(r) Katalog(e)",
    "it": "Catalogo/hi pubblicat*",
    "ca": "Catàleg(s) publicat(s)",
    "eo": "Publikigita(j) katalogo(j)",
    "nl": "Gepubliceerde catalogus(sen)",
    "el": "Δημοσιευμένος(οι) κατάλογος(οι)"
  },
  "catalogacao.catalog.description": {
    "pt-BR": "Consulte documentos, autoridades e exemplares já publicados. Retome para editar ou descarte do catálogo.",
    "en": "Browse published documents, authorities and copies. Resume to edit or discard from catalog.",
    "fr": "Consultez les documents, autorités et exemplaires publiés. Reprenez pour modifier ou mettre au rebut.",
    "es": "Consulte documentos, autoridades y ejemplares publicados. Retome para editar o descarte del catalogo.",
    "de": "Durchsuchen Sie veröffentlichte Dokumente, Autoritäten und Exemplare. Wiederaufnehmen zum Bearbeiten oder aus dem Katalog verwerfen.",
    "it": "Consulta documenti, autorità e esemplari pubblicati. Riprendi per modificare o scarta dal catalogo.",
    "ca": "Consulteu documents, autoritats i exemplars publicats. Repreneu per editar o descarteu del catàleg.",
    "eo": "Konsultu dokumentojn, aŭtorecojn kaj ekzemplerojn jam publikigitajn. Reprenu por redakti aŭ forigu el la katalogo.",
    "nl": "Bekijk gepubliceerde documenten, autoriteiten en exemplaren. Hervat om te bewerken of verwijder uit de catalogus.",
    "el": "Περιηγηθείτε δημοσιευμένα έγγραφα, αρχεία και αντίτυπα."
  },
  "catalogacao.catalog.refreshTooltip": {
    "pt-BR": "Recompila as listas públicas do catálogo a partir das tabelas publicadas.",
    "en": "Recompiles the public catalog lists from published tables.",
    "fr": "Recompile les listes publiques du catalogue à partir des tables publiées.",
    "es": "Recompila las listas publicas del catalogo a partir de las tablas publicadas.",
    "de": "Kompiliert die öffentlichen Kataloglisten aus den veröffentlichten Tabellen neu.",
    "it": "Ricompila le liste pubbliche del catalogo dalle tabelle pubblicate.",
    "ca": "Recompila les llistes públiques del catàleg a partir de les taules publicades.",
    "eo": "Rekompilis la publikajn kataloglistojn el la publikigitaj tabeloj.",
    "nl": "Hercompileert de openbare cataloguslijsten uit de gepubliceerde tabellen.",
    "el": "Επανασυντάσσει τις δημόσιες λίστες καταλόγου."
  },
  "catalogacao.catalog.refresh": {
    "pt-BR": "↻ Atualizar catálogo público",
    "en": "↻ Refresh public catalog",
    "fr": "↻ Actualiser le catalogue public",
    "es": "↻ Actualizar catalogo publico",
    "de": "↻ Öffentlichen Katalog aktualisieren",
    "it": "↻ Aggiorna catalogo pubblico",
    "ca": "↻ Actualitzar catàleg públic",
    "eo": "↻ Aŭdatigi publikan katalogon",
    "nl": "↻ Openbare catalogus bijwerken",
    "el": "↻ Ανανέωση δημόσιου καταλόγου"
  },
  "catalogacao.catalog.refreshBusy": {
    "pt-BR": "Atualização já em curso — tente de novo em instantes.",
    "en": "Refresh already in progress — try again shortly.",
    "fr": "Actualisation déjà en cours — réessayez dans un instant.",
    "es": "Actualizacion ya en curso — intente de nuevo en unos instantes.",
    "de": "Aktualisierung läuft bereits — versuchen Sie es gleich erneut.",
    "it": "Aggiornamento già in corso — riprova tra un momento.",
    "ca": "Actualització ja en curs — torneu a provar en un moment.",
    "eo": "Aŭdatigo jam okazas — reprovu post momento.",
    "nl": "Bijwerken is al bezig — probeer het zo opnieuw.",
    "el": "Η ανανέωση είναι ήδη σε εξέλιξη — δοκιμάστε ξανά σε λίγο."
  },
  "catalogacao.catalog.refreshDone": {
    "pt-BR": "Catálogo público atualizado.",
    "en": "Public catalog updated.",
    "fr": "Catalogue public actualisé.",
    "es": "Catalogo publico actualizado.",
    "de": "Öffentlicher Katalog aktualisiert.",
    "it": "Catalogo pubblico aggiornato.",
    "ca": "Catàleg públic actualitzat.",
    "eo": "Publika katalogo aŭdatigita.",
    "nl": "Openbare catalogus bijgewerkt.",
    "el": "Ο δημόσιος κατάλογος ενημερώθηκε."
  },
  "catalogacao.catalog.refreshError": {
    "pt-BR": "Erro ao atualizar: {message}",
    "en": "Error updating: {message}",
    "fr": "Erreur lors de l’actualisation : {message}",
    "es": "Error al actualizar: {message}",
    "de": "Fehler beim Aktualisieren: {message}",
    "it": "Errore durante l'aggiornamento: {message}",
    "ca": "Error en actualitzar: {message}",
    "eo": "Eraro dum aŭdatigo: {message}",
    "nl": "Fout bij bijwerken: {message}",
    "el": "Σφάλμα ενημέρωσης: {message}"
  },
  "catalogacao.catalog.retakeConfirm": {
    "pt-BR": "Criar um rascunho de retomada a partir deste {type} publicado?",
    "en": "Create an update draft from this published {type}?",
    "fr": "Créer un brouillon de reprise à partir de ce {type} publié ?",
    "es": "Crear un borrador de retomada a partir de este {type} publicado?",
    "de": "Einen Wiederaufnahme-Entwurf aus diesem veröffentlichten {type} erstellen?",
    "it": "Creare una bozza di ripresa da questo {type} pubblicato?",
    "ca": "Crear un esborrany de represa a partir d'aquest {type} publicat?",
    "eo": "Ĉu krei reprena-malneton el ĉi tiu publikigita {type}?",
    "nl": "Een hervatconcept maken van deze gepubliceerde {type}?",
    "el": "Δημιουργία προσχεδίου επανάληψης από αυτό το δημοσιευμένο {type};"
  },
  "catalogacao.catalog.retakeCreated": {
    "pt-BR": "Rascunho de retomada criado (ID {id}) — abrindo no editor…",
    "en": "Update draft created (ID {id}) — opening in editor…",
    "fr": "Brouillon de reprise créé (ID {id}) — ouverture dans l’éditeur…",
    "es": "Borrador de retomada creado (ID {id}) — abriendo en el editor…",
    "de": "Wiederaufnahme-Entwurf erstellt (ID {id}) — wird im Editor geöffnet…",
    "it": "Bozza di ripresa creata (ID {id}) — apertura nell'editor…",
    "ca": "Esborrany de represa creat (ID {id}) — obrint a l'editor…",
    "eo": "Reprena malneto kreita (ID {id}) — malfermanta en la redaktilo…",
    "nl": "Hervatconcept aangemaakt (ID {id}) — wordt geopend in de editor…",
    "el": "Προσχέδιο επανάληψης δημιουργήθηκε (ID {id}) — άνοιγμα…"
  },
  "catalogacao.catalog.retakeCreatedNoEdit": {
    "pt-BR": "Rascunho de retomada criado (ID {id}). Abra a aba correspondente para editar.",
    "en": "Update draft created (ID {id}). Open the corresponding tab to edit.",
    "fr": "Brouillon de reprise créé (ID {id}). Ouvrez l’onglet correspondant pour modifier.",
    "es": "Borrador de retomada creado (ID {id}). Abra la pestana correspondiente para editar.",
    "de": "Wiederaufnahme-Entwurf erstellt (ID {id}). Öffnen Sie den entsprechenden Tab zum Bearbeiten.",
    "it": "Bozza di ripresa creata (ID {id}). Apri la scheda corrispondente per modificare.",
    "ca": "Esborrany de represa creat (ID {id}). Obriu la pestanya corresponent per editar.",
    "eo": "Reprena malneto kreita (ID {id}). Malfermu la respondan langeton por redakti.",
    "nl": "Hervatconcept aangemaakt (ID {id}). Open het bijbehorende tabblad om te bewerken.",
    "el": "Προσχέδιο επανάληψης δημιουργήθηκε (ID {id}). Ανοίξτε την αντίστοιχη καρτέλα."
  },
  "catalogacao.catalog.discardConfirm": {
    "pt-BR": "Descartar \"{label}\" do catálogo publicado?\n\nEsta ação é irreversível.",
    "en": "Discard \"{label}\" from the published catalog?\n\nThis action is irreversible.",
    "fr": "Mettre « {label} » au rebut du catalogue publié ?\n\nCette action est irréversible.",
    "es": "Descartar \"{label}\" del catalogo publicado?\n\nEsta accion es irreversible.",
    "de": "„{label}“ aus dem veröffentlichten Katalog verwerfen?\n\nDiese Aktion ist unwiderruflich.",
    "it": "Scartare \"{label}\" dal catalogo pubblicato?\n\nQuesta azione è irreversibile.",
    "ca": "Descartar \"{label}\" del catàleg publicat?\n\nAquesta acció és irreversible.",
    "eo": "Ĉu foriĝi \"{label}\" el la publikigita katalogo?\n\nĈi tiu ago estas neinversigebla.",
    "nl": "\"{label}\" uit de gepubliceerde catalogus verwijderen?\n\nDeze actie is onomkeerbaar.",
    "el": "Απόρριψη \"{label}\" από τον δημοσιευμένο κατάλογο;\n\nΑυτή η ενέργεια είναι μη αναστρέψιμη."
  },
  "catalogacao.catalog.discardDone": {
    "pt-BR": "\"{label}\" descartado do catálogo.",
    "en": "\"{label}\" discarded from catalog.",
    "fr": "« {label} » mis au rebut du catalogue.",
    "es": "\"{label}\" descartado del catalogo.",
    "de": "„{label}“ aus dem Katalog verworfen.",
    "it": "\"{label}\" scartato dal catalogo.",
    "ca": "\"{label}\" descartat del catàleg.",
    "eo": "\"{label}\" foriĝita el la katalogo.",
    "nl": "\"{label}\" verwijderd uit de catalogus.",
    "el": "Το \"{label}\" απορρίφθηκε από τον κατάλογο."
  },
  "catalogacao.catalog.discardError": {
    "pt-BR": "Erro ao descartar: {message}",
    "en": "Error discarding: {message}",
    "fr": "Erreur lors de la mise au rebut : {message}",
    "es": "Error al descartar: {message}",
    "de": "Fehler beim Verwerfen: {message}",
    "it": "Errore durante l'eliminazione: {message}",
    "ca": "Error en descartar: {message}",
    "eo": "Eraro dum foriĝo: {message}",
    "nl": "Fout bij verwijderen: {message}",
    "el": "Σφάλμα απόρριψης: {message}"
  },
  "catalogacao.catalog.documentsTab": {
    "pt-BR": "Documentos ({count})",
    "en": "Documents ({count})",
    "fr": "Documents ({count})",
    "es": "Documentos ({count})",
    "de": "Dokumente ({count})",
    "it": "Documenti ({count})",
    "ca": "Documents ({count})",
    "eo": "Dokumentoj ({count})",
    "nl": "Documenten ({count})",
    "el": "Έγγραφα ({count})"
  },
  "catalogacao.catalog.authoritiesTab": {
    "pt-BR": "Autoridades ({count})",
    "en": "Authorities ({count})",
    "fr": "Autorités ({count})",
    "es": "Autoridades ({count})",
    "de": "Autoritäten ({count})",
    "it": "Autorità ({count})",
    "ca": "Autoritats ({count})",
    "eo": "Aŭtoritatoj ({count})",
    "nl": "Autoriteiten ({count})",
    "el": "Αρχεία καθιερωμένων ({count})"
  },
  "catalogacao.catalog.exemplarsTab": {
    "pt-BR": "Exemplares ({count})",
    "en": "Copies ({count})",
    "fr": "Exemplaires ({count})",
    "es": "Ejemplares ({count})",
    "de": "Exemplare ({count})",
    "it": "Esemplari ({count})",
    "ca": "Exemplars ({count})",
    "eo": "Ekzempleroj ({count})",
    "nl": "Exemplaren ({count})",
    "el": "Αντίτυπα ({count})"
  },
  "catalogacao.catalog.noItems": {
    "pt-BR": "Nenhum item encontrado.",
    "en": "No items found.",
    "fr": "Aucun élément trouvé.",
    "es": "Ningun item encontrado.",
    "de": "Keine Elemente gefunden.",
    "it": "Nessun elemento trovato.",
    "ca": "Cap element trobat.",
    "eo": "Neniu ero trovita.",
    "nl": "Geen items gevonden.",
    "el": "Δεν βρέθηκαν στοιχεία."
  },
  "catalogacao.catalog.retake": {
    "pt-BR": "Retomar",
    "en": "Resume",
    "fr": "Reprendre",
    "es": "Retomar",
    "de": "Wiederaufnehmen",
    "it": "Riprendi",
    "ca": "Reprendre",
    "eo": "Repreni",
    "nl": "Hervatten",
    "el": "Επανάληψη"
  },
  "catalogacao.catalog.discard": {
    "pt-BR": "Descartar",
    "en": "Discard",
    "fr": "Mettre au rebut",
    "es": "Descartar",
    "de": "Verwerfen",
    "it": "Scarta",
    "ca": "Descartar",
    "eo": "Foriĝi",
    "nl": "Verwijderen",
    "el": "Απόρριψη"
  },
  "catalogacao.catalog.page": {
    "pt-BR": "Página",
    "en": "Page",
    "fr": "Page",
    "es": "Pagina",
    "de": "Seite",
    "it": "Pagina",
    "ca": "Pàgina",
    "eo": "Paĝo",
    "nl": "Pagina",
    "el": "Σελίδα"
  },
  "catalogacao.catalog.prevPage": {
    "pt-BR": "← Anterior",
    "en": "← Previous",
    "fr": "← Précédent",
    "es": "← Anterior",
    "de": "← Vorherige",
    "it": "← Precedente",
    "ca": "← Anterior",
    "eo": "← Antaŭa",
    "nl": "← Vorige",
    "el": "← Προηγούμενη"
  },
  "catalogacao.catalog.nextPage": {
    "pt-BR": "Próxima →",
    "en": "Next →",
    "fr": "Suivant →",
    "es": "Siguiente →",
    "de": "Nächste →",
    "it": "Successiva →",
    "ca": "Següent →",
    "eo": "Sekva →",
    "nl": "Volgende →",
    "el": "Επόμενη →"
  },
  "catalogacao.catalog.searchBook": {
    "pt-BR": "Título, autor, ISBN, referência…",
    "en": "Title, author, ISBN, reference…",
    "fr": "Titre, auteur·rice, ISBN, référence…",
    "es": "Titulo, autore, ISBN, referencia…",
    "de": "Titel, Autor*in, ISBN, Referenz…",
    "it": "Titolo, autor*, ISBN, riferimento…",
    "ca": "Títol, autor-a-e, ISBN, referència…",
    "eo": "Titolo, aŭtor-in-o, ISBN, referenco…",
    "nl": "Titel, auteur, ISBN, referentie…",
    "el": "Τίτλος, συγγραφέας, ISBN, αναφορά…"
  },
  "catalogacao.catalog.searchAuthor": {
    "pt-BR": "Nome preferido, nome para ordenação…",
    "en": "Preferred name, sort name…",
    "fr": "Nom préféré, nom de tri…",
    "es": "Nombre preferido, nombre de ordenacion…",
    "de": "Bevorzugter Name, Sortiername…",
    "it": "Nome preferito, nome di ordinamento…",
    "ca": "Nom preferit, nom d'ordenació…",
    "eo": "Preferata nomo, ordiga nomo…",
    "nl": "Voorkeursnaam, sorteernaam…",
    "el": "Προτιμώμενο όνομα, όνομα ταξινόμησης…"
  },
  "catalogacao.catalog.searchExemplar": {
    "pt-BR": "Tombo, referência, título…",
    "en": "Accession no., reference, title…",
    "fr": "Cote, référence, titre…",
    "es": "Registro, referencia, titulo…",
    "de": "Inventarnr., Referenz, Titel…",
    "it": "Collocazione, riferimento, titolo…",
    "ca": "Registre, referència, títol…",
    "eo": "Numero, referenco, titolo…",
    "nl": "Inventarisnr., referentie, titel…",
    "el": "Αριθμός, αναφορά, τίτλος…"
  }
};

// ── Merger logic ──────────────────────────────────────────────────────────
const LOCALE_MAP = {
  'pt-BR': 'pt-BR.json',
  'en': 'en.json',
  'fr': 'fr.json',
  'es': 'es.json',
  'de': 'de.json',
  'it': 'it.json',
  'ca': 'ca.json',
  'eo': 'eo.json',
  'nl': 'nl.json',
  'el': 'el.json',
};

let totalAdded = 0;
let totalSkipped = 0;

for (const [localeCode, filename] of Object.entries(LOCALE_MAP)) {
  const filepath = path.join(LOCALES_DIR, filename);
  const data = JSON.parse(fs.readFileSync(filepath, 'utf8'));

  let added = 0;
  let skipped = 0;

  for (const [key, translations] of Object.entries(NEW_KEYS)) {
    if (data[key] !== undefined) {
      skipped++;
      continue;
    }
    const value = translations[localeCode];
    if (!value) {
      console.error(`MISSING translation for ${key} in ${localeCode}`);
      process.exit(1);
    }
    data[key] = value;
    added++;
  }

  // Sort keys alphabetically
  const sorted = {};
  Object.keys(data).sort().forEach(k => { sorted[k] = data[k]; });

  // Write back with 2-space indent, no BOM, trailing newline
  fs.writeFileSync(filepath, JSON.stringify(sorted, null, 2) + '\n', 'utf8');

  console.log(`${filename}: +${added} keys (${skipped} already existed)`);
  totalAdded += added;
  totalSkipped += skipped;
}

console.log(`\nTotal: +${totalAdded} keys added, ${totalSkipped} skipped (already existed)`);
console.log(`New key count per locale: check with npm test`);
