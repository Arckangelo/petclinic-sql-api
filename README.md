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
| `11_duplicate_indexes.sql` | Índices duplicados? | Nenhum no banco novo; 7 a cada reinício da API (BUG-02) |
| `12_owners_pets_visits_count.sql` | Quantos pets e visitas tem cada dono? | Todos os 10 têm pet (13 no total); Eduardo Rodriquez (3), Jean Coleman (6) e Carlos Estaban (10) têm 2; só a Jean tem visitas (as 4) |

O banco permite todos os casos acima; nos dados atuais só aparecem os pets antigos e os vets sem especialidade.

## Partições e valores-limite

> Preencher na fase 4.

| Campo | Partição / limite | Valor | Esperado | Obtido |
|-------|-------------------|-------|----------|--------|
|       |                   |       |          |        |

## Achados

> Um item por bug: passos, esperado, obtido e evidência no banco. Link para o Jira ou para a issue oficial, se houver.

Ambiente dos dois achados: `springcommunity/spring-petclinic-rest:latest` (4.0.2) com `postgres:16.3`, via
`docker compose`. Ambos reproduzidos do zero (`docker compose down -v` e `up -d`); o BUG-02 de novo em 2026-11-13.

### BUG-01 · API responde 500 em vez de 400 quando o id do dono não é numérico

- **Passos:** `curl -i http://localhost:9966/petclinic/api/owners/abc` (ou abrir o endereço no navegador).
  Pelo Swagger não reproduz, porque ele valida o campo antes de enviar.
- **Esperado:** `400 Bad Request`, já que o erro é do cliente. O próprio contrato da API lista o 400 para esse endpoint.
- **Obtido:** `500 Internal Server Error`.
- **Evidência:** `HTTP/1.1 500`, com `"title": "MethodArgumentTypeMismatchException"` e
  `"detail": "An unexpected error occurred while processing your request"`. O corpo expõe o nome interno da
  exceção Java. O erro acontece antes de qualquer consulta, então o banco não muda.

### BUG-02 · Cada reinício da API cria mais uma cópia de 7 índices do banco

- **Passos:** `docker compose down -v` → `up -d --wait` → rodar `sql/11_duplicate_indexes.sql` →
  `docker compose restart api` e esperar ela ficar pronta → rodar a consulta de novo. Repetir o reinício.
- **Esperado:** reiniciar a API não altera a estrutura do banco; a consulta continua sem linhas.
- **Obtido:** cada reinício cria mais uma cópia de 7 índices, em 6 tabelas. O crescimento não tem limite.

  | Momento | Índices duplicados |
  |:---|:---|
  | Banco novo, API iniciada uma vez | nenhum |
  | Depois do 1º `restart api` | 7 índices com 2 cópias (`_idx`, `_idx1`) |
  | Depois do 2º `restart api` | 7 índices com 3 cópias (`_idx`, `_idx1`, `_idx2`) |

  Afetados: `owners(last_name)`, `pets(name)`, `pets(owner_id)`, `visits(pet_id)`, `types(name)`,
  `vets(last_name)`, `specialties(name)`. Não duplicam as chaves primárias nem as regras `UNIQUE` de
  `vet_specialties` e `roles`, porque nascem dentro do `CREATE TABLE IF NOT EXISTS`.
- **Evidência no banco** (`sql/11_duplicate_indexes.sql`, depois do 1º reinício):

  ```
     tabela    |                   indices                   | quantos
  -------------+---------------------------------------------+---------
   vets        | vets_last_name_idx, vets_last_name_idx1     |       2
   specialties | specialties_name_idx, specialties_name_idx1 |       2
   types       | types_name_idx, types_name_idx1             |       2
   owners      | owners_last_name_idx, owners_last_name_idx1 |       2
   pets        | pets_name_idx, pets_name_idx1               |       2
   pets        | pets_owner_id_idx, pets_owner_id_idx1       |       2
   visits      | visits_pet_id_idx, visits_pet_id_idx1       |       2
  ```

- **Causa (conferida na imagem):** `application-postgres.properties` define `spring.sql.init.mode=always`, então
  o `/app/resources/db/postgres/schema.sql` roda a cada início. Tabelas (`CREATE TABLE IF NOT EXISTS`) e dados
  (`INSERT ... WHERE NOT EXISTS`) estão protegidos, mas os índices são criados sem nome
  (`CREATE INDEX ON vets (last_name);`, linhas 6 a 52), e o PostgreSQL gera um nome novo a cada execução.
- **Sugestão de correção:** nomear cada índice e usar `IF NOT EXISTS`, por exemplo
  `CREATE INDEX IF NOT EXISTS owners_last_name_idx ON owners (last_name);`.
- **Impacto:** baixo por reinício, mas acumula: cada cópia ocupa espaço e o banco atualiza todas a cada
  `INSERT` e `UPDATE` nessas tabelas. Um teste só de API não pegaria esse defeito.

## O que ficou de fora

> Preencher no fim, com o motivo.
