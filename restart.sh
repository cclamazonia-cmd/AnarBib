#!/bin/bash
echo "=== Nettoyage du cache Vite ==="
rm -rf node_modules/.vite
echo "=== Relancement du serveur ==="
npx vite --force
