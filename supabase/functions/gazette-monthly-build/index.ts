// CHEMIN DÉPÔT : supabase/functions/gazette-monthly-build/index.ts
//
// Pipeline mensuel de la Gazette, SANS GitHub Actions : orchestré par pg_cron (cf. migration
// gazette_automation_jobs.sql). Conçu en ÉTAPES pour tenir dans le temps d'exécution d'une EF :
// chaque appel fait UNE étape, l'état vit dans public.gazette_build_jobs, et le cron
// "reconcile-gazette-dispatch" (*/5 min) rappelle l'EF jusqu'à status='ready'.
//
// Étapes : start → curate (FR) → translate (1 locale/appel) → assemble_reseau → finalize.
//
// TROIS MODES DE FABRICATION, portés par gazette_issues.build_mode et déclarés
// tels quels dans le colophon public de chaque numéro :
//   • 'assisted' : les brèves sont rédigées par un modèle à partir des flux ;
//   • 'revue'    : REPRISE de presse déterministe — titre et chapô tels que la
//                  source les a publiés, sans réécriture, rangés par la rubrique
//                  que le staff a donnée au flux. Aucun appel à un modèle ;
//   • 'manual'   : rien que ce que des membres ont écrit (contributions).
// Les modes 'revue' et 'manual' passent par composerDeterministe().
//
// L'ÉDITORIAL N'EST JAMAIS ÉCRIT PAR LA MACHINE, quel que soit le mode (article 1
// de la charte technique) : il vient d'une contribution rubric='une' acceptée par
// le staff. S'il n'y en a pas, le numéro sort sans édito et le staff est prévenu.
// IMPORTANT : produit un BROUILLON (issue.status='draft'). La publication reste manuelle
// (network_staff, après relecture). La page « Réseau » n'est PAS générée depuis les sources :
// elle est assemblée à partir des contributions acceptées (gazette_submissions.status='accepted').
// Corollaire : l'étape 'start' REFUSE un numéro qui n'est plus un brouillon (cf. stepStart).
// Le pipeline se rejoue étape par étape sur un brouillon, jamais sur un numéro paru.
//
// Déploiement : supabase functions deploy gazette-monthly-build --no-verify-jwt
// Secrets requis : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (défaut), ANTHROPIC_API_KEY.
// Appel protégé par un en-tête partagé X-Cron-Secret == secret GAZETTE_CRON_SECRET.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const LOCALES = ["pt-BR","fr","es","en","it","de","el","ca","eo","nl"];
const TRANSLATE_TARGETS = LOCALES.filter((l) => l !== "fr"); // fr = original curé
// Repli si la table gazette_sources est vide / inaccessible.
const FALLBACK_SOURCES = [
  { id: null as string | null, name: "Info Libertaire", feed: "https://www.infolibertaire.net/feed/" },
  { id: null as string | null, name: "Notícias Anarquistas (ANA)", feed: "https://noticiasanarquistas.noblogs.org/feed/" },
];

