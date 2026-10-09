import {
  BadRequestException,
  Inject,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { A1Certificate, InvalidCertificateError, parseA1 } from './fiscal/govbr/a1-certificate';
import { CertCipher } from './fiscal/govbr/cert-cipher';
import { InvoiceRepository } from './invoice.repository';

export interface CertificateInfo {
  cnpj: string | null;
  subject: string;
  validFrom: string;
  validUntil: string;
}

/**
 * Cofre do certificado A1 de cada tenant (emissão direta na NFS-e Nacional).
 *
 * O .pfx e a senha vão CIFRADOS para `invoice_certificate` (AES-256-GCM, chave
 * em FISCAL_CERT_KEY); a chave privada só existe em memória durante a emissão.
 * Nunca devolve o certificado nem a senha para fora do backend — a API expõe
 * só os metadados (CNPJ, titular, validade).
 */
@Injectable()
export class InvoiceCertificateService {
  private cipher: CertCipher | null = null;

  constructor(
    @Inject(ENV) private readonly env: Env,
    private readonly tenant: TenantContext,
    private readonly repo: InvoiceRepository,
  ) {}

  /** Valida (senha, validade, CNPJ do titular) e guarda cifrado. */
  async save(
    tenantId: string,
    userId: string,
    pfx: Buffer,
    password: string,
    expectedCnpj: string,
  ): Promise<CertificateInfo> {
    let cert: A1Certificate;
    try {
      cert = parseA1(pfx, password);
    } catch (e) {
      if (e instanceof InvalidCertificateError) throw new BadRequestException(e.message);
      throw e;
    }
    const now = Date.now();
    if (cert.notAfter.getTime() < now) {
      throw new BadRequestException('Este certificado está vencido. Envie um certificado válido.');
    }
    if (cert.notBefore.getTime() > now) {
      throw new BadRequestException('Este certificado ainda não começou a valer.');
    }
    const cnpj = digits(expectedCnpj);
    if (!cert.cnpj) {
      throw new BadRequestException(
        'Não encontramos um CNPJ neste certificado. A emissão exige o e-CNPJ (A1) da própria empresa.',
      );
    }
    if (cert.cnpj !== cnpj) {
      throw new BadRequestException(
        `O certificado é do CNPJ ${formatCnpj(cert.cnpj)}, mas a empresa está cadastrada com ${formatCnpj(cnpj)}. ` +
          'A nota só pode ser assinada com o certificado da própria empresa.',
      );
    }

    const cipher = this.getCipher();
    await this.tenant.withTenantTx(() =>
      this.repo.upsertCertificate({
        tenant_id: tenantId,
        pfx_encrypted: cipher.encrypt(pfx),
        password_encrypted: cipher.encrypt(Buffer.from(password, 'utf8')),
        cnpj: cert.cnpj,
        subject: cert.subject,
        not_before: cert.notBefore,
        not_after: cert.notAfter,
        uploaded_by: userId,
      }),
    );
    return toInfo(cert);
  }

  /** Metadados do certificado guardado (null = nenhum enviado). */
  async info(): Promise<CertificateInfo | null> {
    const row = await this.tenant.withTenantTx(() => this.repo.findCertificate());
    if (!row?.not_after || !row.not_before) return null;
    return {
      cnpj: row.cnpj,
      subject: row.subject ?? '',
      validFrom: row.not_before.toISOString(),
      validUntil: row.not_after.toISOString(),
    };
  }

  /**
   * Abre o certificado do tenant do request para assinar/autenticar.
   * Lança 400 com mensagem de usuário se não houver certificado ou se venceu.
   */
  async load(): Promise<A1Certificate> {
    const row = await this.tenant.withTenantTx(() => this.repo.findCertificate());
    if (!row) {
      throw new BadRequestException('Envie o certificado digital A1 da empresa em Configurações › Nota Fiscal.');
    }
    const cipher = this.getCipher();
    let cert: A1Certificate;
    try {
      cert = parseA1(cipher.decrypt(row.pfx_encrypted), cipher.decrypt(row.password_encrypted).toString('utf8'));
    } catch {
      // Chave do cofre trocada ou dado corrompido: o certificado precisa ser reenviado.
      throw new BadRequestException('Não foi possível abrir o certificado guardado. Envie o certificado novamente.');
    }
    if (cert.notAfter.getTime() < Date.now()) {
      throw new BadRequestException('O certificado digital da empresa venceu. Envie o certificado renovado.');
    }
    return cert;
  }

  private getCipher(): CertCipher {
    if (!this.cipher) {
      if (!this.env.FISCAL_CERT_KEY) {
        throw new ServiceUnavailableException('Cofre de certificados não configurado no servidor.');
      }
      this.cipher = new CertCipher(this.env.FISCAL_CERT_KEY);
    }
    return this.cipher;
  }
}

function toInfo(cert: A1Certificate): CertificateInfo {
  return {
    cnpj: cert.cnpj,
    subject: cert.subject,
    validFrom: cert.notBefore.toISOString(),
    validUntil: cert.notAfter.toISOString(),
  };
}

function digits(s: string): string {
  return s.replace(/\D/g, '');
}

function formatCnpj(c: string): string {
  return c.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/, '$1.$2.$3/$4-$5');
}
