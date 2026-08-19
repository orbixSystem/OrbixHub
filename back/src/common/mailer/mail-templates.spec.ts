import {
  buildActionUrl,
  buildTrackingUrl,
  escapeHtml,
  renderLayout,
  renderTrackingLinkEmail,
  renderVerificationEmail,
} from './mail-templates';

describe('mail-templates', () => {
  describe('buildActionUrl', () => {
    // O front usa hash URL strategy: sem o `/#/` a rota não casa e o
    // destinatário cai no login em vez da tela do link.
    it('builds the three identity links in the shape the app routes expect', () => {
      const base = 'https://hub.orbixsystem.com';
      expect(buildActionUrl('email_verify', 'abc', base)).toBe(
        'https://hub.orbixsystem.com/#/verify?token=abc',
      );
      expect(buildActionUrl('password_reset', 'abc', base)).toBe(
        'https://hub.orbixsystem.com/#/reset?token=abc',
      );
      expect(buildActionUrl('invite', 'abc', base)).toBe(
        'https://hub.orbixsystem.com/#/convite/abc',
      );
    });

    it('does not double the slash when APP_PUBLIC_URL ends with one', () => {
      expect(buildActionUrl('password_reset', 'abc', 'http://x:8090/')).toBe(
        'http://x:8090/#/reset?token=abc',
      );
    });

    it('percent-encodes the token so a stray char cannot break the query', () => {
      expect(buildActionUrl('password_reset', 'a b&c', 'http://x')).toBe(
        'http://x/#/reset?token=a%20b%26c',
      );
    });
  });

  describe('renderVerificationEmail', () => {
    it.each(['email_verify', 'password_reset', 'invite'] as const)(
      'renders %s with subject, action link in both html and text',
      (kind) => {
        const mail = renderVerificationEmail(
          { to: 'a@b.com', token: 'tok123', kind },
          'https://hub.orbixsystem.com',
        );
        const url = buildActionUrl(kind, 'tok123', 'https://hub.orbixsystem.com');
        expect(mail.subject.length).toBeGreaterThan(0);
        expect(mail.html).toContain(url);
        expect(mail.text).toContain(url);
      },
    );

    it('tells the reader to ignore a reset they did not ask for', () => {
      const mail = renderVerificationEmail(
        { to: 'a@b.com', token: 't', kind: 'password_reset' },
        'http://x',
      );
      expect(mail.text).toMatch(/ignore este e-mail/i);
    });
  });

  describe('link de acompanhamento da OS', () => {
    it('monta o link público com o /#/ que a rota /t/:token espera', () => {
      expect(buildTrackingUrl('tok-1', 'https://hub.orbixsystem.com/')).toBe(
        'https://hub.orbixsystem.com/#/t/tok-1',
      );
    });

    it('leva a marca da OFICINA (não a nossa) e a OS no assunto', () => {
      const mail = renderTrackingLinkEmail({
        companyName: 'Oficina do Zé',
        customerName: 'Maria',
        orderNumber: 'OS-0007',
        url: 'https://hub.orbixsystem.com/#/t/tok-1',
      });
      expect(mail.subject).toBe('Acompanhe sua OS OS-0007 — Oficina do Zé');
      expect(mail.html).toContain('Oficina do Zé');
      expect(mail.html).toContain('Maria');
      expect(mail.html).toContain('https://hub.orbixsystem.com/#/t/tok-1');
      expect(mail.text).toContain('https://hub.orbixsystem.com/#/t/tok-1');
    });

    it('sem nome/número: continua um e-mail válido', () => {
      const mail = renderTrackingLinkEmail({
        companyName: 'Oficina do Zé',
        url: 'http://x/#/t/t1',
      });
      expect(mail.subject).toBe(
        'Acompanhe sua ordem de serviço — Oficina do Zé',
      );
      expect(mail.text).toContain('http://x/#/t/t1');
    });

    it('escapa nome de cliente com markup', () => {
      const mail = renderTrackingLinkEmail({
        companyName: 'Oficina',
        customerName: '<script>alert(1)</script>',
        url: 'http://x/#/t/t1',
      });
      expect(mail.html).not.toContain('<script>');
    });
  });

  describe('renderLayout', () => {
    it('escapes data so a name with markup cannot inject html', () => {
      const mail = renderLayout({
        heading: 'Oi',
        paragraphs: [escapeHtml('Oficina <script>alert(1)</script>')],
        ctaLabel: 'Abrir',
        ctaUrl: 'http://x',
      });
      expect(mail.html).not.toContain('<script>');
      expect(mail.html).toContain('&lt;script&gt;');
    });

    it('keeps a text part — html-only mail is penalized by spam filters', () => {
      const mail = renderLayout({
        heading: 'Titulo',
        paragraphs: ['<b>Corpo</b> do e-mail'],
        ctaLabel: 'Abrir',
        ctaUrl: 'http://x',
      });
      expect(mail.text).toContain('Titulo');
      expect(mail.text).toContain('Corpo do e-mail');
      expect(mail.text).not.toContain('<b>');
    });
  });
});
