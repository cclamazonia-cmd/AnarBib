import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
// Délai minimum (ms) appliqué en cas d'échec d'authentification.
// Vise à brouiller les timing attacks qui distingueraient
// "identifiant inconnu" de "mot de passe invalide".
const FAILED_AUTH_MIN_DELAY_MS = 250;
const FAILED_AUTH_MAX_DELAY_MS = 600;
function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders
    }
  });
}
function normalizeIdentifier(value) {
  return String(value ?? "").trim();
}
function sleep(ms) {
  return new Promise((resolve)=>setTimeout(resolve, ms));
}
function readEnvString(name, fallback = "") {
  const value = Deno.env.get(name);
  return value && value.trim() ? value.trim() : fallback;
}
/**
 * Réponse opaque d'échec d'authentification.
 * 
 * IMPORTANT : ne jamais distinguer entre :
 *   - identifiant inconnu
 *   - mot de passe invalide
 *   - email non confirmé
 *   - compte suspendu
 *   - profil corrompu
 * 
 * Toute fuite d'information à ce niveau permettrait l'énumération de comptes,
 * ce qui est inacceptable pour un SIGB anarchiste où l'appartenance au réseau
 * peut être politiquement sensible.
 */ async function genericAuthFailure(reason, context = {}) {
  // Logging interne pour le debug, jamais exposé au client.
  console.log("login-with-identifier: auth failure", {
    reason,
    ...context
  });
  // Délai aléatoire pour brouiller le timing.
  const delay = FAILED_AUTH_MIN_DELAY_MS + Math.floor(Math.random() * (FAILED_AUTH_MAX_DELAY_MS - FAILED_AUTH_MIN_DELAY_MS));
  await sleep(delay);
  return json({
    error: "INVALID_CREDENTIALS"
  }, 401);
}
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return json({
      error: "METHOD_NOT_ALLOWED"
    }, 405);
  }
  try {
    const body = await req.json();
    const identifier = normalizeIdentifier(body?.identifier);
    const password = String(body?.password ?? "");
    // Validation d'entrée : on rejette les requêtes vides immédiatement
    // sans appliquer le délai (économise des ressources, ne fuit rien).
    if (!identifier || !password) {
      return json({
        error: "MISSING_CREDENTIALS"
      }, 400);
    }
    const SUPABASE_URL = readEnvString("SUPABASE_URL");
    const SERVICE_ROLE_KEY = readEnvString("SUPABASE_SERVICE_ROLE_KEY");
    const SUPABASE_ANON_KEY = readEnvString("SUPABASE_ANON_KEY");
    if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
      console.error("login-with-identifier: MISSING_ENV", {
        hasUrl: Boolean(SUPABASE_URL),
        hasServiceRole: Boolean(SERVICE_ROLE_KEY),
        hasAnonKey: Boolean(SUPABASE_ANON_KEY)
      });
      return json({
        error: "MISSING_ENV"
      }, 500);
    }
    // Client admin pour la résolution de profil (lit profiles avec service_role,
    // bypass RLS, ce qui est nécessaire pour résoudre par public_id).
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });
    // Résolution unifiée : email OU public_id, normalisation casse.
    // Cette logique remplace les deux fonctions SQL resolve_login_email
    // (api.* et public.*) qui divergaient.
    const isEmailLike = identifier.includes("@");
    let resolvedEmail = "";
    if (isEmailLike) {
      // Cas 1 : l'utilisateur·rice a tapé un email.
      // On le normalise et on l'utilise directement, sans interroger profiles.
      resolvedEmail = identifier.toLowerCase();
    } else {
      // Cas 2 : c'est un public_id (ou autre identifiant).
      // On résout via profiles, en cherchant insensible à la casse.
      const { data: profile, error: profileLookupError } = await admin.from("profiles").select("id, email").ilike("public_id", identifier).limit(1).maybeSingle();
      if (profileLookupError) {
        console.error("login-with-identifier: profile lookup error", profileLookupError);
        // On ne distingue pas une erreur DB d'un identifiant inconnu côté client.
        return await genericAuthFailure("PROFILE_LOOKUP_ERROR");
      }
      if (!profile?.email) {
        return await genericAuthFailure("PROFILE_NOT_FOUND");
      }
      resolvedEmail = String(profile.email).toLowerCase();
    }
    // Tentative d'authentification réelle avec un client anon
    // (pas service_role : on veut passer par le flow auth normal).
    const auth = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false
      }
    });
    const { data: authData, error: authError } = await auth.auth.signInWithPassword({
      email: resolvedEmail,
      password: password
    });
    if (authError || !authData?.session) {
      return await genericAuthFailure("AUTH_REJECTED", {
        message: authError?.message
      });
    }
    // Succès : on retourne la session pour que le frontend la pose.
    // On NE retourne PAS l'email résolu, le public_id, ou tout autre
    // information qui permettrait de remonter à l'identité réelle.
    console.log("login-with-identifier: success", {
      userId: authData.user?.id
    });
    return json({
      ok: true,
      session: {
        access_token: authData.session.access_token,
        refresh_token: authData.session.refresh_token,
        expires_at: authData.session.expires_at,
        expires_in: authData.session.expires_in,
        token_type: authData.session.token_type
      },
      user: {
        id: authData.user?.id
      }
    });
  } catch (error) {
    console.error("login-with-identifier function crash", error);
    return json({
      error: "LOGIN_FAILED"
    }, 500);
  }
});
