// ═══════════════════════════════════════════════════════════
// AnarBib — Country & State data
// ───────────────────────────────────────────────────────────
// Données structurées pour les formulaires internationalisés :
//  - Pays prioritaires (~10) listés en haut des dropdowns
//  - Listes d'états/provinces par pays (BR, FR, ES, IT, DE, AR, MX, CH)
//  - Codes ISO 3166-1 alpha-2 (FR, BR, AR, etc.) comme valeurs
//
// Les noms de pays affichés sont chargés via i18n-iso-countries
// au runtime, dans la langue active.
// ═══════════════════════════════════════════════════════════

/**
 * Pays prioritaires affichés en haut des dropdowns.
 * Choisis selon la sociologie du public AnarBib : forte présence
 * lusophone, hispanophone, francophone et germanophone, avec
 * présence libertaire historique notable.
 */
export const PRIORITY_COUNTRIES = [
  'BR', // Brésil
  'AR', // Argentine
  'MX', // Mexique
  'CL', // Chili
  'UY', // Uruguay
  'ES', // Espagne
  'PT', // Portugal
  'FR', // France
  'BE', // Belgique
  'CH', // Suisse
  'IT', // Italie
  'DE', // Allemagne
  'AT', // Autriche
  'GB', // Royaume-Uni
  'US', // États-Unis
  'CA', // Canada
];

/**
 * Listes d'états/provinces par pays.
 * Codes ISO 3166-2 (sans le préfixe pays) en valeur,
 * nom local en label affiché.
 *
 * Pour les pays non listés, le formulaire tombera en input texte libre.
 */
