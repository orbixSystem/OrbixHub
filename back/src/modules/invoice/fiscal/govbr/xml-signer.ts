import { SignedXml } from 'xml-crypto';
import type { A1Certificate } from './a1-certificate';

/**
 * Assinatura XMLDSig enveloped do elemento `inf*` (infDPS / infPedReg), no
 * padrão dos documentos fiscais eletrônicos: C14N inclusivo, transform
 * enveloped-signature, referência ao atributo Id, X509Certificate no KeyInfo.
 * A <Signature> entra como irmã do `inf*`, dentro do elemento raiz — que é o
 * lugar que o XSD (`ds:Signature` depois de infDPS/infPedReg) espera.
 *
 * Algoritmo RSA-SHA1/SHA1: é o que os emissores open-source em uso na produção
 * da NFS-e Nacional mandam (o leiaute herda o padrão da NF-e). Se a Sefin passar
 * a exigir SHA-256, troque só as duas constantes abaixo.
 */
const SIGNATURE_ALGORITHM = 'http://www.w3.org/2000/09/xmldsig#rsa-sha1';
const DIGEST_ALGORITHM = 'http://www.w3.org/2000/09/xmldsig#sha1';
const C14N = 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315';
const ENVELOPED = 'http://www.w3.org/2000/09/xmldsig#enveloped-signature';

export function signFiscalXml(xml: string, infTag: 'infDPS' | 'infPedReg', cert: A1Certificate): string {
  const sig = new SignedXml({
    privateKey: cert.privateKeyPem,
    publicCert: cert.certificatePem,
    signatureAlgorithm: SIGNATURE_ALGORITHM,
    canonicalizationAlgorithm: C14N,
  });
  sig.addReference({
    xpath: `//*[local-name(.)='${infTag}']`,
    digestAlgorithm: DIGEST_ALGORITHM,
    transforms: [ENVELOPED, C14N],
  });
  sig.computeSignature(xml, {
    location: { reference: `//*[local-name(.)='${infTag}']`, action: 'after' },
  });
  return sig.getSignedXml();
}
