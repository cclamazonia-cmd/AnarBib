# AnarBib — User Manual
## Network of Libertarian Libraries

*Version 1.1 — September 2026*

---

## 1. Getting started

### Logging in
Go to your AnarBib instance URL and click **Entrar** (or the login button in your interface language). Enter your email address and password.

### Changing the language
The language selector is at the top right of every page (🇧🇷🇵🇹 / 🇫🇷 / 🇪🇸 / 🇬🇧 / 🇮🇹 / 🇩🇪 / 🇳🇱 / 🇬🇷 / Català / Esperanto). Your choice is saved locally.

### Searching the catalog
The **Catalog** shows one line per work, in the language of your interface when the title has been translated: author, title, number of editions and the libraries that hold it.
1. Click **Show editions** (the “+” on the line): each edition appears below, with its cover, publisher and year. The volumes of a multi-volume work are numbered and sorted.
2. Click **Copies by library**: availability is shown library by library. If you are signed in, “your library” is flagged; what is available elsewhere but not for you is said as such.
3. The **Flat list** button goes back to one line per edition; the choice is remembered.

---

## 2. Reader — My account

### Reserving a document
1. Search for the document in the **Catalogue**
2. Click on its record
3. If the document is available, click **Réserver un emprunt**
4. You can also go to the **Reservations** tab in your account and enter the local reference

### Tracking your loans
The **Active loans** tab shows your current loans with:
- The checkout date and due date
- A **Renew** button (if renewal is permitted)
- An indication of any overdue status

### Renewing a loan
Click **Renew** in your loan list. Renewal may be refused if:
- The loan has already been renewed once
- The loan is overdue
- Another reader has reserved the same document

### Account status banner
At the top of the **My account** page, a coloured banner shows your account status:
- ✓ **Green**: Account active, everything is fine
- ⚠ **Orange**: Attention required (overdue loan, password change needed)
- ⛔ **Red**: Account restricted (contact your library)

### History
The **History** tab lists your past reservations and loans. You can click on a title to view the document record, and **Hide** entries you no longer wish to see.

---

## 3. Librarian — Dashboard

### Work for today
The dashboard automatically generates priority tasks:
- Pickups scheduled for today
- New reservations to process
- Reservations ready for pickup
- Overdue loans
- Returns expected today
- In-library consultations to process

### Managing reservations
The **Reservations** tab allows you to:
- Select multiple reservations (checkboxes)
- Apply a step in bulk (prepare, schedule pickup, confirm)
- Cancel reservations

### Managing loans
- **Create a loan**: enter the reader's ID or email + the local references
- **Full return**: enter the loan ID
- **Partial return**: enter individual copy IDs
- **Grouped loans**: summary view by loan

### Managing a reader
The **Manage reader** tab allows you to:
- Search by public ID, email, or name
- Edit the profile (name, email, phone, gender, address)
- **Restrict access** (with reason: non-return, etc.)
- **Lift the restriction**

---

## 4. Cataloguing

### Creating a document record
1. Go to **Cataloguing** > **Document** tab
2. Select the **material type** (Book, Periodical, Leaflet, Audio, etc.)
3. Fill in the fields (Simple mode shows the essentials, Full mode shows all fields)
4. Use **Search metadata** to pre-fill via ISBN
5. **Save the draft**

### Work, editions and volumes
A work gathers all the editions of one text. In a document's record, the **Work** block lets you:
- **Attach to another work**: search the work by title, then **Attach**. The work you leave disappears if it is left empty.
- **Titles by language**: one title per interface language. Titles marked “machine translation — correct me” were proposed by the machine: read them over and click **Save** to confirm them.
- **Uniform title**: the reference title of the work, written in the original language of the work itself, not in the language of a translation.
- **Volume**: the volume number when the work spans several volumes. Volumes stay within a single work.

### Deduplication assistant: split works and volumes
In the **Deduplication assistant** (Cataloguing), two tabs complement record duplicates:
- **Split works**: two works that look like the same text. **Merge into “…”** brings them together; **Keep apart** records the decision and the pair does not come back.
- **Volumes**: records that look like the volumes of one work. Tick **Join this record** for each volume you keep, enter its number and confirm; a settled group does not come back.

No merge and no volume number is ever set by the machine: every action is yours.

### Document types and specialised fields
Each document type displays adapted fields:
- **Periodical**: volume, issue, fascicle, periodicity, ISSN
- **Leaflet**: campaign, issuing organisation, approximate date, physical format
- **Audio**: duration, medium, technical format, participants
- **Audiovisual**: duration, direction, subtitles
- **Digital resource**: URL, access condition, restriction
- **File/Dossier**: scope, period, organisations, political context

### Translating author biographies
In the **Author** tab, when editing a published author:
1. Open the **Biography translations** panel
2. Enter the biography in each desired language
3. Click **Save translations**

### Printing labels
In the **Indexing** tab, beneath the copy form:
1. Filter and select the copies
2. Click **Print X label(s)**
3. An A4 document opens with 21 labels per page (7×3)

---

## 5. Administration

### Library management
The **Library** page lets you configure:
- Identity (name, city, contact)
- Communications (emails, sending modes, notification types)
- Rules (PDF upload, circulation rules)
- Team, interlibrary exchanges, reports

### Network management
The **Network** page (accessible to coordinators and administrators) lets you:
- View the overview (global stats)
- Manage library requests
- Administer network members
- Promote administrators

---

## 6. Available languages

The interface is available in 10 languages:
- 🇧🇷🇵🇹 Português (reference language)
- 🇫🇷 Français
- 🇪🇸 Castellano
- 🇬🇧 English
- 🇮🇹 Italiano
- 🇩🇪 Deutsch
- 🇳🇱 Nederlands
- 🇬🇷 Ελληνικά
- Català
- Esperanto

Author biographies can be translated independently into each language.

Work titles are pre-translated automatically into the ten languages; they carry the mention “correct me” until a person has read them over.

---

*AnarBib — Network of Libertarian Libraries*
*Free/libre software for the cooperative management of militant knowledge*
