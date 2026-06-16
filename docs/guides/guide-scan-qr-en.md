# Guide — Scanning & QR Codes in AnarBib

> **Who this guide is for.** Any library comrade who wants to use their phone (or
> computer) camera to save time: identifying a reader by their membership card,
> pulling a book's data from its barcode, or running a stock check. Written on
> request — and for the **commons** of the network.
>
> **Spirit.** Nothing here watches you or evaluates you. Code scanning happens
> **100% on your device**: no camera image leaves it. These tools exist to give
> you autonomy, not to lock you in. If something doesn't work, **the catalogue
> is never broken** — in the worst case, you just type it in by hand.
>
> Part of the **knowledge commons** of mutual aid (see the framing piece "Mutual
> aid in cataloguing"). Written by and for each language community: if you want a
> version in another language, it gets written in parallel — not translated top-down.

---

## What you can scan

AnarBib has **a single camera reader**, reused in three places:

| Where | What to scan | Why |
|---|---|---|
| **Dashboard › Manage reader** | **Membership card** QR | Identify a reader instantly |
| **Cataloguing** (book record) | **ISBN barcode** | Auto-fill title/author |
| **Dashboard › Inventory** | **Copy label** QR | Run a stock check |

In all cases: the camera opens inside AnarBib, reads the code, and that's it. No
app to install. If you like, you can **add AnarBib to your home screen** (browser
menu › "Add to home screen"): it opens full-screen like an app, but it's still
just the website.

---

## 1. Reader membership card

**Who creates the card:** the reader themselves, in their account (`/conta`), once
the library has enabled the feature. They generate a QR code and can download it
as PNG or PDF. The QR carries only an **opaque code** — no name, no personal data
inside it.

**How you use it at the desk:**

1. Go to **Dashboard › Manage reader**.
2. Click **"Scan card"** and point the camera at the membership card QR.
3. AnarBib resolves the code and shows **who the reader is** (and whether any
   restriction is active). Ready to lend, return, etc.

> **"Card not recognised"?** Almost always it's an **old card**. When a reader
> generates a new card, the previous one is **revoked** (a security measure). Ask
> them to generate/download their current card. Since 15/06, the system itself
> shows the message "card replaced — please generate a new one" in this case.

---

## 2. Scanning the ISBN when cataloguing

When adding a book that has a barcode (ISBN), you can skip typing everything in
by hand:

1. In the book record (cataloguing), open the **metadata search** panel.
2. Click **"Scan ISBN"** and point the camera at the **barcode** on the book's
   back cover.
3. The number fills the ISBN field automatically and AnarBib **fetches the data**
   (title, author…) from public sources. You review and adjust — the catalogue
   is yours.

> **Device tip.** Barcodes are more "demanding" than QR codes. **A phone reads
> them much better** than a desktop webcam (camera focus and resolution). If the
> webcam can't pick it up, don't insist: type the ISBN in by hand — it amounts to
> the same thing.

---

## 3. Stock inventory

Checking, copy by copy, what is actually on the shelves — and comparing it with
what the system believes the library holds.

**Before you start:** copy labels need to include a **QR code**. Print labels
with QR codes in **Cataloguing › Labels** (there is an "Include QR codes" option).
Each QR points to the individual copy.

**Running the inventory:**

1. Go to **Dashboard › Inventory** (visible to *librarians* and *coordinators*).
2. **"Start inventory"** — opens a session and shows how many copies the library
   has.
3. The camera stays open: **scan copies one after another**, QR by QR. Each
   successful read gives a **beep** and the counter goes up. No need to close and
   reopen the camera between books.
   - ✓ green = copy belongs to this collection, counted.
   - "Already scanned" = you already passed that one (no problem, it won't count
     twice).
   - ⚠ "Not in collection" = a copy that does **not** belong to this library
     (intruder).
4. If a QR code is damaged, you can **type it in by hand** (the label URL or the
   copy number).
5. **"Finish and view report"** — ends the session and shows:
   - **Present** (scanned and in the collection),
   - **Missing** (in the collection, but not scanned → search for them / write
     them off),
   - **Intruders** (scanned, but from another library / unknown).
6. Export the result as **CSV** (for a spreadsheet) or **PDF** (to print the
   missing list and go hunting on the shelves).

> **Pause and resume.** Big collection? You can stop and continue later. If you
> leave mid-session, it stays **in progress** and appears under "Sessions in
> progress" so you can **resume** from where you left off.

---

## Practical questions

**Do I need to install anything?** No. It's the website itself. Optionally, "Add
to home screen" to open it like an app.

**Does it work in my browser?** Yes. On Chrome/Android it uses the native reader
(faster). On **Brave**, **iOS/Safari**, and **Firefox**, AnarBib automatically
loads a fallback reader — so it **works there too**. If you see "scanning not
supported" when scanning an ISBN on one of these, refresh the page: the fallback
reader will load on its own.

**The camera won't open.** Check that you have given the site **camera
permission** (the padlock in the address bar). Browsers only allow camera access
over **HTTPS** — `app.anarbib.org` already is.

**Privacy.** Decoding is **local**. The camera image is **never sent** to any
server. The membership card QR holds only an opaque code; the label QR holds only
the copy's address. Sensitive holdings (BTL collections and the like) remain
protected by the same rules as always.

---

## In one sentence

The camera is **an outstretched hand** to spare you typing and checking — not an
obligation. Use it when it helps; ignore it when it doesn't. And if it freezes,
the keyboard is always there.

---

*An AnarBib commons document. Improvements and versions in other languages are
welcome, written in parallel by each language community.*
