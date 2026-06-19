#!/usr/bin/env bash
# =============================================================================
# refresh-tunnel-secret.sh — rétablit le géocodage après un (re)démarrage.
# =============================================================================
# Auteur : AnarBib · Session : Carte réseau 10 locales
# Runbook : docs/journal/operations/SETUP_nominatim_geocoding_2026-06-18.md (§9)
#
# Le tunnel cloudflared (quick tunnel, gratuit) change d'URL à chaque (re)démarrage.
# Ce script : (1) s'assure que le tunnel tourne (le recrée sinon), (2) lit l'URL
# courante, (3) la repose comme secret NOMINATIM_URL de l'Edge Function geocode.
# À lancer après chaque démarrage de la machine :  bash scripts/nominatim/refresh-tunnel-secret.sh
# Bridge TEMPORAIRE — disparaît quand le VPS camarades prend le relais (runbook §9).
# =============================================================================
PROJECT_REF=uflwmikiyjfnikiphtcp
CF=anarbib-cloudflared
NOMI=anarbib-nominatim

# 0) Nominatim doit tourner
if ! docker ps --format '{{.Names}}' | grep -qx "$NOMI"; then
  echo "⚠ Nominatim ($NOMI) n'est pas démarré. Lance d'abord :"
  echo "    docker compose -f scripts/nominatim/docker-compose.yml up -d"
  exit 1
fi

# 1) (Re)crée le tunnel s'il ne tourne pas
if ! docker ps --format '{{.Names}}' | grep -qx "$CF"; then
  echo "→ Tunnel absent : (re)création…"
  docker rm -f "$CF" >/dev/null 2>&1
  NET=$(docker network ls --format '{{.Name}}' | grep -i nominatim | head -1)
  if [ -z "$NET" ]; then echo "✗ Réseau Docker de Nominatim introuvable."; exit 1; fi
  docker run -d --name "$CF" --restart unless-stopped \
    --network "$NET" cloudflare/cloudflared:latest \
    tunnel --no-autoupdate --url "http://$NOMI:8080" >/dev/null
fi

# 2) Récupère l'URL trycloudflare courante (la plus récente dans les logs)
echo "→ Récupération de l'URL du tunnel…"
URL=""
for _ in $(seq 1 20); do
  URL=$(docker logs "$CF" 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)
  [ -n "$URL" ] && break
  sleep 3
done
if [ -z "$URL" ]; then echo "✗ URL du tunnel introuvable. Voir : docker logs $CF"; exit 1; fi
echo "→ URL : $URL"

# 3) Repose le secret de l'Edge Function
echo "→ Mise à jour du secret NOMINATIM_URL…"
if supabase secrets set "NOMINATIM_URL=$URL" --project-ref "$PROJECT_REF" >/dev/null 2>&1; then
  echo "✓ Secret NOMINATIM_URL mis à jour — géocodage prêt (si l'import Nominatim est terminé)."
  echo "  (Sinon le bouton « Localiser depuis l'adresse » reste en repli pin manuel.)"
else
  echo "✗ Échec de 'supabase secrets set'. Vérifie la connexion du CLI (supabase login)."
  exit 1
fi
