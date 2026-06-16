/* ===========================================================================
 * i18n-add-subject-governance.cjs
 * Onglet « Matière » + panneau de coordination matière (thésaurus v1 étape 2c).
 * 9 clés × 10 locales. Idempotent (sentinelle catalogacao.tab.materia).
 * Session : Fédération — Communs & Entraide
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'catalogacao.tab.materia';

const K = [
  'catalogacao.tab.materia',
  'catalogacao.subjectGov.title',
  'catalogacao.subjectGov.intro',
  'catalogacao.subjectGov.empty',
  'catalogacao.subjectGov.activate',
  'catalogacao.subjectGov.deprecate',
  'catalogacao.subjectGov.statusUpdated',
  'catalogacao.subjectGov.coordOnly',
  'catalogacao.subjectGov.proposedAt',
];

const V = {
  fr: ['Matière', 'Coordination matière', 'Les termes proposés au catalogage attendent ici leur activation. Tout le monde les voit ; seule la coordination les active.', 'Aucun terme en attente.', 'Activer', 'Déprécier', 'Statut mis à jour.', 'L’activation est réservée à la coordination catalogage (coordenador / administrador).', 'Proposé le {date}'],
  'pt-BR': ['Matéria', 'Coordenação de matéria', 'Os termos propostos na catalogação aguardam aqui sua ativação. Todo mundo os vê; só a coordenação os ativa.', 'Nenhum termo pendente.', 'Ativar', 'Descontinuar', 'Status atualizado.', 'A ativação é reservada à coordenação de catalogação (coordenador / administrador).', 'Proposto em {date}'],
  es: ['Materia', 'Coordinación de materia', 'Los términos propuestos en la catalogación esperan aquí su activación. Todo el mundo los ve; solo la coordinación los activa.', 'Ningún término pendiente.', 'Activar', 'Descartar', 'Estado actualizado.', 'La activación está reservada a la coordinación de catalogación (coordenador / administrador).', 'Propuesto el {date}'],
  en: ['Subjects', 'Subject coordination', 'Terms proposed during cataloging await activation here. Everyone can see them; only the coordination activates them.', 'No terms pending.', 'Activate', 'Deprecate', 'Status updated.', 'Activation is reserved for the cataloging coordination (coordenador / administrador).', 'Proposed on {date}'],
  it: ['Soggetti', 'Coordinamento dei soggetti', 'I termini proposti in catalogazione attendono qui la loro attivazione. Tutti li vedono; solo il coordinamento li attiva.', 'Nessun termine in attesa.', 'Attiva', 'Deprecare', 'Stato aggiornato.', 'L’attivazione è riservata al coordinamento di catalogazione (coordenador / administrador).', 'Proposto il {date}'],
  de: ['Sachthemen', 'Sachthemen-Koordination', 'Die beim Katalogisieren vorgeschlagenen Begriffe warten hier auf ihre Freischaltung. Alle sehen sie; nur die Koordination schaltet sie frei.', 'Keine Begriffe ausstehend.', 'Freischalten', 'Verwerfen', 'Status aktualisiert.', 'Die Freischaltung ist der Katalogisierungskoordination vorbehalten (coordenador / administrador).', 'Vorgeschlagen am {date}'],
  ca: ['Matèria', 'Coordinació de matèria', 'Els termes proposats a la catalogació esperen aquí la seva activació. Tothom els veu; només la coordinació els activa.', 'Cap terme pendent.', 'Activar', 'Descartar', 'Estat actualitzat.', 'L’activació està reservada a la coordinació de catalogació (coordenador / administrador).', 'Proposat el {date}'],
  eo: ['Temaro', 'Kunordigo de temaro', 'La terminoj proponitaj dum katalogado atendas ĉi tie sian aktivigon. Ĉiuj vidas ilin; nur la kunordigo aktivigas ilin.', 'Neniu termino atendanta.', 'Aktivigi', 'Malrekomendi', 'Statuso ĝisdatigita.', 'La aktivigo estas rezervita al la kataloga kunordigo (coordenador / administrador).', 'Proponita la {date}'],
  nl: ['Onderwerpen', 'Onderwerpcoördinatie', 'De tijdens het catalogiseren voorgestelde termen wachten hier op activering. Iedereen ziet ze; alleen de coördinatie activeert ze.', 'Geen termen in afwachting.', 'Activeren', 'Afkeuren', 'Status bijgewerkt.', 'Activering is voorbehouden aan de catalogiseringscoördinatie (coordenador / administrador).', 'Voorgesteld op {date}'],
  el: ['Θεματική', 'Συντονισμός θεματικής', 'Οι όροι που προτείνονται κατά την καταλογογράφηση αναμένουν εδώ την ενεργοποίησή τους. Όλες/οι τους βλέπουν· μόνο ο συντονισμός τους ενεργοποιεί.', 'Κανένας όρος σε εκκρεμότητα.', 'Ενεργοποίηση', 'Κατάργηση', 'Η κατάσταση ενημερώθηκε.', 'Η ενεργοποίηση προορίζεται για τον συντονισμό καταλογογράφησης (coordenador / administrador).', 'Προτάθηκε στις {date}'],
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const vals = V[loc];
    if (!vals || vals.length !== K.length) throw new Error('Valeurs manquantes: ' + loc);
    const entries = K.map((k, i) => '  ' + JSON.stringify(k) + ': ' + JSON.stringify(vals[i]));
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 9 clés subject-governance (si absentes), JSON valide.');
}
console.log('\nTerminé.');
