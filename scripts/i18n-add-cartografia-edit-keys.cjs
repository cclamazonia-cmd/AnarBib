#!/usr/bin/env node
/* eslint-disable */
// ============================================================================
// i18n-add-cartografia-edit-keys.cjs
// Auteur : AnarBib · Session : Carte réseau 10 locales
// Clés de l'UI d'édition des fiches cartographiques (Phase 3, MAP-D) + libellés
// statut réseau + lien de nav. Parité 10 locales, idempotent, UTF-8 sans BOM.
// Usage : node scripts/i18n-add-cartografia-edit-keys.cjs
// ============================================================================
const fs = require('node:fs');
const path = require('node:path');
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const T = {
  'federacao.carte.edit': { fr:'Éditer', 'pt-BR':'Editar', es:'Editar', it:'Modifica', de:'Bearbeiten', en:'Edit', ca:'Edita', eo:'Redakti', nl:'Bewerken', el:'Επεξεργασία' },
  'federacao.carte.edit.title': { fr:'Éditer la fiche', 'pt-BR':'Editar a ficha', es:'Editar la ficha', it:'Modifica la scheda', de:'Eintrag bearbeiten', en:'Edit entry', ca:'Edita la fitxa', eo:'Redakti la slipon', nl:'Vermelding bewerken', el:'Επεξεργασία καταχώρισης' },
  'federacao.carte.edit.localeNote': {
    fr:"Le nom et les notes s'éditent dans votre langue d'affichage.",
    'pt-BR':'O nome e as notas são editados no seu idioma de exibição.',
    es:'El nombre y las notas se editan en tu idioma de visualización.',
    it:'Nome e note si modificano nella tua lingua di visualizzazione.',
    de:'Name und Notizen werden in deiner Anzeigesprache bearbeitet.',
    en:'Name and notes are edited in your display language.',
    ca:"El nom i les notes s'editen en la teva llengua de visualització.",
    eo:'Nomo kaj notoj estas redaktataj en via vidlingvo.',
    nl:'Naam en notities worden in je weergavetaal bewerkt.',
    el:'Το όνομα και οι σημειώσεις επεξεργάζονται στη γλώσσα εμφάνισής σας.' },
  'federacao.carte.edit.name': { fr:'Nom', 'pt-BR':'Nome', es:'Nombre', it:'Nome', de:'Name', en:'Name', ca:'Nom', eo:'Nomo', nl:'Naam', el:'Όνομα' },
  'federacao.carte.edit.city': { fr:'Ville', 'pt-BR':'Cidade', es:'Ciudad', it:'Città', de:'Stadt', en:'City', ca:'Ciutat', eo:'Urbo', nl:'Stad', el:'Πόλη' },
  'federacao.carte.edit.country': { fr:'Pays', 'pt-BR':'País', es:'País', it:'Paese', de:'Land', en:'Country', ca:'País', eo:'Lando', nl:'Land', el:'Χώρα' },
  'federacao.carte.edit.notes': { fr:'Notes', 'pt-BR':'Notas', es:'Notas', it:'Note', de:'Notizen', en:'Notes', ca:'Notes', eo:'Notoj', nl:'Notities', el:'Σημειώσεις' },
  'federacao.carte.edit.langs': { fr:'Langues du fonds', 'pt-BR':'Idiomas do acervo', es:'Idiomas del fondo', it:'Lingue del fondo', de:'Bestandssprachen', en:'Collection languages', ca:'Llengües del fons', eo:'Lingvoj de la kolekto', nl:'Collectietalen', el:'Γλώσσες συλλογής' },
  'federacao.carte.edit.site': { fr:'Site web', 'pt-BR':'Site', es:'Sitio web', it:'Sito web', de:'Website', en:'Website', ca:'Lloc web', eo:'Retejo', nl:'Website', el:'Ιστότοπος' },
  'federacao.carte.edit.email': { fr:'E-mail', 'pt-BR':'E-mail', es:'Correo electrónico', it:'E-mail', de:'E-Mail', en:'Email', ca:'Correu electrònic', eo:'Retpoŝto', nl:'E-mail', el:'E-mail' },
  'federacao.carte.edit.tel': { fr:'Téléphone', 'pt-BR':'Telefone', es:'Teléfono', it:'Telefono', de:'Telefon', en:'Phone', ca:'Telèfon', eo:'Telefono', nl:'Telefoon', el:'Τηλέφωνο' },
  'federacao.carte.edit.address': { fr:'Adresse', 'pt-BR':'Endereço', es:'Dirección', it:'Indirizzo', de:'Adresse', en:'Address', ca:'Adreça', eo:'Adreso', nl:'Adres', el:'Διεύθυνση' },
  'federacao.carte.edit.public': { fr:'Visible sur la carte publique', 'pt-BR':'Visível no mapa público', es:'Visible en el mapa público', it:'Visibile sulla mappa pubblica', de:'Auf der öffentlichen Karte sichtbar', en:'Visible on the public map', ca:'Visible al mapa públic', eo:'Videbla sur la publika mapo', nl:'Zichtbaar op de openbare kaart', el:'Ορατό στον δημόσιο χάρτη' },
  'federacao.carte.edit.contactPublic': { fr:'Coordonnées visibles publiquement', 'pt-BR':'Contatos visíveis publicamente', es:'Datos de contacto visibles públicamente', it:'Contatti visibili pubblicamente', de:'Kontaktdaten öffentlich sichtbar', en:'Contact details shown publicly', ca:'Dades de contacte visibles públicament', eo:'Kontaktinformoj publike videblaj', nl:'Contactgegevens openbaar zichtbaar', el:'Στοιχεία επικοινωνίας δημόσια ορατά' },
  'federacao.carte.edit.adminSection': { fr:'Coordination (champs partagés)', 'pt-BR':'Coordenação (campos compartilhados)', es:'Coordinación (campos compartidos)', it:'Coordinamento (campi condivisi)', de:'Koordination (geteilte Felder)', en:'Coordination (shared fields)', ca:'Coordinació (camps compartits)', eo:'Kunordigo (komunaj kampoj)', nl:'Coördinatie (gedeelde velden)', el:'Συντονισμός (κοινά πεδία)' },
  'federacao.carte.edit.category': { fr:'Catégorie', 'pt-BR':'Categoria', es:'Categoría', it:'Categoria', de:'Kategorie', en:'Category', ca:'Categoria', eo:'Kategorio', nl:'Categorie', el:'Κατηγορία' },
  'federacao.carte.edit.status': { fr:'Statut dans le réseau', 'pt-BR':'Status na rede', es:'Estatus en la red', it:'Stato nella rete', de:'Status im Netzwerk', en:'Network status', ca:'Estatus a la xarxa', eo:'Statuso en la reto', nl:'Status in het netwerk', el:'Κατάσταση στο δίκτυο' },
  'federacao.carte.edit.save': { fr:'Enregistrer', 'pt-BR':'Salvar', es:'Guardar', it:'Salva', de:'Speichern', en:'Save', ca:'Desa', eo:'Konservi', nl:'Opslaan', el:'Αποθήκευση' },
  'federacao.carte.edit.cancel': { fr:'Annuler', 'pt-BR':'Cancelar', es:'Cancelar', it:'Annulla', de:'Abbrechen', en:'Cancel', ca:'Cancel·la', eo:'Nuligi', nl:'Annuleren', el:'Άκυρο' },
  'federacao.carte.edit.saved': { fr:'Fiche mise à jour', 'pt-BR':'Ficha atualizada', es:'Ficha actualizada', it:'Scheda aggiornata', de:'Eintrag aktualisiert', en:'Entry updated', ca:'Fitxa actualitzada', eo:'Slipo ĝisdatigita', nl:'Vermelding bijgewerkt', el:'Η καταχώριση ενημερώθηκε' },
  'federacao.carte.edit.error': { fr:"Échec de l'enregistrement", 'pt-BR':'Falha ao salvar', es:'Error al guardar', it:'Salvataggio non riuscito', de:'Speichern fehlgeschlagen', en:'Save failed', ca:'Error en desar', eo:'Konservado malsukcesis', nl:'Opslaan mislukt', el:'Αποτυχία αποθήκευσης' },
  'federacao.carte.statut.membre': { fr:'Membre', 'pt-BR':'Membro', es:'Miembro', it:'Membro', de:'Mitglied', en:'Member', ca:'Membre', eo:'Membro', nl:'Lid', el:'Μέλος' },
  'federacao.carte.statut.partenaire': { fr:'Partenaire', 'pt-BR':'Parceiro', es:'Socio', it:'Partner', de:'Partner', en:'Partner', ca:'Soci', eo:'Partnero', nl:'Partner', el:'Εταίρος' },
  'federacao.carte.statut.cible': { fr:'Cible', 'pt-BR':'Alvo', es:'Objetivo', it:'Obiettivo', de:'Ziel', en:'Target', ca:'Objectiu', eo:'Celo', nl:'Doelwit', el:'Στόχος' },
  'cartografia.nav': { fr:'Carte du réseau', 'pt-BR':'Mapa da rede', es:'Mapa de la red', it:'Mappa della rete', de:'Netzwerkkarte', en:'Network map', ca:'Mapa de la xarxa', eo:'Reto-mapo', nl:'Netwerkkaart', el:'Χάρτης δικτύου' },
};

let total = 0;
for (const file of fs.readdirSync(DIR).filter((f) => f.endsWith('.json'))) {
  const loc = file.replace(/\.json$/, '');
  const p = path.join(DIR, file);
  const obj = JSON.parse(fs.readFileSync(p, 'utf8'));
  let added = 0;
  for (const [key, byLoc] of Object.entries(T)) {
    const val = byLoc[loc];
    if (val == null) { console.warn(`[warn] ${key} manque pour ${loc}`); continue; }
    if (!(key in obj)) { obj[key] = val; added++; }
  }
  if (added) { fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n', 'utf8'); total += added; }
  console.log(`${file.padEnd(11)} +${added}`);
}
console.log(`Total : ${total}`);
