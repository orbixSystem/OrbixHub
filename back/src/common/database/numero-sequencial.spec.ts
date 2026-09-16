import { criarComNumeroSequencial } from './numero-sequencial';

/**
 * A corrida que isto cobre não aparece em teste de integração nem em uso de um
 * usuário só: são dois atendentes fechando documento no mesmo segundo. Quando
 * acontece, o segundo recebia um erro cru e a venda não existia.
 */
const p2002 = () => Object.assign(new Error('unique'), { code: 'P2002' });
const outroErro = () => Object.assign(new Error('boom'), { code: 'P2003' });

describe('criarComNumeroSequencial', () => {
  it('sucesso de primeira não repete nada', async () => {
    const criar = jest.fn().mockResolvedValue('ok');
    await expect(
      criarComNumeroSequencial(criar, { ehConflitoDeId: () => false }),
    ).resolves.toBe('ok');
    expect(criar).toHaveBeenCalledTimes(1);
  });

  it('colisão de número repete e devolve o resultado da nova tentativa', async () => {
    const criar = jest
      .fn()
      .mockRejectedValueOnce(p2002())
      .mockResolvedValue('OS-0002');
    await expect(
      criarComNumeroSequencial(criar, { ehConflitoDeId: () => false }),
    ).resolves.toBe('OS-0002');
    expect(criar).toHaveBeenCalledTimes(2);
  });

  it('conflito de ID não repete — repetir só repetiria o mesmo conflito', async () => {
    // É o replay de um documento criado offline: o id vem do aparelho e já
    // existe no servidor. Insistir seria um laço inútil.
    const criar = jest.fn().mockRejectedValue(p2002());
    await expect(
      criarComNumeroSequencial(criar, { ehConflitoDeId: () => true }),
    ).rejects.toThrow('unique');
    expect(criar).toHaveBeenCalledTimes(1);
  });

  it('deixa o erro do discriminador subir (ex.: ConflictException mapeada)', async () => {
    const criar = jest.fn().mockRejectedValue(p2002());
    await expect(
      criarComNumeroSequencial(criar, {
        ehConflitoDeId: () => {
          throw new Error('Registro já existe (id duplicado).');
        },
      }),
    ).rejects.toThrow('Registro já existe (id duplicado).');
  });

  it('erro que não é unique violation sobe na hora', async () => {
    const criar = jest.fn().mockRejectedValue(outroErro());
    await expect(
      criarComNumeroSequencial(criar, { ehConflitoDeId: () => false }),
    ).rejects.toThrow('boom');
    expect(criar).toHaveBeenCalledTimes(1);
  });

  it('desiste depois do limite em vez de tentar para sempre', async () => {
    const criar = jest.fn().mockRejectedValue(p2002());
    await expect(
      criarComNumeroSequencial(criar, {
        ehConflitoDeId: () => false,
        tentativas: 3,
      }),
    ).rejects.toThrow('unique');
    expect(criar).toHaveBeenCalledTimes(3);
  });
});
