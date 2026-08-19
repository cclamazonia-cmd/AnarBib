import js from '@eslint/js';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import globals from 'globals';

export default [
  js.configs.recommended,

  {
    // 19/08/2026 : `mjs` ajoute. Sans lui, deploy/genkeys.mjs ne recevait
    // AUCUNE globale (il tombait dans js.configs.recommended nu) et sortait
    // 21 erreurs no-undef sur process/console/Buffer — alors que
    // globals.node est bien charge ci-dessous. Le lint etant BLOQUANT en CI,
    // ca aurait empeche tout deploiement, migrations comprises.
    files: ['**/*.{js,jsx,mjs}'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
    plugins: {
      react,
      'react-hooks': reactHooks,
    },
    settings: {
      react: { version: 'detect' },
    },
    rules: {
      'react/jsx-uses-react': 'off',
      'react/react-in-jsx-scope': 'off',
      'react/prop-types': 'off',
      'react/jsx-uses-vars': 'error',
      'react/jsx-no-undef': 'error',
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      'no-unused-vars': ['warn', {
        argsIgnorePattern: '^_',
        varsIgnorePattern: '^_',
      }],
      'no-undef': 'error',
      'no-empty': ['error', { allowEmptyCatch: true }],
    },
  },

  {
    files: ['**/*.test.{js,jsx,ts,tsx}', 'src/tests/**/*.{js,jsx}'],
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        describe: 'readonly',
        it: 'readonly',
        test: 'readonly',
        expect: 'readonly',
        beforeAll: 'readonly',
        beforeEach: 'readonly',
        afterAll: 'readonly',
        afterEach: 'readonly',
        vi: 'readonly',
      },
    },
  },

  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'public/**',
      'supabase/functions/**',
      'scripts/**',
      'docs/**',
      'notes-audit/**',
      '*.config.js',
      'i18n.test.js',
    ],
  },
];