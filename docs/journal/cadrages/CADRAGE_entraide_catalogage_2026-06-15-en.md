# Scoping document — Cataloguing mutual aid (the "Mutual Aid" tab of the Federation)

**Date**: 2026-06-15
**Status**: **scoping / draft** — exploratory reflection laying out the *vision*,
the *architecture*, and *foundational decisions*. **This is not yet a spec to build**:
to be discussed, tested, then broken down into specs.
**Ethical foundation**: [`notes-audit/anarbib-charte-relationnelle-v0.1.md`](../../../notes-audit/anarbib-charte-relationnelle-v0.1.md)
("the open hand"). **Every screen below has been run through the "does it offer or does it grab?" checklist.**
This scoping document is, in a sense, the first concrete test of the charter.

---

## 1. The need

Cataloguing is the pain point for new libraries (cf. the authority, subject indexing,
and discovery wizard workstreams). A library left alone with authorities, subjects, and
classification is intimidated. The "Mutual Aid" tab addresses that precise need — but
anarchist cataloguing is not neutral: mainstream subject headings pathologise, erase,
and misname. **Mutual aid transmits a *political craft* that neither standards nor AI
can encode.**

Transversal principle: **the call for help is generic** (mutual aid on *any* thorny
technical subject), **cataloguing is the first domain wired up**.

## 2. Three degrees of mutual aid — a scale, by subsidiarity

Not "one OR another" but three *intensities*; the call for help is the pivot, the
response takes one of three forms, from lightest to heaviest:

1. **The knowledge commons** (vademecums, cases, thesaurus) — zero cost, zero
   dependency, 100% peer-to-peer. The durable foundation.
2. **Mini-wizards** — guide the library to do things *itself* (empowering, not
   dependency-creating).
3. **Direct human help** (call → response → possible video call) — the most relational,
   for when the commons and the wizard are not enough.

**The downward loop**: a hard case resolved at degree 3 → summary → becomes a
case/wizard at degree 1-2 → next time the wizard is enough. *Knowledge descends the
degrees over time; the network becomes smarter and more self-sufficient with each episode.*

## 3. The knowledge commons — the autonomy layer

Three layers, and the deepest is **the vocabulary itself**:

- **The thesaurus, political core.** Not a word list: a *concept graph*. Politics lives
  in the **terms**, the **relations** (broader/narrower/related), and the **scope notes**
  (which are micro-vademecums). Build on **SKOS** (free standard) — bequeath a norm, not
  a workaround. A seed exists (thesaurus ~30 categories).
- **Cases & vademecums** — worked examples, editable, surfacing *at the point of need*.
- **Wizards as *data*, not *code*** — *the autonomy wager*: if a wizard is code, we
  depend on developers forever; if it is a **structured document** (a tree of
  question-cards → end-cards) that a write-once engine unfolds, **any library can write
  one without coding**. Guardrails to prevent it becoming a disguised programming language:
  no variables/calculations/free conditions; the only state is the path taken; any
  conditions come from a closed list; **the wizard *advises*, never *writes*** (worst
  failure = "not helpful", never "broke the catalogue"); small, single-topic wizards.

**Multilingual without AI**: the i18n shell (10 locales) carries the interface; the
*substance* (terms, cases) is written **by language community** (parallel cross-linked
writing, not top-down translation) — slow but durable and free. **Governance**: additions
and modifications of terms via the circles' **consent/objection** flow; the political
slider "admitted variants vs. convergence" to be set by the network.

## 4. The trigger — at the point of need (charter ③)

**The trigger is the *field*, the *data*, or the *request* — never surveillance of the
person.** Ban behavioural signals ("5 min on the field", hesitations): that is Clippy
*and* workplace surveillance. Three honest triggers:
- **intrinsic to the field** (subjects/authority are hard *for everyone* → help always
  there);
- **derived from the data** (no ISBN, ambiguous author → the book signals, not the person);
- **explicit request** ("help" button, calm, always within reach).

Help moves **up the scale one-click-further** (inline → wizard → circle), **discreet
but discoverable** (reliable placement, never modal/gamified), with **domain-curve
presence** (a little more welcoming if the field is empty and notice count is low; fades
with mastery; always collapsible by hand).

## 5. Two screens already run through the checklist

