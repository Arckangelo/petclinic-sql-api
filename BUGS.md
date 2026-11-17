# Bugs e observações

Achados dos testes de API com o banco como oráculo. O resumo fica no [README](README.md#achados); aqui ficam os
detalhes de cada um: passos, esperado, obtido, evidência no banco e, quando conferida, a causa.

Ambiente: `springcommunity/spring-petclinic-rest:latest` (4.0.2) com `postgres:16.3`, via `docker compose`. Todos
reproduzidos do zero (`docker compose down -v` e `up -d --wait`). BUG-01, BUG-02 e BUG-03 foram reproduzidos de novo
em 2026-11-15 na `4.0.2` republicada em 2026-11-14 (digest `sha256:daba846d…`); o BUG-04 foi reproduzido nela em
2026-11-17.

| Bug | Resumo | Impacto | Issue |
|:---|:---|:---|:---|
| [BUG-01](#bug-01--api-responde-500-em-vez-de-400-quando-o-id-do-dono-não-é-numérico) | Id de dono não numérico responde 500 em vez de 400 | médio | [#1](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/1) |
| [BUG-02](#bug-02--cada-reinício-da-api-cria-mais-uma-cópia-de-7-índices-do-banco) | Cada reinício da API duplica 7 índices | baixo, acumula | [#2](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/2) |
| [BUG-03](#bug-03--apagar-um-dono-apaga-também-o-tipo-do-pet-dele) | Apagar dono apaga também o tipo do pet | alto | [#3](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/3) |
| [BUG-04](#bug-04--criar-visita-com-id-no-corpo-sobrescreve-uma-visita-que-já-existe) | POST de visita com `id` sobrescreve visita existente | alto | [#4](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/4) |

## BUG-01 · API responde 500 em vez de 400 quando o id do dono não é numérico

- **Issue:** [#1](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/1)
- **Passos:** `curl -i http://localhost:9966/petclinic/api/owners/abc` (ou abrir o endereço no navegador).
  Pelo Swagger não reproduz, porque ele valida o campo antes de enviar.
- **Esperado:** `400 Bad Request`, já que o erro é do cliente. O próprio contrato da API lista o 400 para esse endpoint.
- **Obtido:** `500 Internal Server Error`.
- **Evidência:** `HTTP/1.1 500`, com `"title": "MethodArgumentTypeMismatchException"` e
  `"detail": "An unexpected error occurred while processing your request"`. O corpo expõe o nome interno da
  exceção Java. O erro acontece antes de qualquer consulta, então o banco não muda.

## BUG-02 · Cada reinício da API cria mais uma cópia de 7 índices do banco

> **Aviso: a suíte roda com limpeza automática das cópias.** O serviço `db-index-cleanup` do `docker-compose.yml`
> roda `sql/maintenance/drop_duplicate_indexes.sql` a cada 10 s e apaga as cópias que a API criou. Serve só para o
> banco local não acumular índices desnecessários.
> **O bug continua existindo:** a API segue criando as cópias a cada início, e a limpeza não corrige a causa.
> Para reproduzir, pare a limpeza antes (`docker compose stop db-index-cleanup`), como nos passos abaixo; com ela
> ligada, as cópias somem em até 10 s depois de cada reinício.

- **Issue:** [#2](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/2)
- **Passos:** `docker compose down -v` → `up -d --wait` → `docker compose stop db-index-cleanup` → rodar
  `sql/11_duplicate_indexes.sql` → `docker compose restart api` e esperar ela ficar pronta → rodar a consulta de
  novo. Repetir o reinício. No fim, `docker compose start db-index-cleanup` apaga as cópias.
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

## BUG-03 · Apagar um dono apaga também o tipo do pet dele

- **Issue:** [#3](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/3)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar um dono (`POST /api/owners`), um tipo de pet
  (`POST /api/pettypes`) e um pet desse tipo para o dono (`POST /api/owners/{ownerId}/pets`) → conferir no banco
  as três linhas → `DELETE /api/owners/{ownerId}` → conferir no banco de novo.
- **Esperado:** o tipo de pet continua no banco. Ele é um cadastro geral, não pertence ao dono. Sobre o pet, a regra
  ainda está a confirmar (ver `CT-API-OWNERS-10`): ou a API recusa apagar dono com pet, ou apaga dono e pets juntos.
  Em nenhuma das duas o tipo some.
- **Obtido:** `204 No Content`, e somem do banco o dono, o pet **e o tipo**.

  | Linha | Antes do DELETE | Depois do DELETE |
  |:---|:---|:---|
  | `owners` id 11 (Maria Souza) | existe | não existe |
  | `pets` id 14 (Rex, `type_id` 7, `owner_id` 11) | existe | não existe |
  | `types` id 7 (furão) | existe | **não existe** |

- **Quando o tipo é usado por outro pet**, o defeito aparece de outro jeito: a API tenta apagar o tipo, o banco
  recusa pela chave estrangeira e o dono **não pode ser apagado**. Reproduzido com um pet do tipo `cat` (id 1, do
  `populateDB`, usado por outros pets): `DELETE /api/owners/12` devolve `404` com
  `"title": "DataIntegrityViolationException"`, e dono, pet e tipo continuam no banco. O `404` também está errado
  (o dono existe), e o corpo expõe o nome da exceção, como no BUG-01.
- **Evidência no banco e no log:** as chaves estrangeiras de `pets` não têm `ON DELETE CASCADE` (`\d pets`), então
  o banco não apaga nada sozinho: quem manda apagar o pet e o tipo é a API. No segundo cenário, o log da API mostra a
  tentativa de apagar da tabela `types` ao receber o pedido de apagar um dono:

  ```
  ERROR: update or delete on table "types" violates foreign key constraint "pets_type_id_fkey" on table "pets"
  Data integrity violation at DELETE /petclinic/api/owners/12
  ```

- **Causa (conferida na imagem):** nas classes de `/app/classes/org/springframework/samples/petclinic/model/`, o campo
  `type` de `Pet` é `@ManyToOne(cascade = CascadeType.ALL)`, e o campo `pets` de `Owner` é
  `@OneToMany(cascade = CascadeType.ALL)`. Ao apagar o dono, o Hibernate apaga os pets dele e, pela cascata do
  `@ManyToOne`, apaga também o tipo de cada pet. O `DELETE /api/pets/{petId}` não passa por isso porque
  `SpringDataPetRepositoryImpl` apaga com consultas diretas (`DELETE FROM Visit ...` e `DELETE FROM Pet ...`), que
  ignoram as cascatas; por isso ali o tipo fica.
- **Sugestão de correção:** tirar o `cascade` do campo `type` de `Pet` (deixar só `@ManyToOne`). Um tipo de pet é
  cadastro compartilhado e não deve nascer nem morrer junto com um pet. Se apagar o dono apaga ou não os pets é a
  regra a confirmar do `CT-API-OWNERS-10`.
- **Impacto:** alto. Apagar um dono pode apagar um tipo de pet que outro cadastro usaria depois, e um dono com pet de
  tipo comum (gato, cachorro) nunca pode ser apagado pela API. A resposta `204` parece sucesso: só o banco mostra o
  tipo que sumiu.

## BUG-04 · Criar visita com `id` no corpo sobrescreve uma visita que já existe

- **Passos:** `docker compose down -v` → `up -d --wait` → criar um dono, um tipo e um pet → conferir no banco a
  visita 1 (do `populateDB`) → `POST /api/visits` com `"id": 1`, uma data, uma descrição e o `petId` do pet novo →
  conferir a visita 1 de novo.
- **Esperado:** o POST cria uma visita nova, com id gerado pelo banco, e ignora o `id` enviado (como faz o
  `POST /api/owners`, ver `CT-API-OWNERS-13a`), ou recusa o pedido com 400. A visita 1 continua igual.
- **Obtido:** `201 Created` com `"id": 1` no corpo da resposta, e a visita 1 é trocada pelos dados enviados. Nenhuma
  visita nova é criada.

  | `visits` id 1 | pet_id | visit_date | description |
  |:---|:---|:---|:---|
  | Antes do POST | 7 (Samantha) | 2010-03-04 | rabies shot |
  | Depois do POST | 14 (pet novo) | 2026-11-02 | Visita com id 1 |

  Total de visitas: 4 antes e 4 depois. A vacina da Samantha mudou de pet, e a data e a descrição originais se
  perderam.
- **Efeito em cascata:** a visita passa a pertencer ao pet novo. Ao apagar esse pet, a API apaga as visitas dele, e
  a visita 1 some do banco. Foi assim que o defeito apareceu: uma limpeza de teste apagou um dado do `populateDB`.
- **Evidência no banco:** a consulta da visita 1 antes e depois do POST (tabela acima). Reproduzido do zero em
  2026-11-17, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Relação com o contrato:** o schema `Visit`, usado no corpo do `POST /api/visits`, marca o `id` como obrigatório.
  Para uma criação isso não faz sentido, e a API usa esse id para gravar por cima de uma visita existente.
- **Impacto:** alto. Qualquer cliente que envie o `id` (por engano, ou copiando a resposta de outra visita) apaga o
  histórico de outro pet sem nenhum aviso, com uma resposta que parece sucesso. Só o banco mostra a troca.

## Observações

Diferenças que não quebram o funcionamento, mas ficam registradas para a fase 5 (contrato).

### OBS-01 · Contrato documenta 200 como sucesso, mas a API devolve 201 ou 204

| Endpoint | Contrato (`/petclinic/v3/api-docs`) | Obtido |
|:---|:---|:---|
| `PUT /api/owners/{ownerId}` | `200` | `204 No Content` |
| `DELETE /api/owners/{ownerId}` | `200` | `204 No Content` |
| `DELETE /api/pets/{petId}` | `200` | `204 No Content` |
| `POST /api/pettypes` | `200` | `201 Created` |
| `DELETE /api/pettypes/{petTypeId}` | `200` | `204 No Content` |
| `DELETE /api/visits/{visitId}` | `200` | `204 No Content` |
| `POST /api/visits` | `200` | `201 Created` |

- **Como foi conferido:** em 2026-11-14, com dados criados só para isso e apagados em seguida, e pelos testes
  `CT-API-OWNERS-07`, `CT-API-PET-TYPES-01` e `Limpeza:` da coleção do Postman.
- **Por que não é bug:** `201` é a resposta adequada para "criado" e `204` para "alterado" ou "apagado" sem nada
  a devolver, e o banco recebe a mudança certa. O defeito está na documentação, que não descreve o que a API faz.
- **Efeito nos testes:** quem seguir o contrato e esperar `200` vai ver o teste falhar. Os testes conferem o
  status que a API devolve e que é o correto; na fase 5, a validação de contrato deve apontar essa diferença.
