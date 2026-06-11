/**
 * Ajoute les clés biblioteca.extPartner.* (section « partenaire externe de dépôt »
 * de l'onglet Relações, inc. B2) aux 10 locales. Insertion TEXTUELLE additive.
 * Run : node scripts/merge-biblioteca-ext-partner-keys.cjs
 */
const fs = require('fs');
const path = require('path');
const DIR = path.resolve(__dirname, '../src/i18n/locales');
const FILES = { 'pt-BR': 'pt-BR.json', fr: 'fr.json', es: 'es.json', en: 'en.json', it: 'it.json', de: 'de.json', ca: 'ca.json', eo: 'eo.json', nl: 'nl.json', el: 'el.json' };

const K = (title, hint, name, namePlaceholder, country, baseUrl, notes, dupHint, importAuth, register, registering, created, linked, error) => ({
  'biblioteca.extPartner.title': title,
  'biblioteca.extPartner.hint': hint,
  'biblioteca.extPartner.name': name,
  'biblioteca.extPartner.namePlaceholder': namePlaceholder,
  'biblioteca.extPartner.country': country,
  'biblioteca.extPartner.baseUrl': baseUrl,
  'biblioteca.extPartner.notes': notes,
  'biblioteca.extPartner.dupHint': dupHint,
  'biblioteca.extPartner.importAuth': importAuth,
  'biblioteca.extPartner.register': register,
  'biblioteca.extPartner.registering': registering,
  'biblioteca.extPartner.created': created,
  'biblioteca.extPartner.linked': linked,
  'biblioteca.extPartner.error': error,
});

