import { Inject, Injectable } from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';

export type DevInboxKind = 'invite' | 'email_verify' | 'password_reset';
export interface DevInboxEntry {
  type: DevInboxKind;
  label: string;
  value: string;
  createdAt: string; // ISO
}

const LABELS: Record<DevInboxKind, string> = {
  invite: 'Link de convite',
  email_verify: 'Token de verificação de e-mail',
  password_reset: 'Token de reset de senha',
};

@Injectable()
export class DevInboxService {
  constructor(@Inject(ENV) private readonly env: Env) {}

  private readonly latest = new Map<DevInboxKind, DevInboxEntry>();

  /** Records the most recent artifact for a kind (overwrites the previous one). */
  record(kind: DevInboxKind, token: string): void {
    const value =
      kind === 'invite'
        ? `${this.env.APP_PUBLIC_URL}/#/convite/${token}`
        : token;
    this.latest.set(kind, {
      type: kind,
      label: LABELS[kind],
      value,
      createdAt: new Date().toISOString(),
    });
  }

  list(): DevInboxEntry[] {
    return [...this.latest.values()];
  }
}
