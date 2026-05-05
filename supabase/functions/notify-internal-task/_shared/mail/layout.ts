import { FOOTER_TEXT, LIBRARIAN_PHONE, REGIMENTO_URL } from "../core/env.ts";
import { resolveMailRouting } from "../context/library-mail-routing.ts";
import { esc } from "../shared/format.ts";
export function footerPadrao(context) {
  const pieces = [];
  if (REGIMENTO_URL) {
    pieces.push(`Regimento: <a href="${esc(REGIMENTO_URL)}" style="color:#fff;text-decoration:underline;">abrir</a>`);
  }
  if (LIBRARIAN_PHONE) {
    pieces.push(`Telefone da biblioteca: <b>${esc(LIBRARIAN_PHONE)}</b>`);
  }
  if (context?.footer_local) pieces.push(String(context.footer_local).trim());
  else pieces.push("Em caso de dúvida, entre em contato com a biblioteca.");
  return pieces.join("<br>");
}
export function renderEmail(opts) {
  const routing = resolveMailRouting(opts.context);
  const pre = opts.preheader ? esc(opts.preheader) : "";
  const greeting = opts.greeting ? `<p style="margin:0 0 12px;font-size:16px;line-height:1.5;">${esc(opts.greeting)}</p>` : "";
  const details = opts.details?.length ? `<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:14px 0 0;border-collapse:collapse;">
        ${opts.details.map((r)=>`
          <tr>
            <td style="padding:8px 0;color:#cfcfcf;font-size:14px;vertical-align:top;">${esc(r.label)}</td>
            <td style="padding:8px 0;color:#ffffff;font-size:14px;text-align:right;"><b>${esc(r.value)}</b></td>
          </tr>`).join("")}
       </table>
       <div style="height:1px;background:rgba(255,255,255,0.12);margin:14px 0 0;"></div>` : "";
  const footer = opts.footerHtml || "";
  const showNetworkLogo = !!routing.networkLogoUrl;
  const showLibraryLogo = !!routing.libraryLogoUrl && routing.libraryLogoUrl !== routing.networkLogoUrl;
  const networkLogoHtml = showNetworkLogo ? `<img src="${esc(routing.networkLogoUrl)}" alt="AnarBib" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">` : "";
  const libraryLogoHtml = showLibraryLogo ? `<img src="${esc(routing.libraryLogoUrl)}" alt="${esc(routing.brandName)}" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">` : "";
  const html = `<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(opts.title)}</title>
</head>
<body style="margin:0;background:#0f0f10;color:#ffffff;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${pre}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;">
    <tr>
      <td align="center" style="padding:24px 12px;">
        <table role="presentation" width="640" cellspacing="0" cellpadding="0" style="border-collapse:collapse;max-width:640px;width:100%;">
          <tr>
            <td style="background:rgba(27,27,27,0.94);border:1px solid rgba(255,255,255,0.12);border-radius:18px;overflow:hidden;">
              <div style="padding:18px 18px 14px;display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;">
                <div style="display:flex;align-items:center;gap:12px;min-width:0;">
                  ${networkLogoHtml}
                  <div>
                    <div style="font-size:18px;font-weight:800;line-height:1.2;">${esc(routing.brandName)}</div>
                    <div style="font-size:13px;color:#cfcfcf;line-height:1.2;">Notificação automática</div>
                  </div>
                </div>
                ${showLibraryLogo ? `<div style="display:flex;align-items:center;justify-content:flex-end;">${libraryLogoHtml}</div>` : ""}
              </div>
              <div style="height:3px;background:#c00000;"></div>
              <div style="padding:18px;">
                <h1 style="margin:0 0 12px;font-size:20px;line-height:1.25;">${esc(opts.title)}</h1>
                ${greeting}
                <div style="font-size:16px;line-height:1.55;color:#f2f2f2;">${opts.introHtml}</div>
                ${details}
                <div style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#cfcfcf;">
                  ${footer}
                </div>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 6px 0;color:#9c9c9c;font-size:12px;line-height:1.4;text-align:center;">
              © ${esc(routing.subjectTag)} — ${esc(routing.footerText || FOOTER_TEXT)}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body></html>`;
  const textLines = [];
  textLines.push(`${routing.brandName} (${routing.subjectTag})`);
  textLines.push(opts.title);
  textLines.push("");
  if (opts.greeting) textLines.push(opts.greeting, "");
  const introText = opts.introHtml.replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>\s*<p>/gi, "\n\n").replace(/<[^>]+>/g, "").replace(/&nbsp;/g, " ").trim();
  textLines.push(introText, "");
  if (opts.details?.length) {
    for (const r of opts.details)textLines.push(`${r.label}: ${r.value}`);
    textLines.push("");
  }
  if (REGIMENTO_URL) textLines.push(`Regimento: ${REGIMENTO_URL}`);
  if (LIBRARIAN_PHONE) textLines.push(`Telefone da biblioteca: ${LIBRARIAN_PHONE}`);
  textLines.push(FOOTER_TEXT);
  const text = textLines.join("\n");
  return {
    html,
    text
  };
}
