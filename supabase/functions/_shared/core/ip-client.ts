// CHEMIN DÉPÔT : supabase/functions/_shared/core/ip-client.ts
//
// L'adresse IP d'un appel, lue dans un en-tête que le client ne fixe pas
// lui-même (19/10/2026). Sert de clé (hachée) aux compteurs d'abus. C'est la
// SEULE lecture d'IP des fonctions : src/tests/ip-client.test.js refuse tout
// autre `headers.get("x-forwarded-for" | "cf-connecting-ip" | "x-real-ip")`.
//
// Ordre de lecture :
//   1. IP_CLIENT_HEADER posé (pile auto-hébergée, deploy/compose.yml) : cet
//      en-tête-là et lui seul, que la passerelle (deploy/Caddyfile) écrase avec
//      l'adresse qu'elle voit. Absent, on ne se rabat sur RIEN d'autre : un
//      cf-connecting-ip ou un x-forwarded-for arrivé jusque-là viendrait du
//      client ;
//   2. cf-connecting-ip : en hébergé, Cloudflare le pose devant Supabase et
//      remplace toute valeur envoyée par le client (relevé le 19/10/2026 : sur
//      toutes les requêtes des fonctions, égal à x-real-ip) ;
//   3. le DERNIER élément de x-forwarded-for, ajouté par le dernier proxy —
//      jamais le premier, que le client écrit ;
//   4. « inconnue » : tous ces appels partagent alors une même clé, ce qui
//      freine plus qu'il ne laisse passer.

export function ipClient(req: Request): string {
  const choisi = (Deno.env.get("IP_CLIENT_HEADER") || "").trim().toLowerCase();
  if (choisi) return req.headers.get(choisi)?.trim() || "inconnue";
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const xff = (req.headers.get("x-forwarded-for") || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (xff.length) return xff[xff.length - 1];
  return "inconnue";
}
