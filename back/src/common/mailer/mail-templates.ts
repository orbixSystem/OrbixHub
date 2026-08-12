import { VerificationEmail } from './mailer.service';

/**
 * Templates dos e-mails transacionais. HTML com estilo INLINE de propósito:
 * Gmail/Outlook descartam <style> e classes, então cada regra vai no atributo.
 * Toda mensagem leva também versão em texto puro — filtro de spam penaliza
 * e-mail só-HTML, e cliente de e-mail antigo só mostra o texto.
 *
 * Paleta espelhada de `front/lib/core/theme/app_colors.dart` (grafite + brand).
 */

const GRAPHITE = '#2B2F44';
const BRAND = '#575DA8';
const INK = '#2B2F44';
const INK_MUTED = '#7B8094';
const CANVAS = '#E6E7EE';

export interface RenderedMail {
  subject: string;
  html: string;
  text: string;
}

/** Escapa texto vindo de dados (nome de cliente, oficina) antes de ir pro HTML. */
export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** Remove barras finais para concatenar caminho sem gerar `//`. */
export function trimTrailingSlash(url: string): string {
  return url.replace(/\/+$/, '');
}

export interface LayoutInput {
  /** Título grande dentro do card. */
  heading: string;
  /** Parágrafos do corpo — JÁ escapados/seguros. */
  paragraphs: string[];
  ctaLabel: string;
  ctaUrl: string;
  /** Linha discreta no rodapé do card (ex.: aviso de expiração). */
  footnote?: string;
  brandName?: string;
}

/**
 * Molde único de todos os e-mails: cabeçalho grafite com a marca, card branco
 * com o texto e um botão, e o link em texto logo abaixo — cliente de e-mail que
 * bloqueia o botão ainda deixa o destinatário copiar o endereço.
 */
