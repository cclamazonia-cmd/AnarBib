// =============================================================================
// AnarBib — Client SMTP pur pour Deno / Edge Runtime
// =============================================================================
// Permet d'envoyer des e-mails en auto-hébergement sans dépendre d'une API tierce.
// Supporte :
//   - Connexion TCP directe (port 25 / 587) avec STARTTLS obligatoire
//     (sauf opt-in explicite SMTP_ALLOW_INSECURE=true pour relais local)
//   - Connexion TLS directe (port 465)
//   - Authentification AUTH LOGIN et AUTH PLAIN
//   - Envoi multipart/alternative (HTML + texte brut) encodé en base64 plié
//     à 76 colonnes selon RFC 2045 (immunité dot-stuffing et limite 1000 octets)
//   - Timeout configurable sur chaque opération réseau
// =============================================================================

export interface SmtpOptions {
  host: string;
  port?: number;
  user?: string;
  pass?: string;
  secure?: boolean; // true pour port 465 (TLS direct)
  allowInsecure?: boolean; // true pour autoriser l'absence de STARTTLS sur port 25/587
  timeoutMs?: number; // timeout par commande/connexion (défaut: 15000 ms)
  from: string;
  // Adresse d'ENVELOPPE (MAIL FROM, futur Return-Path) : là où reviennent les
  // refus. Absente, c'est l'adresse du From (24/10/2026).
  envelopeFrom?: string;
  to: string[];
  replyTo?: string;
  subject: string;
  html: string;
  text?: string;
}

// ─── Erreurs qualifiées (19/10/2026, sortie de Resend par Nodo50) ──────────
// Le transport (_shared/transport/email.ts) rejoue un échec temporaire et
// jamais un refus définitif : il lui faut le code de la réponse et l'étape où
// l'envoi a échoué, sans relire le message. Chaque erreur qui sort de
// sendViaSmtp porte `smtpEtape` (connexion, ehlo, starttls, auth, mail_from,
// rcpt, data, livraison) et, quand le serveur a répondu, `smtpCode` (421, 535,
// 550…) ; un timeout ou une connexion rompue n'a pas de code. Le message, lui,
// ne change pas : c'est lui qu'on note dans mail_transport_failures.
export interface SmtpErreur extends Error {
  smtpCode?: number | null;
  smtpEtape?: string;
}

function echec(message: string, reponse?: string): SmtpErreur {
  const e = new Error(message) as SmtpErreur;
  const m = /^\s*(\d{3})/.exec(reponse ?? "");
  e.smtpCode = m ? Number(m[1]) : null;
  return e;
}

export function resolveTimeout(raw: unknown, fallbackMs = 15000): number {
  const parsed = typeof raw === "number" ? raw : parseInt(String(raw ?? ""), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackMs;
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number, operation: string): Promise<T> {
  let timer: number | undefined;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reject(new Error(`Timeout SMTP (${timeoutMs}ms) dépassé lors de : ${operation}`));
    }, timeoutMs);
  });
  return Promise.race([promise, timeoutPromise]).finally(() => {
    if (timer !== undefined) clearTimeout(timer);
  });
}

class SmtpConnection {
  private conn: Deno.Conn | null = null;
  private reader: ReadableStreamDefaultReader<Uint8Array> | null = null;
  private encoder = new TextEncoder();
  private decoder = new TextDecoder();
  private buffer = "";
  private timeoutMs: number;

  constructor(timeoutMs = 15000) {
    this.timeoutMs = timeoutMs;
  }

  async connect(host: string, port: number, secure: boolean): Promise<void> {
    const connectPromise = secure
      ? Deno.connectTls({ hostname: host, port })
      : Deno.connect({ hostname: host, port });

    this.conn = await withTimeout(connectPromise, this.timeoutMs, `connexion à ${host}:${port}`);
    this.reader = this.conn.readable.getReader();

    const banner = await this.readResponse();
    if (!banner.startsWith("220")) {
      throw echec(`SMTP banner inattendue : ${banner}`, banner);
    }
  }

  async upgradeToTls(host: string): Promise<void> {
    if (!this.conn) throw new Error("Connexion non établie");
    if (this.reader) {
      this.reader.releaseLock();
    }
    const tlsPromise = Deno.startTls(this.conn as Deno.TcpConn, { hostname: host });
    this.conn = await withTimeout(tlsPromise, this.timeoutMs, `handshake TLS avec ${host}`);
    this.reader = this.conn.readable.getReader();
    this.buffer = "";
  }

  async sendCommand(cmd: string): Promise<string> {
    if (!this.conn) throw new Error("Connexion fermée");
    const writer = this.conn.writable.getWriter();
    await withTimeout(writer.write(this.encoder.encode(cmd + "\r\n")), this.timeoutMs, `écriture commande SMTP`);
    writer.releaseLock();
    return await this.readResponse();
  }

