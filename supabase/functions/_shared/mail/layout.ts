import type { EmailDetails, LibraryNotificationContext } from "../core/types.ts";
import { FOOTER_TEXT, LIBRARIAN_PHONE, REGIMENTO_URL } from "../core/env.ts";
import { resolveMailRouting } from "../context/library-mail-routing.ts";
import { esc } from "../shared/format.ts";

// ActionBox : encadré visuel inséré dans le mail biblio pour signaler clairement
// si une action est attendue ('action', orange/rouge) ou si c'est purement
// informatif ('info', gris). Paquet 6 commit comportement (2026-05-09).
//
// Quand 'action' avec ctaUrl/ctaLabel : un bouton CTA est rendu pointant vers
// le painel staff. Le mail texte reproduit le label + l'URL pour les clients
// qui n'affichent pas le HTML.
export type ActionBox = {
  kind: 'action' | 'info';
  title: string;
  ctaLabel?: string;
  ctaUrl?: string;
};
export function footerPadrao(ctx?: LibraryNotificationContext|null) { const p:string[]=[]; if (REGIMENTO_URL) p.push(`Regimento: <a href="${esc(REGIMENTO_URL)}" style="color:#fff;text-decoration:underline;">abrir</a>`); if (LIBRARIAN_PHONE) p.push(`Telefone: <b>${esc(LIBRARIAN_PHONE)}</b>`); if (ctx?.footer_local) p.push(String(ctx.footer_local).trim()); else p.push("Em caso de dúvida, entre em contato com a biblioteca."); return p.join("<br>"); }
export function renderEmail(opts: {preheader?:string;title:string;greeting?:string;introHtml:string;details?:EmailDetails;footerHtml?:string;context?:LibraryNotificationContext|null;actionBox?:ActionBox;libreDiffusionLabel?:string}) {
  const r=resolveMailRouting(opts.context); const pre=opts.preheader?esc(opts.preheader):"";
  const gr=opts.greeting?`<p style="margin:0 0 12px;font-size:16px;line-height:1.5;">${esc(opts.greeting)}</p>`:"";
  // ActionBox HTML — rendu juste après greeting, avant introHtml.
  // Couleurs : action = orange (#f0a040 sur fond rgba(200,100,0,.12)),
  // info = gris (#cfcfcf sur fond rgba(255,255,255,.06)). Cohérent avec
  // les badges du PanelPage (cf. PanelPage.css .ab-painel-stage).
  const ab=opts.actionBox?(()=>{
    const box=opts.actionBox!;
    const isAction=box.kind==='action';
    const bg=isAction?'rgba(200,100,0,.12)':'rgba(255,255,255,.06)';
    const bd=isAction?'rgba(200,100,0,.4)':'rgba(255,255,255,.15)';
    const fg=isAction?'#f0a040':'#cfcfcf';
    const cta=(isAction&&box.ctaUrl&&box.ctaLabel)?`<div style="margin-top:10px;"><a href="${esc(box.ctaUrl)}" style="display:inline-block;padding:8px 16px;background:#c00000;color:#fff;text-decoration:none;border-radius:6px;font-weight:700;font-size:14px;">${esc(box.ctaLabel)}</a></div>`:"";
    return `<div style="margin:0 0 14px;padding:12px 14px;background:${bg};border:1px solid ${bd};border-radius:8px;color:${fg};font-size:14px;line-height:1.5;"><strong>${esc(box.title)}</strong>${cta}</div>`;
  })():"";
  const det=(opts.details?.length)?`<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:14px 0 0;border-collapse:collapse;">${opts.details.map(d=>`<tr><td style="padding:8px 0;color:#cfcfcf;font-size:14px;vertical-align:top;">${esc(d.label)}</td><td style="padding:8px 0;color:#ffffff;font-size:14px;text-align:right;"><b>${esc(d.value)}</b></td></tr>`).join("")}</table><div style="height:1px;background:rgba(255,255,255,0.12);margin:14px 0 0;"></div>`:"";
  const ft=opts.footerHtml||"";
  const nlogo=r.networkLogoUrl?`<img src="${esc(r.networkLogoUrl)}" alt="AnarBib" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">`:"";
  const llib=r.libraryLogoUrl&&r.libraryLogoUrl!==r.networkLogoUrl?`<img src="${esc(r.libraryLogoUrl)}" alt="${esc(r.brandName)}" style="display:block;max-width:84px;max-height:52px;width:auto;height:auto;object-fit:contain;">`:"";
  const html=`<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(opts.title)}</title></head><body style="margin:0;background:#0f0f10;color:#ffffff;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;"><div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${pre}</div><table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border-collapse:collapse;"><tr><td align="center" style="padding:24px 12px;"><table role="presentation" width="640" cellspacing="0" cellpadding="0" style="border-collapse:collapse;max-width:640px;width:100%;"><tr><td style="background:rgba(27,27,27,0.94);border:1px solid rgba(255,255,255,0.12);border-radius:18px;overflow:hidden;"><div style="padding:18px 18px 14px;display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap;"><div style="display:flex;align-items:center;gap:12px;min-width:0;">${nlogo}<div><div style="font-size:18px;font-weight:800;line-height:1.2;">${esc(r.brandName)}</div><div style="font-size:13px;color:#cfcfcf;line-height:1.2;">Notificação automática</div></div></div>${llib?`<div style="display:flex;align-items:center;justify-content:flex-end;">${llib}</div>`:""}</div><div style="height:3px;background:#c00000;"></div><div style="padding:18px;"><h1 style="margin:0 0 12px;font-size:20px;line-height:1.25;">${esc(opts.title)}</h1>${gr}${ab}<div style="font-size:16px;line-height:1.55;color:#f2f2f2;">${opts.introHtml}</div>${det}<div style="margin:16px 0 0;font-size:13px;line-height:1.5;color:#cfcfcf;">${ft}</div></div></td></tr><tr><td style="padding:12px 6px 0;color:#9c9c9c;font-size:12px;line-height:1.4;text-align:center;">${esc(r.subjectTag)}${opts.libreDiffusionLabel?` — ${esc(opts.libreDiffusionLabel)}`:""} — ${esc(r.footerText||FOOTER_TEXT)}</td></tr></table></td></tr></table></body></html>`;
  const tl:string[]=[`${r.brandName} (${r.subjectTag})`,opts.title,""];
  if (opts.greeting) tl.push(opts.greeting,"");
  // ActionBox version texte : titre + (label + URL si CTA)
  if (opts.actionBox) { tl.push(`>>> ${opts.actionBox.title} <<<`); if (opts.actionBox.kind==='action'&&opts.actionBox.ctaUrl&&opts.actionBox.ctaLabel) tl.push(`${opts.actionBox.ctaLabel}: ${opts.actionBox.ctaUrl}`); tl.push(""); }
  tl.push(opts.introHtml.replace(/<br\s*\/?>/gi,"\n").replace(/<\/p>\s*<p>/gi,"\n\n").replace(/<[^>]+>/g,"").replace(/&nbsp;/g," ").trim(),"");
  if (opts.details?.length) for (const d of opts.details) tl.push(`${d.label}: ${d.value}`); tl.push(""); if (REGIMENTO_URL) tl.push(`Regimento: ${REGIMENTO_URL}`); if (LIBRARIAN_PHONE) tl.push(`Telefone: ${LIBRARIAN_PHONE}`); tl.push(FOOTER_TEXT);
  return { html, text: tl.join("\n") };
}
