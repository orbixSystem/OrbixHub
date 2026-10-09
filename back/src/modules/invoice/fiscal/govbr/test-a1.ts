import * as forge from 'node-forge';

/**
 * Só para testes: gera um "e-CNPJ" autoassinado com o CNPJ no CN (formato
 * ICP-Brasil "RAZAO:CNPJ") e devolve o .pfx. Chave RSA de 1024 bits para o
 * teste ficar rápido — nada aqui serve para assinar documento de verdade.
 */
export function makeTestPfx(opts: {
  cnpj?: string;
  password?: string;
  notAfter?: Date;
  notBefore?: Date;
  cn?: string;
}): Buffer {
  const keys = forge.pki.rsa.generateKeyPair({ bits: 1024, e: 0x10001 });
  const cert = forge.pki.createCertificate();
  cert.publicKey = keys.publicKey;
  cert.serialNumber = '01';
  cert.validity.notBefore = opts.notBefore ?? new Date(Date.now() - 24 * 3600 * 1000);
  cert.validity.notAfter = opts.notAfter ?? new Date(Date.now() + 365 * 24 * 3600 * 1000);
  const attrs = [{ name: 'commonName', value: opts.cn ?? `OFICINA TESTE LTDA:${opts.cnpj ?? '12345678000199'}` }];
  cert.setSubject(attrs);
  cert.setIssuer(attrs);
  cert.sign(keys.privateKey, forge.md.sha256.create());
  const p12 = forge.pkcs12.toPkcs12Asn1(keys.privateKey, [cert], opts.password ?? 'senha123', {
    algorithm: '3des',
  });
  return Buffer.from(forge.asn1.toDer(p12).getBytes(), 'binary');
}
