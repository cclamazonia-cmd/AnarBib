// CHEMIN DÉPÔT : supabase/functions/_shared/core/ip-client.ts
//
// L'adresse IP d'un appel, lue dans un en-tête que le client ne fixe pas
// lui-même (19/10/2026). Sert de clé (hachée) aux compteurs d'abus.
//
// Ordre de lecture :
//   1. l'en-tête nommé par IP_CLIENT_HEADER s'il est posé — la pile
//      auto-hébergée y met celui que son reverse proxy écrase (x-real-ip) ;
//   2. cf-connecting-ip : en hébergé, Cloudflare le pose devant Supabase et
//      remplace toute valeur envoyée par le client ;
//   3. le DERNIER élément de x-forwarded-for, ajouté par le dernier proxy —
//      jamais le premier, que le client écrit ;
//   4. « inconnue » : tous ces appels partagent alors une même clé, ce qui
//      freine plus qu'il ne laisse passer.

export function ipClient(req: Request): string {
  const choisi = (Deno.env.get("IP_CLIENT_HEADER") || "").trim().toLowerCase();
  if (choisi) {
    const v = req.headers.get(choisi)?.trim();
    if (v) return v;
  }
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const xff = (req.headers.get("x-forwarded-for") || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (xff.length) return xff[xff.length - 1];
  return "inconnue";
}