// Sources actives lues depuis le registre éditable par network_staff (table gazette_sources).
async function loadSources() {
  const { data, error } = await sb.from("gazette_sources")
    .select("id,name,feed_url").eq("active", true).order("locale");
  if (error || !data || data.length === 0) return FALLBACK_SOURCES;
  return data.map((s) => ({ id: s.id as string, name: s.name as string, feed: s.feed_url as string }));
}
const ANTHROPIC_MODEL = "claude-opus-4-8"; // ajuster si besoin
const sb = createClient(
  Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

// ---------- utilitaires ----------
function issueForToday() {
  const d = new Date();
  const ym = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
  // numéro = nb de mois depuis le n°01 (juin 2026) ; ajuster la base si besoin.
  const base = new Date(Date.UTC(2026, 5, 1)); // juin 2026 = n°01
  const number = (d.getUTCFullYear() - base.getUTCFullYear()) * 12 + (d.getUTCMonth() - base.getUTCMonth()) + 1;
  return { number, slug: `n${String(number).padStart(2, "0")}-${ym}`, cover_date: `${ym}-15` };
}

async function fetchFeedItems(feedUrl: string, limit = 12) {
  const res = await fetch(feedUrl, { headers: { "User-Agent": "AnarBib-Gazette/1.0" } });
  const xml = await res.text();
  const items: { title: string; link: string; date?: string; summary?: string }[] = [];
  for (const m of xml.matchAll(/<item[\s\S]*?<\/item>/g)) {
    const block = m[0];
    const pick = (tag: string) => {
      const r = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`).exec(block);
      return r ? r[1].replace(/<!\[CDATA\[|\]\]>/g, "").replace(/<[^>]+>/g, "").trim() : undefined;
    };
    const title = pick("title"); const link = pick("link");
    if (title && link) items.push({ title, link, date: pick("pubDate"), summary: pick("description")?.slice(0, 400) });
    if (items.length >= limit) break;
  }
  return items;
}

async function claude(system: string, user: string): Promise<string> {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL, max_tokens: 8000, system,
      messages: [{ role: "user", content: user }],
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error("anthropic: " + JSON.stringify(j).slice(0, 300));
  return j.content?.[0]?.text ?? "";
}
function parseJsonBlock(s: string) {
  const a = s.indexOf("["); const b = s.lastIndexOf("]");
  const o1 = s.indexOf("{"); const o2 = s.lastIndexOf("}");
  const start = a >= 0 && (o1 < 0 || a < o1) ? a : o1;
  const end = a >= 0 && (o1 < 0 || a < o1) ? b : o2;
  return JSON.parse(s.slice(start, end + 1));
}

// Schéma de blocs attendu (identique au gabarit front / au n°01).
const SCHEMA_DOC = `
Le "content" est un tableau de pages. Pages attendues, dans l'ordre :
1) {"sec":"La Une","blocks":[{type:"toc",title,items:[["1","…"],…]},{type:"lead",label,h,p[],src}]}
3) {"sec":"Luttes & mouvements","blocks":[{type:"art",h,p[],src}, …]}
4) {"sec":"International","blocks":[{type:"art",h,p[],src}, …]}
5) {"sec":"Cultures & idées","blocks":[{type:"art",h,p[],src}, …]}
6) {"sec":"Agenda & entraide","blocks":[{type:"agenda",h,items:[["date — lieu","desc"],…]},{type:"support",h,items:[["label ","desc"],…]},{type:"colophon",p}]}
NE PAS produire la page 2 "Vie du réseau" : elle est assemblée séparément depuis les contributions.
NE PAS produire de bloc "edito" : l'éditorial est écrit par des membres du réseau et inséré à part.
HTML minimal autorisé dans les textes : <b>…</b>. Toujours renseigner "src" (source) sur les brèves.`;

// ---------- composition sans modèle ----------
// Tout ce qui suit ne fait qu'assembler des textes déjà écrits par des humains :
// les mots que les sources ont elles-mêmes publiés, et ceux que les collectifs
// ont envoyés. Rien n'y est rédigé.

const RUBRIQUES = [
  { key: "luttes", sec: "Luttes & mouvements" },
  { key: "international", sec: "International" },
  { key: "cultures", sec: "Cultures & idées" },
];
const PAR_RUBRIQUE = 4; // reprises par page, les plus récentes

async function buildMode(number: number): Promise<string> {
  const { data } = await sb.from("gazette_issues").select("build_mode").eq("number", number).single();
  return (data?.build_mode as string) ?? "assisted";
}

function horodatage(d?: string): number {
  const t = d ? Date.parse(d) : NaN;
  return Number.isNaN(t) ? 0 : t;
}

// On reprend les mots de la source, donc on ne les coupe pas au milieu : on
// s'arrête à la fin de phrase la plus proche, sinon au dernier mot entier.
function chapo(texte: string, max = 340): string {
  const t = String(texte ?? "").replace(/\s+/g, " ").trim();
  if (t.length <= max) return t;
  const bout = t.slice(0, max);
  const fin = Math.max(bout.lastIndexOf(". "), bout.lastIndexOf("! "), bout.lastIndexOf("? "));
  if (fin > max * 0.5) return bout.slice(0, fin + 1).trim();
  const esp = bout.lastIndexOf(" ");
  return (esp > 0 ? bout.slice(0, esp) : bout).trim() + "…";
}

function paragraphes(corps: string): string[] {
  return String(corps ?? "").split(/\n\s*\n/).map((x) => x.trim()).filter(Boolean);
}

// L'éditorial vient du réseau, jamais de la machine : la contribution rubric='une'
// acceptée la plus récente. La signature est celle du collectif qui l'a envoyée.
async function editoDuNumero(): Promise<{ id: string; bloc: unknown } | null> {
  const { data } = await sb.from("gazette_submissions")
    .select("id,title,body,contributor_name,contributor_collective")
    .eq("rubric", "une").eq("status", "accepted")
    .order("created_at", { ascending: false }).limit(1);
  const s = data?.[0] as Record<string, string> | undefined;
  if (!s) return null;
  return {
    id: s.id,
    bloc: {
      type: "edito", label: "Éditorial", h: s.title,
      byline: s.contributor_collective || s.contributor_name || "L'équipe d'AnarBib",
      p: paragraphes(s.body),
    },
  };
}

// Compose les 5 pages du corps (la page « Vie du réseau » est insérée plus tard).
// avecFlux=false → mode 'manual' : on ne garde que les contributions.
async function composerDeterministe(sources: Record<string, unknown>, avecFlux: boolean) {
  const consumed: string[] = [];

  // La rubrique d'un flux est le SEUL arbitrage éditorial du mode déterministe,
  // et il a été fait à la main, une fois, dans l'écran « Sources ».
  const { data: srcRows } = await sb.from("gazette_sources").select("name,rubric").eq("active", true);
  const rubriqueDe = new Map<string, string>(
    (srcRows ?? []).map((r: Record<string, string>) => [r.name, r.rubric || "luttes"]),
  );

  const vus = new Set<string>();
  const reprises: Record<string, unknown>[] = [];
  if (avecFlux) {
    for (const [nom, liste] of Object.entries(sources ?? {})) {
      for (const it of (liste ?? []) as Record<string, string>[]) {
        if (!it?.title || !it?.link || vus.has(it.link)) continue;
        vus.add(it.link);
        reprises.push({
          titre: it.title, lien: it.link, chapo: it.summary ?? "",
          date: horodatage(it.date), source: nom,
          rubrique: rubriqueDe.get(nom) ?? "luttes",
        });
      }
    }
    reprises.sort((a, b) => (b.date as number) - (a.date as number));
  }

  const { data: contribs } = await sb.from("gazette_submissions")
    .select("id,rubric,title,body,link")
    .in("rubric", RUBRIQUES.map((r) => r.key))
    .eq("status", "accepted").order("created_at");

  const blocContrib = (c: Record<string, string>) => {
    consumed.push(c.id);
    return { type: "art", h: c.title, p: paragraphes(c.body), ...(c.link ? { src: c.link } : {}) };
  };
  const blocReprise = (r: Record<string, unknown>) => ({
    type: "art", h: r.titre, p: [chapo(r.chapo as string)], src: `${r.source} — ${r.lien}`,
  });

  // La Une : l'édito humain, le sommaire (inséré après coup), puis la reprise
  // la plus récente du mois — règle déterministe, aucune main sur la balance.
  // Conséquence assumée : la rubrique qui fournit la Une la perd de sa page, et
  // sa page saute si c'était sa seule reprise. Le sujet n'est pas perdu, il est
  // en meilleure place ; le sommaire est calculé sur les pages réellement là.
  const blocsUne: unknown[] = [];
  const edito = await editoDuNumero();
  if (edito) { blocsUne.push(edito.bloc); consumed.push(edito.id); }
  const une = avecFlux ? reprises.shift() : undefined;
  if (une) {
    blocsUne.push({
      type: "lead", label: "À la une", h: une.titre,
      p: [chapo(une.chapo as string, 620)], src: `${une.source} — ${une.lien}`,
    });
  }
  const pages: Record<string, unknown>[] = [{ sec: "La Une", blocks: blocsUne }];

  // Les contributions de membres passent AVANT les reprises : ce sont des textes
  // du réseau, pas des extraits de presse.
  for (const r of RUBRIQUES) {
    const blocs = [
      ...(contribs ?? []).filter((c: Record<string, string>) => c.rubric === r.key).map(blocContrib),
      ...reprises.filter((x) => x.rubrique === r.key).slice(0, PAR_RUBRIQUE).map(blocReprise),
    ];
    if (blocs.length) pages.push({ sec: r.sec, blocks: blocs });
  }

  // L'agenda ne vient jamais des flux : uniquement des contributions datées.
  const { data: agenda } = await sb.from("gazette_submissions")
    .select("id,title,body,event_date").eq("rubric", "agenda").eq("status", "accepted")
    .order("event_date", { ascending: true });
  if (agenda?.length) {
    pages.push({
      sec: "Agenda & entraide",
      blocks: [{
        type: "agenda", h: "Agenda",
        items: (agenda as Record<string, string>[]).map((a) => {
          consumed.push(a.id);
          return [a.event_date ? `${a.event_date} — ${a.title}` : a.title, a.body ?? ""];
        }),
      }],
    });
  }

  // Sommaire : « Vie du réseau » y figure en 2 alors qu'elle sera insérée plus
  // tard par stepAssembleReseau — d'où le décalage de deux crans ensuite.
  const sommaire: string[][] = [["1", "La Une"], ["2", "Vie du réseau"]];
  pages.slice(1).forEach((pg, i) => sommaire.push([String(i + 3), pg.sec as string]));
  blocsUne.splice(edito ? 1 : 0, 0, { type: "toc", title: "Au sommaire", items: sommaire });

  return { pages, consumed };
}

// ---------- étapes ----------
async function stepStart() {
  const { number, slug, cover_date } = issueForToday();

  const { data: dejaLa } = await sb.from("gazette_issues")
    .select("status,build_mode").eq("number", number).maybeSingle();

  // Un numéro DÉJÀ PARU ne se refabrique pas. L'upsert plus bas réécrit
  // status='draft' sans condition : relancé sur un numéro en ligne, il le
  // DÉPUBLIE en silence — la vue publique api.gazette_locales_public_v1 ne
  // sert que les i.status='published' — puis curate/translate en écrasent le
  // contenu. Le cron du 15 calcule un numéro neuf chaque mois, donc le cas ne
  // vient que d'une relance à la main ou d'un rattrapage après un build raté
  // dans le même mois — soit exactement les moments où on appellera 'start'.
  // On refuse AVANT le moindre écrit : ni gazette_issues, ni gazette_build_jobs
  // (qui redémarrerait le pipeline), ni les horodatages de gazette_sources.
  // 'archived' est refusé au même titre que 'published' : ce numéro-là a paru,
  // le rejouer en écraserait le contenu. Sur un brouillon (ou un numéro qui
  // n'existe pas encore), rien ne change : l'étape reste idempotente.
  const etatActuel = dejaLa?.status as string | undefined;
  if (etatActuel && etatActuel !== "draft") {
    throw new Error(
      `gazette n°${number} : refus de (re)fabriquer, le numéro est en ` +
      `status='${etatActuel}' et non 'draft'. Rien n'a été touché. Pour le ` +
      `refaire, repasser d'abord le numéro en brouillon à la main.`,
    );
  }

  // Le mode de fabrication se REPORTE d'un numéro à l'autre : un mandat du réseau
  // n'a pas à être resaisi chaque mois. On respecte celui déjà posé sur ce numéro
  // (le staff a pu le changer sur le brouillon), sinon on reprend celui du numéro
  // précédent, sinon 'assisted' — l'état d'avant cette bascule.
  let build_mode = dejaLa?.build_mode as string | undefined;
  if (!build_mode) {
    const { data: precedent } = await sb.from("gazette_issues")
      .select("build_mode").lt("number", number)
      .order("number", { ascending: false }).limit(1).maybeSingle();
    build_mode = (precedent?.build_mode as string) ?? "assisted";
  }

  await sb.from("gazette_issues").upsert(
    { number, slug, masthead_title: "Rizoma — la gazette du réseau AnarBib", cover_date, status: "draft", build_mode },
    { onConflict: "number" },
  );
  const sources: Record<string, unknown> = {};
  for (const s of await loadSources()) {
    try {
      const items = await fetchFeedItems(s.feed);
      sources[s.name] = items;
      const newest = items.map((i) => i.date).filter(Boolean)
        .map((d) => new Date(d as string).getTime()).sort((a, b) => b - a)[0];
      if (s.id) await sb.from("gazette_sources").update({
        last_fetched_at: new Date().toISOString(),
        last_item_at: newest ? new Date(newest).toISOString() : null,
        last_status: items.length ? "ok" : "empty", last_error: null,
      }).eq("id", s.id);
    } catch (e) {
      sources[s.name] = [];
      if (s.id) await sb.from("gazette_sources").update({
        last_fetched_at: new Date().toISOString(), last_status: "error", last_error: String(e).slice(0, 500),
      }).eq("id", s.id);
    }
  }
  await sb.from("gazette_build_jobs").upsert(
    { issue_number: number, status: "curating", sources, step_error: null },
    { onConflict: "issue_number" },
  );
  return { number, status: "curating", build_mode };
}