  async readResponse(): Promise<string> {
    if (!this.reader) throw new Error("Reader non disponible");
    return await withTimeout((async () => {
      while (true) {
        const lineEnd = this.buffer.indexOf("\r\n");
        if (lineEnd !== -1) {
          const line = this.buffer.slice(0, lineEnd);
          this.buffer = this.buffer.slice(lineEnd + 2);
          // Les réponses multilignes SMTP ont un tiret (ex: "250-SIZE")
          if (line.length >= 4 && line[3] === "-") {
            continue; // ligne intermédiaire
          }
          return line;
        }
        const { value, done } = await this.reader!.read();
        if (done) break;
        if (value) {
          this.buffer += this.decoder.decode(value, { stream: true });
        }
      }
      return this.buffer;
    })(), this.timeoutMs, "lecture réponse SMTP");
  }

  async close(): Promise<void> {
    try {
      if (this.conn) {
        await this.sendCommand("QUIT");
        this.conn.close();
      }
    } catch {
      // Ignore les erreurs de fermeture
    } finally {
      this.conn = null;
      this.reader = null;
    }
  }
}

export function extractEmail(address: string): string {
  const m = address.match(/<([^>]+)>/);
  return m ? m[1].trim() : address.trim();
}

export function encodeUtf8Header(text: string): string {
  if (!/[^\x20-\x7E]/.test(text)) {
    return text;
  }
  const b64 = btoa(unescape(encodeURIComponent(text)));
  return `=?UTF-8?B?${b64}?=`;
}

export function encodeAddress(address: string): string {
  const m = address.match(/^(.*)<([^>]+)>\s*$/);
  if (!m) return address.trim();
  const name = m[1].trim().replace(/^"|"$/g, "");
  const addr = m[2].trim();
  return name ? `${encodeUtf8Header(name)} <${addr}>` : `<${addr}>`;
}

// ─── Message-ID sur le domaine de l'expéditeur (21/10/2026) ───────────────
// Le premier courriel réel parti par le relais Nodo50 est arrivé chez Gmail
// sans Message-ID (Gmail en a posé un : « …SMTPIN_ADDED_MISSING@mx.google.com »),
// alors que ce client en écrivait un sur le nom du relais (@correo.nodo50.org).
// La règle (RFC 5322 §3.6.4, consignes d'envoi de Gmail) : un identifiant
// unique, à droite le domaine de l'expéditeur — c'est aussi celui que le DKIM
// signe. Sans domaine lisible dans le From, on garde le repli (le relais).
export function identifiantMessage(from: string, repli: string): string {
  const domaine = (extractEmail(from).split("@")[1] || "").trim().toLowerCase();
  const droite = /^[a-z0-9.-]+\.[a-z]{2,}$/.test(domaine) ? domaine : repli;
  return `<${Date.now()}.${Math.random().toString(36).slice(2)}@${droite}>`;
}

export function toBase64Wrapped(str: string): string {
  const b64 = btoa(unescape(encodeURIComponent(str)));
  return b64.replace(/(.{76})/g, "$1\r\n");
}

