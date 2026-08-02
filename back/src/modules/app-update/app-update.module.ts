import { Module } from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { AppUpdateController } from './app-update.controller';
import { AppUpdateService } from './app-update.service';
import {
  GithubReleasesClient,
  NoopReleasesClient,
  RELEASES_CLIENT,
} from './github-releases.client';

/**
 * Entrega ao app instalado a última versão publicada. O token do GitHub fica
 * SÓ no servidor (o repositório é privado) — o cliente recebe apenas uma URL
 * assinada e temporária.
 */
@Module({
  controllers: [AppUpdateController],
  providers: [
    AppUpdateService,
    {
      provide: RELEASES_CLIENT,
      inject: [ENV],
      // Token é OPCIONAL: o repositório é público, então basta o nome dele.
      // Com token o limite de requisições à API do GitHub sobe bastante.
      useFactory: (env: Env) =>
        env.APP_UPDATE_ENABLED && env.GITHUB_RELEASES_REPO
          ? new GithubReleasesClient(
              env.GITHUB_RELEASES_REPO,
              env.GITHUB_RELEASES_TOKEN,
            )
          : new NoopReleasesClient(),
    },
  ],
})
export class AppUpdateModule {}
