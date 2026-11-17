# petclinic-sql-api

Testes de API e de integridade de dados para o [Spring PetClinic REST](https://github.com/spring-petclinic/spring-petclinic-rest).
O banco é o oráculo: cada teste chama a API e confere o efeito direto no PostgreSQL.

> Status: em construção. Fase atual: **3 — Postman**.

## Stack

Python, pytest, PostgreSQL/SQL, Postman/Newman, Gherkin (pytest-bdd), k6, Docker Compose e GitHub Actions.

## Como rodar

Requer Docker com o plugin Compose.

```bash
docker compose up -d --wait                           # sobe API e PostgreSQL e espera os dois ficarem prontos
docker compose exec db psql -U petclinic petclinic    # abre o psql no banco
docker compose down -v                                # derruba e apaga os dados do banco
```

Os dois serviços têm healthcheck: o banco com `pg_isready`, a API com `curl` no `/v3/api-docs`. A API só sobe
depois do banco saudável, e o `--wait` só termina quando a API responde (cerca de 20 s).

Um terceiro serviço, `db-index-cleanup`, sobe depois que a API fica pronta e, a cada 10 s, apaga as cópias de índice
que ela cria a cada início (ver o aviso no BUG-02, em [BUGS.md](BUGS.md)). Assim limpa sozinho depois de `docker compose up`,
`docker compose restart` ou `docker compose restart api`. O healthcheck dele só fica saudável depois da primeira
limpeza sem erro; se ela falhar, o `--wait` também falha. Para ver as cópias, pare o serviço:
`docker compose stop db-index-cleanup` (e `docker compose start db-index-cleanup` para religar).

Testes (ainda não existem):

```bash
# pytest tests/api
# npx newman run postman/... -e postman/...
```

- API: http://localhost:9966/petclinic/api
- Swagger: http://localhost:9966/petclinic/swagger-ui.html

## Fases

Núcleo (fases 0 a 4): já forma um projeto completo. Complemento (fases 5 a 8): só depois do núcleo.

- [x] **0. Repositório:** estrutura de pastas, `.gitignore`, este README, primeiro commit.
- [x] **1. Ambiente:** `docker-compose.yml` com API e PostgreSQL; ler o `initDB.sql`; escrever `docs/dicionario-de-dados.md`.
- [x] **2. SQL exploratório:** de 10 a 15 consultas de integridade em `sql/`.
- [ ] **3. Postman:** CRUD de donos, pets e visitas com testes de status e corpo; Newman no GitHub Actions.
- [ ] **4. pytest com banco como oráculo:** chamada na API e verificação no banco; valor-limite e partição.
- [ ] **5. Contrato:** respostas validadas contra o OpenAPI da aplicação.
- [ ] **6. BDD:** de 5 a 8 cenários Gherkin para "agendar visita"; 2 ou 3 automatizados.
- [ ] **7. Jira:** bugs encontrados passando pelo ciclo completo; capturas aqui no README.
- [ ] **8. k6:** carga leve contra o ambiente local.

## Estrutura

```
docs/              dicionário de dados e casos de teste
BUGS.md            bugs e observações em detalhe
sql/               consultas exploratórias de integridade
sql/maintenance/   limpeza automática das cópias de índice (BUG-02)
postman/           coleção e environment do Newman
tests/api/         pytest com o banco como oráculo
tests/contract/    validação contra o OpenAPI
tests/bdd/         cenários Gherkin e pytest-bdd
k6/                teste de carga leve
.github/workflows/ CI
```

## Decisões

> Uma linha por decisão, sempre com o porquê.

- **PetClinic REST como sistema testado:** roda local e no CI, com acesso total ao banco; nada de site de terceiros nem ação irreversível.
- **PostgreSQL em vez do banco em memória:** permite consultar o efeito de cada chamada com SQL.
- …

## Consultas de integridade

Cada arquivo de `sql/` responde a uma pergunta sobre regras que o banco não garante (ver "Fora do banco" no
dicionário). Resultado no banco recém-criado (dados do `populateDB`), em 2026-11-13. Cada consulta foi conferida
também com dados ruins inseridos numa transação desfeita com `ROLLBACK`.

| Arquivo | Pergunta | Resultado |
|:---|:---|:---|
| `01_owners_invalid_telephone.sql` | Telefone fora de 10 dígitos? | Nenhum, nos 10 donos |
| `02_owners_missing_name.sql` | Dono sem nome ou sobrenome, ou só com espaços? | Nenhum |
| `03_pets_invalid_birth_date.sql` | Pet nascido no futuro ou com mais de 30 anos? | Nenhum no futuro; Samantha (7) e Max (8), de 1995-09-04, têm 31 anos |
| `04_visits_before_birth.sql` | Visita antes do nascimento do pet? | Nenhuma, nas 4 visitas |
| `05_visits_duplicated.sql` | Visita repetida (mesmo pet, data e descrição)? | Nenhuma |
| `06_types_specialties_duplicated_or_unnamed.sql` | Tipo ou especialidade sem nome ou repetido, inclusive com maiúsculas diferentes? | Nenhum, nos 6 tipos e 3 especialidades |
| `07_vets_without_specialty.sql` | Veterinário sem especialidade? | 2 dos 6: James Carter (1) e Sharon Jenkins (6) |
| `08_specialties_unused.sql` | Especialidade que nenhum veterinário usa? | Nenhuma |
| `09_users_password_not_bcrypt.sql` | Senha que não parece hash bcrypt? | Nenhuma; o único usuário (`admin`) tem hash `$2a$` de 60 caracteres |
| `10_roles_unknown.sql` | Papel fora dos três que a API conhece? | Nenhum; os 3 papéis são do `admin` |
| `11_duplicate_indexes.sql` | Índices duplicados? | Nenhum no banco novo; 7 a cada reinício da API (BUG-02), apagados pela limpeza automática em até 10 s |
| `12_owners_pets_visits_count.sql` | Quantos pets e visitas tem cada dono? | Todos os 10 têm pet (13 no total); Eduardo Rodriquez (3), Jean Coleman (6) e Carlos Estaban (10) têm 2; só a Jean tem visitas (as 4) |

O banco permite todos os casos acima; nos dados atuais só aparecem os pets antigos e os vets sem especialidade.

## Partições e valores-limite

> Preencher na fase 4.

| Campo | Partição / limite | Valor | Esperado | Obtido |
|-------|-------------------|-------|----------|--------|
|       |                   |       |          |        |

## Achados

Três bugs e uma observação de contrato, todos reproduzidos do zero e com evidência no banco. Os detalhes (passos,
esperado, obtido, evidência e causa) estão em [BUGS.md](BUGS.md).

| Bug | Resumo | Impacto | Issue |
|:---|:---|:---|:---|
| BUG-01 | `GET /api/owners/abc` responde 500 em vez de 400 e expõe o nome da exceção | médio | [#1](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/1) |
| BUG-02 | Cada reinício da API cria mais uma cópia de 7 índices do banco (a suíte limpa as cópias automaticamente) | baixo, acumula | [#2](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/2) |
| BUG-03 | Apagar um dono apaga também o tipo do pet; com tipo compartilhado, o dono não pode ser apagado | alto | [#3](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/3) |

**OBS-01:** o contrato documenta 200 como sucesso em seis endpoints, mas a API devolve 201 ou 204 (o correto). Não
é bug; fica para a validação de contrato da fase 5.

## O que ficou de fora

> Preencher no fim, com o motivo.