async function stepCurate(number: number) {
  const { data: job } = await sb.from("gazette_build_jobs").select("sources").eq("issue_number", number).single();
  const mode = await buildMode(number);

  // Modes déterministes : on n'ouvre même pas la connexion au modèle.
  // translation_status='original' — ce français-là n'est pas une traduction, et
  // il n'a pas été écrit par une machine.
  if (mode === "revue" || mode === "manual") {
    const { pages, consumed } = await composerDeterministe(
      (job?.sources ?? {}) as Record<string, unknown>, mode === "revue",
    );
    await upsertLocale(number, "fr", pages, "original", null);
    await sb.from("gazette_build_jobs")
      .update({ status: "translating", cursor_locale: TRANSLATE_TARGETS[0], consumed_ids: consumed })
      .eq("issue_number", number);
    return { status: "translating", next: TRANSLATE_TARGETS[0], mode, pages: pages.length };
  }

  const system =
    `Tu es l'équipe éditoriale d'AnarBib, gazette de bibliothèques anarchistes. Tu rédiges en FRANÇAIS, ` +
    `registre militant mais sobre, des digests fidèles (sans inventer) à partir d'extraits de flux. ` +
    `Tu produis UNIQUEMENT un JSON valide (le tableau "content"). ${SCHEMA_DOC}`;
  const user = `Voici les articles récents (sélectionne les ~12-14 plus pertinents, répartis dans les rubriques) :\n` +
    JSON.stringify(job!.sources).slice(0, 24000) +
    `\n\nRends le tableau "content" (5 pages : Une, Luttes, International, Cultures, Agenda). Pas de page Réseau.`;
  const pages = parseJsonBlock(await claude(system, user));
  // Même en mode assisté, l'éditorial reste humain : le gabarit interdit au
  // modèle d'en produire un, et on insère ici celui du réseau s'il existe.
  const consumed: string[] = [];
  const edito = await editoDuNumero();
  if (edito && Array.isArray(pages?.[0]?.blocks)) {
    pages[0].blocks.unshift(edito.bloc);
    consumed.push(edito.id);
  }
  await upsertLocale(number, "fr", pages, "machine", null);
  await sb.from("gazette_build_jobs")
    .update({ status: "translating", cursor_locale: TRANSLATE_TARGETS[0], consumed_ids: consumed })
    .eq("issue_number", number);
  return { status: "translating", next: TRANSLATE_TARGETS[0], mode };
}