export const STATES_BY_COUNTRY = {

  // ─── Brésil — 27 unités fédératives ISO 3166-2:BR ───
  BR: [
    { code: 'AC', name: 'Acre' },
    { code: 'AL', name: 'Alagoas' },
    { code: 'AP', name: 'Amapá' },
    { code: 'AM', name: 'Amazonas' },
    { code: 'BA', name: 'Bahia' },
    { code: 'CE', name: 'Ceará' },
    { code: 'DF', name: 'Distrito Federal' },
    { code: 'ES', name: 'Espírito Santo' },
    { code: 'GO', name: 'Goiás' },
    { code: 'MA', name: 'Maranhão' },
    { code: 'MT', name: 'Mato Grosso' },
    { code: 'MS', name: 'Mato Grosso do Sul' },
    { code: 'MG', name: 'Minas Gerais' },
    { code: 'PA', name: 'Pará' },
    { code: 'PB', name: 'Paraíba' },
    { code: 'PR', name: 'Paraná' },
    { code: 'PE', name: 'Pernambuco' },
    { code: 'PI', name: 'Piauí' },
    { code: 'RJ', name: 'Rio de Janeiro' },
    { code: 'RN', name: 'Rio Grande do Norte' },
    { code: 'RS', name: 'Rio Grande do Sul' },
    { code: 'RO', name: 'Rondônia' },
    { code: 'RR', name: 'Roraima' },
    { code: 'SC', name: 'Santa Catarina' },
    { code: 'SP', name: 'São Paulo' },
    { code: 'SE', name: 'Sergipe' },
    { code: 'TO', name: 'Tocantins' },
  ],

  // ─── France — 13 régions métropolitaines + 5 régions d'outre-mer ───
  // ISO 3166-2:FR (uniquement régions, pas départements)
  FR: [
    { code: 'ARA', name: 'Auvergne-Rhône-Alpes' },
    { code: 'BFC', name: 'Bourgogne-Franche-Comté' },
    { code: 'BRE', name: 'Bretagne' },
    { code: 'CVL', name: 'Centre-Val de Loire' },
    { code: 'COR', name: 'Corse' },
    { code: 'GES', name: 'Grand Est' },
    { code: 'HDF', name: 'Hauts-de-France' },
    { code: 'IDF', name: 'Île-de-France' },
    { code: 'NOR', name: 'Normandie' },
    { code: 'NAQ', name: 'Nouvelle-Aquitaine' },
    { code: 'OCC', name: 'Occitanie' },
    { code: 'PDL', name: 'Pays de la Loire' },
    { code: 'PAC', name: 'Provence-Alpes-Côte d\'Azur' },
    // DOM-TOM
    { code: 'GP', name: 'Guadeloupe' },
    { code: 'MQ', name: 'Martinique' },
    { code: 'GF', name: 'Guyane' },
    { code: 'RE', name: 'La Réunion' },
    { code: 'YT', name: 'Mayotte' },
  ],

  // ─── Espagne — 17 communautés autonomes + 2 villes autonomes ───
  // ISO 3166-2:ES
  ES: [
    { code: 'AN', name: 'Andalucía' },
    { code: 'AR', name: 'Aragón' },
    { code: 'AS', name: 'Asturias' },
    { code: 'IB', name: 'Illes Balears' },
    { code: 'CN', name: 'Canarias' },
    { code: 'CB', name: 'Cantabria' },
    { code: 'CL', name: 'Castilla y León' },
    { code: 'CM', name: 'Castilla-La Mancha' },
    { code: 'CT', name: 'Catalunya' },
    { code: 'EX', name: 'Extremadura' },
    { code: 'GA', name: 'Galicia' },
    { code: 'MD', name: 'Madrid' },
    { code: 'MC', name: 'Murcia' },
    { code: 'NC', name: 'Nafarroa / Navarra' },
    { code: 'PV', name: 'Euskadi / País Vasco' },
    { code: 'RI', name: 'La Rioja' },
    { code: 'VC', name: 'Comunitat Valenciana' },
    // Villes autonomes
    { code: 'CE', name: 'Ceuta' },
    { code: 'ML', name: 'Melilla' },
  ],

  // ─── Italie — 20 régions ISO 3166-2:IT ───
  IT: [
    { code: '65', name: 'Abruzzo' },
    { code: '77', name: 'Basilicata' },
    { code: '78', name: 'Calabria' },
    { code: '72', name: 'Campania' },
    { code: '45', name: 'Emilia-Romagna' },
    { code: '36', name: 'Friuli-Venezia Giulia' },
    { code: '62', name: 'Lazio' },
    { code: '42', name: 'Liguria' },
    { code: '25', name: 'Lombardia' },
    { code: '57', name: 'Marche' },
    { code: '67', name: 'Molise' },
    { code: '21', name: 'Piemonte' },
    { code: '75', name: 'Puglia' },
    { code: '88', name: 'Sardegna' },
    { code: '82', name: 'Sicilia' },
    { code: '52', name: 'Toscana' },
    { code: '32', name: 'Trentino-Alto Adige / Südtirol' },
    { code: '55', name: 'Umbria' },
    { code: '23', name: 'Valle d\'Aosta' },
    { code: '34', name: 'Veneto' },
  ],

  // ─── Allemagne — 16 Länder ISO 3166-2:DE ───
  DE: [
    { code: 'BW', name: 'Baden-Württemberg' },
    { code: 'BY', name: 'Bayern' },
    { code: 'BE', name: 'Berlin' },
    { code: 'BB', name: 'Brandenburg' },
    { code: 'HB', name: 'Bremen' },
    { code: 'HH', name: 'Hamburg' },
    { code: 'HE', name: 'Hessen' },
    { code: 'MV', name: 'Mecklenburg-Vorpommern' },
    { code: 'NI', name: 'Niedersachsen' },
    { code: 'NW', name: 'Nordrhein-Westfalen' },
    { code: 'RP', name: 'Rheinland-Pfalz' },
    { code: 'SL', name: 'Saarland' },
    { code: 'SN', name: 'Sachsen' },
    { code: 'ST', name: 'Sachsen-Anhalt' },
    { code: 'SH', name: 'Schleswig-Holstein' },
    { code: 'TH', name: 'Thüringen' },
  ],

  // ─── Argentine — 23 provinces + Ciudad Autónoma de Buenos Aires ───
  // ISO 3166-2:AR
  AR: [
    { code: 'C', name: 'Ciudad Autónoma de Buenos Aires' },
    { code: 'B', name: 'Buenos Aires' },
    { code: 'K', name: 'Catamarca' },
    { code: 'H', name: 'Chaco' },
    { code: 'U', name: 'Chubut' },
    { code: 'X', name: 'Córdoba' },
    { code: 'W', name: 'Corrientes' },
    { code: 'E', name: 'Entre Ríos' },
    { code: 'P', name: 'Formosa' },
    { code: 'Y', name: 'Jujuy' },
    { code: 'L', name: 'La Pampa' },
    { code: 'F', name: 'La Rioja' },
    { code: 'M', name: 'Mendoza' },
    { code: 'N', name: 'Misiones' },
    { code: 'Q', name: 'Neuquén' },
    { code: 'R', name: 'Río Negro' },
    { code: 'A', name: 'Salta' },
    { code: 'J', name: 'San Juan' },
    { code: 'D', name: 'San Luis' },
    { code: 'Z', name: 'Santa Cruz' },
    { code: 'S', name: 'Santa Fe' },
    { code: 'G', name: 'Santiago del Estero' },
    { code: 'V', name: 'Tierra del Fuego' },
    { code: 'T', name: 'Tucumán' },
  ],

  // ─── Mexique — 31 états + Mexico City ISO 3166-2:MX ───
  MX: [
    { code: 'AGU', name: 'Aguascalientes' },
    { code: 'BCN', name: 'Baja California' },
    { code: 'BCS', name: 'Baja California Sur' },
    { code: 'CAM', name: 'Campeche' },
    { code: 'CHP', name: 'Chiapas' },
    { code: 'CHH', name: 'Chihuahua' },
    { code: 'CMX', name: 'Ciudad de México' },
    { code: 'COA', name: 'Coahuila' },
    { code: 'COL', name: 'Colima' },
    { code: 'DUR', name: 'Durango' },
    { code: 'GUA', name: 'Guanajuato' },
    { code: 'GRO', name: 'Guerrero' },
    { code: 'HID', name: 'Hidalgo' },
    { code: 'JAL', name: 'Jalisco' },
    { code: 'MEX', name: 'México (Estado)' },
    { code: 'MIC', name: 'Michoacán' },
    { code: 'MOR', name: 'Morelos' },
    { code: 'NAY', name: 'Nayarit' },
    { code: 'NLE', name: 'Nuevo León' },
    { code: 'OAX', name: 'Oaxaca' },
    { code: 'PUE', name: 'Puebla' },
    { code: 'QUE', name: 'Querétaro' },
    { code: 'ROO', name: 'Quintana Roo' },
    { code: 'SLP', name: 'San Luis Potosí' },
    { code: 'SIN', name: 'Sinaloa' },
    { code: 'SON', name: 'Sonora' },
    { code: 'TAB', name: 'Tabasco' },
    { code: 'TAM', name: 'Tamaulipas' },
    { code: 'TLA', name: 'Tlaxcala' },
    { code: 'VER', name: 'Veracruz' },
    { code: 'YUC', name: 'Yucatán' },
    { code: 'ZAC', name: 'Zacatecas' },
  ],

  // ─── Suisse — 26 cantons ISO 3166-2:CH ───
  CH: [
    { code: 'AG', name: 'Aargau' },
    { code: 'AR', name: 'Appenzell Ausserrhoden' },
    { code: 'AI', name: 'Appenzell Innerrhoden' },
    { code: 'BL', name: 'Basel-Landschaft' },
    { code: 'BS', name: 'Basel-Stadt' },
    { code: 'BE', name: 'Bern / Berne' },
    { code: 'FR', name: 'Fribourg / Freiburg' },
    { code: 'GE', name: 'Genève' },
    { code: 'GL', name: 'Glarus' },
    { code: 'GR', name: 'Graubünden / Grigioni / Grischun' },
    { code: 'JU', name: 'Jura' },
    { code: 'LU', name: 'Luzern' },
    { code: 'NE', name: 'Neuchâtel' },
    { code: 'NW', name: 'Nidwalden' },
    { code: 'OW', name: 'Obwalden' },
    { code: 'SG', name: 'Sankt Gallen' },
    { code: 'SH', name: 'Schaffhausen' },
    { code: 'SZ', name: 'Schwyz' },
    { code: 'SO', name: 'Solothurn' },
    { code: 'TG', name: 'Thurgau' },
    { code: 'TI', name: 'Ticino' },
    { code: 'UR', name: 'Uri' },
    { code: 'VS', name: 'Valais / Wallis' },
    { code: 'VD', name: 'Vaud' },
    { code: 'ZG', name: 'Zug' },
    { code: 'ZH', name: 'Zürich' },
  ],
};

