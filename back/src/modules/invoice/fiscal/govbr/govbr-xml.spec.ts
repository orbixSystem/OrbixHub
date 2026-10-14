import { DOMParser } from '@xmldom/xmldom';
import { SignedXml } from 'xml-crypto';
import { InvalidCertificateError, parseA1 } from './a1-certificate';
import { CertCipher } from './cert-cipher';
import {
  brasiliaDate,
  brasiliaDateTime,
  buildCancelamentoXml,
  buildDpsXml,
  DpsData,
  dpsId,
} from './dps-xml';
import { makeTestPfx } from './test-a1';
import { signFiscalXml } from './xml-signer';

const baseDps = (over: Partial<DpsData> = {}): DpsData => ({
  tpAmb: '2',
  dhEmi: new Date('2026-10-08T15:30:00Z'),
  verAplic: 'OrbixHub-1.0',
  serie: '1',
  nDPS: 42,
  dCompet: new Date('2026-10-08T15:30:00Z'),
  cLocEmi: '3550308',
  prestador: { cnpj: '12345678000199', opSimpNac: '3', regApTribSN: '1', regEspTrib: '0' },
  tomador: { documento: '123.456.789-09', nome: 'João & Filhos <Ltda>' },
  servico: {
    cLocPrestacao: '3550308',
    cTribNac: '140101',
    cNBS: '120012200',
    descricao: 'OS 123: Troca de óleo; Alinhamento',
  },
  valores: { vServ: 150.5, pAliq: null, pTotTribSN: null },
  ...over,
});

describe('parseA1', () => {
  it('abre o .pfx, acha o titular e extrai o CNPJ do CN', () => {
    const cert = parseA1(makeTestPfx({ cnpj: '11222333000181' }), 'senha123');
    expect(cert.cnpj).toBe('11222333000181');
    expect(cert.privateKeyPem).toContain('PRIVATE KEY');
    expect(cert.certificatePem).toContain('BEGIN CERTIFICATE');
    expect(cert.notAfter.getTime()).toBeGreaterThan(Date.now());
  });

  it('senha errada vira erro de usuário, não exceção crua', () => {
    expect(() => parseA1(makeTestPfx({}), 'errada')).toThrow(InvalidCertificateError);
  });

  it('arquivo que não é pfx vira erro de usuário', () => {
    expect(() => parseA1(Buffer.from('isto não é um certificado'), 'x')).toThrow(InvalidCertificateError);
  });

  it('CN sem CNPJ → cnpj null (o service decide o que fazer)', () => {
    expect(parseA1(makeTestPfx({ cn: 'SEM DOCUMENTO' }), 'senha123').cnpj).toBeNull();
  });
});

describe('CertCipher', () => {
  const key = Buffer.alloc(32, 7).toString('base64');

  it('cifra e decifra (round-trip) com IV aleatório', () => {
    const c = new CertCipher(key);
    const a = c.encrypt(Buffer.from('segredo'));
    const b = c.encrypt(Buffer.from('segredo'));
    expect(a).not.toBe(b);
    expect(c.decrypt(a).toString()).toBe('segredo');
  });

  it('dado adulterado no banco falha (GCM autentica)', () => {
    const c = new CertCipher(key);
    const buf = Buffer.from(c.encrypt(Buffer.from('segredo')), 'base64');
    buf[buf.length - 1] ^= 1;
    expect(() => c.decrypt(buf.toString('base64'))).toThrow();
  });

  it('chave de tamanho errado é recusada', () => {
    expect(() => new CertCipher(Buffer.alloc(16).toString('base64'))).toThrow();
  });
});