async function stepTranslate(number: number) {
  const { data: job } = await sb.from("gazette_build_jobs").select("cursor_locale").eq("issue_number", number).single();
  const target = job!.cursor_locale as string;
  const { data: fr } = await sb.from("gazette_issue_locales")
    .select("content").eq("issue_id", (await issueId(number))).eq("locale", "fr").single();
  const system = `Tu traduis fidèlement du français vers la locale "${target}" un JSON de gazette anarchiste. ` +
    `Conserve EXACTEMENT la structure et les clés. Ne traduis pas les noms propres ni les sources (src). ` +
    `Conserve les balises <b>…</b>. Rends UNIQUEMENT le JSON traduit.`;
  const pages = parseJsonBlock(await claude(system, JSON.stringify(fr!.content)));
  await upsertLocale(number, target, pages, "machine", "fr");
  const idx = TRANSLATE_TARGETS.indexOf(target);
  const next = TRANSLATE_TARGETS[idx + 1] ?? null;
  await sb.from("gazette_build_jobs").update(
    next ? { cursor_locale: next } : { status: "assembling", cursor_locale: null },
  ).eq("issue_number", number);
  return { translated: target, next };
}

// Page « Réseau » assemblée depuis les contributions acceptées (rubric='reseau'),
// LOCALISÉE par locale grâce aux traductions title_i18n / body_i18n des brèves.
async function stepAssembleReseau(number: number) {
  const F: Record<string, { sec: string; intro: string; cta: string; ctp: string }> = {
    "fr":   { sec:"Vie du réseau",      intro:"Cette page appartient aux membres d'AnarBib — collectifs, bibliothèques, distros et individus.", cta:"▸ Proposez vos brèves",          ctp:"Cette page est la vôtre. Transmettez vos nouvelles via l'application." },
    "pt-BR":{ sec:"Vida da rede",       intro:"Esta página pertence aos membros da AnarBib — coletivos, bibliotecas, distros e indivíduos.",   cta:"▸ Envie suas notas",            ctp:"Esta página é sua. Envie suas notícias pelo aplicativo." },
    "es":   { sec:"Vida de la red",     intro:"Esta página pertenece a las y los miembros de AnarBib — colectivos, bibliotecas, distros e individuos.", cta:"▸ Proponed vuestras breves", ctp:"Esta página es la vuestra. Transmitid vuestras noticias a través de la aplicación." },
    "en":   { sec:"Network life",       intro:"This page belongs to AnarBib's members — collectives, libraries, distros and individuals.",  cta:"▸ Submit your bulletins",       ctp:"This page is yours. Send your news via the app." },
    "it":   { sec:"Vita della rete",    intro:"Questa pagina appartiene ai membri di AnarBib — collettivi, biblioteche, distro e individui.",  cta:"▸ Proponete le vostre brevi",   ctp:"Questa pagina è la vostra. Trasmettete le vostre notizie tramite l'applicazione." },
    "de":   { sec:"Leben des Netzwerks",intro:"Diese Seite gehört den Mitgliedern von AnarBib — Kollektiven, Bibliotheken, Distros und Einzelpersonen.", cta:"▸ Schlagt eure Kurzmeldungen vor", ctp:"Diese Seite ist die eure. Übermittelt eure Nachrichten über die Anwendung." },
    "el":   { sec:"Ζωή του δικτύου",     intro:"Αυτή η σελίδα ανήκει στα μέλη της AnarBib — συλλογικότητες, βιβλιοθήκες, ντίστρο και άτομα.", cta:"▸ Προτείνετε τα σύντομα νέα σας", ctp:"Αυτή η σελίδα είναι δική σας. Μεταδώστε τα νέα σας μέσω της εφαρμογής." },
    "ca":   { sec:"Vida de la xarxa",   intro:"Aquesta pàgina pertany als membres d'AnarBib — col·lectius, biblioteques, distros i individus.", cta:"▸ Proposeu les vostres breus",  ctp:"Aquesta pàgina és la vostra. Transmeteu les vostres notícies via l'aplicació." },
    "eo":   { sec:"Vivo de la reto",    intro:"Ĉi tiu paĝo apartenas al la membroj de AnarBib — kolektivoj, bibliotekoj, distroj kaj individuoj.", cta:"▸ Proponu viajn novaĵetojn",   ctp:"Ĉi tiu paĝo estas la via. Transdonu viajn novaĵojn per la aplikaĵo." },
    "nl":   { sec:"Leven van het netwerk", intro:"Deze pagina behoort toe aan de leden van AnarBib — collectieven, bibliotheken, distro's en individuen.", cta:"▸ Dien jullie korte berichten in", ctp:"Deze pagina is de jouwe. Bezorg ons jullie nieuws via de applicatie." },
  };
  const { data: subs } = await sb.from("gazette_submissions")
    .select("id,title,body,link,title_i18n,body_i18n").eq("rubric", "reseau")
    .eq("status", "accepted").order("created_at", { ascending: true });
  const id = await issueId(number);
  const { data: rows } = await sb.from("gazette_issue_locales").select("locale,content").eq("issue_id", id);
  for (const r of rows ?? []) {
    const loc = r.locale as string;
    const f = F[loc] ?? F["fr"];
    const blocks: any[] = (subs ?? []).map((s: any) => ({
      type: "art",
      h: (s.title_i18n && s.title_i18n[loc]) || s.title,
      p: [(s.body_i18n && s.body_i18n[loc]) || s.body],
      src: s.link ?? undefined,
    }));
    blocks.push({ type: "callout", h: f.cta, p: [f.ctp] });
    const reseauPage = { sec: f.sec, intro: f.intro, blocks };
    const pages = r.content as any[];
    const withReseau = [pages[0], reseauPage, ...pages.slice(1)];
    await sb.from("gazette_issue_locales").update({ content: withReseau }).eq("issue_id", id).eq("locale", loc);
  }
  // Les brèves reprises rejoignent le registre du numéro : stepFinalize les
  // sortira du vivier pour qu'elles ne reviennent pas le mois prochain.
  const { data: jobRow } = await sb.from("gazette_build_jobs")
    .select("consumed_ids").eq("issue_number", number).single();
  const dejaVues = Array.isArray(jobRow?.consumed_ids) ? (jobRow!.consumed_ids as string[]) : [];
  const consumed = [...new Set([...dejaVues, ...(subs ?? []).map((s: { id: string }) => s.id)])];
  await sb.from("gazette_build_jobs")
    .update({ status: "finalizing", consumed_ids: consumed }).eq("issue_number", number);
  return { reseau_localised: (rows ?? []).length, contributions: consumed.length };
}