### 5.1 — The "?" beneath a hard field (cataloguing)
Present *because the field is tricky for everyone* (dignity framing, not "you seem to be
struggling"). On opening it: inline thesaurus suggestions + cases from the commons →
"guided path" (wizard) → "ask the circle" (degree 3, moment of consent).
**The checklist killed two tempting features**: ❌ detect hesitation to offer help
(surveillance, facet ③); ❌ badges/streaks/bar towards "expert" (facet ⑥).
**Retained defaults**: "first time? guided path" net *offered in an offer register*;
"?" always visible, suggestions **unfolded on click** (discreet + discoverable).

### 5.2 — Episode closure + commons capture
Closure **initiated by the person who was helped** (no auto-close, no closure by the
helper). Sober "thank you" screen, **nothing hooked on** (anti-debt decoupling). Symmetric
"keep in touch?" feather-bar, ignorable, creates nothing except a double-yes.
**Commons capture without debt**: we invite the **helper** (who holds the new knowledge),
not the person helped; **micro-contribution hooked to the object** (note on a term/field),
**seeded by the episode trace**; then the **person helped is invited to review/enrich**
("what was really difficult") — *their voice, declinable, never a judgement from the
helper*, and **non-blocking** (the note stands on its own).
**The checklist killed**: ❌ "rate your experience" (disguised ranking); ❌ completion badge.

## 6. Confidentiality

Catalogue data is *less* sensitive than reader data (metadata about *books*, never
copies/loans/identities), **but not zero** (a radical library's holdings can be
politically sensitive; cf. the `visibility_level='network'` / BTL distinction). Therefore:
- **opt-in per item** (never a dump), **BTL/sensitive items excluded by default**;
- **the helper *proposes*, the owner *validates*** — never direct third-party writing;
  access **scoped, revocable, audited**;
- the **"ask the circle" step IS the moment of consent** ("you are about to show these
  items to library X — here is what will be shared");
- **the commons captures *generic de-identified craft*, not *identifying cases***;
  specifics are stripped or explicitly consented to.

Answer to the question "absolute right to delegate?": **yes to autonomy, but
*informed and bounded* consent, not a blank cheque** — make the risk small and take it
knowingly.

## 7. Matching & partnership maturation

- **Soft ranking, not hard filter.** In a sparse network, an AND (same language AND
  geography AND availability AND expertise) = empty set. We **rank** by affinity
  (language ↑, time zone ↑, volunteer ↑) without **excluding**; subsidiarity **circle
  first → network if silence**. The **relevant circle depends on the type of help**
  (cataloguing → linguistic; material/repression → geographic).
- **First gesture without prerequisites**: volunteering for *one* act requires no circle
  or profile. **Belonging accretes from gestures** (consented recognition, never a label).
- **Anti-hierarchy**: no individual reputation, no marketplace; declared availability,
  visible reciprocity without scoring, rotation.
- **Partnership maturation (§21)** — *second phase that dissolves scarcity*: a good
  episode can **mature** into a partnership → future help is *pre-matched* (language,
  time zone, consent already given); the network **densifies**. **Decoupled** from the
  episode (never in the moment = debt); **after repetition** (recognition, not creation);
  **symmetric double-opt-in**; **depth scale** (0 → keep-in-touch → companionship →
  formal partnership); **debt inversion** (the partnership is a *gift* to the person
  helped: "a comrade to call on without re-consenting", not a debt); always **severable**.

## 8. The video call plugin (degree 3)

Couple human help with a **Jitsi video call** (synchronous = efficient transmission);
pool = **linguistic circle**. **Async first, video call as optional turbo** (the most
precarious person is poorly connected → degrees 0-2 in text/offline).
Technically, "for free": **code the integration once via the iframe API with `domain`
in config** → never locked to one provider. Default to a **militant Jitsi instance**
(most in keeping with doctrine, free, no GAFAM); failing that `meet.jit.si` (assuming
room-creator auth). **Ephemeral rooms, non-guessable name, lobby**. **Zero server,
zero secret, zero recurring cost.** Self-hosting remains *parking* (VPS ruled out).

## 9. Cost & autonomy

Everything (commons, wizards, panels, matching, video link-out) **runs on the existing
stack** (Supabase + static front-end): **zero marginal cost, no AI required to run**.
AI remains an **optional, disconnectable accelerator** (pre-cataloguing of *neutral*
material only; the political stays between comrades). **The organs already exist**:
thesaurus seed, discovery wizard, i18n 10 locales, circles' consent/objection flow, §21
partnership. **This scoping document connects existing organs — hence its modesty, and
its independence from cost and any external dependency.**

## 10. Settled decisions / open questions

**Settled (in the course of reflection):**
- Three degrees on a scale + downward knowledge loop.
- Commons = thesaurus (SKOS, political core) + cases + **data-driven wizards**.
- Trigger by field/data/request, **never surveillance**; one-click scale;
  domain-curve presence.
- "?" screen: defaults (offer, suggestions on click); rejections (hesitation detection,
  gamification).
- Closure: person helped closes; **helper drafts → person helped enriches** (zero debt);
  commons = **generic craft**; governance **additive = 2 people / vocabulary = collective**.
- Matching **soft ranking + circle first**; circle **by type of help**; first gesture
  without prerequisites; **belonging through the gesture**.
- §21 maturation **decoupled, after repetition, double-opt-in, depth scale, debt
  inversion, severable**.
- Video call **Jitsi `domain` configurable**, async-first, zero infra/secret.
- (Mail reminder, already wired outside this scoping document) recipient locale =
  **their personal preference**.

**Open (political sliders to be set by the network):**
- **Initial welcome level** (hospitality) and **who sets it**: network / circle / library /
  individual. Lead: *ask* the newcomer what welcome they want (consent) + subsidiarity
  (the higher level fills only the silence) + *in-person sponsorship* option by a circle
  volunteer.
- Level of **presence of the feather-bar** and the commons invitation (offered vs.
  available) — largely defused by **semantics** (offer register ≠ injunction).
- Concrete form of the **data-wizard editor** (how far without becoming code).
- **Variants vs. convergence** slider for the thesaurus.

## 11. Status

Scoping document to be **discussed and tested**, not a build order. When a section is
ready, it will be broken down into a spec, and each screen will be run through the
**relational charter checklist** again.
