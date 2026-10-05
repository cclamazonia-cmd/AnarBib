// Interface policy: pictograms belong to the icon layer, never to labels or
// notification copy. This also covers emoji injected by old database rows.
// Extended pictographic covers modern emoji; the symbol range catches the
// legacy dingbats commonly used as pseudo-icons (⚠, ✓, ★, arrows, etc.).
const EMOJI_RE = /[\p{Extended_Pictographic}\u2300-\u23FF\u2600-\u27BF]/gu;
const EMOJI_JOINERS_RE = /[\uFE0F\u200D]/gu;

export function stripEmoji(value) {
  return typeof value === 'string' ? value.replace(EMOJI_RE, '').replace(EMOJI_JOINERS_RE, '') : value;
}

export function stripEmojiDeep(value) {
  if (typeof value === 'string') return stripEmoji(value);
  if (Array.isArray(value)) return value.map(stripEmojiDeep);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, stripEmojiDeep(item)]));
  }
  return value;
}
