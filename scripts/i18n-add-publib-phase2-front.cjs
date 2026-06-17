/* ===========================================================================
 * i18n-add-publib-phase2-front.cjs
 * PUBLIB Phase 2 frontend : panneau « Fiche publique » (toggles opt-in, #PUB3)
 * + en-tête Contact de la fiche publique (#PUB4). 6 clés × 10 locales.
 * Les libellés de champs (email/tél/…) + « Horaires » réutilisent account.mylib.*.
 * Idempotent (sentinelle biblioteca.publicFiche.requiresPublic).
 * =========================================================================== */
const fs = require('fs');
const path = require('path');
const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');
const SENTINEL = 'biblioteca.publicFiche.requiresPublic';

const ADD = {
  'pt-BR': {
    'biblioteca.publicFiche.title': 'Ficha pública',
    'biblioteca.publicFiche.hint': 'Escolha o que aparece na ficha pública da biblioteca. Desativado por padrão.',
    'biblioteca.publicFiche.contactToggle': 'Mostrar o contato público',
    'biblioteca.publicFiche.hoursToggle': 'Mostrar os horários / plantões',
    'biblioteca.publicFiche.collective': 'Tornar informações públicas compromete o coletivo: decidam juntes.',
    'biblioteca.publicFiche.requiresPublic': 'Só tem efeito se a biblioteca estiver listada publicamente.',
    'bibliotecaPublica.contact': 'Contato',
  },
  fr: {
    'biblioteca.publicFiche.title': 'Fiche publique',
    'biblioteca.publicFiche.hint': 'Choisissez ce qui apparaît sur la fiche publique de votre bibliothèque. Désactivé par défaut.',
    'biblioteca.publicFiche.contactToggle': 'Afficher le contact public',
    'biblioteca.publicFiche.hoursToggle': 'Afficher les horaires / permanences',
    'biblioteca.publicFiche.collective': 'Rendre des informations publiques engage le collectif : à décider ensemble.',
    'biblioteca.publicFiche.requiresPublic': 'Effectif seulement si la bibliothèque est répertoriée publiquement.',
    'bibliotecaPublica.contact': 'Contact',
  },
  es: {
    'biblioteca.publicFiche.title': 'Ficha pública',
    'biblioteca.publicFiche.hint': 'Elige qué aparece en la ficha pública de tu biblioteca. Desactivado por defecto.',
    'biblioteca.publicFiche.contactToggle': 'Mostrar el contacto público',
    'biblioteca.publicFiche.hoursToggle': 'Mostrar los horarios / turnos',
    'biblioteca.publicFiche.collective': 'Hacer pública información compromete al colectivo: decídanlo juntes.',
    'biblioteca.publicFiche.requiresPublic': 'Solo surte efecto si la biblioteca aparece públicamente.',
    'bibliotecaPublica.contact': 'Contacto',
  },
  en: {
    'biblioteca.publicFiche.title': 'Public profile',
    'biblioteca.publicFiche.hint': "Choose what appears on your library's public profile. Off by default.",
    'biblioteca.publicFiche.contactToggle': 'Show public contact',
    'biblioteca.publicFiche.hoursToggle': 'Show opening hours / shifts',
    'biblioteca.publicFiche.collective': 'Making information public commits the collective — decide together.',
    'biblioteca.publicFiche.requiresPublic': 'Only effective if the library is publicly listed.',
    'bibliotecaPublica.contact': 'Contact',
  },
  it: {
    'biblioteca.publicFiche.title': 'Scheda pubblica',
    'biblioteca.publicFiche.hint': 'Scegli cosa appare sulla scheda pubblica della biblioteca. Disattivato per impostazione predefinita.',
    'biblioteca.publicFiche.contactToggle': 'Mostrare il contatto pubblico',
    'biblioteca.publicFiche.hoursToggle': 'Mostrare gli orari / turni',
    'biblioteca.publicFiche.collective': 'Rendere pubbliche informazioni impegna il collettivo: decidete insieme.',
    'biblioteca.publicFiche.requiresPublic': 'Ha effetto solo se la biblioteca è elencata pubblicamente.',
    'bibliotecaPublica.contact': 'Contatti',
  },
  de: {
    'biblioteca.publicFiche.title': 'Öffentliches Profil',
    'biblioteca.publicFiche.hint': 'Wähle, was auf dem öffentlichen Profil deiner Bibliothek erscheint. Standardmäßig deaktiviert.',
    'biblioteca.publicFiche.contactToggle': 'Öffentlichen Kontakt anzeigen',
    'biblioteca.publicFiche.hoursToggle': 'Öffnungszeiten / Dienste anzeigen',
    'biblioteca.publicFiche.collective': 'Informationen öffentlich zu machen betrifft das Kollektiv – gemeinsam entscheiden.',
    'biblioteca.publicFiche.requiresPublic': 'Nur wirksam, wenn die Bibliothek öffentlich gelistet ist.',
    'bibliotecaPublica.contact': 'Kontakt',
  },
  ca: {
    'biblioteca.publicFiche.title': 'Fitxa pública',
    'biblioteca.publicFiche.hint': 'Tria què apareix a la fitxa pública de la teva biblioteca. Desactivat per defecte.',
    'biblioteca.publicFiche.contactToggle': 'Mostrar el contacte públic',
    'biblioteca.publicFiche.hoursToggle': 'Mostrar els horaris / torns',
    'biblioteca.publicFiche.collective': 'Fer pública informació compromet el col·lectiu: decidiu-ho juntes.',
    'biblioteca.publicFiche.requiresPublic': 'Només té efecte si la biblioteca apareix públicament.',
    'bibliotecaPublica.contact': 'Contacte',
  },
  eo: {
    'biblioteca.publicFiche.title': 'Publika paĝo',
    'biblioteca.publicFiche.hint': 'Elektu kio aperas sur la publika paĝo de via biblioteko. Defaŭlte malŝaltita.',
    'biblioteca.publicFiche.contactToggle': 'Montri la publikan kontakton',
    'biblioteca.publicFiche.hoursToggle': 'Montri la horojn / deĵorojn',
    'biblioteca.publicFiche.collective': 'Publikigi informojn engaĝas la kolektivon: decidu kune.',
    'biblioteca.publicFiche.requiresPublic': 'Efika nur se la biblioteko estas publike listigita.',
    'bibliotecaPublica.contact': 'Kontakto',
  },
  nl: {
    'biblioteca.publicFiche.title': 'Openbaar profiel',
    'biblioteca.publicFiche.hint': 'Kies wat er op het openbare profiel van je bibliotheek verschijnt. Standaard uitgeschakeld.',
    'biblioteca.publicFiche.contactToggle': 'Openbaar contact tonen',
    'biblioteca.publicFiche.hoursToggle': 'Openingsuren / diensten tonen',
    'biblioteca.publicFiche.collective': 'Informatie openbaar maken betreft het collectief – beslis samen.',
    'biblioteca.publicFiche.requiresPublic': 'Alleen van kracht als de bibliotheek openbaar vermeld is.',
    'bibliotecaPublica.contact': 'Contact',
  },
  el: {
    'biblioteca.publicFiche.title': 'Δημόσια σελίδα',
    'biblioteca.publicFiche.hint': 'Επίλεξε τι εμφανίζεται στη δημόσια σελίδα της βιβλιοθήκης σου. Απενεργοποιημένο από προεπιλογή.',
    'biblioteca.publicFiche.contactToggle': 'Εμφάνιση δημόσιας επικοινωνίας',
    'biblioteca.publicFiche.hoursToggle': 'Εμφάνιση ωραρίων / βαρδιών',
    'biblioteca.publicFiche.collective': 'Η δημοσιοποίηση πληροφοριών αφορά τη συλλογικότητα — αποφασίστε μαζί.',
    'biblioteca.publicFiche.requiresPublic': 'Ισχύει μόνο αν η βιβλιοθήκη είναι δημόσια καταχωρισμένη.',
    'bibliotecaPublica.contact': 'Επικοινωνία',
  },
};

for (const loc of LOCALES) {
  const file = path.join(DIR, loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes('"' + SENTINEL + '"')) {
    const map = ADD[loc];
    const keys = Object.keys(ADD['pt-BR']);
    const entries = keys.map((k) => {
      if (map[k] == null) throw new Error('Traduction manquante: ' + k + ' / ' + loc);
      return '  ' + JSON.stringify(k) + ': ' + JSON.stringify(map[k]);
    });
    const marker = content.lastIndexOf('}');
    content = content.slice(0, marker).replace(/\s*$/, '') + ',\n' + entries.join(',\n') + '\n' + content.slice(marker);
    if (!content.endsWith('\n')) content += '\n';
    fs.writeFileSync(file, content, 'utf8');
  }
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': 6 clés Phase 2 (si absentes), JSON valide.');
}
console.log('\nTerminé.');
