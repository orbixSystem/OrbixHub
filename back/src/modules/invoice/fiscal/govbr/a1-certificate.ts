import * as forge from 'node-forge';

/**
 * Certificado A1 (ICP-Brasil, e-CNPJ) já aberto: chave privada + certificado do
 * titular em PEM (para o mTLS e para a assinatura XMLDSig) e os metadados que a
 * tela de config mostra.
 *
 * O .pfx é lido com node-forge (JS puro) e não com o `crypto` do Node: os A1
 * emitidos pelas certificadoras costumam vir cifrados com RC2/3DES, que o
 * OpenSSL 3 do Node só abre com o provider "legacy" ligado.
 */
export interface A1Certificate {
  privateKeyPem: string;
  certificatePem: string;
  /** DER do certificado em base64 — vai no <X509Certificate> da assinatura. */
  certificateBase64: string;
  cnpj: string | null;
  subject: string;
  notBefore: Date;
  notAfter: Date;
}

/** Arquivo/senha inválidos — a mensagem já é para o usuário final. */
export class InvalidCertificateError extends Error {}

// OID ICP-Brasil do CNPJ da pessoa jurídica titular (otherName do SubjectAltName),
// DER-encodado: 06 05 60 4C 01 03 03 = 2.16.76.1.3.3.
const ICP_CNPJ_OID_DER = '\x06\x05\x60\x4c\x01\x03\x03';

export function parseA1(pfx: Buffer, password: string): A1Certificate {
  let p12: forge.pkcs12.Pkcs12Pfx;
  try {
    const asn1 = forge.asn1.fromDer(forge.util.createBuffer(pfx.toString('binary')));
    p12 = forge.pkcs12.pkcs12FromAsn1(asn1, false, password);
  } catch {
    // forge não distingue "senha errada" de "arquivo corrompido" de forma estável.
    throw new InvalidCertificateError('Não foi possível abrir o certificado. Confira o arquivo .pfx e a senha.');
  }

  const key = findPrivateKey(p12);
  if (!key) throw new InvalidCertificateError('O arquivo não contém a chave privada do certificado.');

  // O .pfx traz a cadeia (AC raiz/intermediárias) junto; o do titular é o que
  // casa com a chave privada.
  const certs = (p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag] ?? [])
    .map((b) => b.cert)
    .filter((c): c is forge.pki.Certificate => !!c);
  const leaf = certs.find((c) => {
    const pub = c.publicKey as forge.pki.rsa.PublicKey;
    return pub.n !== undefined && pub.n.equals(key.n) && pub.e.equals(key.e);
  });
  if (!leaf) throw new InvalidCertificateError('O arquivo não contém o certificado da chave privada.');

  const certDer = forge.asn1.toDer(forge.pki.certificateToAsn1(leaf)).getBytes();
  return {
    privateKeyPem: forge.pki.privateKeyToPem(key),
    certificatePem: forge.pki.certificateToPem(leaf),
    certificateBase64: forge.util.encode64(certDer),
    cnpj: extractCnpj(leaf),
    subject: subjectString(leaf),
    notBefore: leaf.validity.notBefore,
    notAfter: leaf.validity.notAfter,
  };
}

function findPrivateKey(p12: forge.pkcs12.Pkcs12Pfx): forge.pki.rsa.PrivateKey | null {
  for (const bagType of [forge.pki.oids.pkcs8ShroudedKeyBag, forge.pki.oids.keyBag]) {
    const bags = p12.getBags({ bagType })[bagType] ?? [];
    const withKey = bags.find((b) => b.key);
    if (withKey?.key) return withKey.key as forge.pki.rsa.PrivateKey;
  }
  return null;
}

function subjectString(cert: forge.pki.Certificate): string {
  return cert.subject.attributes
    .map((a) => `${a.shortName ?? a.name}=${String(a.value)}`)
    .join(', ');
}

/**
 * CNPJ do titular. No e-CNPJ ICP-Brasil ele aparece no CN ("RAZAO SOCIAL:CNPJ")
 * e, de forma normativa, no otherName 2.16.76.1.3.3 do SubjectAltName.
 */
export function extractCnpj(cert: forge.pki.Certificate): string | null {
  const cn = cert.subject.getField('CN')?.value;
  const fromCn = typeof cn === 'string' ? /:(\d{14})$/.exec(cn.trim()) : null;
  if (fromCn) return fromCn[1];

  const san = cert.getExtension('subjectAltName') as { value?: string } | null;
  const raw = san?.value;
  if (typeof raw === 'string') {
    const at = raw.indexOf(ICP_CNPJ_OID_DER);
    if (at >= 0) {
      const digits = /\d{14}/.exec(raw.slice(at + ICP_CNPJ_OID_DER.length));
      if (digits) return digits[0];
    }
  }
  return null;
}