export function renderLayout(input: LayoutInput): RenderedMail {
  const brand = escapeHtml(input.brandName ?? 'OrbixHub');
  const body = input.paragraphs
    .map(
      (p) =>
        `<p style="margin:0 0 16px;font-size:15px;line-height:1.6;color:${INK};">${p}</p>`,
    )
    .join('');
  const footnote = input.footnote
    ? `<p style="margin:24px 0 0;font-size:13px;line-height:1.5;color:${INK_MUTED};">${input.footnote}</p>`
    : '';

  const html = `<!doctype html>
<html lang="pt-BR">
<body style="margin:0;padding:0;background:${CANVAS};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${CANVAS};padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#FFFFFF;border-radius:14px;overflow:hidden;font-family:Arial,Helvetica,sans-serif;">
        <tr><td style="background:${GRAPHITE};padding:20px 28px;">
          <span style="color:#FFFFFF;font-size:18px;font-weight:bold;letter-spacing:0.3px;">${brand}</span>
        </td></tr>
        <tr><td style="padding:32px 28px;">
          <h1 style="margin:0 0 20px;font-size:21px;line-height:1.3;color:${INK};">${escapeHtml(input.heading)}</h1>
          ${body}
          <table role="presentation" cellpadding="0" cellspacing="0" style="margin:26px 0 8px;">
            <tr><td style="background:${BRAND};border-radius:10px;">
              <a href="${input.ctaUrl}" style="display:inline-block;padding:13px 26px;font-size:15px;font-weight:bold;color:#FFFFFF;text-decoration:none;">${escapeHtml(input.ctaLabel)}</a>
            </td></tr>
          </table>
          <p style="margin:16px 0 0;font-size:12px;line-height:1.5;color:${INK_MUTED};word-break:break-all;">
            Se o botão não funcionar, copie e cole este endereço no navegador:<br />${input.ctaUrl}
          </p>
          ${footnote}
        </td></tr>
        <tr><td style="padding:18px 28px;border-top:1px solid #E6E7EE;font-size:12px;color:${INK_MUTED};">
          Este e-mail foi enviado automaticamente pelo ${brand}. Não é preciso respondê-lo.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

  const text = [
    input.heading,
    '',
    ...input.paragraphs.map(stripTags),
    '',
    `${input.ctaLabel}: ${input.ctaUrl}`,
    ...(input.footnote ? ['', stripTags(input.footnote)] : []),
  ].join('\n');

  return { subject: input.heading, html, text };
}

/** Versão texto: tira as tags e desfaz as entidades que o escape introduziu. */
function stripTags(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();
}

/** Minutos de validade dos tokens de verificação/reset (espelha OTT_TTL_MIN). */
const TOKEN_TTL_MIN = 30;

/**
 * Monta o link que o app entende. O front usa hash URL strategy, então o `/#/`
 * é obrigatório — sem ele a rota não casa e o destinatário cai no login.
 * As telas já leem `?token=` (verify/reset) e `/convite/:token`.
 */
export function buildActionUrl(
  kind: VerificationEmail['kind'],
  token: string,
  publicUrl: string,
): string {
  const base = trimTrailingSlash(publicUrl);
  const safe = encodeURIComponent(token);
  switch (kind) {
    case 'email_verify':
      return `${base}/#/verify?token=${safe}`;
    case 'password_reset':
      return `${base}/#/reset?token=${safe}`;
    case 'invite':
      return `${base}/#/convite/${safe}`;
  }
}

/**
 * Link público de acompanhamento da OS. Mesmo `/#/` dos links de identidade —
 * o front usa hash URL strategy, e sem ele o cliente cai no login.
 */
export function buildTrackingUrl(token: string, publicUrl: string): string {
  return `${trimTrailingSlash(publicUrl)}/#/t/${encodeURIComponent(token)}`;
}

export interface TrackingLinkMailInput {
  /** Nome da oficina (vira a marca do e-mail e o remetente visível). */
  companyName: string;
  customerName?: string | null;
  /** Número da OS (ex.: `OS-0007`), quando houver. */
  orderNumber?: string | null;
  url: string;
}

/**
 * E-mail com o link de acompanhamento da OS. Vai para o CLIENTE (não é um
 * fluxo de identidade): a marca é a da oficina, não a nossa, e o assunto cita a
 * OS para o destinatário reconhecer de imediato.
 */
export function renderTrackingLinkEmail(
  input: TrackingLinkMailInput,
): RenderedMail {
  const company = input.companyName.trim() || 'OrbixHub';
  const name = input.customerName?.trim();
  const number = input.orderNumber?.trim();
  const greeting = name ? `Olá, ${escapeHtml(name)}!` : 'Olá!';
  const os = number
    ? `a sua ordem de serviço <strong>${escapeHtml(number)}</strong>`
    : 'a sua ordem de serviço';

  const rendered = renderLayout({
    heading: 'Acompanhe sua ordem de serviço',
    paragraphs: [
      greeting,
      `A ${escapeHtml(company)} preparou uma página para você acompanhar ${os} em tempo real: status, fotos e mensagens.`,
    ],
    ctaLabel: 'Acompanhar minha OS',
    ctaUrl: input.url,
    footnote:
      'O link é pessoal — guarde-o para voltar quando quiser. Se você não reconhece esta mensagem, pode ignorá-la.',
    brandName: company,
  });

  return {
    ...rendered,
    subject: number
      ? `Acompanhe sua OS ${number} — ${company}`
      : `Acompanhe sua ordem de serviço — ${company}`,
  };
}

/** Renderiza um dos três e-mails de identidade a partir do kind + token. */
export function renderVerificationEmail(
  email: VerificationEmail,
  publicUrl: string,
): RenderedMail {
  const url = buildActionUrl(email.kind, email.token, publicUrl);
  switch (email.kind) {
    case 'email_verify':
      return renderLayout({
        heading: 'Confirme seu e-mail',
        paragraphs: [
          'Falta pouco para sua conta no OrbixHub ficar pronta. Confirme que este endereço é seu clicando no botão abaixo.',
        ],
        ctaLabel: 'Confirmar e-mail',
        ctaUrl: url,
        footnote: `O link vale por ${TOKEN_TTL_MIN} minutos. Se você não criou uma conta no OrbixHub, ignore este e-mail.`,
      });
    case 'password_reset':
      return renderLayout({
        heading: 'Redefinir sua senha',
        paragraphs: [
          'Recebemos um pedido para redefinir a senha da sua conta no OrbixHub. Clique no botão abaixo para escolher uma nova senha.',
        ],
        ctaLabel: 'Criar nova senha',
        ctaUrl: url,
        footnote: `O link vale por ${TOKEN_TTL_MIN} minutos e só pode ser usado uma vez. Se não foi você que pediu, ignore este e-mail — sua senha atual continua valendo.`,
      });
    case 'invite':
      return renderLayout({
        heading: 'Você foi convidado para o OrbixHub',
        paragraphs: [
          'Alguém da sua equipe criou um acesso para você no OrbixHub. Clique no botão abaixo para definir sua senha e entrar.',
        ],
        ctaLabel: 'Aceitar convite',
        ctaUrl: url,
        footnote:
          'Se você não esperava este convite, pode ignorar este e-mail — nenhum acesso é criado sem você definir a senha.',
      });
  }
}
