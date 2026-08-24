/**
 * Ambiente das suítes e2e.
 *
 * O autocadastro (`POST /auth/register`) está desligado por padrão desde que a
 * criação de ambiente passou a ser exclusividade do Orbix Admin. Os testes
 * continuam usando essa rota para montar tenant + dono + trial numa chamada,
 * então ela é religada AQUI — e só aqui.
 */
process.env.SELF_SIGNUP_ENABLED = 'true';
