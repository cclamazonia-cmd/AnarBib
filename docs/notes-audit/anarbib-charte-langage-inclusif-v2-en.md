# AnarBib Inclusive Language Charter

**Version**: 2.0
**Date**: 2026-06-05
**Status**: project reference (single source of authority)
**Replaces**: `anarbib-charte-langage-inclusif-v1.md` (v1.0, 2026-04-28), now **deprecated**

This document establishes the inclusive language conventions adopted across the **ten
locales** of AnarBib (`pt-BR`, `fr`, `es`, `en`, `it`, `de`, `ca`, `eo`, `nl`,
`el`). It applies to every new translation, every review, and every future
contribution. It is intended for people contributing to the
`src/i18n/locales/*.json` files, to the mail notification strings
(`supabase/functions/_shared/i18n/mail-strings.ts`), and to any translation
generated thereafter.

> **Changes since v1**: v1 covered only six locales (`pt-BR`, `fr`,
> `es`, `en`, `it`, `de`). v2 adds `ca`, `eo`, `nl`, `el`, and **officially
> establishes the Italian convention** (asterisk for regular pairs, slash for
> irregular pairs), replacing the provisional slash from v1.

---

## Table of contents

1. [Why this document](#why-this-document)
2. [Guiding principle: internal consistency per language](#guiding-principle-internal-consistency-per-language)
3. [Status table](#status-table)
4. [Charter by language](#charter-by-language)
   - [French (fr)](#french-fr)
   - [German (de)](#german-de)
   - [English (en)](#english-en)
   - [Brazilian Portuguese (pt-BR)](#brazilian-portuguese-pt-br)
   - [Castilian Spanish (es)](#castilian-spanish-es)
   - [Italian (it)](#italian-it)
   - [Catalan (ca)](#catalan-ca)
   - [Esperanto (eo)](#esperanto-eo)
   - [Dutch (nl)](#dutch-nl)
   - [Greek (el)](#greek-el)
5. [Reference political terms](#reference-political-terms)
6. [Proscribed terms](#proscribed-terms)
7. [Procedure for future additions](#procedure-for-future-additions)
8. [Test coverage (CI)](#test-coverage-ci)
9. [Evolution of the charter](#evolution-of-the-charter)

---

## Why this document

AnarBib is an integrated library management system designed for anarchist militant
libraries. A militant library is not a library like any other: it does not merely
archive documents, it constitutes **a collective memory**, and the language of its
interface is part of that memory. An interface that refers to "lecteur" in the
masculine generic reproduces the erasure that a feminist or queer library is
precisely seeking to undo; an interface that says "compagn·e·s" signals from the
very first moment which movement it belongs to.

But inclusive language is not a universal norm. Every language has its own history,
its own militant conventions, its own politically mined terrain. **There is no single
"correct" cross-cutting inclusive writing**: there are situated local choices,
defended by situated militant communities. This charter respects those local
situations while guaranteeing that within a single language, AnarBib speaks with
one voice.

Three concrete objectives:

1. **Consistency.** Within a single locale file, the same gender position is always
   written in the same way.
2. **Respect for local militant cultures.** No convention from one language is imposed
   on another.
3. **Readability for non-specialists.** A militant librarian discovering AnarBib must
   be able to use it without being an expert in inclusive typography.

---

## Guiding principle: internal consistency per language

Each AnarBib language applies **its own typographic convention for inclusive
writing**, inherited from local militant practice. No cross-cutting convention is
imposed.

Within a language, **these conventions are mandatory and exclusive**:
a `fr.json` file does not mix the middle dot with `(e)` forms; an
`it.json` file does not mix the asterisk with the middle dot. The choices made in
this charter are the **official form** used by AnarBib for that language.

---

## Status table

| Locale | Convention | Status |
|---|---|---|
| `pt-BR` | Triple form `(o/a/e)` | **Adopted** (reference) |
| `fr` | Middle dot `·` | **Adopted** |
| `es` | Neutral `e` (Argentine convention) | **Adopted** |
| `en` | Epicene + singular `they` | **Adopted** |
| `de` | Genderstern `*` | **Adopted** |
| `it` | Asterisk (regular pairs) / slash (irregular pairs) | **Adopted** |
| `ca` | Triple ending `-a-e` + article `le` | **Adopted** |
| `eo` | Infix `-in-` made visible by hyphens + pronoun `ri` | **Adopted** |
| `nl` | Neutral role forms | **Provisional** — to be validated by the community |
| `el` | — | **To be defined** with a militant Greek-speaking contributor |

---

## Charter by language

### French (fr)

**Adopted convention**: middle dot (`·`, U+00B7).

**Generic form**: common root + middle dot + feminine ending.

| Masculine | Feminine | AnarBib form |
|---|---|---|
| lecteur | lectrice | **lecteur·rice** |
| auteur | autrice | **auteur·rice** |
| administrateur | administratrice | **administrateur·rice** |
| compagnon | compagne | **compagnon·ne** |
| coordinateur | coordinatrice | **coordinateur·rice** |
| militant | militante | **militant·e** |
| utilisateur | utilisatrice | **utilisateur·rice** |

**Plural**: add `·s` (`lecteur·rice·s`).
**Combined articles / determiners**: `le·la`, `du·de la`, `au·à la`, `un·e`,
`le·la SEUL·E`, `actif·ve`.
**Already epicene words**: unchanged (`bibliothécaire`, `camarade`, `responsable`,
`personne`).
**Proscribed**: `(e)`, separate `-e` (pre-2010 conventions), ordinary period `.` or
bullet `•` in place of the middle dot.

### German (de)

**Adopted convention**: Genderstern (`*`, ASCII asterisk U+002A).

| Masculine | Feminine | AnarBib form |
|---|---|---|
| Leser | Leserin | **Leser*in** |
| Bibliothekar | Bibliothekarin | **Bibliothekar*in** |
| Autor | Autorin | **Autor*in** |
| Administrator | Administratorin | **Administrator*in** |
| Genosse | Genossin | **Genoss*in** |
| Benutzer | Benutzerin | **Benutzer*in** |

**Plural**: `*innen` (`Genoss*innen`, `Leser*innen`).
**Proscribed**: Mediopunkt `·`, Genderdoppelpunkt `:innen`, and the Spanish-language
neologism *"Compas"* left untranslated (always use `Genoss*in`/`Genoss*innen`).

### English (en)

**Adopted convention**: epicene terms by default, `they/them/their` in the
singular as the neutral pronoun.

English grammar is largely epicene: consistently use the existing neutral
form (`reader`, `librarian`, `author`, `administrator`,
`comrade`, `coordinator`, `user`), without typographic marking. For the rare
gendered terms, choose the epicene form (`actor` rather than `actress`,
`server` rather than `waitress`).
**Proscribed**: `he/she`, `s/he`, `(s)he`, `he or she`, `his/her`, `him/her`.

### Brazilian Portuguese (pt-BR)

**Adopted convention**: triple form `(o/a/e)` or `(a/e)` depending on grammar,
explicitly including all three positions (feminine, masculine, non-binary).
**This is the project's reference locale.**

| Masculine | Feminine | AnarBib form |
|---|---|---|
| leitor | leitora | **leitor(a/e)** |
| bibliotecário | bibliotecária | **bibliotecári(o/a/e)** |
| autor | autora | **autor(a/e)** |
| administrador | administradora | **administrador(a/e)** |
| companheiro | companheira | **companheir(o/a/e)** |
| coordenador | coordenadora | **coordenador(a/e)** |
| usuário | usuária | **usuári(o/a/e)** |

**Rule**: words ending in `-or` → `(a/e)`; words ending in `-o` → `(o/a/e)`. Endings
in alphabetical order inside the parentheses.
**Article-preposition contractions**: `d(o/a/e)`, `dest(e/a/e)`, `pel(o/a/e)`,
`(o/a/e)s`.
**Already epicene words**: unchanged (`camarada`, `colega`, `responsável`,
`pessoa`).
**Proscribed**: `(a)` alone, `/a`, `/o`, `@` (arroba), `x`. Watch out for the
**false friend `camarade`** (French form): in pt-BR, it is **`camarada`**.

### Castilian Spanish (es)

**Adopted convention**: neutral `e` (Argentine militant convention).

| Masculine | Feminine | AnarBib form |
|---|---|---|
| lector | lectora | **lectore** |
| bibliotecario | bibliotecaria | **bibliotecarie** |
| autor | autora | **autore** |
| administrador | administradora | **administradore** |
| compañero | compañera | **compañere** |
| usuario | usuaria | **usuarie** |

**Rule**: replace the final gender vowel (`-o`/`-a`) with `-e`; words ending in
`-or` → root + `-e` (`lector → lectore`).
**Plural**: `-s` (`compañeres`).
**Articles / determiners**: `le` (neutral singular), `les` (neutral plural).
**Agreed participles**: `informade`, `conectade`, `active`.
**Already epicene words**: unchanged (`camarada`, `colega`, `responsable`,
`persona`).
**Proscribed**: `(a)`, `/a`, `/o`, **the pt-BR triple form `(o/a/e)`**
(Spanish uses ONLY the neutral `e`), `@` (arroba), `x` (Latinx), and the
**middle dot `·`** (French convention; not to be used in Spanish).

### Italian (it)

**Officially adopted convention**: **asterisk `*` for regular pairs,
abbreviated slash for irregular pairs.** This convention replaces the provisional
slash from v1.

#### Regular pairs (common root in `-o`/`-a`) → asterisk `*`

When masculine and feminine share the **same root**, the gender ending is replaced
by an asterisk, for consistency with the German Genderstern.

| Masculine | Feminine | AnarBib form |
|---|---|---|
| compagno | compagna | **compagn*** |
| bibliotecario | bibliotecaria | **bibliotecari*** |
| attivo | attiva | **attiv*** |
| militante | militante | **militant*** *(already epicene in singular)* |

Also applies to **agreed participles and adjectives**: `stat*` (stato/a),
`ammess*` (ammesso/a), `collegat*` (collegato/a), `trovat*` (trovato/a),
`benvenut*` (benvenuto/a), `esclu*` (escluso/a), `nuov*` (nuovo/a), `quest*`
(questo/a), `tutt*` (tutti/e), `un*` (uno/una), `contrari*` (contrario/a).

#### Irregular pairs (different roots, type `-tore`/`-trice`) → abbreviated slash

When the feminine does not share the root of the masculine (`lettore` → `lettric-e`),
the asterisk is **incorrect** (`lettor*` would imply a non-existent feminine
`lettora`). The **abbreviated slash form** is therefore used, which is the
attested house style in the repository.

| Masculine | Feminine | AnarBib form |
|---|---|---|
| lettore | lettrice | **lettore/trice** |
| autore | autrice | **autore/trice** |
| amministratore | amministratrice | **amministratore/trice** |
| coordinatore | coordinatrice | **coordinatore/trice** |
| traduttore | traduttrice | **traduttore/trice** |
| curatore | curatrice | **curatore/trice** |

**Irregular plural**: `lettori/trici`, `amministratori/trici`,
`coordinatori/trici`.
**Articles**: `il/la`, `del/la`, `al/la`, `dal/la` (abbreviated form), `un*` for
`uno/una`.
**Already epicene words**: unchanged (`utente`, `responsabile`, `persona`,
`collega`).

#### Note on the `·` character

The middle dot `·` is **not** an inclusive marker in Italian: it serves only as a
**typographic separator** in email subject lines and metadata lines (`Email · ID · Genere`).
Never use it to mark gender.

**🚫 Absolutely proscribed**: **`camerata` / `camerati` / `cameratesco`** — internal
fascist form of address (PNF, MSI, CasaPound, Forza Nuova, FdI). Use `compagn*` and
its variants. **This proscription is tested in CI** (`i18n.test.js` and
`mail-strings.test.ts`).
**Other proscribed forms**: `(a)`/`(o)` parentheses, triple `/trice/e`, suffix
`/x`, middle dot `·` as a gender marker.

**Militant justification**: the asterisk (*asterisco*) is attested in Italian
anarchist and autonomist circles (Carmilla, DinamoPress, InfoAut,
Wu Ming), and offers visual consistency with the German Genderstern. The abbreviated
slash for irregular pairs avoids incorrect feminines while remaining legible.

### Catalan (ca)

**Adopted convention**: triple suffix ending `-a-e` + neutral article `le`.

| Masculine | Feminine | AnarBib form |
|---|---|---|
| lector | lectora | **lector-a-e** |
| bibliotecari | bibliotecària | **bibliotecari-ària-e** |
| coordinador | coordinadora | **coordinador-a-e** |
| administrador | administradora | **administrador-a-e** |

**Parenthesised variant** accepted for contractions:
`lector(a/e)`, `coordinador(a/e)`.
**Neutral determiner**: `le` (`le lector-a-e`).
**Plural**: `-s` or combined form `els-les-les` / `als-a les-a les`.
**Already epicene words**: unchanged.

> The Catalan geminate `·` appears in **`l·l`**
> (`col·lectiu`, `cancel·lada`, `sol·licitud`): this is a **standard Catalan
> spelling convention**, unrelated to inclusivity. Do not modify it.

### Esperanto (eo)

**Adopted convention**: infix `-in-` made visible by hyphens + neutral pronoun
`ri`.

| Base | AnarBib form |
|---|---|
| leganto (lecteur·rice) | **legant-in-o** |
| bibliotekisto | **bibliotekist-in-o** |
| administranto | **administrant-in-o** |
| kunordiganto | **kunordigant-in-o** |
| uzanto | **uzant-in-o** |
| aŭtoro | **aŭtor-in-o** |

**Non-binary variant**: suffix `-in-e` (`legant-in-e`, `kamarad-in-o`).
**Neutral pronoun**: `ri`.
**Plural**: `-j` (`legant-in-oj`).

### Dutch (nl)

**Status: PROVISIONAL — to be validated by the community.**

**Provisional orientation**: prefer existing **neutral role forms**
rather than typographic marking.

| Concept | Provisional form |
|---|---|
| reader | **lezer** |
| librarian | **bibliothecaris** |
| coordinator | **coördinator** |
| administrator | **beheerder** |

**Provisional rules**: avoid gendered suffixes `-ster`/`-e` when a neutral
form exists; non-binary pronoun `die` (or `hen`/`hun`) — **usage not yet
settled**.

> ⚠️ This convention is **not** definitive. It must be validated by militant
> Dutch-speaking contributors before being fixed. In the meantime,
> stick to neutral forms.

### Greek (el)

**Status: CONVENTION TO BE DEFINED.**

There is **no consensual typographic standard** for inclusive writing in Greek.
**Do not propose a marker by default.** The convention will be established
**with a militant Greek-speaking contributor** who joins the project.

**Transitional approach** (in the meantime): doublets or existing neutral forms
(`αναγνώστης/στρια`, `συντονιστής/στρια`), monotonic Greek, 2nd person
singular for addressing readers (formal address for the team). GDPR acronym → `ΓΚΠΔ`.

> ⚠️ Any proposal for a systematic inclusive typographic marker in Greek is
> **premature** until a militant Hellenic-speaking contributor has joined
> the project.

---

## Reference political terms

### Comrade / Compagn·e

| Language | Official form | Plural |
|---|---|---|
| 🇫🇷 fr | `camarade` *(epicene)* | `camarades` |
| 🇩🇪 de | `Genoss*in` | `Genoss*innen` |
| 🇬🇧 en | `comrade` *(epicene)* | `comrades` |
| 🇧🇷 pt-BR | `camarada` *(epicene)* | `camaradas` |
| 🇪🇸 es | `compañere` | `compañeres` |
| 🇮🇹 it | `compagn*` | `compagn*` |
| ca | `camarada` *(epicene)* | `camarades` |
| eo | `kamarad-in-o` | `kamarad-in-oj` |
| nl | `kameraad` *(provisional)* | `kameraden` |
| el | `σύντροφος` *(to be confirmed)* | — |

### Reader

| Language | Official form |
|---|---|
| 🇫🇷 fr | `lecteur·rice` |
| 🇩🇪 de | `Leser*in` |
| 🇬🇧 en | `reader` |
| 🇧🇷 pt-BR | `leitor(a/e)` |
| 🇪🇸 es | `lectore` |
| 🇮🇹 it | `lettore/trice` |
| ca | `lector-a-e` |
| eo | `legant-in-o` |
| nl | `lezer` *(provisional)* |
| el | `αναγνώστης/στρια` *(transitional)* |

### Librarian

| Language | Official form |
|---|---|
| 🇫🇷 fr | `bibliothécaire` *(epicene)* |
| 🇩🇪 de | `Bibliothekar*in` |
| 🇬🇧 en | `librarian` |
| 🇧🇷 pt-BR | `bibliotecári(o/a/e)` |
| 🇪🇸 es | `bibliotecarie` |
| 🇮🇹 it | `bibliotecari*` |
| ca | `bibliotecari-ària-e` |
| eo | `bibliotekist-in-o` |
| nl | `bibliothecaris` *(provisional)* |
| el | `βιβλιοθηκάριος` *(to be confirmed)* |

### Administrator

| Language | Official form |
|---|---|
| 🇫🇷 fr | `administrateur·rice` |
| 🇩🇪 de | `Administrator*in` |
| 🇬🇧 en | `administrator` |
| 🇧🇷 pt-BR | `administrador(a/e)` |
| 🇪🇸 es | `administradore` |
| 🇮🇹 it | `amministratore/trice` |
| ca | `administrador-a-e` |
| eo | `administrant-in-o` |
| nl | `beheerder` *(provisional)* |
| el | *(to be defined)* |

---

## Proscribed terms

### Politically marked (absolute proscription)

| Term | Language | Reason |
|---|---|---|
| `camerata` / `camerati` / `cameratesco` | 🇮🇹 it | Internal fascist form of address (PNF, MSI, CasaPound, Forza Nuova, FdI). **Tested in CI.** |
| `Compas` *(untranslated)* | 🇩🇪 de | Spanish-language neologism left as-is — use `Genoss*in`/`Genoss*innen`. |

### Bureaucratic or ill-suited typographic conventions

| Form | Languages concerned | Why |
|---|---|---|
| `(a)`, `/a`, `/o` | pt-BR, es, it | Administrative form, not militant. |
| `@` (arroba) | pt-BR, es | Obsolete, accessibility issue (screen readers). |
| `x` (Latinx) | es, pt-BR | Supplanted by neutral `e` in contemporary militant usage. |
| `(e)`, separate `-e` | fr | Pre-2010 convention, replaced by the middle dot. |
| `Genderdoppelpunkt` (`:innen`) | de | Valid but not adopted for consistency with `*`. |
| `he/she`, `s/he`, `(s)he` | en | Prefer singular `they/them`. |
| Triple `(o/a/e)` | es | Reserved for pt-BR; Spanish uses ONLY the neutral `e`. |
| Middle dot `·` as gender marker | es, it, ca | French convention; elsewhere `·` is only a separator (or the geminate `l·l` in ca). |
| Triple `/trice/e`, suffix `/x` | it | Malformed; use abbreviated slash `/trice`. |

---

## Procedure for future additions

### When adding a new i18n key

1. **Identify** the word/expression to translate. Is it a term that requires gendering?
2. **If so, choose the epicene form when it exists** (`camarada` pt-BR,
   `responsable` fr, `utente` it…).
3. **Otherwise, apply the convention of the language** as defined above.
4. **For Italian**: distinguish regular pairs (asterisk) from irregular pairs
   (abbreviated slash).
5. **Check consistency** with the rest of the file.
6. **Fill in all 10 locales in a single pass.** A partially translated key is a bug.
   **Key parity** across the 10 locales is mandatory.

### When reviewing an existing translation

1. Look for **proscribed** markers (`(a)`, `@`, `camerata`, middle dot outside
   fr/ca-geminate, triple `/trice/e`…).
2. Replace them with the official form for the language.
3. Check singular/plural consistency.
4. Check cross-locale consistency for the same key.

### When requesting a translation from an AI

Always provide this charter as context, specify the expected convention for
the target language and the proscribed terms, prefer epicene forms, and
**verify the result** before integration.

---

## Test coverage (CI)

- `src/tests/i18n.test.js` tests **key parity** and **conformity** across
  **8 locales**: `pt-BR, fr, en, de, it, es, ca, eo`. It includes the blocking test
  "Italian must never contain camerata/camerati".
- `supabase/functions/_shared/i18n/mail-strings.test.ts` (Deno) tests the
  mail strings: parity, proscribed terms (camerata), interpolation, fallback.
- ⚠️ **`nl` and `el` are NOT covered by the CI gate**: their key parity
  and conformity are not automatically guaranteed. **Backlog**: add them to
  `i18n.test.js` once their conventions are settled.

---

## Evolution of the charter

This charter is a living document. It may be modified according to the following
principles:

- **Additions to reference political terms**: by collective decision documented in
  the repository (issue or pull request).
- **Changing the convention for a language**: requires the participation of at least
  one militant native speaker of the language concerned. The change must be
  politically and technically motivated.
- **Settling provisional (`nl`) or to-be-defined (`el`) conventions**: follows the
  same protocol — a situated militant typographic choice, justified, validated by
  native contributors, then committed to this charter and added to the CI gate.
- **Adding a new language**: same protocol.

---

*Charter v2 drafted on 2026-06-05 following the inclusive language audit of the
ten locales and the mail strings. Reference document to be committed to
`notes-audit/` in the repository. Replaces v1.0 of 2026-04-28.*
