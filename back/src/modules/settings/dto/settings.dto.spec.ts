import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { UpdateCompanyDto } from './settings.dto';

async function errs(obj: Record<string, unknown>) {
  return validate(plainToInstance(UpdateCompanyDto, obj));
}

describe('UpdateCompanyDto', () => {
  it('aceita um payload fiscal válido', async () => {
    expect(await errs({
      legalName: 'Oficina Silva ME', taxId: '12345678000199',
      regimeTributario: 'simples', uf: 'SP', themePreset: 'azul',
      email: 'a@b.com', primaryColor: '#2E6BE6',
    })).toHaveLength(0);
  });
  it('rejeita regimeTributario fora da lista', async () => {
    expect((await errs({ regimeTributario: 'inventado' })).length).toBeGreaterThan(0);
  });
  it('rejeita uf inválida e themePreset inválido', async () => {
    expect((await errs({ uf: 'XX' })).length).toBeGreaterThan(0);
    expect((await errs({ themePreset: 'arcoiris' })).length).toBeGreaterThan(0);
  });
});