const KEYS = {
  'pt-BR': K("Parceiro externo de depósito", "Registre um coletivo externo (que entregou seu catálogo em arquivo, ex. export Zotero). Será criado como entidade parceira e ficará disponível como fonte na importação.", "Nome do parceiro", "Ex.: CIRA Marseille", "País (ISO-2)", "URL do catálogo (opcional)", "Notas (opcional)", "Parceiros semelhantes já registrados — verifique antes de criar um duplicado:", "Autoriza a importação de dados deste parceiro", "Registrar o parceiro", "Registrando…", "Parceiro «{name}» criado e disponível na importação.", "Parceiro «{name}» já existia — fonte de depósito vinculada.", "Erro ao registrar o parceiro."),
  fr: K("Partenaire externe de dépôt", "Enregistrez un collectif externe (qui a fourni son catalogue en fichier, ex. export Zotero). Il sera créé comme entité partenaire et deviendra une source disponible à l’import.", "Nom du partenaire", "Ex. : CIRA Marseille", "Pays (ISO-2)", "URL du catalogue (optionnel)", "Notes (optionnel)", "Partenaires similaires déjà enregistrés — vérifiez avant de créer un doublon :", "Autorise l’import de données de ce partenaire", "Enregistrer le partenaire", "Enregistrement…", "Partenaire « {name} » créé et disponible à l’import.", "Partenaire « {name} » déjà existant — source de dépôt liée.", "Erreur lors de l’enregistrement du partenaire."),
  es: K("Socio externo de depósito", "Registre un colectivo externo (que entregó su catálogo en archivo, p. ej. exportación Zotero). Se creará como entidad asociada y estará disponible como fuente en la importación.", "Nombre del socio", "Ej.: CIRA Marseille", "País (ISO-2)", "URL del catálogo (opcional)", "Notas (opcional)", "Socios similares ya registrados — verifique antes de crear un duplicado:", "Autoriza la importación de datos de este socio", "Registrar el socio", "Registrando…", "Socio «{name}» creado y disponible en la importación.", "Socio «{name}» ya existía — fuente de depósito vinculada.", "Error al registrar el socio."),
  en: K("External deposit partner", "Register an external collective (who handed over their catalog as a file, e.g. a Zotero export). It will be created as a partner entity and become an available source at import.", "Partner name", "E.g. CIRA Marseille", "Country (ISO-2)", "Catalog URL (optional)", "Notes (optional)", "Similar partners already registered — check before creating a duplicate:", "Authorizes importing data from this partner", "Register the partner", "Registering…", "Partner “{name}” created and available at import.", "Partner “{name}” already existed — deposit source linked.", "Error registering the partner."),
  it: K("Partner esterno di deposito", "Registra un collettivo esterno (che ha fornito il suo catalogo come file, es. esportazione Zotero). Sarà creato come entità partner e diventerà una fonte disponibile all’importazione.", "Nome del partner", "Es.: CIRA Marseille", "Paese (ISO-2)", "URL del catalogo (opzionale)", "Note (opzionale)", "Partner simili già registrati — verifica prima di creare un duplicato:", "Autorizza l’importazione dei dati di questo partner", "Registra il partner", "Registrazione…", "Partner «{name}» creato e disponibile all’importazione.", "Partner «{name}» già esistente — fonte di deposito collegata.", "Errore nella registrazione del partner."),
  de: K("Externer Depot-Partner", "Registriere ein externes Kollektiv (das seinen Katalog als Datei übergeben hat, z. B. Zotero-Export). Es wird als Partner-Entität angelegt und steht beim Import als Quelle zur Verfügung.", "Partnername", "Z. B. CIRA Marseille", "Land (ISO-2)", "Katalog-URL (optional)", "Notizen (optional)", "Ähnliche Partner bereits registriert — vor dem Anlegen eines Duplikats prüfen:", "Erlaubt den Datenimport von diesem Partner", "Partner registrieren", "Wird registriert…", "Partner „{name}“ angelegt und beim Import verfügbar.", "Partner „{name}“ existierte bereits — Depot-Quelle verknüpft.", "Fehler beim Registrieren des Partners."),
  ca: K("Soci extern de dipòsit", "Registreu un col·lectiu extern (que ha lliurat el seu catàleg en fitxer, p. ex. exportació Zotero). Es crearà com a entitat sòcia i estarà disponible com a font a la importació.", "Nom del soci", "Ex.: CIRA Marseille", "País (ISO-2)", "URL del catàleg (opcional)", "Notes (opcional)", "Socis similars ja registrats — verifiqueu abans de crear un duplicat:", "Autoritza la importació de dades d’aquest soci", "Registra el soci", "S’està registrant…", "Soci «{name}» creat i disponible a la importació.", "Soci «{name}» ja existia — font de dipòsit vinculada.", "Error en registrar el soci."),
  eo: K("Ekstera deponeja partnero", "Registru eksteran kolektivon (kiu transdonis sian katalogon kiel dosieron, ekz. Zotero-eksporto). Ĝi estos kreita kiel partnera ento kaj fariĝos disponebla fonto ĉe importo.", "Nomo de la partnero", "Ekz.: CIRA Marseille", "Lando (ISO-2)", "URL de la katalogo (nedeviga)", "Notoj (nedeviga)", "Similaj partneroj jam registritaj — kontrolu antaŭ ol krei duplikaton:", "Permesas la importon de datumoj de ĉi tiu partnero", "Registri la partneron", "Registrado…", "Partnero «{name}» kreita kaj disponebla ĉe importo.", "Partnero «{name}» jam ekzistis — deponeja fonto ligita.", "Eraro dum registrado de la partnero."),
  nl: K("Externe depotpartner", "Registreer een extern collectief (dat zijn catalogus als bestand heeft aangeleverd, bv. een Zotero-export). Het wordt aangemaakt als partnerentiteit en komt beschikbaar als bron bij het importeren.", "Naam van de partner", "Bijv. CIRA Marseille", "Land (ISO-2)", "Catalogus-URL (optioneel)", "Notities (optioneel)", "Vergelijkbare partners al geregistreerd — controleer voordat je een duplicaat aanmaakt:", "Staat het importeren van gegevens van deze partner toe", "Partner registreren", "Bezig met registreren…", "Partner ‘{name}’ aangemaakt en beschikbaar bij het importeren.", "Partner ‘{name}’ bestond al — depotbron gekoppeld.", "Fout bij het registreren van de partner."),
  el: K("Εξωτερικός εταίρος κατάθεσης", "Καταχωρίστε ένα εξωτερικό συλλογικό σχήμα (που παρέδωσε τον κατάλογό του ως αρχείο, π.χ. εξαγωγή Zotero). Θα δημιουργηθεί ως οντότητα εταίρου και θα γίνει διαθέσιμη πηγή κατά την εισαγωγή.", "Όνομα εταίρου", "Π.χ. CIRA Marseille", "Χώρα (ISO-2)", "URL καταλόγου (προαιρετικό)", "Σημειώσεις (προαιρετικό)", "Παρόμοιοι εταίροι ήδη καταχωρισμένοι — ελέγξτε πριν δημιουργήσετε διπλότυπο:", "Επιτρέπει την εισαγωγή δεδομένων από αυτόν τον εταίρο", "Καταχώριση εταίρου", "Καταχώριση…", "Ο εταίρος «{name}» δημιουργήθηκε και είναι διαθέσιμος στην εισαγωγή.", "Ο εταίρος «{name}» υπήρχε ήδη — η πηγή κατάθεσης συνδέθηκε.", "Σφάλμα κατά την καταχώριση του εταίρου."),
};

let total = 0;
for (const [loc, file] of Object.entries(FILES)) {
  const p = path.join(DIR, file);
  let txt = fs.readFileSync(p, 'utf8');
  const toAdd = Object.entries(KEYS[loc]).filter(([k]) => !txt.includes('"' + k + '"'));
  if (toAdd.length) {
    const ins = toAdd.map(([k, v]) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(v)).join(',\n');
    const i = txt.lastIndexOf('}');
    txt = txt.slice(0, i).replace(/\s*,?\s*$/, '') + ',\n' + ins + '\n' + txt.slice(i);
    fs.writeFileSync(p, txt, 'utf8');
  }
  JSON.parse(fs.readFileSync(p, 'utf8'));
  console.log(loc.padEnd(6), '+' + toAdd.length);
  total += toAdd.length;
}
console.log('\nTotal :', total);