/**
 * Renvoie true si le pays a une liste fermée d'états/provinces dans STATES_BY_COUNTRY.
 * Sinon, le formulaire utilisera un input texte libre.
 */
export function hasStatesList(countryCode) {
  return Boolean(STATES_BY_COUNTRY[countryCode]);
}

/**
 * Renvoie le nom local d'un état/province à partir de son code.
 * Exemple : getStateName('BR', 'SP') → 'São Paulo'
 */
export function getStateName(countryCode, stateCode) {
  const list = STATES_BY_COUNTRY[countryCode];
  if (!list) return stateCode;
  const found = list.find(s => s.code === stateCode);
  return found ? found.name : stateCode;
}

/**
 * Métadonnées par pays pour adapter les labels et la validation.
 *
 *  - postalCodeLabel : clé i18n pour le label du code postal
 *  - postalCodePattern : regex de validation (côté JS, pas exhaustif — on reste tolérant)
 *  - stateLabel : clé i18n pour le label du sous-découpage administratif
 *
 * Pour les pays non listés ici, on utilise des fallbacks génériques (cf. composants).
 */
export const COUNTRY_METADATA = {
  BR: { postalCodeLabel: 'address.postalCode.BR',  stateLabel: 'address.state.BR'  }, // CEP + Estado
  PT: { postalCodeLabel: 'address.postalCode.PT',  stateLabel: 'address.state.PT'  }, // Código postal + Distrito
  AR: { postalCodeLabel: 'address.postalCode.AR',  stateLabel: 'address.state.AR'  }, // CP + Provincia
  MX: { postalCodeLabel: 'address.postalCode.MX',  stateLabel: 'address.state.MX'  }, // CP + Estado
  CL: { postalCodeLabel: 'address.postalCode.CL',  stateLabel: 'address.state.CL'  }, // Código postal + Región
  UY: { postalCodeLabel: 'address.postalCode.UY',  stateLabel: 'address.state.UY'  }, // CP + Departamento
  ES: { postalCodeLabel: 'address.postalCode.ES',  stateLabel: 'address.state.ES'  }, // CP + Comunidad autónoma
  FR: { postalCodeLabel: 'address.postalCode.FR',  stateLabel: 'address.state.FR'  }, // CP + Région
  BE: { postalCodeLabel: 'address.postalCode.BE',  stateLabel: 'address.state.BE'  }, // CP + Région
  CH: { postalCodeLabel: 'address.postalCode.CH',  stateLabel: 'address.state.CH'  }, // PLZ/NPA + Canton
  IT: { postalCodeLabel: 'address.postalCode.IT',  stateLabel: 'address.state.IT'  }, // CAP + Regione
  DE: { postalCodeLabel: 'address.postalCode.DE',  stateLabel: 'address.state.DE'  }, // PLZ + Bundesland
  AT: { postalCodeLabel: 'address.postalCode.AT',  stateLabel: 'address.state.AT'  }, // PLZ + Bundesland
  GB: { postalCodeLabel: 'address.postalCode.GB',  stateLabel: 'address.state.GB'  }, // Postcode + Country (Eng/Sco/Wal/NI)
  US: { postalCodeLabel: 'address.postalCode.US',  stateLabel: 'address.state.US'  }, // ZIP + State
  CA: { postalCodeLabel: 'address.postalCode.CA',  stateLabel: 'address.state.CA'  }, // Postal code + Province
};

/**
 * Renvoie les métadonnées d'un pays, avec fallback générique si non répertorié.
 */
export function getCountryMetadata(countryCode) {
  return COUNTRY_METADATA[countryCode] || {
    postalCodeLabel: 'address.postalCode.generic',
    stateLabel: 'address.state.generic',
  };
}
