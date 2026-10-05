// Notification copy only: pictograms belong to the icon layer, and old database
// rows still carry emoji in their stored text. Interface labels are NOT filtered
// (their ✓ and ⚠ carry meaning — see PR #32 review).
// Extended pictographic covers modern emoji; the symbol range catches the
// legacy dingbats commonly used as pseudo-icons (⚠, ✓, ★, arrows, etc.).
const EMOJI_RE = /[\p{Extended_Pictographic}⌀-⏿☀-➿]/gu;
const EMOJI_JOINERS_RE = /[️‍]/gu;

export function stripEmoji(value) {
  return typeof value === 'string' ? value.replace(EMOJI_RE, '').replace(EMOJI_JOINERS_RE, '') : value;
}
