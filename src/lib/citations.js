// Helpers de citation & export bibliographique — mutualisés entre
// BookPage (notice, #OPAC1) et AuthorPage (bibliographie, #AUT3).
// Texte brut, métadonnées limitées : formats approximatifs mais propres.

export function citeAuthorString(book, contributors) {
  if (Array.isArray(contributors) && contributors.length) {
    const names = contributors.map(c => c.name).filter(Boolean);
    if (names.length) return names.join('; ');
  }
  return book.author_display || book.autor || '';
}

export function citeAuthorList(book, contributors) {
  if (Array.isArray(contributors) && contributors.length) {
    const names = contributors.map(c => c.name).filter(Boolean);
    if (names.length) return names;
  }
  const a = book.author_display || book.autor || '';
  return a ? [a] : [];
}

// APA / Chicago / MLA (approximatifs).
export function buildCitations(book, a) {
  const year = (book.ano && String(book.ano).trim()) || 's.d.';
  const title = (book.titulo || '') + (book.subtitulo ? `: ${book.subtitulo}` : '');
  const pub = book.editora || '';
  const place = book.local_publicacao || '';
  const ed = book.edicao || '';
  const auth = a ? a.trim() : '';
  const clean = s => s.replace(/\s+/g, ' ').replace(/\s+([.,;:])/g, '$1').replace(/([.,;:]){2,}/g, '$1').trim();
  return {
    apa: clean(`${auth ? auth + ' ' : ''}(${year}). ${title}${ed ? ` (${ed})` : ''}. ${place ? place + ': ' : ''}${pub ? pub + '.' : ''}`),
    chicago: clean(`${auth ? auth + '. ' : ''}${title}. ${place ? place + ': ' : ''}${pub ? pub + ', ' : ''}${year}.`),
    mla: clean(`${auth ? auth + '. ' : ''}${title}. ${pub ? pub + ', ' : ''}${year}.`),
  };
}

export function buildBibtex(book, authorStr, url) {
  const key = (book.bib_ref || `anarbib-${book.book_id || book.id}`).replace(/[^A-Za-z0-9_-]/g, '');
  const fields = [
    ['author', authorStr], ['title', book.titulo], ['subtitle', book.subtitulo],
    ['year', book.ano], ['publisher', book.editora], ['address', book.local_publicacao],
    ['edition', book.edicao], ['series', book.colecao], ['isbn', book.isbn], ['issn', book.issn],
    ['language', book.idioma], ['pages', book.paginas], ['url', url],
  ].filter(([, v]) => v != null && String(v).trim() !== '');
  const body = fields.map(([k, v]) => `  ${k} = {${String(v).replace(/[{}]/g, '')}}`).join(',\n');
  return `@book{${key},\n${body}\n}\n`;
}

export function buildRis(book, authors, url) {
  const lines = ['TY  - BOOK'];
  (authors || []).forEach(n => { if (n) lines.push(`AU  - ${n}`); });
  const push = (tag, v) => { if (v != null && String(v).trim() !== '') lines.push(`${tag}  - ${String(v).trim()}`); };
  push('TI', book.titulo); push('T2', book.subtitulo); push('PY', book.ano);
  push('PB', book.editora); push('CY', book.local_publicacao); push('ET', book.edicao);
  push('SN', book.isbn || book.issn); push('LA', book.idioma); push('SP', book.paginas); push('UR', url);
  lines.push('ER  - ');
  return lines.join('\r\n') + '\r\n';
}

export function triggerDownload(filename, text, mime) {
  const blob = new Blob([text], { type: mime || 'text/plain;charset=utf-8' });
  const href = URL.createObjectURL(blob);
  const el = document.createElement('a');
  el.href = href; el.download = filename;
  document.body.appendChild(el); el.click(); document.body.removeChild(el);
  setTimeout(() => URL.revokeObjectURL(href), 1000);
}
