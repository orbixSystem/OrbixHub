import { Injectable, Logger } from '@nestjs/common';

/**
 * Impedimento que OUTRO módulo tem sobre uma OS já fechada.
 *
 * A OS sabe tudo sobre estoque e status, mas não sabe — nem deve saber — que
 * existe nota fiscal. Quando alguém pede para REABRIR ou EXCLUIR uma OS
 * finalizada, quem tem um documento amarrado a ela precisa poder dizer "não".
 * Cada módulo dono registra o seu impedimento aqui em `onModuleInit`; a OS só
 * pergunta ao registro ("aponta, não invade" — nenhum dos dois lê a tabela do
 * outro).
 */
export interface OrderLock {
  /** Módulo dono do impedimento ('invoice') — usado em log. */
  key: string;
  /**
   * Motivo em PT-BR quando a OS NÃO pode ser mexida; `null` quando pode.
   * A mensagem vai direto para a tela, então diga o que fazer para destravar.
   */
  motivo(orderId: string): Promise<string | null>;
}

/**
 * Registro aberto de impedimentos. Vazio é o caso normal: sem nenhum módulo
 * registrado, reabrir/excluir segue livre (nada a proteger).
 */
@Injectable()
export class OrderLockRegistry {
  private readonly logger = new Logger(OrderLockRegistry.name);
  private readonly locks: OrderLock[] = [];

  registrar(lock: OrderLock): void {
    this.locks.push(lock);
  }

  /**
   * O primeiro motivo que impede mexer na OS, ou `null` se está liberada.
   *
   * Falha ao CONSULTAR um impedimento trava a operação de propósito: excluir
   * uma OS porque o módulo fiscal estava fora do ar é exatamente o erro que
   * este seam existe para evitar.
   */
  async primeiroImpedimento(orderId: string): Promise<string | null> {
    for (const lock of this.locks) {
      const motivo = await lock.motivo(orderId).catch((e: Error) => {
        this.logger.warn(`Impedimento '${lock.key}' falhou: ${e.message}`);
        throw e;
      });
      if (motivo) return motivo;
    }
    return null;
  }
}
