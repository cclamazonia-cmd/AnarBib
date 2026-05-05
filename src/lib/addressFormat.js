// =============================================================================
// AnarBib -- Address parsing & formatting helper
// =============================================================================
// Centralise la logique de parsing et de génération du format texte multi-ligne
// utilisé pour stocker les adresses des utilisateur·rices dans `profiles.address`.
//
// Format de stockage canonique (texte multi-ligne, lignes "Clé: Valeur") :
//
//   Logradouro: Rua das Flores, 123
//   Complemento: Apto 5B
//   Casa/Apto: 5B
//   CEP/Code postal: 04567-890
//   Bairro/Quartier: Vila Madalena
//   Cidade/Ville: São Paulo
//   Estado/Região: São Paulo [SP]      ← code ISO 3166-2 entre crochets
//   País: Brasil [BR]                   ← code ISO 3166-1 alpha-2 entre crochets
//
// Les codes ISO entre crochets permettent une réinitialisation exacte des
// dropdowns CountrySelect/StateSelect à l'édition. Le format reste rétro-
// compatible avec l'ancien format sans crochets.
//
// Formats legacy également supportés en LECTURE :
//   1. Objet JSON (ancien stockage en JSONB) — typeof raw === 'object'
//   2. Chaîne JSON.stringify (ancien /painel) — détectée par le caractère { initial
//   3. Texte sans préfixes Logradouro/Complemento (ancien /conta) — line1/line2 libres
//
// =============================================================================

import { resolveToIsoCode, getCountryNames } from './countries';
import {
  STATES_BY_COUNTRY,
  hasStatesList,
} from '@/components/forms/countryData';

/**
 * Parse une adresse stockée et la convertit en objet structuré exploitable
 * par les formulaires (CountrySelect, StateSelect, etc.).
 *
 * @param {string|object} raw - Adresse sous différents formats possibles
 * @returns {Object} Objet structuré avec line1, line2, unit, postal_code,
 *                   district, city, state_region, country (codes ISO)
 */
