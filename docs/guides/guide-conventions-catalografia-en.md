# Sheet — Writing a name, writing a title

> **Translation to be reviewed.** This version was translated from the French so
> that it exists now rather than in six months. If you read this language better
> than the translation writes it, correct it: this is a common, not a closed
> text.

> **Who this sheet is for.** For you, cataloguing. It gathers what gets decided
> at the moment you type: how a name is written, where to cut a particle, what
> to do with a corporate body, and why an empty field is worth more than a
> guessed one.
>
> The detailed *why* lives elsewhere, in the decisions register, section `CONV`.
> Here, we catalogue.

## The rule, in one sentence

**One single truth in the database, several renderings.** You enter the
cataloguing form; capitals, forename-surname order and bibliographic formatting
are **computed** on display and on export. Never type them by hand.

That is where all the disorder we have been repairing comes from: the access
point, the display form and the export form were lodged **in the same field**,
at different times, by different hands.

---

## 1. A person's name

### The sort form is what counts

The **"Sort form"** field is the truth. The **"Standard form"** derives from it
automatically, by simply inverting the comma. Never the other way round.

| You write in "Sort form" | The app displays |
|---|---|
| `Kropotkin, Peter` | Peter Kropotkin |
| `Malatesta, Errico` | Errico Malatesta |

### Natural case, never all-capitals

**`Kropotkin, Peter` — never `KROPOTKIN, Peter`.**

Capitalised surnames are a **bibliographic reference convention** (ABNT), not
data. They are added on export, on the fly. Typing them yourself does not make
them truer: it destroys the case information, which cannot be reconstituted
afterwards — `de Sousa` and `De Sousa` are no longer distinguishable once
everything is in capitals.

### Where to cut: the particle

**The language of the NAME decides, not the country of birth.** An Argentinian
may bear an Italian name.

| Language of the name | The particle… | Example |
|---|---|---|
| Portuguese, French | **moves to the end**, after the forename | `Sousa, Manuel Joaquim de`<br>`Beauvoir, Simone de`<br>`Jong, Rudolf de` |
| modern Italian, Afrikaans, Dutch | **stays in front** | `Di Filippo, Luis`<br>`De Amicis, Edmondo`<br>`Van der Walt, Lucien` |

Luis Di Filippo is the textbook case: Argentinian, Italian name, hence
`Di Filippo, Luis` — not `Filippo, Luis Di`.

> **In English**, a particle carried into the surname stays with it:
> `De Cleyre, Voltairine`, not `Cleyre, Voltairine De`.

### What the tool cannot decide

**Double surname or compound forename?** `García Lorca` is a Spanish double
surname (do not cut it); `Jean-Marie` is a compound forename. No function tells
the two apart. When in doubt, **ask** rather than decide: this is exactly the
kind of case that goes to the review queue.

---

## 2. A corporate body is not a person

**A collective name has no inverted form.**

| ✅ | ❌ |
|---|---|
| `Grupo Krisis` | `Krisis, Grupo` |
| `Instituto de Estudos Libertários` | `Libertários, Instituto de Estudos` |
| `CIRA Marseille` | `Marseille, CIRA` |

### Fill in "Authority type"

The field exists and it **drives the rule**. Set to *Corporate body*, it
prevents inversion. Left empty, nothing protects the record: it will be treated
as a person the first time any tooling passes over it.

Three seconds of typing that save three months of correction.

### If the record holds SEVERAL people

It happens — the import manufactured such cases. `KAISER, William Young and
David E.` is not one Kaiser with two forenames: it is **William Young** *and*
**David E. Kaiser**, two authors of the same book.

**Do not repair it in place.** An authority record is shared by the whole
network: renaming it only moves the error. Go through the Authorities Workshop,
proposal of type **Split**: the original record is kept, the others are
created, and the links to books follow. Deliberation period: fourteen days, as
for a merge.

---

## 3. The title

### Case depends on the language of the title

There is **no** universal rule. German capitalises its nouns: that is its
**orthography**, not a typing mistake.

The normalisation tool lowers only the **function words of the title's
language**, in non-initial position. It preserves:

- the **first word**;
- words after **strong punctuation** (`.` `:` `;` `?` `!` and the subtitle
  dash);
- **acronyms**.

**It removes an import artefact, it does not "re-case" the title.** When it
offers a correction, you remain the judge of whether a word is a proper noun —
the tool does not know.

| Before | After |
|---|---|
| `Antologia Do Movimento Operário Gaúcho` | `Antologia do Movimento Operário Gaúcho` |
| `Der Einzige Und Sein Eigentum` | `Der Einzige und sein Eigentum` |

### The initial article: never mutilate the title

`The Workers` is written **`The Workers`**. Not `Workers, The` — that is a
relic of the card catalogue — and not `Workers` on its own.

Sorting is handled by a **count of non-filing characters** (here: 4, for
`The `), which leaves the title intact.

---

## 4. Language and country

| Field | Format | Examples |
|---|---|---|
| **Language** (of the document) | BCP-47 code | `pt-BR`, `fr`, `es`, `de`, `it` |
| **Country** (of the authority) | ISO 3166-1 α-2 code | `BR`, `FR`, `ES`, `NL` |

Not `English`, not `Britain`, not `eng`. The app's selector gives you the right
code: use it rather than typing.

**A blank stays blank.** If you do not know the language, leave it empty. An
unknown language is honest information; a wrong language then drives the
title's case and the name's entry rule — it propagates the error instead of
containing it.

---

## 5. Dates

Two integers and a **qualifier**:

| Qualifier | When |
|---|---|
| `exact` | the date is established |
| `circa` | approximate ("around 1876") |
| `uncertain` | sources disagree |
| `unknown` | not known |
| `living` | **the person is alive** |

`living` is not a comfort detail: without it, "still alive" and "date of death
unknown" were conflated — which amounted to killing people off in the
catalogue.

When both birth and death are unknown, use the **activity period** ("active
1900-1910"). And when sources contradict each other, write it in the **dates
note**: this is historiographic repair, not filler.

---

## 6. What is not yours to decide alone

The authority corpus is **shared by the whole network**. Changing one record
means changing the catalogue of several libraries.

| Action | Where it happens |
|---|---|
| fixing a typo on a record | directly |
| **merging** two duplicate records | Workshop — proposal, 14 days |
| **splitting** a record that holds two | Workshop — proposal, 14 days |
| deciding a case or surname proposed by the tool | review queue |

In the Workshop, a proposal stays open long enough for other libraries to
object. That delay is not administrative slowness: it is what keeps the corpus
common.

---

## When in doubt

**Leave it empty rather than guess.**

An empty field asks a question — someone will see it and answer. A wrong field
answers a question nobody asked, and it looks right. That is the one we find
again three months later, copied into five catalogues.
