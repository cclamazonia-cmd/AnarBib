// Garde du 12/10/2026 : le fond de carte se lit hors du cache HTTP, et un script
// vendorisé qui échoue ne laisse pas de balise morte.
//
// Vécu : sur le Brave de Xavier, le cache rendait un 200 « fichier entier » à une
// demande de plage du fichier PMTiles ; le greffon abandonnait toutes les tuiles
// (« Server returned no content-length header… ») et il fallait recharger deux
// fois. Cache désactivé : carte complète du premier coup. Et une balise <script>
// restée après un 502 de Codeberg Pages faisait croire la bibliothèque chargée.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { lireCarteSansCache, MAPTILES_URL } from '@/lib/mapTiles';
import { loadVendorScript } from '@/lib/loadVendorScript';

describe('lireCarteSansCache', () => {
  const URL_CARTE = 'https://exemple.supabase.co/storage/v1/object/public/map-tiles/planet-z13.pmtiles';
  let appels; let win;
  beforeEach(() => {
    appels = [];
    win = { fetch: (input, init) => { appels.push({ input, init }); return Promise.resolve('ok'); } };
  });

  it('force cache: no-store sur une demande de plage du fichier de carte', async () => {
    lireCarteSansCache(win, URL_CARTE);
    await win.fetch(URL_CARTE, { headers: { range: 'bytes=0-16383' } });
    expect(appels[0].init.cache).toBe('no-store');
    expect(appels[0].init.headers.range).toBe('bytes=0-16383');
  });

  it("laisse passer un 'reload' choisi par le greffon (sa propre reprise après ETag)", async () => {
    lireCarteSansCache(win, URL_CARTE);
    await win.fetch(URL_CARTE, { cache: 'reload' });
    expect(appels[0].init.cache).toBe('reload');
  });

  it("ne touche à aucune autre adresse (API, autres fichiers)", async () => {
    lireCarteSansCache(win, URL_CARTE);
    await win.fetch('https://exemple.supabase.co/rest/v1/public_libraries', { headers: {} });
    await win.fetch('https://exemple.supabase.co/storage/v1/object/public/map-tiles/autre.pmtiles');
    expect(appels[0].init.cache).toBeUndefined();
    expect(appels[1].init).toBeUndefined();
  });

  it("ne s'enroule pas deux fois (plusieurs cartes sur la même page)", async () => {
    lireCarteSansCache(win, URL_CARTE);
    const premier = win.fetch;
    lireCarteSansCache(win, URL_CARTE);
    expect(win.fetch).toBe(premier);
  });

  it("vise bien l'adresse réelle du fond par défaut", () => {
    expect(MAPTILES_URL).toMatch(/map-tiles\/planet-z\d+\.pmtiles$/);
  });
});

describe('loadVendorScript', () => {
  beforeEach(() => {
    document.head.querySelectorAll('script').forEach((s) => s.remove());
    delete window.__libEssai;
    vi.useRealTimers();
  });

  it('ne charge rien si la bibliothèque est déjà là', async () => {
    window.__libEssai = { ok: true };
    await expect(loadVendorScript('/vendor/x.js', '__libEssai')).resolves.toEqual({ ok: true });
    expect(document.head.querySelectorAll('script').length).toBe(0);
  });

  it('retire la balise en échec et retente (pas de balise morte)', async () => {
    vi.useFakeTimers();
    const p = loadVendorScript('/vendor/x.js', '__libEssai');
    // 1er essai : échec réseau → la balise doit disparaître
    let s = document.head.querySelector('script');
    expect(s).not.toBeNull();
    s.dispatchEvent(new Event('error'));
    await vi.advanceTimersByTimeAsync(0);
    expect(document.head.querySelector('script')).toBeNull();
    // attente d'1 s puis 2e essai : une balise neuve, cette fois chargée
    await vi.advanceTimersByTimeAsync(1000);
    s = document.head.querySelector('script');
    expect(s).not.toBeNull();
    window.__libEssai = { recharge: true };
    s.dispatchEvent(new Event('load'));
    await expect(p).resolves.toEqual({ recharge: true });
  });

  it('abandonne après trois échecs, sans laisser de balise', async () => {
    vi.useFakeTimers();
    const p = loadVendorScript('/vendor/x.js', '__libEssai');
    const resultat = p.catch((e) => e);
    for (let i = 0; i < 3; i++) {
      const s = document.head.querySelector('script');
      expect(s).not.toBeNull();
      s.dispatchEvent(new Event('error'));
      await vi.advanceTimersByTimeAsync(2000);
    }
    expect(await resultat).toBeInstanceOf(Error);
    expect(document.head.querySelector('script')).toBeNull();
  });

  it('attend une balise déjà en cours de chargement au lieu de répondre « déjà là »', async () => {
    const enCours = document.createElement('script');
    enCours.src = '/vendor/x.js';
    document.head.appendChild(enCours);
    let resolu = false;
    const p = loadVendorScript('/vendor/x.js', '__libEssai').then((v) => { resolu = true; return v; });
    await Promise.resolve();
    expect(resolu).toBe(false);
    window.__libEssai = { tard: true };
    enCours.dispatchEvent(new Event('load'));
    await expect(p).resolves.toEqual({ tard: true });
    expect(document.head.querySelectorAll('script').length).toBe(1);
  });
});
