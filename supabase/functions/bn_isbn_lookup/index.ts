import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
function json(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Access-Control-Allow-Methods": "POST, OPTIONS"
    }
  });
}
function mergeCookieStrings(...cookieStrings) {
  const jar = new Map();
  for (const raw of cookieStrings){
    if (!raw) continue;
    const chunks = raw.split(/,(?=[^;]+=[^;]+)/g);
    for (const chunk of chunks){
      const pair = chunk.split(";")[0]?.trim();
      if (!pair) continue;
      const eq = pair.indexOf("=");
      if (eq === -1) continue;
      const name = pair.slice(0, eq).trim();
      const value = pair.slice(eq + 1).trim();
      if (!name) continue;
      jar.set(name, value);
    }
  }
  return Array.from(jar.entries()).map(([k, v])=>`${k}=${v}`).join("; ");
}
function extractSetCookie(headers) {
  return headers.get("set-cookie") || "";
}
function extractAntiForgeryToken(html) {
  const patterns = [
    /name=["']__RequestVerificationToken["'][^>]*value=["']([^"']+)["']/i,
    /value=["']([^"']+)["'][^>]*name=["']__RequestVerificationToken["']/i,
    /window\.AntiForgeryToken\s*=\s*['"]([^'"]+)['"]/i
  ];
  for (const pattern of patterns){
    const match = html.match(pattern);
    if (match?.[1]) return match[1];
  }
  return null;
}
function extractGuid(html) {
  const patterns = [
    /name=["']Guid["'][^>]*value=["']([^"']+)["']/i,
    /id=["']Guid["'][^>]*value=["']([^"']+)["']/i,
    /Resultado\/Listar\?guid=([0-9{}A-Za-z._-]+)/i,
    /MinhaSelecao\?guid=([0-9{}A-Za-z._-]+)/i
  ];
  for (const pattern of patterns){
    const match = html.match(pattern);
    if (match?.[1]) return match[1];
  }
  return null;
}
function isRealGuid(value) {
  if (!value) return false;
  const v = String(value).trim();
  if (!v) return false;
  if (v.includes("{{") || v.includes("}}")) return false;
  return true;
}
function cleanText(value) {
  return value.replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>/gi, "\n").replace(/<\/div>/gi, "\n").replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/\s+\n/g, "\n").replace(/\n\s+/g, "\n").replace(/[ \t]{2,}/g, " ").trim();
}
function extractSearchSummary(html) {
  const match = html.match(/<div>\s*<p>\s*<strong>.*?<\/p>\s*<\/div>/is);
  return match ? cleanText(match[0]) : "";
}
function parseResults(html) {
  const items = [];
  const blocks = html.match(/<div class="col-xs-12 ficha-acervo-detalhe"[\s\S]*?<\/div>\s*<\/div>\s*<\/div>/gi) || [];
  for (const block of blocks){
    const indexMatch = block.match(/<span class="numeracaoItem">(\d+)\.<\/span>/i);
    const titleMatch = block.match(/<p class="titulo"[\s\S]*?<a[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/i);
    const authorMatch = block.match(/<p class="autor"[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i);
    const materialMatch = block.match(/<p class="material"[^>]*>([\s\S]*?)<\/p>/i);
    const locationMatch = block.match(/<p class="localizacao"[\s\S]*?<\/span>([\s\S]*?)<\/p>/i);
    const publicationMatch = block.match(/<p class="publicacao"[\s\S]*?<\/span>([\s\S]*?)<\/p>/i);
    const subjectMatch = block.match(/<p class="assunto"[\s\S]*?<\/span>([\s\S]*?)<\/p>/i);
    if (!titleMatch) continue;
    items.push({
      index: Number(indexMatch?.[1] || items.length + 1),
      title: cleanText(titleMatch[2] || ""),
      author: cleanText(authorMatch?.[1] || ""),
      material: cleanText(materialMatch?.[1] || ""),
      location: cleanText(locationMatch?.[1] || ""),
      publication: cleanText(publicationMatch?.[1] || ""),
      subject: cleanText(subjectMatch?.[1] || ""),
      detail_url: titleMatch[1].startsWith("http") ? titleMatch[1] : `https://acervo.bn.gov.br${titleMatch[1]}`
    });
  }
  return items;
}
serve(async (req)=>{
  if (req.method === "OPTIONS") return json({
    ok: true
  });
  if (req.method !== "POST") return json({
    error: "method not allowed"
  }, 405);
  try {
    const body = await req.json().catch(()=>({}));
    const isbnRaw = String(body?.isbn || "").trim();
    const debug = !!body?.debug;
    const isbn = isbnRaw.replace(/[^0-9Xx]/g, "").toUpperCase();
    if (!isbn) {
      return json({
        error: "isbn missing"
      }, 400);
    }
    const base = "https://acervo.bn.gov.br";
    const searchPageUrl = `${base}/sophia_web/busca/acervo/isbn/`;
    const postUrl = `${base}/Sophia_Web/Busca/RapidaAcervo?bibliotecas=&localizacoes=`;
    const commonHeaders = {
      "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
      "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "accept-language": "pt-BR,pt;q=0.9,en;q=0.8,fr;q=0.7",
      "cache-control": "no-cache",
      "pragma": "no-cache"
    };
    // 1) Open search page
    const pageResp = await fetch(searchPageUrl, {
      method: "GET",
      headers: commonHeaders,
      redirect: "follow"
    });
    const pageHtml = await pageResp.text();
    const pageCookies = extractSetCookie(pageResp.headers);
    const token = extractAntiForgeryToken(pageHtml);
    const extractedGuid = extractGuid(pageHtml);
    const guid = isRealGuid(extractedGuid) ? extractedGuid : Date.now().toString();
    if (!token) {
      return json({
        error: "token not found",
        step: "get_search_page",
        final_url: pageResp.url,
        status: pageResp.status,
        snippet: pageHtml.slice(0, 2500)
      }, 500);
    }
    // 2) Submit search
    const form = new URLSearchParams();
    form.set("__RequestVerificationToken", token);
    form.set("Guid", guid);
    form.set("TipoBuscaRapida", "0");
    form.set("IniciadoCom", "false");
    form.set("PalavraChave", isbn);
    const postResp = await fetch(postUrl, {
      method: "POST",
      headers: {
        ...commonHeaders,
        "content-type": "application/x-www-form-urlencoded",
        "origin": base,
        "referer": `${searchPageUrl}?PalavraChave=${encodeURIComponent(isbn)}`,
        "cookie": mergeCookieStrings(pageCookies)
      },
      body: form.toString(),
      redirect: "manual"
    });
    const postCookies = extractSetCookie(postResp.headers);
    const mergedCookies = mergeCookieStrings(pageCookies, postCookies);
    const location = postResp.headers.get("location");
    let resultUrl = "";
    if (location) {
      resultUrl = location.startsWith("http") ? location : `${base}${location}`;
    } else {
      const postText = await postResp.text();
      const responseGuid = extractGuid(postText);
      if (isRealGuid(responseGuid)) {
        resultUrl = `${base}/Sophia_Web/Resultado/Listar?guid=${responseGuid}`;
      }
    }
    if (!resultUrl) {
      return json({
        error: "result url not found",
        step: "post_search",
        post_status: postResp.status,
        request_guid: guid,
        extracted_guid_from_get: extractedGuid,
        location: location || null
      }, 500);
    }
    // 3) Fetch result page WITH SAME SESSION
    const resultResp = await fetch(resultUrl, {
      method: "GET",
      headers: {
        ...commonHeaders,
        "referer": `${searchPageUrl}?PalavraChave=${encodeURIComponent(isbn)}`,
        "cookie": mergedCookies
      },
      redirect: "follow"
    });
    const resultHtml = await resultResp.text();
    if (/Sess[aã]o expirada/i.test(resultHtml)) {
      return json({
        error: "session expired on result fetch",
        step: "get_results",
        result_url: resultUrl,
        status: resultResp.status,
        snippet: resultHtml.slice(0, 2500)
      }, 500);
    }
    const summary = extractSearchSummary(resultHtml);
    const results = parseResults(resultHtml);
    return json({
      ok: true,
      isbn,
      result_url: resultUrl,
      total: results.length,
      summary,
      results,
      ...debug ? {
        debug: {
          search_page_status: pageResp.status,
          post_status: postResp.status,
          result_status: resultResp.status,
          request_guid: guid,
          extracted_guid_from_get: extractedGuid,
          token_preview: token.slice(0, 20)
        }
      } : {}
    });
  } catch (error) {
    return json({
      error: "unexpected error",
      message: error instanceof Error ? error.message : String(error)
    }, 500);
  }
});