async function stepFinalize(number: number) {
  const { data: job } = await sb.from("gazette_build_jobs")
    .select("consumed_ids").eq("issue_number", number).single();
  const ids = Array.isArray(job?.consumed_ids) ? (job!.consumed_ids as string[]) : [];
  // Sans ce passage à 'published', une brève acceptée reviendrait à l'identique
  // dans tous les numéros suivants — le vivier n'était jamais vidé.
  if (ids.length) {
    await sb.from("gazette_submissions").update({ status: "published" }).in("id", ids);
  }

  // Le staff doit savoir s'il manque un éditorial : la machine n'en écrira pas.
  const { data: fr } = await sb.from("gazette_issue_locales")
    .select("content").eq("issue_id", await issueId(number)).eq("locale", "fr").single();
  const pages = (fr?.content ?? []) as { blocks?: { type?: string }[] }[];
  const aEdito = Array.isArray(pages)
    && (pages[0]?.blocks ?? []).some((b) => b?.type === "edito");

  // Notifie network_staff qu'un brouillon est prêt à relire (NE publie pas).
  await sb.from("gazette_submission_notification_outbox").insert({
    event: "gazette.draft.ready_for_review",
    payload: {
      issue_number: number, to_role: "network_staff",
      mode: await buildMode(number), contributions_reprises: ids.length, edito: aEdito,
      message: aEdito
        ? `Brouillon de la Gazette n°${number} prêt à relire et publier.`
        : `Brouillon de la Gazette n°${number} prêt à relire — SANS ÉDITORIAL : `
          + `aucune contribution « Une » acceptée. L'éditorial ne peut pas être `
          + `écrit par la machine ; envoyez-en un avant de publier.`,
    },
  });
  await sb.from("gazette_build_jobs").update({ status: "ready" }).eq("issue_number", number);
  return { status: "ready", edito: aEdito, contributions_reprises: ids.length };
}

