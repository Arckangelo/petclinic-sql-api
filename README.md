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

Nenhum até agora.

## O que ficou de fora

> Preencher no fim, com o motivo.
