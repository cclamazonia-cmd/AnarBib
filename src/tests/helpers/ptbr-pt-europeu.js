// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — le motif du VOCABULAIRE du Portugal en pt-BR.
//
// Sorti de src/tests/i18n-ecriture.test.js (chemin 5) le 27/09/2026 pour être
// partagé avec src/tests/mail-ptbr-voce.test.js (courriels des Edge
// Functions), comme `TU_EUROPEU` dans ptbr-tu-europeu.js. Un motif, deux
// gardes ; l'élargir ici élargit les deux.
// ─────────────────────────────────────────────────────────────────────────────

// Chemin (5), pt-BR — le VOCABULAIRE du Portugal. Relevé le 27/09/2026 après
// la passe « você » : 78 valeurs parlaient européen — « ficheiro » 32 fois
// (écran Exportação), « partilha digital » alors que le droit s'appelle
// « Compartilhamento digital » dans Parcerias, « Guardar », « A carregar… »,
// « registo », « Gerir leitor(a/e) », « Valores por omissão ». Réécrites par
// `scripts/i18n-ptbr-vocabulario.cjs`.
//
// CRITÈRE D'ADMISSION, celui du chemin (3) : un mot n'entre dans
// `PT_EUROPEU_FORMAS` que s'il n'existe pas au Brésil dans un sens que l'app
// pourrait employer. « partilha » y entre bien que le droit brésilien parle de
// « partilha de bens » (succession) : ce sens-là n'a rien à faire dans un
// catalogue de bibliothèque.
//
// Quatre motifs de STRUCTURE s'y ajoutent, sans homographe non plus :
//   — le progressif « A carregar… » en tête de phrase (le Brésil dit
//     « Carregando… ») ; points de suspension exigés, parce que « a
//     verificar » sans eux est un statut brésilien (« à vérifier ») ;
//   — « está/estão/estava… a + infinitif », sauf « a par » et « a seguir »,
//     qui sont brésiliens (« estar a par », « as instruções estão a seguir ») ;
//   — le passé « -ámos » (« criámos », « enviámos ») : le Brésil n'accentue
//     jamais la 1re personne du pluriel ;
//   — le timbre ouvert devant m/n (« género », « anónimo », « académico »,
//     « eletrónico ») : le Brésil écrit « gênero », « anônimo »… Mots en
//     minuscule seulement, pour laisser passer un nom propre (« Émile »).
//
// ANGLE MORT, mesuré : rejoué sur le fichier d'avant correction, le motif
// trouve 53 des 78 valeurs réécrites. Les 25 autres emploient un mot qui
// EXISTE au Brésil dans un autre sens ou à un autre registre, et que la liste
// ne peut donc pas prendre : « gerir » ×12 (brésilien soutenu, « gerenciar »
// à l'écran), « Guardar » ×7 (enregistrer, au Portugal ; garder, au Brésil —
// « Guarde as informações abaixo » est juste), « Eliminar » ×2, « por
// omissão » (sens juridique au Brésil), « fecho » (fermeture éclair, « eu
// fecho »), « cinzento », « entretanto » (« cependant », au Brésil). « na
// mesma » (« na mesma página ») n'est tombé que par son voisin « criámos ».
// Même raison pour « equipa » (verbe « equipar »), « facto » (« de facto »
// latin), « separador » (le caractère), « cota » (la cotisation), « rastreio »
// (dépistage), « sítio », « rato », « apelido », « descarregar », « aceder ».
// Ils ne tombent qu'à la relecture ; le chiffre de ce chemin est un PLANCHER.
// Il ne voit pas non plus la syntaxe (enclise, « já não », « à espera de »),
// ni les calques du français (« notícia » pour une notice, « flux RSS »,
// « cote »), qui ne sont pas européens.
//
// PARTAGÉ depuis le 27/09/2026 au soir avec la garde des courriels
// (`mail-ptbr-voce.test.js`), une fois leur propre passe faite
// (`scripts/mail-ptbr-vocabulario.cjs` : « partilha digital » ×11, « Gerir
// a parceria »…). Jusque-là il était resté local à i18n-ecriture.test.js,
// exprès : le partager plus tôt aurait fait tomber leur garde avant leur passe.
const capitalizada = (w) => w[0].toUpperCase() + w.slice(1);
export const PT_EUROPEU_FORMAS = [
  'ficheiro', 'ficheiros',
  'registo', 'registos', 'registar', 'registado', 'registada', 'registados', 'registadas', 'registe', 'registou',
  'partilha', 'partilhas', 'partilhar', 'partilhado', 'partilhada', 'partilhados', 'partilhadas',
  'partilhe', 'partilham', 'partilhável',
  'ecrã', 'ecrãs', 'utilizador', 'utilizadores', 'utilizadora', 'utilizadoras', 'utente', 'utentes',
  'telemóvel', 'telemóveis', 'factos', 'planeamento', 'palavra-passe', 'palavras-passe',
  'contacto', 'contactos', 'contactar', 'contacte', 'contactado', 'contactada',
  'secção', 'secções', 'plafond',
  'actual', 'actuais', 'actualmente', 'actualizar', 'actualizado', 'actualizada', 'actualização', 'actualizações',
  'acção', 'acções', 'direcção', 'colecção', 'colecções', 'selecção', 'correcção', 'correcções', 'protecção',
  'objecto', 'objectos', 'projecto', 'projectos', 'óptimo', 'óptima',
];
export const PT_EUROPEU = new RegExp(
  `(?<![\\p{L}-])(${PT_EUROPEU_FORMAS.flatMap((w) => [w, capitalizada(w)]).join('|')})(?![\\p{L}])` +
    `|(?:^|[.!?:;—–(]\\s*)(A\\s+\\p{Ll}+(?:ar|er|ir|pôr)(?:…|\\.\\.\\.))` +
    `|(?<![\\p{L}])((?:está|estão|estava|estavam|esteja|estejam|estiver|estiverem|estar)\\s+a\\s+` +
    `(?!(?:par|seguir)(?![\\p{L}]))\\p{L}+(?:ar|er|ir))(?![\\p{L}])` +
    `|(?<![\\p{L}])(\\p{L}+ámos)(?![\\p{L}])` +
    `|(?<![\\p{L}])(\\p{Ll}\\p{L}*[óé][mn][aeiouáéíóú]\\p{L}*)`,
  'u',
);
