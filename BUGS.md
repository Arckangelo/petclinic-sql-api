# Bugs e observações

Achados dos testes de API com o banco como oráculo. O resumo fica no [README](README.md#achados); aqui ficam os
detalhes de cada um: passos, esperado, obtido, evidência no banco e, quando conferida, a causa.

Ambiente: `springcommunity/spring-petclinic-rest:latest` (4.0.2) com `postgres:16.3`, via `docker compose`. Todos
reproduzidos do zero (`docker compose down -v` e `up -d --wait`). BUG-01, BUG-02 e BUG-03 foram reproduzidos de novo
em 2026-11-15 na `4.0.2` republicada em 2026-11-14 (digest `sha256:daba846d…`); o BUG-04 foi reproduzido nela em
2026-11-17, o BUG-05, o BUG-06, o BUG-07, o BUG-08 e o BUG-09, em 2026-11-18, o BUG-10, em 2026-11-19, o BUG-11 e o BUG-12, em 2026-11-20, e o BUG-13, em 2026-11-21.

| Bug | Resumo | Impacto | Issue |
|:---|:---|:---|:---|
| [BUG-01](#bug-01--api-responde-500-em-vez-de-400-quando-o-id-do-dono-não-é-numérico) | Id de dono não numérico responde 500 em vez de 400 | médio | [#1](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/1) |
| [BUG-02](#bug-02--cada-reinício-da-api-cria-mais-uma-cópia-de-7-índices-do-banco) | Cada reinício da API duplica 7 índices | baixo, acumula | [#2](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/2) |
| [BUG-03](#bug-03--apagar-um-dono-apaga-também-o-tipo-do-pet-dele) | Apagar dono apaga também o tipo do pet | alto | [#3](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/3) |
| [BUG-04](#bug-04--criar-visita-com-id-no-corpo-sobrescreve-uma-visita-que-já-existe) | POST de visita com `id` sobrescreve visita existente | alto | [#4](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/4) |
| [BUG-05](#bug-05--busca-de-donos-sem-resultado-responde-404-em-vez-de-200-com-lista-vazia) | Busca de donos sem resultado responde 404 em vez de lista vazia | baixo a médio | [#5](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/5) |
| [BUG-06](#bug-06--nome-de-pet-só-com-espaços-é-aceito-e-gravado) | Nome de pet só com espaços é aceito e gravado | baixo a médio | [#6](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/6) |
| [BUG-07](#bug-07--apagar-um-tipo-de-pet-apaga-todos-os-pets-desse-tipo-e-as-visitas-deles) | Apagar tipo apaga todos os pets desse tipo e as visitas deles | alto | [#7](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/7) |
| [BUG-08](#bug-08--corpo-ilegível-responde-500-em-vez-de-400) | Corpo ilegível responde 500 em vez de 400 | médio | [#8](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/8) |
| [BUG-09](#bug-09--id-negativo-na-url-responde-500-em-vez-de-400) | Id negativo na URL responde 500 em vez de 400 | médio | [#9](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/9) |
| [BUG-10](#bug-10--dono-da-url-não-é-conferido-ao-alterar-pet-nem-ao-criar-visita) | Dono da URL não é conferido ao alterar pet nem ao criar visita | médio | [#10](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/10) |
| [BUG-11](#bug-11--descrição-de-visita-só-com-espaços-é-aceita-e-gravada) | Descrição de visita só com espaços é aceita e gravada | baixo a médio | [#11](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/11) |
| [BUG-12](#bug-12--visita-com-data-anterior-ao-nascimento-do-pet-é-aceita) | Visita com data anterior ao nascimento do pet é aceita | baixo a médio | [#12](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/12) |
| [BUG-13](#bug-13--data-enviada-como-número-é-aceita-e-gravada-como-outra-data) | Data enviada como número é aceita e gravada como outra data | baixo a médio | [#13](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/13) |

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
- **Esperado:** o tipo de pet continua no banco. Ele é um cadastro geral, não pertence ao dono. A regra adotada é
  apagar dono, pets e visitas juntos (ver `CT-API-OWNERS-10`), e o tipo não faz parte dela.
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
  cadastro compartilhado e não deve nascer nem morrer junto com um pet. Apagar o dono continua apagando os pets e as
  visitas dele, como define o `CT-API-OWNERS-10`.
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

## BUG-05 · Busca de donos sem resultado responde 404 em vez de 200 com lista vazia

- **Issue:** [#5](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/5)
- **Passos:** `docker compose down -v` → `up -d --wait` → conferir no banco quantos donos têm sobrenome começando por
  `Davis`, `davis` e `Naoexiste` → `GET /api/owners?lastName=Davis` → `GET /api/owners?lastName=Naoexiste` →
  `GET /api/owners?lastName=davis`.
- **Esperado:** `200 OK` com os donos encontrados e, quando não há nenhum, `200 OK` com a lista vazia (`[]`).
- **Obtido:** a busca sem resultado responde `404` com corpo vazio.

  | Busca | Linhas no banco | Resposta |
  |:---|:---|:---|
  | `lastName=Davis` | 2 | `200`, com os 2 donos |
  | `lastName=Naoexiste` | 0 | `404`, corpo vazio |
  | `lastName=davis` | 0 | `404`, corpo vazio |

- **Evidência no banco:** a contagem de donos por prefixo do sobrenome (tabela acima) confirma que a consulta não
  tem linhas e que o recurso existe. Reproduzido do zero em 2026-11-18, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Relação com o contrato:** `GET /api/owners` documenta `200` (lista de `Owner`), `304` e `500`. O `404` não está
  previsto. Diferenciar maiúsculas (`davis` não encontra `Davis`) não é o defeito: o contrato não define isso.
- **Causa provável:** a classe `OwnerRestControllerV1` da imagem cita `findAllOwners`, `isEmpty` e `NOT_FOUND`, o que
  sugere transformar lista vazia em `404`. É um indício: a lógica do método não foi lida.
- **Impacto:** baixo a médio. Nenhum dado é afetado, mas o cliente precisa tratar "nenhum resultado" como erro e não
  distingue esse caso de uma URL errada.

## BUG-06 · Nome de pet só com espaços é aceito e gravado

- **Issue:** [#6](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/6)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar um dono e um tipo →
  `POST /api/owners/{ownerId}/pets` com `"name": "   "`, uma data e o tipo → conferir o pet no banco e com
  `GET /api/pets/{petId}`.
- **Esperado:** `400 Bad Request` apontando o campo `name`, sem gravar o pet, como acontece com `""` e com o nome do
  dono só com espaços (`CT-API-OWNERS-05`).
- **Obtido:** `201 Created`, com `"name": "   "` na resposta, e uma linha nova em `pets`.

  | Campo em `pets` | Valor gravado |
  |:---|:---|
  | `id` | 14 |
  | `name` | 3 espaços (tamanho 3; vazio depois de tirar os espaços) |
  | `birth_date` | 2020-05-10 |
  | `type_id` / `owner_id` | 7 / 11 (criados no teste) |

  Total de pets: 13 antes e 14 depois. Um espaço e um tab também são aceitos e gravados.
- **Evidência no banco:** a linha do pet criado, com o nome só de espaços, e a contagem de `pets` antes e depois.
  Reproduzido do zero em 2026-11-18, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Relação com o contrato:** `name` de `PetFields` só tem `minLength: 1` e `maxLength: 30`, sem `pattern`. O contrato
  não proíbe o valor: o defeito é de regra de negócio e de consistência, porque o nome do dono e o nome do tipo de
  pet têm `pattern` e recusam esse tipo de valor.
- **Impacto:** baixo a médio. O pet fica sem nome visível nas telas e nos relatórios. O banco não impede: a coluna é
  `NOT NULL`, mas aceita texto só com espaços.

## BUG-07 · Apagar um tipo de pet apaga todos os pets desse tipo e as visitas deles

- **Issue:** [#7](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/7)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar um tipo e dois donos → criar um pet desse tipo para cada
  dono → criar uma visita para o primeiro pet → conferir as linhas no banco → `DELETE /api/pettypes/{petTypeId}` →
  conferir no banco de novo.
- **Esperado:** a API recusa a exclusão de um tipo em uso com um erro `4xx` (o `CT-API-PET-TYPES-08` propõe `409`), e
  tipo, pets e visitas continuam no banco. Um tipo é um cadastro geral: apagá-lo não pode remover pets de ninguém.
- **Obtido:** `204 No Content`, e somem o tipo, os pets dos dois donos e a visita. Os donos continuam.

  | Registro | Antes do DELETE | Depois do DELETE |
  |:---|:---|:---|
  | `types` id 7 | existe | **não existe** |
  | `pets` id 14 (dono 11) | existe | **não existe** |
  | `pets` id 15 (dono 12) | existe | **não existe** |
  | `visits` id 5 (pet 14) | existe | **não existe** |
  | `owners` ids 11 e 12 | existem | existem |

  Total de pets: 15 antes e 13 depois. Total de visitas: 5 antes e 4 depois.
- **Evidência no banco:** a contagem dessas linhas e os totais de `pets` e `visits`, antes e depois do `DELETE`.
  Reproduzido do zero em 2026-11-18, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Causa:** a classe `SpringDataPetTypeRepositoryImpl` da imagem traz as consultas `SELECT pet FROM Pet pet WHERE
  type.id=`, `DELETE FROM Visit visit WHERE id=`, `DELETE FROM Pet pet WHERE id=` e `DELETE FROM PetType pettype WHERE
  id=`. Ou seja, a própria API busca os pets do tipo e os apaga, com as visitas, antes de apagar o tipo. Por isso a
  chave `pets_type_id_fkey` não chega a recusar a operação.
- **Relação com o contrato:** o `DELETE /api/pettypes/{petTypeId}` não diz o que acontece com os pets e não documenta
  `409`. A diferença para o `CT-API-OWNERS-10` é que um dono é responsável pelos próprios pets; o tipo é compartilhado.
- **Impacto:** alto. Uma única chamada apaga pets e históricos de visitas de vários donos, sem aviso e com uma resposta
  de sucesso. Só o banco mostra o que se perdeu.

## BUG-08 · Corpo ilegível responde 500 em vez de 400

- **Issue:** [#8](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/8)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar um dono e um tipo → contar as linhas de `pets` →
  `POST /api/owners/{ownerId}/pets` com `birthDate` igual a `2020-02-30`, depois `04/03/2010` e depois `ontem` →
  contar as linhas de `pets` de novo.
- **Esperado:** `400 Bad Request`, indicando o campo inválido, e nenhum pet novo.
- **Obtido:** `500`, com `"title": "HttpMessageNotReadableException"`, `"detail": "An unexpected error occurred while
  processing your request"` e a lista de erros de validação vazia.

  | Pedido | Resposta |
  |:---|:---|
  | Pet com `birthDate` `2020-02-30` | `500` |
  | Pet com `birthDate` `04/03/2010` | `500` |
  | Pet com `birthDate` `ontem` | `500` |
  | `POST /api/owners` com JSON quebrado | `500` |
  | Pet com `type.id` em texto | `500` |
  | Visita com `date` `2020-02-30` | `500` |
  | Visita com `date` `2021-02-29` (29/02 em ano não bissexto), visto em 2026-11-20 | `500` |
  | Visita com `date` `04/03/2010`, `yesterday` e `ontem`, visto em 2026-11-21 | `500` |

- **Evidência no banco:** `pets` tem 13 linhas antes e depois dos três pedidos com data inválida. Reproduzido do zero
  em 2026-11-18, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Causa:** o log mostra `HttpMessageNotReadableException`, com `Cannot deserialize value of type java.time.LocalDate`
  nos casos de data. A classe `ExceptionControllerAdvice` da imagem trata `MethodArgumentNotValidException`, violação
  de integridade e erros gerais, mas não trata corpo ilegível; por isso o erro cai no tratamento geral e vira `500`.
- **Impacto:** médio. Nenhum dado é afetado, mas um erro do cliente aparece como falha do servidor: quem chama a API
  não sabe o que corrigir, o monitoramento recebe alarmes falsos e o nome da exceção fica exposto, como no BUG-01.

## BUG-09 · Id negativo na URL responde 500 em vez de 400

- **Issue:** [#9](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/9)
- **Passos:** `docker compose down -v` → `up -d --wait` → contar as linhas de `owners`, `pets`, `types`, `visits`,
  `vets` e `specialties` → `GET /api/owners/-1` → `POST /api/owners/-1/pets` com um pet válido → repetir com `-1` nas
  demais operações que recebem id na URL, com corpo válido em `POST` e `PUT` → contar as linhas de novo.
- **Esperado:** `400 Bad Request`, indicando o parâmetro inválido. O contrato define o mínimo `0` para esses ids e
  lista o `400` como resposta.
- **Obtido:** `500`, com `"title": "ConstraintViolationException"`, `"detail": "An unexpected error occurred while
  processing your request"` e a lista de erros de validação vazia.

  | Operações com id `-1` | Quantidade | Resposta |
  |:---|:---:|:---|
  | `GET /api/{owners, pets, pettypes, visits, vets, specialties}/-1` | 6 | `500` |
  | `PUT /api/{owners, pets, pettypes, visits, vets, specialties}/-1` | 6 | `500` |
  | `DELETE /api/{owners, pets, pettypes, visits, vets, specialties}/-1` | 6 | `500` |
  | `POST /api/owners/-1/pets` | 1 | `500` |
  | `GET` e `PUT /api/owners/-1/pets/-1` | 2 | `500` |
  | `POST /api/owners/-1/pets/-1/visits` | 1 | `500` |

  Com id `0`, que o contrato aceita, as mesmas 22 operações respondem `404`.

- **Evidência no banco:** `owners`, `pets`, `types`, `visits`, `vets` e `specialties` têm 10, 13, 6, 4, 6 e 3 linhas
  antes e depois dos pedidos. Reproduzido do zero em 2026-11-18, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Causa:** o log mostra `jakarta.validation.ConstraintViolationException`, por exemplo `getOwner.ownerId: must be
  greater than or equal to 0`. A validação funciona, mas a classe `ExceptionControllerAdvice` da imagem só trata
  `MethodArgumentNotValidException`, `DataIntegrityViolationException` e erros gerais; por isso a exceção cai no
  tratamento geral e vira `500`.
- **Impacto:** médio. Nenhum dado é afetado, mas um erro do cliente aparece como falha do servidor em toda a API: quem
  chama não sabe o que corrigir, o monitoramento recebe alarmes falsos e o nome da exceção fica exposto, como no BUG-01
  e no BUG-08.

## BUG-10 · Dono da URL não é conferido ao alterar pet nem ao criar visita

- **Issue:** [#10](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/10)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar os donos A e B, um tipo e um pet do dono A → contar
  as linhas de `owners`, `pets`, `types` e `visits` → `GET /api/owners/{B}/pets/{pet}` →
  `PUT /api/owners/{B}/pets/{pet}` com novo nome e nova data → `POST /api/owners/{B}/pets/{pet}/visits` → conferir a
  linha do pet e as visitas dele no banco.
- **Esperado:** `404` nos três pedidos, porque o pet não pertence ao dono B, e nenhuma mudança no banco. O contrato
  lista o `404` para o `PUT` e para o `POST` de visita.
- **Obtido:** o `GET` responde `404`, mas o `PUT` responde `204` e o `POST` de visita responde `201`.

  | Pedido pelo caminho do dono B | Resposta | Efeito no banco |
  |:---|:---|:---|
  | `GET /api/owners/{B}/pets/{pet}` | `404` | nenhum |
  | `PUT /api/owners/{B}/pets/{pet}` | `204` | nome e data do pet alterados; `owner_id` continua o do dono A |
  | `POST /api/owners/{B}/pets/{pet}/visits` | `201` | visita nova ligada ao pet do dono A |

  Com um dono inexistente na URL, o `PUT` responde `404` e nada muda.

- **Evidência no banco:** a linha do pet passa de `Rex`, `2020-05-10`, dono A para `Zeus`, `2019-03-15`, dono A, e
  `visits` passa de 4 para 5 linhas, com a visita nova apontando para o pet do dono A. O dono B continua sem pets.
  Reproduzido do zero em 2026-11-19, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Causa provável:** a API confere só se o dono da URL existe; depois busca o pet pelo id, sem conferir de quem ele
  é. O `GET` pelo mesmo caminho faz essa conferência, por isso responde `404`.
- **Impacto:** médio. Os dados de um pet e o histórico de visitas dele podem ser mudados pelo caminho de outro dono,
  e a API confirma a operação como se estivesse certa. Num sistema em que cada pessoa só acessa os próprios dados, isso
  permitiria alterar o pet de outra pessoa.

## BUG-11 · Descrição de visita só com espaços é aceita e gravada

- **Issue:** [#11](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/11)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar um dono, um tipo e um pet → contar as linhas de
  `visits` → `POST /api/owners/{ownerId}/pets/{petId}/visits` com `"date": "2026-11-01"` e `"description": "   "` →
  conferir a visita no banco e com `GET /api/pets/{petId}`.
- **Esperado:** `400 Bad Request` apontando o campo `description`, sem gravar a visita, como acontece com `""`.
- **Obtido:** `201 Created`, com `"description": "   "` na resposta, e uma linha nova em `visits`.

  | Campo em `visits` | Valor gravado |
  |:---|:---|
  | `id` | 5 |
  | `pet_id` | 14 (criado no teste) |
  | `visit_date` | 2026-11-01 |
  | `description` | 3 espaços (tamanho 3; vazio depois de tirar os espaços) |

  Total de visitas: 4 antes e 5 depois. Um espaço e um tab também são aceitos e gravados. Com `""`, a API responde
  `400` com `size must be between 1 and 255`.
- **Evidência no banco:** a linha da visita criada, com a descrição só de espaços, e a contagem de `visits` antes e
  depois. Reproduzido do zero em 2026-11-20, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Relação com o contrato:** `description` de `VisitFields` só tem `minLength: 1` e `maxLength: 255`, sem `pattern`.
  O contrato não proíbe o valor: o defeito é de regra de negócio, o mesmo do BUG-06 no nome do pet.
- **Impacto:** baixo a médio. A visita aparece no histórico do pet sem descrever o atendimento. O banco não impede: a
  coluna aceita texto só com espaços.

## BUG-12 · Visita com data anterior ao nascimento do pet é aceita

- **Issue:** [#12](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/12)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar um dono, um tipo e um pet nascido em `2020-05-10` →
  contar as linhas de `visits` → `POST /api/owners/{ownerId}/pets/{petId}/visits` com `"date": "2020-05-09"`, um dia
  antes do nascimento, e depois com `"date": "1900-01-01"` → conferir as visitas no banco.
- **Esperado:** `400 Bad Request` apontando o campo `date`, sem gravar a visita. Uma visita não pode acontecer antes
  de o pet nascer.
- **Obtido:** `201 Created` nos dois pedidos, e duas linhas novas em `visits`.

  | `visit_date` gravada | `birth_date` do pet | Visita antes do nascimento? |
  |:---|:---|:---|
  | 2020-05-09 | 2020-05-10 | sim |
  | 1900-01-01 | 2020-05-10 | sim |

  Total de visitas: 4 antes e 6 depois. A data `0001-01-01` também é aceita. A visita no dia do nascimento
  (`CT-API-VISITS-05a`) é aceita, como esperado.
- **Evidência no banco:** as duas linhas novas de `visits`, cada uma com data anterior ao nascimento do pet ligado a
  ela, e a contagem de `visits` antes e depois. Reproduzido do zero em 2026-11-20, na imagem `4.0.2` (digest
  `sha256:daba846d…`).
- **Relação com o contrato:** `date` de `VisitFields` só tem `format: date`; o contrato não traz a regra. O defeito é
  de regra de negócio: a API valida a data de nascimento do pet (recusa futuro e mais de 50 anos), mas não compara a
  data da visita com ela nem impõe qualquer limite.
- **Impacto:** baixo a médio. O histórico do pet fica com atendimentos impossíveis, e relatórios por período contam
  visitas que não existiram. O banco não impede: nenhuma restrição compara as duas datas.

## BUG-13 · Data enviada como número é aceita e gravada como outra data

- **Issue:** [#13](https://github.com/angelo-roque-barbosa/petclinic-sql-api/issues/13)
- **Passos:** `docker compose down -v` → `up -d --wait` → criar um dono, um tipo e um pet nascido em `2005-01-15` →
  contar as linhas de `visits` → `POST /api/owners/{ownerId}/pets/{petId}/visits` com `"date": 20100403`, sem
  aspas, depois com `"date": 1795265233` (timestamp Unix em segundos) e `"date": 2010` → `PUT /api/visits/{id}` de
  uma visita existente com `"date": 14000` → `POST /api/owners/{ownerId}/pets` com `"birthDate": 14000` → conferir
  as datas no banco.
- **Esperado:** `400 Bad Request` apontando o campo, sem gravar nada. O contrato define `date` e `birthDate` como
  `type: string, format: date`; um número não é uma data nesse formato.
- **Obtido:** a API lê o número como dias contados a partir de 1970-01-01, responde `201` ou `204` e grava a data
  calculada.

  | Pedido | Resposta | Data gravada |
  |:---|:---|:---|
  | Visita com `date` `20100403` | `201` | 57003-01-14 |
  | Visita com `date` `1795265233` (timestamp em segundos) | `201` | 4917239-04-06 |
  | Visita com `date` `2010` | `201` | 1975-07-04 |
  | `PUT` de visita com `date` `14000` | `204` | 2008-05-01, no lugar da data anterior |
  | Pet com `birthDate` `14000` | `201` | 2008-05-01 |
  | Pet com `birthDate` `20100403` | `400` | nada: só recusado porque 57003 cai na regra "nascimento no futuro" |

  Com o número em texto (`"20100403"`) ou com timestamp em milissegundos, a resposta é `500` (BUG-08) e nada é
  gravado. Com o número `0` a data gravada é 1970-01-01, e com `-1`, 1969-12-31.
- **Evidência no banco:** as linhas novas de `visits` com `visit_date` 57003-01-14, 4917239-04-06 e 1975-07-04, a
  visita alterada para 2008-05-01, o pet com `birth_date` 2008-05-01, e as contagens de donos, pets, tipos e visitas:
  10, 13, 6 e 4 antes; 11, 15, 7 e 8 com os dados do teste (dono, tipo, dois pets, três visitas com número e uma de
  controle); 10, 13, 6 e 4 depois da limpeza.
  Reproduzido do zero em 2026-11-21, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Causa provável:** o desserializador de `LocalDate` do Jackson aceita, por padrão, um número inteiro e o
  interpreta como "dia desde 1970-01-01" (`LocalDate.ofEpochDay`). A API não desliga esse comportamento nem valida
  o tipo do campo antes de usá-lo.
- **Impacto:** baixo a médio. Pela tela ninguém cai nisso, porque o frontend e o Swagger mandam texto; quem cai é quem
  integra com a API. O erro mais provável é mandar um timestamp, que vira uma visita no ano 4,9 milhões, com `201`,
  sem nenhum aviso. Os dados ficam corrompidos em silêncio, o que é pior do que o `500` do BUG-08, que não grava
  nada. O banco não impede: o PostgreSQL aceita datas até o ano 5874897.

## Observações

Diferenças que não quebram o funcionamento, mas ficam registradas.

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

### OBS-02 · Pet com tipo inexistente só é recusado depois de chegar ao banco

- **Passos:** `docker compose down -v` → `up -d --wait` → contar as linhas de `pets` e `types` →
  `POST /api/owners/1/pets` com um pet válido e `type.id` igual a `7`, o maior id de `types` + 1 → contar de novo.
- **Obtido:** `404`, com `"title": "DataIntegrityViolationException"` e `"detail": "The requested resource could not
  be processed due to a data constraint violation"`. O log mostra `null value in column "type_id" of relation "pets"
  violates not-null constraint`: a API não encontra o tipo, tenta gravar o pet com `type_id` nulo e o banco recusa.
- **Evidência no banco:** `pets` continua com 13 linhas, `types` com 6, e o tipo `7` não é criado. Reproduzido do zero
  em 2026-11-18, na imagem `4.0.2` (digest `sha256:daba846d…`).
- **Por que não é bug:** o `404` está no contrato, atende ao `CT-API-PETS-09` e nenhum dado é gravado.
- **Ponto de atenção:** quem protege o dado é a restrição do banco, não uma validação da API. A resposta não diz que
  o problema é o tipo e expõe o nome da exceção.
- **Mesmo padrão em visitas (visto em 2026-11-21):** `POST /api/owners/1/pets/14/visits`, com `14` igual ao maior id de
  `pets` + 1, também responde `404` com `DataIntegrityViolationException`. O log mostra que a API tenta o `insert into
  visits` com `pet_id` 14, e a chave `visits_pet_id_fkey` recusa. `visits` continua com 4 linhas. Atende ao
  `CT-API-VISITS-10`, mas, de novo, quem barra é o banco.
