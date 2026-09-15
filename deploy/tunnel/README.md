# `deploy/tunnel/` — Exposition sécurisée par tunnel et proxy inverse

Ce dossier fournit les briques prêtes à l'emploi pour exposer la pile AnarBib
quand le serveur backend ne dispose pas d'une IP publique fixe directe (ex. :
machine en local, dans un lieu collectif, chez un hébergeur sans IPv4 dédiée,
ou derrière un pare-feu/NAT).

---

## 1. La doctrine de sécurité : Tunnel de couche 4 (Passthrough TCP)

Pour préserver la souveraineté des données et l'étanchéité de l'infrastructure,
le modèle recommandé est le **passthrough TCP de niveau 4** :

```
[Navigateur / Client API]
           │ HTTPS (443) / HTTP (80)
           ▼
┌────────────────────────────────────────────────────────┐
│  VPS Frontal Léger (IP publique fixe en Europe)        │
│  - Port forwarding TCP brut (iptables/nftables)        │
│  - ZÉRO certificat TLS, ZÉRO secret, ZÉRO déchiffrement│
└──────────────────────────┬─────────────────────────────┘
                           │ Tunnel chiffré (WireGuard ou Rathole)
                           ▼
┌────────────────────────────────────────────────────────┐
│  Machine Hôte AnarBib (Backend)                        │
│  - Caddy négocie Let's Encrypt lui-même                │
│  - Déchiffre le TLS localement                         │
│  - Distribue vers PostgREST, GoTrue, Storage, Functions│
└────────────────────────────────────────────────────────┘
```

### Pourquoi ce choix ?
1. **Zéro secret sur le frontal** : Si le VPS public est saisi, compromis ou coupé, l'attaquant ne dispose d'aucune clé privée TLS, d'aucun mot de passe et d'aucun jeton JWT.
2. **Caddy autonome** : Le `Caddyfile` existant dans `deploy/Caddyfile` continue de gérer automatiquement le renouvellement Let's Encrypt pour `{$API_DOMAIN}` (`api.anarbib.org`).
3. **Zéro dépendance commerciale** : Pas de Cloudflare Tunnel ni d'intermédiaire tiers (conforme à la sortie de Cloudflare actée en août 2026).

---

## 2. Option 1 : WireGuard (Niveau Réseau / L3-L4) — *Recommandé*

WireGuard est inclus dans le noyau Linux, ultra-rapide, et supporte la reconnexion automatique en cas de coupure réseau.

### A. Configuration du VPS Frontal (`wg0` : `10.10.0.1/24`)

Sur le VPS frontal (Debian/Ubuntu avec `wireguard` et `iptables` installés) :

1. Générer les clés :
   ```bash
   umask 077
   wg genkey | tee server_private.key | wg pubkey > server_public.key
   ```
2. Poser `/etc/wireguard/wg0.conf` (voir modèle dans `deploy/tunnel/wireguard/server.conf`) :
   ```ini
   [Interface]
   Address = 10.10.0.1/24
   ListenPort = 51820
   PrivateKey = <SERVER_PRIVATE_KEY>
   
   # Forwarding TCP 80 et 443 vers le backend AnarBib (10.10.0.2)
   PostUp = iptables -A FORWARD -i eth0 -o wg0 -p tcp --dport 80 -d 10.10.0.2 -j ACCEPT
   PostUp = iptables -A FORWARD -i eth0 -o wg0 -p tcp --dport 443 -d 10.10.0.2 -j ACCEPT
   PostUp = iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to-destination 10.10.0.2:80
   PostUp = iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 443 -j DNAT --to-destination 10.10.0.2:443
   PostUp = iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
   
   [Peer]
   PublicKey = <BACKEND_PUBLIC_KEY>
   AllowedIPs = 10.10.0.2/32
   ```
3. Activer le forwarding IP et démarrer :
   ```bash
   sysctl -w net.ipv4.ip_forward=1
   systemctl enable --now wg-quick@wg0
   ```

### B. Configuration de la Machine Hôte AnarBib (`wg0` : `10.10.0.2/24`)

Sur la machine qui porte les conteneurs Docker :

1. Générer les clés :
   ```bash
   umask 077
   wg genkey | tee client_private.key | wg pubkey > client_public.key
   ```
2. Poser `/etc/wireguard/wg0.conf` (voir modèle dans `deploy/tunnel/wireguard/client.conf`) :
   ```ini
   [Interface]
   Address = 10.10.0.2/24
   PrivateKey = <CLIENT_PRIVATE_KEY>
   
   [Peer]
   PublicKey = <SERVER_PUBLIC_KEY>
   Endpoint = <IP_PUBLIQUE_VPS>:51820
   AllowedIPs = 10.10.0.0/24
   PersistentKeepalive = 25
   ```
3. Démarrer le tunnel :
   ```bash
   systemctl enable --now wg-quick@wg0
   ```

---

## 3. Option 2 : Rathole (Niveau Transport / L4 en conteneur Docker)

Si vous ne souhaitez pas configurer WireGuard au niveau du système d'exploitation de l'hôte, **Rathole** est un tunnel TCP/UDP écrit en Rust, sécurisé par cryptographie Noise (similaire à WireGuard), et pouvant tourner entièrement sous forme de conteneurs Docker non privilégiés.

Les configurations sont fournies dans `deploy/tunnel/rathole/` :
- `server.toml` (à poser sur le VPS frontal)
- `client.toml` (à poser côté backend)
- `docker-compose.tunnel.yml`

Pour lancer le client Rathole à côté de la pile AnarBib :
```bash
docker compose -f compose.yml -f tunnel/rathole/docker-compose.tunnel.yml up -d
```

---

## 4. Configuration DNS et Caddy

Une fois le tunnel établi :
1. Configurer l'enregistrement DNS :
   - `api.anarbib.org` → `A <IP_PUBLIQUE_VPS>`
2. Dans `deploy/.env` du backend :
   ```env
   API_DOMAIN=api.anarbib.org
   API_EXTERNAL_URL=https://api.anarbib.org
   ```
3. Redémarrer Caddy :
   ```bash
   docker compose restart caddy
   ```
Caddy recevra le flux TCP acheminé par le tunnel, initiera le challenge Let's Encrypt sur le port 80/443, obtiendra le certificat TLS et sécurisera tous les échanges.
