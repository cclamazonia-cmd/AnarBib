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
  },
});
