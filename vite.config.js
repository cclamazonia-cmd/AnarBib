import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],

  // ── GitHub Pages / Codeberg Pages ─────────────────────────
  // Ajuste "base" pour ton nom de repo. Ex: si le repo s'appelle
  // "anarbib", le site sera à https://cclamazonia-cmd.github.io/anarbib/
  base: '/',

  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },

  // ── Vendor pdfjs : ne PAS pré-traiter ─────────────────────
  // Les fichiers dans public/vendor/pdfjs/ sont déjà compilés
  // (build/, web/cmaps/, web/standard_fonts/, web/wasm/, web/iccs/).
  // Vite doit les servir tels quels en dev ET en prod, avec les bons
  // MIME types (notamment application/wasm pour les .wasm).
  //
  // Sans ces options, Vite tente d'analyser pdf.mjs comme un module
  // applicatif, ce qui peut casser le chargement du worker et des
  // ressources WASM (jbig2.wasm, openjpeg.wasm, qcms_bg.wasm).
  optimizeDeps: {
    // Empêche Vite de pré-bundler ces imports — ils doivent rester
    // chargés depuis /vendor/pdfjs/ à l'exécution
    exclude: ['pdfjs-dist'],
  },

  // ── Serveur de dev ────────────────────────────────────────
  server: {
    fs: {
      // Autorise la lecture des fichiers du dossier public/ (devrait
      // être le cas par défaut, mais on l'explicite pour /vendor/)
      strict: false,
    },
    // Headers MIME corrects pour les .wasm servis depuis /vendor/
    // (Vite par défaut peut renvoyer application/octet-stream)
    middlewareMode: false,
    // En dev, on n'a pas de Cache-Control agressif sur /vendor/
    // pour pouvoir tester un nouveau pdfjs sans purger le cache navigateur
  },

  // ── Assets statiques explicites ───────────────────────────
  // Indique à Vite que les .wasm dans public/ sont à inclure
  // dans le build de prod sans transformation
  assetsInclude: ['**/*.wasm'],

  build: {
    outDir: 'dist',
    sourcemap: false,

    // ── Code splitting des vendors ──────────────────────────
    // Casse le bundle en chunks logiques pour :
    // 1. Téléchargement parallèle (HTTP/2 multiplexing)
    // 2. Cache long sur les vendors (qui changent rarement)
    // 3. Cache invalidé seulement sur le chunk modifié quand on push
    rollupOptions: {
      output: {
        manualChunks: {
          // React + Router (très stable, change ~1x/an)
          'react-vendor': ['react', 'react-dom', 'react-router-dom'],
          // Supabase (change quelques fois par an)
          'supabase-vendor': ['@supabase/supabase-js'],
          // i18n (change rarement)
          'i18n-vendor': ['react-intl', 'i18n-iso-countries'],
          // Phone input (utilisé seulement dans CriarConta + Conta)
          'phone-vendor': ['react-phone-number-input'],
          // Le code applicatif reste dans index.js (et les pages déjà
          // lazy-loadées par React Router restent dans leurs chunks)
        },
      },
    },
  },
});
