# petclinic-sql-api

Testes de API e de integridade de dados para o [Spring PetClinic REST](https://github.com/spring-petclinic/spring-petclinic-rest).
O banco é o oráculo: cada teste chama a API e confere o efeito direto no PostgreSQL.

> Status: em construção. Fase atual: **0 — preparação do repositório**.

## Stack

Python, pytest, PostgreSQL/SQL, Postman/Newman, Gherkin (pytest-bdd), k6, Docker Compose e GitHub Actions.

## Como rodar

> Preencher quando o `docker-compose.yml` e os testes existirem.

```bash
docker compose up -d          # sobe API e PostgreSQL
# pytest tests/api
# npx newman run postman/... -e postman/...
```

- API: http://localhost:9966/petclinic/api
- Swagger: http://localhost:9966/petclinic/swagger-ui.html

## Fases

Núcleo (fases 0 a 4): já forma um projeto completo. Complemento (fases 5 a 8): só depois do núcleo.

- [ ] **0. Repositório:** estrutura de pastas, `.gitignore`, este README, primeiro commit.
- [ ] **1. Ambiente:** `docker-compose.yml` com API e PostgreSQL; ler o `initDB.sql`; escrever `docs/dicionario-de-dados.md`.
- [ ] **2. SQL exploratório:** de 10 a 15 consultas de integridade em `sql/`, escritas por mim, sem IA.
- [ ] **3. Postman:** CRUD de donos, pets e visitas com testes de status e corpo; Newman no GitHub Actions.
- [ ] **4. pytest com banco como oráculo:** chamada na API e verificação no banco; valor-limite e partição.
- [ ] **5. Contrato:** respostas validadas contra o OpenAPI da aplicação.
- [ ] **6. BDD:** de 5 a 8 cenários Gherkin para "agendar visita"; 2 ou 3 automatizados.
- [ ] **7. Jira:** bugs encontrados passando pelo ciclo completo; capturas aqui no README.
- [ ] **8. k6:** carga leve contra o ambiente local.

## Estrutura

```
docs/              dicionário de dados
sql/               consultas exploratórias de integridade
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

## Partições e valores-limite

> Preencher na fase 4.

| Campo | Partição / limite | Valor | Esperado | Obtido |
|-------|-------------------|-------|----------|--------|
|       |                   |       |          |        |

## Achados

> Um item por bug: passos, esperado, obtido e evidência no banco. Link para o Jira ou para a issue oficial, se houver.

Ambiente dos dois achados: `springcommunity/spring-petclinic-rest:latest` (4.0.2) com `postgres:16.3`, via
`docker compose`. Ambos reproduzidos do zero (`docker compose down -v` e `up -d`).

### BUG-01 · API responde 500 em vez de 400 quando o id do dono não é numérico

- **Passos:** `curl -i http://localhost:9966/petclinic/api/owners/abc` (ou abrir o endereço no navegador).
  Pelo Swagger não reproduz, porque ele valida o campo antes de enviar.
- **Esperado:** `400 Bad Request`, já que o erro é do cliente. O próprio contrato da API lista o 400 para esse endpoint.
- **Obtido:** `500 Internal Server Error`.
- **Evidência:** `HTTP/1.1 500`, com `"title": "MethodArgumentTypeMismatchException"` e
  `"detail": "An unexpected error occurred while processing your request"`. O corpo expõe o nome interno da
  exceção Java. O erro acontece antes de qualquer consulta, então o banco não muda.

### BUG-02 · Cada reinício da API cria mais uma cópia de cada índice do banco

- **Passos:** `docker compose down -v` → `up -d` → no `psql`, `\d types` → `docker compose restart api` →
  `\d types` de novo.
- **Esperado:** continuar com um índice só na coluna `name`.
- **Obtido:** aparece `types_name_idx1`, igual ao primeiro; a cada reinício, mais um (`idx2`, `idx3`...).
  Acontece em todos os índices criados pelo script (`owners`, `pets`, `vets`, `visits`, `specialties`, `types`).
- **Evidência no banco** (`\d types`, depois de um reinício):

  ```
  "types_name_idx" btree (name)
  "types_name_idx1" btree (name)
  ```

- **Causa provável:** a API roda o `schema.sql` a cada início (`spring.sql.init.mode=always`), confiando que ele
  é idempotente. Tabelas (`CREATE TABLE IF NOT EXISTS`) e dados (`INSERT ... WHERE NOT EXISTS`) estão protegidos,
  mas o `CREATE INDEX` não tem nome nem `IF NOT EXISTS`, e o PostgreSQL gera um nome novo a cada execução.
- **Impacto:** baixo. Não quebra funcionalidade, mas gasta espaço e deixa cada gravação mais lenta com o tempo.
  Um teste só de API não pegaria esse defeito.

## O que ficou de fora

> Preencher no fim, com o motivo.
