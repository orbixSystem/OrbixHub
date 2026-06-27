import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { PasswordService } from '../../common/crypto/password.service';

@Injectable()
export class ReauthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
  ) {}

  /** Re-verify the acting user's CURRENT password before a sensitive mutation. */
  async assertReauth(userId: string, currentPassword: string): Promise<void> {
    const user = await this.prisma.users.findUnique({ where: { id: userId } });
    const ok =
      !!user && (await this.passwords.verify(user.password_hash, currentPassword));
    if (!ok) throw new UnauthorizedException('Senha atual incorreta.');
  }
}