async function issueId(number: number): Promise<string> {
  const { data } = await sb.from("gazette_issues").select("id").eq("number", number).single();
  return data!.id;
}

// Bandeau localisé et NEUTRE (jamais le mot "brouillon" dans le contenu : l'état
// brouillon est porté uniquement par gazette_issues.status, affiché en badge côté
// panel network_staff). Même style que le n°01 (taglines + préfixe numérique par locale).
// `tagline` = sous-titre localisé de la gazette (bug #tagline-fr-2026-08 : il était
// codé « La gazette du réseau » en dur pour toutes les locales dans upsertLocale).
const MASTHEAD_I18N: Record<string, { left: string; right: string; numPrefix: string; tagline: string }> = {
  "fr":    { left: "Réseau libre — autogéré",              right: "Diffusion libre ✳ Copiez-Partagez",         numPrefix: "N°",     tagline: "La gazette du réseau" },
  "pt-BR": { left: "Rede livre — autogerida",               right: "Difusão livre ✳ Copie-Compartilhe",         numPrefix: "N.º ",   tagline: "A gazeta da rede" },
  "es":    { left: "Red libre — autogestionada",            right: "Difusión libre ✳ Copia-Comparte",           numPrefix: "N.º ",   tagline: "La gaceta de la red" },
  "en":    { left: "Free network — self-managed",           right: "Free distribution ✳ Copy-Share",            numPrefix: "No. ",   tagline: "The network gazette" },
  "it":    { left: "Rete libera — autogestita",              right: "Diffusione libera ✳ Copiate-Condividete",   numPrefix: "N. ",    tagline: "La gazzetta della rete" },
  "de":    { left: "Freies Netzwerk — selbstverwaltet",      right: "Freie Verbreitung ✳ Kopiert-Teilt",         numPrefix: "Nr. ",   tagline: "Die Gazette des Netzwerks" },
  "el":    { left: "Ελεύθερο δίκτυο — αυτοδιαχειριζόμενο",   right: "Ελεύθερη διάδοση ✳ Αντιγράψτε-Μοιραστείτε",  numPrefix: "Αρ. ",   tagline: "Η εφημερίδα του δικτύου" },
  "ca":    { left: "Xarxa lliure — autogestionada",          right: "Difusió lliure ✳ Copieu-Compartiu",         numPrefix: "Núm. ",  tagline: "La gaseta de la xarxa" },
  "eo":    { left: "Libera reto — memmastrumata",            right: "Libera disvastigo ✳ Kopiu-Kunhavigu",       numPrefix: "N-ro ",  tagline: "La gazeto de la reto" },
  "nl":    { left: "Vrij netwerk — zelfbeheerd",             right: "Vrije verspreiding ✳ Kopieer-Deel",         numPrefix: "Nr. ",   tagline: "De gazette van het netwerk" },
};
function buildMasthead(locale: string, number: number, coverDate: string) {
  const m = MASTHEAD_I18N[locale] ?? MASTHEAD_I18N["fr"];
  const monthYear = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" })
    .format(new Date(`${coverDate}T00:00:00Z`));
  const mid = `${m.numPrefix}${String(number).padStart(2, "0")} · ${monthYear.charAt(0).toUpperCase()}${monthYear.slice(1)}`;
  return { left: m.left, right: m.right, mid };
}