export async function sendViaSmtp(opts: SmtpOptions): Promise<string> {
  const host = opts.host;
  const port = opts.port ?? (opts.secure ? 465 : 587);
  const secure = opts.secure ?? (port === 465);
  const timeoutMs = resolveTimeout(opts.timeoutMs);
  const allowInsecure = opts.allowInsecure ?? false;

  const client = new SmtpConnection(timeoutMs);
  let etape = "connexion";
  try {
    await client.connect(host, port, secure);

    // Salutation EHLO
    etape = "ehlo";
    let ehloRes = await client.sendCommand(`EHLO ${Deno.env.get("API_DOMAIN") || "localhost"}`);
    if (!ehloRes.startsWith("250")) {
      ehloRes = await client.sendCommand(`HELO ${Deno.env.get("API_DOMAIN") || "localhost"}`);
      if (!ehloRes.startsWith("250")) {
        throw echec(`Échec EHLO/HELO : ${ehloRes}`, ehloRes);
      }
    }

    // STARTTLS si sur port non-sécurisé (587 ou 25)
    if (!secure) {
      etape = "starttls";
      const startTlsRes = await client.sendCommand("STARTTLS");
      if (startTlsRes.startsWith("220")) {
        await client.upgradeToTls(host);
        // Ré-émettre EHLO après le handshake TLS
        await client.sendCommand(`EHLO ${Deno.env.get("API_DOMAIN") || "localhost"}`);
      } else if (!allowInsecure) {
        throw echec(
          `STARTTLS refusé par le serveur SMTP (${startTlsRes.trim()}). ` +
          `Refus d'envoyer des identifiants en clair sans chiffrement TLS. ` +
          `(Pour autoriser explicitement un relais local sans TLS, définissez SMTP_ALLOW_INSECURE=true).`,
          startTlsRes
        );
      }
    }

    // Authentification si identifiants fournis
    if (opts.user && opts.pass) {
      etape = "auth";
      const authRes = await client.sendCommand("AUTH LOGIN");
      if (authRes.startsWith("334")) {
        const userB64 = btoa(opts.user);
        const userRes = await client.sendCommand(userB64);
        if (!userRes.startsWith("334")) {
          throw echec(`Échec auth SMTP (username) : ${userRes}`, userRes);
        }
        const passB64 = btoa(opts.pass);
        const passRes = await client.sendCommand(passB64);
        if (!passRes.startsWith("235")) {
          throw echec(`Échec auth SMTP (mot de passe) : ${passRes}`, passRes);
        }
      } else {
        // Tentative AUTH PLAIN
        const plainStr = `\0${opts.user}\0${opts.pass}`;
        const plainB64 = btoa(plainStr);
        const plainRes = await client.sendCommand(`AUTH PLAIN ${plainB64}`);
        if (!plainRes.startsWith("235")) {
          throw echec(`Échec auth SMTP (AUTH PLAIN) : ${plainRes}`, plainRes);
        }
      }
    }

    // Enveloppe MAIL FROM
    etape = "mail_from";
    const fromEmail = extractEmail(opts.envelopeFrom || opts.from);
    const mailFromRes = await client.sendCommand(`MAIL FROM:<${fromEmail}>`);
    if (!mailFromRes.startsWith("250")) {
      throw echec(`Échec MAIL FROM : ${mailFromRes}`, mailFromRes);
    }

    // Enveloppe RCPT TO
    etape = "rcpt";
    for (const to of opts.to) {
      const toEmail = extractEmail(to);
      const rcptRes = await client.sendCommand(`RCPT TO:<${toEmail}>`);
      if (!rcptRes.startsWith("250")) {
        throw echec(`Échec RCPT TO pour ${toEmail} : ${rcptRes}`, rcptRes);
      }
    }

    // Commande DATA
    etape = "data";
    const dataRes = await client.sendCommand("DATA");
    if (!dataRes.startsWith("354")) {
      throw echec(`Échec DATA : ${dataRes}`, dataRes);
    }

    // Construction du message MIME
    const boundary = `----=_Part_${Date.now()}_${Math.random().toString(36).slice(2)}`;
    const headers: string[] = [
      `From: ${encodeAddress(opts.from)}`,
      `To: ${opts.to.map(encodeAddress).join(", ")}`,
      `Subject: ${encodeUtf8Header(opts.subject)}`,
      `Date: ${new Date().toUTCString()}`,
      `MIME-Version: 1.0`,
      `Message-ID: ${identifiantMessage(opts.from, host)}`
    ];

    if (opts.replyTo) {
      headers.push(`Reply-To: ${encodeAddress(opts.replyTo)}`);
    }

    headers.push(`Content-Type: multipart/alternative; boundary="${boundary}"`);

    const textContent = opts.text || opts.html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
    const textPartB64 = toBase64Wrapped(textContent);
    const htmlPartB64 = toBase64Wrapped(opts.html);

    const bodyLines: string[] = [
      headers.join("\r\n"),
      "",
      `--${boundary}`,
      `Content-Type: text/plain; charset=utf-8`,
      `Content-Transfer-Encoding: base64`,
      "",
      textPartB64,
      "",
      `--${boundary}`,
      `Content-Type: text/html; charset=utf-8`,
      `Content-Transfer-Encoding: base64`,
      "",
      htmlPartB64,
      "",
      `--${boundary}--`,
      "." // Point final de fin de données SMTP
    ];

    etape = "livraison";
    const sendDataRes = await client.sendCommand(bodyLines.join("\r\n"));
    if (!sendDataRes.startsWith("250")) {
      throw echec(`Échec livraison DATA : ${sendDataRes}`, sendDataRes);
    }

    return sendDataRes;
  } catch (err) {
    // Timeout, connexion refusée ou rompue, TLS : l'erreur vient de Deno, sans
    // code ; on lui attache l'étape. Une erreur figée (non extensible) passe telle quelle.
    if (err && typeof err === "object") {
      const e = err as SmtpErreur;
      try {
        if (e.smtpEtape === undefined) e.smtpEtape = etape;
        if (e.smtpCode === undefined) e.smtpCode = null;
      } catch { /* ignoré */ }
    }
    throw err;
  } finally {
    await client.close();
  }
}
