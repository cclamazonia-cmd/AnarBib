const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};
function json(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      ...CORS,
      'Content-Type': 'application/json; charset=utf-8'
    }
  });
}
function cleanText(html) {
  return html.replace(/<script[\s\S]*?<\/script>/gi, '').replace(/<style[\s\S]*?<\/style>/gi, '').replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/\s+/g, ' ').trim();
}
function extractTag(xml, tag) {
  const re = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i');
  const m = xml.match(re);
  return m ? cleanText(m[1]) : '';
}
function extractAllTags(xml, tag) {
  const re = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'gi');
  const results = [];
  let m;
  while((m = re.exec(xml)) !== null)results.push(m[1]);
  return results;
}
function extractAttr(tag, attr) {
  const re = new RegExp(`${attr}=["']([^"']*)["']`, 'i');
  const m = tag.match(re);
  return m ? m[1] : '';
}
// ── RSS/Atom parser ───────────────────────────────────────
function parseRssFeed(xml) {
  const isAtom = /<feed[\s>]/i.test(xml);
  const feedTitle = extractTag(xml, isAtom ? 'title' : 'title');
  const feedLink = isAtom ? xml.match(/<link[^>]*rel=["']alternate["'][^>]*href=["']([^"']+)["']/i)?.[1] || extractTag(xml, 'link') || '' : extractTag(xml, 'link');
  const items = [];
  if (isAtom) {
    const entries = extractAllTags(xml, 'entry');
    for (const entry of entries){
      items.push({
        title: extractTag(entry, 'title'),
        link: entry.match(/<link[^>]*href=["']([^"']+)["']/i)?.[1] || '',
        author: extractTag(entry, 'name') || extractTag(entry, 'author'),
        date: extractTag(entry, 'updated') || extractTag(entry, 'published'),
        summary: cleanText(extractTag(entry, 'summary') || extractTag(entry, 'content')).slice(0, 300),
        category: extractTag(entry, 'category') || entry.match(/<category[^>]*term=["']([^"']+)["']/i)?.[1] || ''
      });
    }
  } else {
    const channelMatch = xml.match(/<channel[\s\S]*<\/channel>/i);
    const channel = channelMatch ? channelMatch[0] : xml;
    const rawItems = extractAllTags(channel, 'item');
    for (const item of rawItems){
      items.push({
        title: extractTag(item, 'title'),
        link: extractTag(item, 'link'),
        author: extractTag(item, 'author') || extractTag(item, 'dc:creator') || extractTag(item, 'creator'),
        date: extractTag(item, 'pubDate') || extractTag(item, 'dc:date') || extractTag(item, 'date'),
        summary: cleanText(extractTag(item, 'description')).slice(0, 300),
        category: extractTag(item, 'category')
      });
    }
  }
  return {
    feedTitle,
    feedLink,
    items: items.slice(0, 100)
  };
}
// ── HTML metadata extractor ───────────────────────────────
function extractHtmlMetadata(html, url) {
  function meta(name) {
    const patterns = [
      new RegExp(`<meta[^>]*(?:name|property)=["']${name}["'][^>]*content=["']([^"']*)["']`, 'i'),
      new RegExp(`<meta[^>]*content=["']([^"']*)["'][^>]*(?:name|property)=["']${name}["']`, 'i')
    ];
    for (const p of patterns){
      const m = html.match(p);
      if (m?.[1]) return m[1].trim();
    }
    return '';
  }
  const title = meta('og:title') || meta('dc.title') || meta('citation_title') || extractTag(html, 'title');
  const author = meta('og:author') || meta('dc.creator') || meta('citation_author') || meta('author');
  const description = meta('og:description') || meta('dc.description') || meta('description');
  const isbn = meta('citation_isbn') || meta('dc.identifier');
  const publisher = meta('citation_publisher') || meta('dc.publisher') || meta('og:site_name');
  const date = meta('citation_publication_date') || meta('dc.date') || meta('article:published_time') || meta('og:updated_time');
  const language = meta('dc.language') || meta('og:locale') || html.match(/<html[^>]*lang=["']([^"']*)["']/i)?.[1] || '';
  const type = meta('og:type');
  const image = meta('og:image') || meta('citation_image');
  // Try to find ISBN in page text
  let detectedIsbn = isbn;
  if (!detectedIsbn) {
    const isbnMatch = html.match(/ISBN[:\s-]*([0-9]{10,13}[0-9Xx]?)/i) || html.match(/\b(97[89]\d{10})\b/) || html.match(/\b(\d{9}[\dXx])\b/);
    if (isbnMatch) detectedIsbn = isbnMatch[1].replace(/[^0-9Xx]/g, '').toUpperCase();
  }
  return {
    url,
    title: cleanText(title),
    author: cleanText(author),
    description: cleanText(description).slice(0, 500),
    isbn: detectedIsbn,
    publisher: cleanText(publisher),
    date: cleanText(date),
    language: cleanText(language),
    type: cleanText(type),
    image
  };
}
// ── Main handler ──────────────────────────────────────────
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') return json({
    ok: true
  });
  if (req.method !== 'POST') return json({
    error: 'Use POST'
  }, 405);
  try {
    const body = await req.json().catch(()=>({}));
    const url = String(body?.url || '').trim();
    const mode = String(body?.mode || 'auto').trim(); // auto | rss | html
    if (!url) return json({
      error: 'Informe uma URL.'
    }, 400);
    // Validate URL format
    try {
      new URL(url);
    } catch  {
      return json({
        error: 'URL inválida.'
      }, 400);
    }
    // Fetch the URL
    const controller = new AbortController();
    const timer = setTimeout(()=>controller.abort(), 15000);
    let response;
    try {
      response = await fetch(url, {
        method: 'GET',
        redirect: 'follow',
        signal: controller.signal,
        headers: {
          'User-Agent': 'AnarBib fetch-url-metadata/1.0',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, text/html, */*'
        }
      });
    } finally{
      clearTimeout(timer);
    }
    const contentType = (response.headers.get('content-type') || '').toLowerCase();
    const text = await response.text();
    if (!response.ok) {
      return json({
        ok: false,
        error: `HTTP ${response.status}`,
        url,
        content_type: contentType
      });
    }
    // Detect if it's RSS/Atom
    const isRss = mode === 'rss' || contentType.includes('rss') || contentType.includes('atom') || contentType.includes('xml') && (/<rss[\s>]/i.test(text) || /<feed[\s>]/i.test(text)) || /<rss[\s>]/i.test(text.slice(0, 500)) || /<feed[\s>]/i.test(text.slice(0, 500));
    if (isRss && mode !== 'html') {
      const feed = parseRssFeed(text);
      return json({
        ok: true,
        mode: 'rss',
        url,
        content_type: contentType,
        feed_title: feed.feedTitle,
        feed_link: feed.feedLink,
        total: feed.items.length,
        items: feed.items
      });
    }
    // HTML metadata extraction
    const metadata = extractHtmlMetadata(text, url);
    return json({
      ok: true,
      mode: 'html',
      url,
      content_type: contentType,
      ...metadata
    });
  } catch (err) {
    return json({
      ok: false,
      error: err instanceof Error ? err.message : String(err)
    }, 500);
  }
});