async function upsertLocale(number: number, locale: string, content: unknown, tstatus: string, src: string | null) {
  const { data: issue } = await sb.from("gazette_issues").select("id,cover_date").eq("number", number).single();
  const id = issue!.id as string;
  const masthead = buildMasthead(locale, number, issue!.cover_date as string);
  // Le modèle renvoie parfois {"content":[…]} (ou {"pages":[…]}) au lieu du tableau
  // nu de pages attendu par TOUS les consommateurs (GazetteTab public, aperçu
  // GazetteStaffPanel, et stepAssembleReseau qui fait content.slice()). On dé-emballe
  // pour toujours stocker content = tableau de pages.
  const co = content as Record<string, unknown> | null;
  const pages = Array.isArray(content) ? content
    : (co && Array.isArray(co.content)) ? co.content
    : (co && Array.isArray(co.pages)) ? co.pages
    : content;
  const tagline = (MASTHEAD_I18N[locale] ?? MASTHEAD_I18N["fr"]).tagline;
  await sb.from("gazette_issue_locales").upsert(
    { issue_id: id, locale, tagline, masthead, content: pages,
      translation_status: tstatus, source_locale: src },
    { onConflict: "issue_id,locale" },
  );
}

// ---------- routeur ----------
Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("GAZETTE_CRON_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const { step, issue_number } = await req.json().catch(() => ({ step: "tick" }));
  try {
    // "tick" : avance le job courant d'une étape (utilisé par le cron reconcile).
    let s = step, n = issue_number;
    if (s === "tick") {
      const { data: job } = await sb.from("gazette_build_jobs")
        .select("issue_number,status").not("status", "in", "(ready,failed)")
        .order("issue_number", { ascending: false }).limit(1).maybeSingle();
      if (!job) return Response.json({ idle: true });
      n = job.issue_number;
      s = ({ curating: "curate", translating: "translate", assembling: "assemble_reseau",
             finalizing: "finalize" } as Record<string, string>)[job.status] ?? "noop";
    }
    let out;
    if (s === "start") out = await stepStart();
    else if (s === "curate") out = await stepCurate(n);
    else if (s === "translate") out = await stepTranslate(n);
    else if (s === "assemble_reseau") out = await stepAssembleReseau(n);
    else if (s === "finalize") out = await stepFinalize(n);
    else out = { noop: true };
    return Response.json({ ok: true, step: s, ...out });
  } catch (e) {
    if (issue_number) await sb.from("gazette_build_jobs")
      .update({ status: "failed", step_error: String(e) }).eq("issue_number", issue_number);
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
