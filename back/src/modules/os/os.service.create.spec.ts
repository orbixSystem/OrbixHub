import { BadRequestException } from '@nestjs/common';
import { OsService } from './os.service';
import type { AuthUser } from '../../common/auth/auth.types';
import type { CreateOrderDto } from './dto/order.dto';

/**
 * Unit do caminho de CRIAÇÃO da OS: como cliente e veículo são resolvidos.
 * Cobre o cadastro-relâmpago (cliente novo) e o caso que motivou a mudança —
 * cliente JÁ existente que ainda não tem veículo e quer cadastrar um na hora.
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
} as unknown as AuthUser;

const tenant = {
  withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
  runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) =>
    Promise.resolve(fn()),
} as unknown as ConstructorParameters<typeof OsService>[0];

function makeService(opts: { usaSubjects?: boolean } = {}) {
  const customers = {
    getCustomer: jest
      .fn()
      .mockResolvedValue({ id: 'c1', name: 'Cliente Existente' }),
    getSubject: jest
      .fn()
      .mockResolvedValue({ id: 's-old', label: null, identifier: 'AAA1A11' }),
    createCustomer: jest
      .fn()
      .mockResolvedValue({ id: 'c-new', name: 'Cliente Novo' }),
    createSubject: jest
      .fn()
      .mockResolvedValue({ id: 's-new', label: null, identifier: 'ABC1D23' }),
    getConfig: jest
      .fn()
      .mockResolvedValue({ usaSubjects: opts.usaSubjects ?? true }),
  };
  const repo = {
    maxOrderNumber: jest.fn().mockResolvedValue(0),
    createOrder: jest.fn().mockImplementation((_t: string, data: unknown) =>
      Promise.resolve({ id: 'os-new', ...(data as object) }),
    ),
    createEvent: jest.fn().mockResolvedValue(undefined),
    listEvents: jest.fn().mockResolvedValue([]),
    listPhotos: jest.fn().mockResolvedValue([]),
    findOrderById: jest.fn().mockResolvedValue(null),
  };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const svc = new OsService(
    tenant,
    repo as never,
    audit as never,
    customers as never,
    {} as never, // inventory
    { findByRef: jest.fn().mockResolvedValue(null) } as never, // messages
    {} as never, // iam
    { getPaymentSummary: jest.fn() } as never, // cashier
    {} as never, // storage,
      // EventEmitter2 do push em tempo real: o teste não observa socket,
      // então um emit no-op basta.
      { emit: () => true } as never,
    );
  return { svc, customers, repo };
}

const baseDto = { complaint: 'Barulho na roda' } as CreateOrderDto;

describe('OsService.createOrder — cliente e veículo', () => {
  it('cliente EXISTENTE sem veículo: cadastra o veículo pedido no corpo', async () => {
    const { svc, customers, repo } = makeService();
    await svc.createOrder(user, {
      ...baseDto,
      customerId: 'c1',
      newSubjectIdentifier: 'ABC1D23',
      newSubjectAttributes: { marca: 'VW' },
    } as CreateOrderDto);

    expect(customers.createSubject).toHaveBeenCalledWith(
      user,
      'c1', // o veículo nasce no cliente já existente
      expect.objectContaining({
        identifier: 'ABC1D23',
        attributes: { marca: 'VW' },
      }),
    );
    // A OS já aponta para o veículo recém-criado.
    const data = repo.createOrder.mock.calls[0][1] as Record<string, unknown>;
    expect(data.customer_id).toBe('c1');
    expect(data.subject_id).toBe('s-new');
    expect(customers.createCustomer).not.toHaveBeenCalled();
  });

  it('persiste a consulta de placa no veículo criado pela OS', async () => {
    const { svc, customers } = makeService();
    await svc.createOrder(user, {
      ...baseDto,
      customerId: 'c1',
      newSubjectIdentifier: 'ABC1D23',
      newSubjectPlateData: { placa: 'ABC1D23', marca: 'VW' },
    } as CreateOrderDto);

    expect(customers.createSubject).toHaveBeenCalledWith(
      user,
      'c1',
      expect.objectContaining({
        plateData: { placa: 'ABC1D23', marca: 'VW' },
      }),
    );
  });

  it('cliente existente COM subjectId escolhido não cria veículo novo', async () => {
    const { svc, customers, repo } = makeService();
    await svc.createOrder(user, {
      ...baseDto,
      customerId: 'c1',
      subjectId: 's-old',
    } as CreateOrderDto);

    expect(customers.createSubject).not.toHaveBeenCalled();
    const data = repo.createOrder.mock.calls[0][1] as Record<string, unknown>;
    expect(data.subject_id).toBe('s-old');
  });

  it('cliente NOVO: cria cliente com telefone e o veículo junto', async () => {
    const { svc, customers } = makeService();
    await svc.createOrder(user, {
      ...baseDto,
      newCustomerName: 'Cliente Novo',
      newCustomerPhone: '(11) 99999-9999',
      newSubjectIdentifier: 'ABC1D23',
    } as CreateOrderDto);

    expect(customers.createCustomer).toHaveBeenCalledWith(user, {
      name: 'Cliente Novo',
      phone: '(11) 99999-9999',
    });
    expect(customers.createSubject).toHaveBeenCalledWith(
      user,
      'c-new',
      expect.objectContaining({ identifier: 'ABC1D23' }),
    );
  });

  it('tenant sem objetos (usaSubjects=false): OS fica só com o cliente', async () => {
    const { svc, customers, repo } = makeService({ usaSubjects: false });
    await svc.createOrder(user, {
      ...baseDto,
      customerId: 'c1',
      newSubjectIdentifier: 'ABC1D23',
    } as CreateOrderDto);

    expect(customers.createSubject).not.toHaveBeenCalled();
    const data = repo.createOrder.mock.calls[0][1] as Record<string, unknown>;
    expect(data.subject_id).toBeNull();
  });

  it('grava o desconto fechado na abertura (e 0 quando não vem)', async () => {
    const comDesconto = makeService();
    await comDesconto.svc.createOrder(user, {
      ...baseDto,
      customerId: 'c1',
      discount: 25.5,
    } as CreateOrderDto);
    expect(
      (comDesconto.repo.createOrder.mock.calls[0][1] as Record<string, unknown>)
        .discount,
    ).toBe(25.5);

    const semDesconto = makeService();
    await semDesconto.svc.createOrder(user, {
      ...baseDto,
      customerId: 'c1',
    } as CreateOrderDto);
    expect(
      (semDesconto.repo.createOrder.mock.calls[0][1] as Record<string, unknown>)
        .discount,
    ).toBe(0);
  });

  it('sem cliente algum: recusa com mensagem clara', async () => {
    const { svc } = makeService();
    await expect(svc.createOrder(user, { ...baseDto })).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });
});