describe('DPS XML', () => {
  it('Id = DPS + município(7) + 2 + CNPJ(14) + série(5) + número(15) → 45 chars', () => {
    const id = dpsId({ cLocEmi: '3550308', cnpj: '12345678000199', serie: '1', nDPS: 42 });
    expect(id).toBe('DPS3550308' + '2' + '12345678000199' + '00001' + '000000000000042');
    expect(id).toHaveLength(45);
  });

  it('datas no fuso de Brasília com offset explícito', () => {
    const d = new Date('2026-10-08T02:10:05Z'); // 23:10 do dia 7 em Brasília
    expect(brasiliaDateTime(d)).toBe('2026-10-07T23:10:05-03:00');
    expect(brasiliaDate(d)).toBe('2026-10-07');
  });

  it('monta os grupos na ordem do XSD e escapa texto livre', () => {
    const { xml, id } = buildDpsXml(baseDps());
    expect(xml.startsWith('<DPS xmlns="http://www.sped.fazenda.gov.br/nfse" versao="1.01">')).toBe(true);
    expect(xml).toContain(`<infDPS Id="${id}">`);
    const order = ['tpAmb', 'dhEmi', 'verAplic', 'serie', 'nDPS', 'dCompet', 'tpEmit', 'cLocEmi', 'prest', 'toma', 'serv', 'valores'];
    const pos = order.map((t) => xml.indexOf(`<${t}>`));
    expect(pos.every((p) => p > 0)).toBe(true);
    expect([...pos].sort((a, b) => a - b)).toEqual(pos);
    expect(xml).toContain('<CPF>12345678909</CPF>');
    expect(xml).toContain('<xNome>João &amp; Filhos &lt;Ltda&gt;</xNome>');
    expect(xml).toContain('<vServ>150.50</vServ>');
    expect(xml).toContain('<indTotTrib>0</indTotTrib>');
    // emitente = prestador: nome/endereço do prestador não vão (vêm do cadastro nacional)
    expect(xml).not.toMatch(/<prest>(?:(?!<\/prest>).)*<xNome>/);
  });

  it('tomador com 14 dígitos vira CNPJ; sem tomador o grupo some', () => {
    expect(buildDpsXml(baseDps({ tomador: { documento: '11.222.333/0001-81', nome: 'X' } })).xml).toContain(
      '<toma><CNPJ>11222333000181</CNPJ>',
    );
    expect(buildDpsXml(baseDps({ tomador: null })).xml).not.toContain('<toma>');
  });

  it('regApTribSN só para ME/EPP; pTotTribSN substitui indTotTrib quando informado', () => {
    const mei = buildDpsXml(baseDps({ prestador: { cnpj: '12345678000199', opSimpNac: '2', regApTribSN: '1', regEspTrib: '0' } })).xml;
    expect(mei).not.toContain('regApTribSN');
    const sn = buildDpsXml(baseDps({ valores: { vServ: 10, pTotTribSN: 6, pAliq: 2 } })).xml;
    expect(sn).toContain('<pTotTribSN>6.00</pTotTribSN>');
    expect(sn).toContain('<pAliq>2.00</pAliq>');
    expect(sn).not.toContain('indTotTrib');
  });

  it('evento de cancelamento: Id PRE + chave + 101101 + 001', () => {
    const chave = '3'.repeat(50);
    const { xml, id } = buildCancelamentoXml({
      tpAmb: '2',
      verAplic: 'OrbixHub-1.0',
      dhEvento: new Date('2026-10-08T15:30:00Z'),
      cnpjAutor: '12345678000199',
      chNFSe: chave,
      cMotivo: '1',
      xMotivo: 'Valor do serviço lançado errado',
    });
    expect(id).toBe('PRE' + chave + '101101' + '001');
    expect(xml).toContain('<nPedRegEvento>1</nPedRegEvento><e101101><xDesc>Cancelamento de NFS-e</xDesc>');
  });
});

describe('assinatura XMLDSig', () => {
  const cert = parseA1(makeTestPfx({}), 'senha123');

  const verify = (signed: string): boolean => {
    const doc = new DOMParser().parseFromString(signed, 'text/xml');
    const node = doc.getElementsByTagNameNS('http://www.w3.org/2000/09/xmldsig#', 'Signature')[0];
    const v = new SignedXml({ publicCert: cert.certificatePem });
    v.loadSignature(node as unknown as Node);
    return v.checkSignature(signed);
  };

  it('assina o infDPS, põe a Signature como irmã dentro de <DPS> e verifica', () => {
    const { xml, id } = buildDpsXml(baseDps());
    const signed = signFiscalXml(xml, 'infDPS', cert);
    expect(signed).toMatch(/<\/infDPS><Signature xmlns="http:\/\/www.w3.org\/2000\/09\/xmldsig#">/);
    expect(signed).toContain(`<Reference URI="#${id}">`);
    expect(signed).toContain('<X509Certificate>');
    expect(signed.endsWith('</Signature></DPS>')).toBe(true);
    expect(verify(signed)).toBe(true);
  });

  it('qualquer alteração depois de assinar invalida', () => {
    const signed = signFiscalXml(buildDpsXml(baseDps()).xml, 'infDPS', cert);
    expect(verify(signed.replace('<vServ>150.50</vServ>', '<vServ>1.50</vServ>'))).toBe(false);
  });
});