export function parseAddressText(raw) {
  const result = {
    line1: '', line2: '', unit: '',
    postal_code: '', district: '', city: '',
    state_region: '', country: ''
  };
  if (!raw) return result;

  // ─── Cas 1 : objet JSON (ancien format JSONB) ────────────
  if (typeof raw === 'object') {
    return {
      line1: raw.line1 || '',
      line2: raw.line2 || '',
      unit: raw.unit || '',
      postal_code: raw.cep || raw.postal_code || '',
      district: raw.bairro || raw.district || '',
      city: raw.city || raw.cidade || '',
      state_region: raw.state || raw.state_region || raw.estado || '',
      country: raw.country || raw.pais || '',
    };
  }

  // ─── Cas 2 : chaîne JSON.stringify (ancien /painel) ──────
  // Détection : la chaîne commence par { (après trim).
  const trimmed = String(raw).trim();
  if (trimmed.startsWith('{')) {
    try {
      const parsed = JSON.parse(trimmed);
      if (typeof parsed === 'object' && parsed !== null) {
        // Récursion sur le cas objet (gère aussi les variantes pt-BR/en des champs)
        return parseAddressText(parsed);
      }
    } catch {
      // JSON invalide → on tombe dans le parsing texte ci-dessous
    }
  }

  // ─── Cas 3 : texte mono-ligne avec séparateur " | " (legacy Edge Function register) ─
  // L'Edge Function `register` (avant harmonisation) générait des adresses sur une
  // seule ligne avec " | " comme séparateur, sous la forme :
  //
  //   Rua das Flores, 123 | Apto 5B | Unidade: 5B | CEP: ... | Cidade: ... | Estado: ... | País: ...
  //
  // Pour les lire avec le même parser que les formats multi-ligne, on remplace
  // " | " par des sauts de ligne. Détection : la chaîne contient " | " et n'a
  // pas de saut de ligne (sinon c'est un format hybride non géré).
  let textForParsing = String(raw);
  if (!textForParsing.includes('\n') && textForParsing.includes(' | ')) {
    textForParsing = textForParsing.split(' | ').join('\n');
  }

  // ─── Cas 4 : texte multi-ligne avec préfixes "Clé: Valeur" ─
  const lines = textForParsing.split('\n').map(l => l.trim()).filter(Boolean);
  const freeLines = [];

  // Helper : extrait "Valeur" et "ISO_CODE" depuis "São Paulo [SP]" ou "Brasil [BR]"
  const extractIsoCode = (str) => {
    const m = str.match(/^(.+?)\s*\[([A-Z0-9]{1,5})\]\s*$/);
    if (m) return { value: m[1].trim(), code: m[2] };
    return { value: str.trim(), code: '' };
  };

  let countryRaw = '';
  let stateRaw = '';

  for (const line of lines) {
    const m = line.match(/^(Logradouro|Complemento|Casa\/Apto|Unidade|CEP|Code postal|CEP\/Code postal|Bairro|Quartier|Bairro\/Quartier|Cidade|Ville|Cidade\/Ville|Estado|Região|Estado\/Região|País)\s*:\s*(.+)$/i);
    if (m) {
      const key = m[1].toLowerCase();
      const val = m[2].trim();
      if (key.includes('logradouro')) result.line1 = val;
      else if (key.includes('complemento')) result.line2 = val;
      else if (key.includes('casa') || key.includes('apto') || key.includes('unidade')) result.unit = val;
      else if (key.includes('cep') || key.includes('postal')) result.postal_code = val;
      else if (key.includes('bairro') || key.includes('quartier')) result.district = val;
      else if (key.includes('cidade') || key.includes('ville')) result.city = val;
      else if (key.includes('estado') || key.includes('região') || key.includes('region')) stateRaw = val;
      else if (key.includes('país') || key.includes('pais')) countryRaw = val;
    } else {
      freeLines.push(line);
    }
  }

  // Lignes libres → line1/line2 si pas déjà capturées par préfixes (compat ancien format)
  if (!result.line1 && freeLines.length >= 1) result.line1 = freeLines[0];
  if (!result.line2 && freeLines.length >= 2) result.line2 = freeLines.slice(1).join(', ');

  // Résolution du pays : code ISO entre crochets prioritaire, sinon résolution par nom
  if (countryRaw) {
    const { value, code } = extractIsoCode(countryRaw);
    if (code) {
      result.country = code;
    } else {
      result.country = resolveToIsoCode(value || countryRaw) || '';
    }
  }

  // Résolution de l'état : code entre crochets prioritaire, sinon recherche par nom
  if (stateRaw) {
    const { value, code } = extractIsoCode(stateRaw);
    if (code) {
      result.state_region = code;
    } else if (result.country && hasStatesList(result.country)) {
      const list = STATES_BY_COUNTRY[result.country];
      const found = list.find(s => s.name.toLowerCase() === value.toLowerCase());
      result.state_region = found ? found.code : value;
    } else {
      result.state_region = value;
    }
  }

  return result;
}

/**
 * Génère le format texte multi-ligne d'une adresse pour stockage,
 * avec les codes ISO entre crochets pour pays et état.
 *
 * @param {Object} addr - Objet d'adresse (cf. parseAddressText pour la structure)
 * @param {string} locale - Locale react-intl (ex: 'pt-BR', 'fr') pour le nom du pays
 * @returns {string} Format texte multi-ligne, vide si addr ne contient rien
 */
export function formatAddressText(addr, locale) {
  if (!addr) return '';

  // Nom du pays dans la locale active de l'utilisateur·rice
  const countryNames = addr.country ? getCountryNames(locale) : null;
  const countryName = countryNames?.[addr.country] || addr.country || '';
  const countryLine = addr.country
    ? `País: ${countryName} [${addr.country}]`
    : '';

  // État : si pays a une liste fermée, state_region est un code ISO 3166-2.
  // Sinon, c'est du texte libre (pas de crochets).
  let stateLine = '';
  if (addr.state_region) {
    if (addr.country && hasStatesList(addr.country)) {
      const list = STATES_BY_COUNTRY[addr.country];
      const found = list.find(s => s.code === addr.state_region);
      const stateName = found?.name || addr.state_region;
      stateLine = `Estado/Região: ${stateName} [${addr.state_region}]`;
    } else {
      stateLine = `Estado/Região: ${addr.state_region}`;
    }
  }

  return [
    addr.line1 ? `Logradouro: ${addr.line1}` : '',
    addr.line2 ? `Complemento: ${addr.line2}` : '',
    addr.unit ? `Casa/Apto: ${addr.unit}` : '',
    addr.postal_code ? `CEP/Code postal: ${addr.postal_code}` : '',
    addr.district ? `Bairro/Quartier: ${addr.district}` : '',
    addr.city ? `Cidade/Ville: ${addr.city}` : '',
    stateLine,
    countryLine,
  ].filter(Boolean).join('\n');
}
