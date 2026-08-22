# Sheet — Digitising a work

> **Translation to be reviewed.** This version was translated from the French so
> that it exists now rather than in six months. If you read this language better
> than the translation writes it, correct it: this is a common, not a closed
> text.

> **Who this sheet is for.** For you, standing at the scanner. It fits on one
> page and contains only what gets decided while scanning: the three settings,
> the five checks, and what happens to the files.
>
> The *why* is elsewhere, in the decision
> `DECISION_profil_numerisation_2026-08-20`. Here, we do.

## The rule, in one sentence

**Capture in greyscale, deliver in bitonal, keep online only what is
delivered.**

---

## 1. Before scanning — what are we allowed to digitise?

| The work is… | What you scan |
|---|---|
| **in the public domain** | the whole work |
| **released by its author**, or under a **free licence** | the whole work |
| **in copyright** | **the cover, and nothing else** |

When in doubt, **the cover alone**. You can always digitise more later; taking
down a whole collection put online by mistake is a great deal harder.

> **Write down why.** When you upload, the justification field expects a
> sentence: the author's name and date of death, the licence reference, or a
> link to the written release. **It is that sentence that protects the library,
> not the ticked box.** If you do not know what to write there, the status is
> not established — set `sob_direitos` and ask.

---

## 2. The three settings

| What is in front of you | Setting |
|---|---|
| Ordinary printed text | **Greyscale — 300 dpi** |
| Small type, footnotes, yellowed or damaged paper | **Greyscale — 400 dpi** |
| Engravings, posters, leaflets, illustrated press, covers | **Colour — 300 dpi** |

**Never straight to black and white.** The scanner will offer it — it is often
the factory setting. Refuse. Converting to black and white is irreversible: a
grey turned white does not come back, and on yellowed paper it takes whole
pages with it, along with stamps and handwritten annotations.

The criterion for colour: **is the material itself the document?** A poster,
yes. A chapter of text, no.

---

## 3. After the capture

The PDF you upload is not the capture: it is **derived** from it, page by page
— text in bitonal, illustrations in grey or colour. A 200-page, mostly textual
work then weighs 8 to 15 MB.

> **The chosen chain: ScanTailor Advanced, then `img2pdf`.** The first
> deskews, crops and separates text from illustrations, page by page; the
> second assembles the result into a PDF without re-encoding it.
>
> Do take **Advanced**: "ScanTailor" also refers to an abandoned version, which
> lacks the mixed mode needed here.
>
> **The precise settings will land in this sheet** once the chain has been
> tested on ten works. Until then, ask your library — and in any case, never
> upload the raw captures.

Two fields not to get wrong on upload:

- **Rights status** — a closed list of four choices: *Public domain* · *Rights
  released (written authorisation)* · *Free licence (CC, copyleft…)* · *In
  copyright — cover only*. Nothing else is accepted, and the **Rights
  justification** field right next to it is waiting for your sentence.
- **Access** — two choices: *Public* or *Active account (restricted)*. For a
  free work, it must be **Public**. The cataloguing form already offers it on
  *Public*: simply check that it stayed there. A resource created **outside the
  form** (import, automatic upload), however, arrives as *Active account* —
  exactly the opposite of what we want for a public-domain work. If you go
  through an import, check that field afterwards.

---

## 4. The five checks

On **three pages taken at random**, by eye, before uploading:

1. **No character eaten** — including accents and fine punctuation.
2. **Stamps, bookplates and handwritten annotations legible.**
3. **Illustrations have not been turned black and white** by mistake.
4. **The page is straight and complete** — no cropped margin, no black binding
   spilling in.
5. **The text is selectable** in a PDF reader: the OCR layer is there.

**A single failing point → redo it from the capture.** That is precisely why we
keep the capture until validation.

---

## 5. What becomes of the capture files?

**They never go up to the server.** They stay with you or at the library, on an
external drive, for as long as it takes to validate the delivery.

**Then they are erased.** That is the network's rule: no systematic archiving
of captures.

> **What that means for you.** As long as the capture exists, a failed delivery
> is redone in ten minutes. Once erased, the work has to come off the shelf
> again and be re-scanned page by page. **The five checks above are therefore
> your last chance — do them before erasing, not after.**

**One exception, yours to recognise**: a rare, fragile or unique work that
could not be re-scanned without risk to the object. There, keep the capture.
The rule targets the ordinary, not the irreplaceable.

---

## In one sentence

Scan in grey, refuse black and white, check three pages, keep the capture until
the PDF is validated. The rest is learned by doing.

---

*A document of the AnarBib commons. This version is a translation: correct it
if your language deserves better — that is how it becomes ours.*
