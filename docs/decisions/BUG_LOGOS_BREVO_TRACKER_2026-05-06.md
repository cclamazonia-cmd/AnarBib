# Bug : logos cassés dans les mails archivés (tracker Brevo `sendibt3.com`)

**Data:** 06/05/2026 (sessão da noite, durante o desenvolvimento do Lote 5 spec-gouvernance)
**Tipo:** Bug pré-existente descoberto incidentalmente
**Prioridade:** Média (afeta a leitura dos arquivos, não a entrega)
**Status:** Documentado, correção a planejar

## Resumo

Os emails enviados via Brevo (todos os emails de notificação AnarBib : circulação, perfil, equipe…) contêm logos AnarBib e BLMF que **não se exibem** quando os emails são abertos depois de algum tempo. Os logos aparecem como imagens quebradas ou ausentes.

## Investigação técnica

O HTML dos emails enviados por Brevo contém balises `<img>` cujas URLs são reescritas pelo tracker Brevo, da forma:

```html
<img src="https://baheaahh.r.bh.d.sendibt3.com/im/10740077/<hash_do_arquivo>.png" ...>
```

Em vez de pointer diretamente para as URLs originais (Supabase Storage), Brevo as reescreve para passar pelo seu CDN de tracking. Isso lhe permite medir aberturas/clicks etc. O domínio `baheaahh.r.bh.d.sendibt3.com` é específico à campanha e ao destinatário.

**Diagnóstico definitivo** efetuado em 06/05/2026 22h:

```bash
# Teste das URLs Brevo (depuis o cliente local) :
> Invoke-WebRequest -Uri "https://baheaahh.r.bh.d.sendibt3.com/im/..."
ERROR : Le nom distant n'a pas pu être résolu

# Teste das URLs Supabase Storage originais :
> Invoke-WebRequest -Uri "https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/.../logo.png"
Status: 200, Content-Type: image/png, Size: 177353 octets
```

**Conclusão** : os arquivos sources existem e estão acessíveis. O problema é exclusivamente o tracker Brevo cuja DNS não resolve mais (provavelmente deletado/expirado para essa campanha específica).

## Impacto

- **Emails recém-enviados** : logos podem se exibir corretamente (URL Brevo ainda ativa)
- **Emails arquivados** : logos quebrados após alguns dias/semanas
- **Não afeta a entrega** : os emails chegam e são legíveis (apenas os logos faltam)
- **Afeta TODAS as notificações AnarBib** : circulação (notify-event existente), perfil (notify-event), equipe (Lote 5), tarefas internas, etc.

## Soluções possíveis

### Solução A — Desativar reescrita de imagens em Brevo
Configurar a conta Brevo para que ela não reescreva as URLs `<img>` (passthrough mode). Vantagem : as URLs Supabase originais ficam estáveis. Desvantagem : perda do tracking de aberturas baseado em pixel.

### Solução B — Embarcar os logos como anexos inline (CID)
Em vez de URLs externas, embarcar os PNGs como Content-ID inline. Vantagem : máxima estabilidade, nenhuma dependência externa. Desvantagem : aumenta o peso de cada email (~370 KB de logos por email).

### Solução C — Cache CDN externo (Cloudflare Images, etc.)
Hospedar os logos em uma CDN com longa rétention. Mas como Brevo reescreve qualquer URL externa, isso não resolve nada.

## Recomendação

**Solução A** se Brevo permite desativar o tracking de imagens via configuração. Verificar primeiro nas configurações da conta Brevo:
- Account Settings → Email tracking → Image tracking → Disable
- Ou via API: parâmetro `params: {"tracking": {"opens": false}}` ao enviar

Se a Solução A não está disponível, **Solução B** vale a pena para os logos AnarBib + BLMF (que são pequenos), mesmo se isso aumenta o peso dos emails.

## Próximas etapas

1. **Verificar nas configurações da conta Brevo** se o tracking de imagens pode ser desativado
2. **Testar em staging** com um email não-rastreado e validar que os logos se exibem corretamente
3. **Se Solução A funciona** : aplicar em produção, observar a taxa de abertura (deveria não cair se o tracking by pixel já é parcialmente bloqueado)
4. **Se Solução A não funciona** : implementar a Solução B (embarcar inline) em `_shared/transport/email.ts` (a função `sendBrevoEmail` deve então passar `attachment` com `cid` no lugar de URLs `<img src>`)

## Referências

- `_shared/transport/email.ts` → função `sendBrevoEmail`
- `_shared/mail/layout.ts` → função `renderEmail` que constrói o HTML
- Edge Function Secrets : `ANARBIB_LOGO_URL`, `BLMF_LOGO_URL` (apontam corretamente para Supabase Storage)
- API Brevo : https://developers.brevo.com/reference/sendtransacemail
