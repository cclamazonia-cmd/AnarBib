/* ===========================================================================
 * i18n-add-login-erreurs.cjs
 * Les trois refus de l'Edge Function `login` (identifiants, trop de
 * tentatives, erreur serveur), traduits par l'écran à partir du `code` que la
 * fonction renvoie depuis le 27/09/2026. Avant, LoginPage.jsx affichait le
 * texte `error` de la fonction tel quel : « Email ou mot de passe incorrect. »,
 * « Trop de tentatives. Réessayez dans une heure. » — en français dans les dix
 * langues, et au vouvoiement (DOC-ADDR-1).
 *
 * Registre de chaque langue (DOC-ADDR-1) : você en pt-BR, tu en fr/it/ca/es,
 * du en de, je en nl, εσύ en el. Le message d'identifiants reprend les
 * libellés du formulaire (auth.publicId, auth.password) et ne dit pas lequel
 * des deux est faux : c'est voulu (anti-énumération, cf. la fonction).
 *
 * Ajout si absent : une clé déjà présente n'est pas touchée.
 * Usage : node scripts/i18n-add-login-erreurs.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, '..', 'src', 'i18n', 'locales');

const T = {
  'auth.loginInvalid': {
    'pt-BR': 'E-mail, ID público ou senha incorretos.',
    fr: 'E-mail, ID public ou mot de passe incorrect.',
    en: 'Incorrect email, public ID or password.',
    de: 'E-Mail, öffentliche ID oder Passwort falsch.',
    it: 'Email, ID pubblico o password errati.',
    es: 'Correo, ID público o contraseña incorrectos.',
    ca: 'Correu electrònic, ID públic o contrasenya incorrectes.',
    eo: 'Malĝusta retpoŝto, publika ID aŭ pasvorto.',
    nl: 'Onjuist e-mailadres, openbare ID of wachtwoord.',
    el: 'Λάθος email, δημόσιο αναγνωριστικό ή κωδικός.',
  },
  'auth.loginRateLimited': {
    'pt-BR': 'Muitas tentativas. Tente novamente em uma hora.',
    fr: 'Trop de tentatives. Réessaie dans une heure.',
    en: 'Too many attempts. Try again in an hour.',
    de: 'Zu viele Versuche. Versuche es in einer Stunde erneut.',
    it: 'Troppi tentativi. Riprova tra un’ora.',
    es: 'Demasiados intentos. Vuelve a intentarlo en una hora.',
    ca: 'Massa intents. Torna-ho a provar d’aquí a una hora.',
    eo: 'Tro da provoj. Reprovu post unu horo.',
    nl: 'Te veel pogingen. Probeer het over een uur opnieuw.',
    el: 'Πάρα πολλές προσπάθειες. Δοκίμασε ξανά σε μία ώρα.',
  },
  'auth.loginServerError': {
    'pt-BR': 'Erro no servidor. Tente novamente em instantes.',
    fr: 'Erreur serveur. Réessaie dans un instant.',
    en: 'Server error. Try again in a moment.',
    de: 'Serverfehler. Versuche es gleich noch einmal.',
    it: 'Errore del server. Riprova tra un momento.',
    es: 'Error del servidor. Vuelve a intentarlo en un momento.',
    ca: 'Error del servidor. Torna-ho a provar d’aquí a un moment.',
    eo: 'Servila eraro. Reprovu post momento.',
    nl: 'Serverfout. Probeer het zo meteen opnieuw.',
    el: 'Σφάλμα διακομιστή. Δοκίμασε ξανά σε λίγο.',
  },
};

const LOCALES = ['pt-BR', 'fr', 'en', 'de', 'it', 'es', 'ca', 'eo', 'nl', 'el'];
for (const loc of LOCALES) {
  const f = path.join(DIR, `${loc}.json`);
  const obj = JSON.parse(fs.readFileSync(f, 'utf8'));
  let added = 0;
  for (const [k, vals] of Object.entries(T)) {
    if (!vals[loc]) throw new Error(`${k} : pas de valeur ${loc}`);
    if (!(k in obj)) { obj[k] = vals[loc]; added++; }
  }
  fs.writeFileSync(f, JSON.stringify(obj, null, 2) + '\n');
  console.log(`${loc}: +${added}`);
}
