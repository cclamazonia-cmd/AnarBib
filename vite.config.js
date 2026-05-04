import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],

  // ── GitHub Pages ──────────────────────────────────────────
  // Ajuste "base" pour ton nom de repo GitHub Pages.
  // Ex: si le repo s'appelle "anarbib", le site sera à
  //     https://cclamazonia-cmd.github.io/anarbib/
  base: '/',

  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },

  build: {
    outDir: 'dist',
    sourcemap: false,

    // ── Code splitting des vendors ─────────────────────────
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
