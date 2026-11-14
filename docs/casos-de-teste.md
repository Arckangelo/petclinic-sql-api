# Casos de teste — petclinic-sql-api

Casos de teste derivados do [dicionário de dados](dicionario-de-dados.md), um por teste a automatizar, identificados pelo ID CT que vai no comentário acima do teste no código. Os arquivos de cada seção são os previstos em `tests/api/`; nenhum existe ainda. Total: 76 casos.

**Notas gerais**

- Todos os casos rodam contra a API e o PostgreSQL locais, pelo `docker compose` (`http://localhost:9966/petclinic/api`).
- O banco é o oráculo: cada caso confere a resposta da API **e** o estado do banco depois da chamada. Os passos dizem em palavras o que conferir no banco; as consultas ficam no código do teste.
- Preparação por API; o valor esperado vem do que o teste enviou ou do banco, nunca da própria resposta da API.
- Cada caso cria e apaga os próprios dados; nomes e textos levam um sufixo único por execução. Nenhum caso depende do `populateDB.sql` nem da ordem de execução.
- "Banco intacto" quer dizer que a tabela tem as mesmas linhas, com os mesmos valores, de antes da chamada.
- Onde o banco **não** garante uma regra (seção "Fora do banco" do dicionário), o esperado é a API recusar com 4xx e não gravar nada. Quando a regra não está no contrato da API (OpenAPI) e é uma suposição, as Observações dizem "regra a confirmar".
- Recusa esperada é sempre 4xx. Um 500 reprova o caso, mesmo que o banco fique intacto.
- Limites de tamanho e formato citados como "contrato" vêm do OpenAPI da imagem `springcommunity/spring-petclinic-rest` 4.0.2 (`/petclinic/v3/api-docs`).
- Status "Não executado": o teste ainda não existe. Nos bugs conhecidos, o esperado é o comportamento correto e o obtido é o reproduzido à mão e registrado no README.

## Índice

| Área | Arquivo | Casos |
|---|---|---|
| API | [tests/api/test_owners.py](#testsapitest_ownerspy) | 13 |
| API | [tests/api/test_pets.py](#testsapitest_petspy) | 13 |
| API | [tests/api/test_visits.py](#testsapitest_visitspy) | 12 |
| API | [tests/api/test_pet_types.py](#testsapitest_pet_typespy) | 8 |
| API | [tests/api/test_specialties.py](#testsapitest_specialtiespy) | 8 |
| API | [tests/api/test_vets.py](#testsapitest_vetspy) | 11 |
| API | [tests/api/test_users.py](#testsapitest_userspy) | 9 |
| Bugs conhecidos | [tests/api/known_bugs/test_http_status.py](#testsapiknown_bugstest_http_statuspy) | 1 |
| Bugs conhecidos | [tests/api/known_bugs/test_schema_indexes.py](#testsapiknown_bugstest_schema_indexespy) | 1 |
| **Total** | | **76** |

## API

### tests/api/test_owners.py

**Notas gerais**

- Tabela `owners`. Contrato: `firstName` e `lastName` com 1 a 30 letras (até 3 palavras, separadas por espaço, `'` ou `-`), `address` com 1 a 255 caracteres, `city` com 1 a 80, `telephone` com exatamente 10 dígitos.
- No banco, só `telephone` é `NOT NULL`, e o `varchar(10)` limita apenas o tamanho máximo.

#### CT-API-OWNERS-01 — Criar dono com dados válidos

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que o cadastro grava no banco exatamente os dados enviados. |
| **Dados de teste** | Dono padrão: firstName, lastName, address, city e telephone com 10 dígitos. |
| **Passos** | 1. Enviar POST /api/owners com o dono padrão.<br>2. Verificar a resposta.<br>3. Buscar no banco a linha de `owners` com o id devolvido. |
| **Resultado esperado** | Passo 2: status 201 e corpo com os campos enviados e um id.<br>Passo 3: existe uma linha com esse id, e first_name, last_name, address, city e telephone são iguais aos enviados. |
| **Status** | Não executado |
| **Observações** | Dono removido no teardown (DELETE /api/owners/{id} aceita 2xx ou 404). |

#### CT-API-OWNERS-02 — Criar dono sem cada um dos campos obrigatórios

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API recusa o cadastro quando falta qualquer campo obrigatório e não grava dono parcial. |
| **Dados de teste** | Dono padrão, omitindo um campo por vez: firstName, lastName, address, city, telephone. |
| **Passos** | 1. Contar as linhas de `owners`.<br>2. Para cada campo da lista, enviar POST /api/owners sem esse campo.<br>3. Verificar cada resposta.<br>4. Contar as linhas de `owners` de novo. |
| **Resultado esperado** | Passo 3 (para cada campo): status 400.<br>Passo 4: mesma contagem do passo 1. |
| **Status** | Não executado |
| **Observações** | Dicionário, owners › Fora do banco: o banco aceita dono só com telefone, porque nome, sobrenome, endereço e cidade aceitam NULL. A regra fica só na API.<br>Um caso parametrizado por campo (pytest.mark.parametrize). |

#### CT-API-OWNERS-03 — Telefone no limite de 10 dígitos

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que só um telefone de exatamente 10 dígitos é aceito e que o limite do banco não vira erro 500. |
| **Dados de teste** | Telefone com 9, 10 e 11 dígitos. |
| **Passos** | 1. Para cada telefone, enviar POST /api/owners com o dono padrão e esse telefone.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 10 dígitos: status 201 e telefone gravado igual ao enviado.<br>9 e 11 dígitos: status 400 e banco intacto. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita 9 dígitos (`'608555102'`) e recusa 11 (`varchar(10)`). Se a API não validar, 11 dígitos chegam ao banco e podem virar 500.<br>Linhas da tabela de partições do README (fase 4). |

#### CT-API-OWNERS-04 — Telefone com caracteres não numéricos ou vazio

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Criação |
| **Tipo de teste** | Funcional – validação de formato |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API recusa telefone que não seja só dígitos e não grava o dono. |
| **Dados de teste** | Telefone: `'abc'`, `'60855510ab'` (10 caracteres), `'608 555 10'` (10 caracteres com espaços), `''`. |
| **Passos** | 1. Para cada telefone, enviar POST /api/owners com o dono padrão e esse telefone.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400 em todos e banco intacto. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita `'abc'` e `''` (o NOT NULL não barra texto vazio). Os de 10 caracteres testam o formato sem depender do tamanho. |

#### CT-API-OWNERS-05 — Nome e sobrenome vazios ou só com espaços

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa nome ou sobrenome sem conteúdo e não grava o dono. |
| **Dados de teste** | firstName e, depois, lastName com `''` e com `'   '`. |
| **Passos** | 1. Para cada combinação, enviar POST /api/owners com o dono padrão e o campo alterado.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400 em todos e banco intacto. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita nome só com espaços. |

#### CT-API-OWNERS-06 — Nome e sobrenome no limite de 30 caracteres

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que o limite do contrato vale e que o nome aceito é gravado inteiro, sem corte. |
| **Dados de teste** | firstName e lastName com 30 e com 31 letras. |
| **Passos** | 1. Para cada tamanho, enviar POST /api/owners com o dono padrão e o campo alterado.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 30 letras: status 201 e valor gravado igual ao enviado, com 30 caracteres.<br>31 letras: status 400 e banco intacto. |
| **Status** | Não executado |
| **Observações** | O limite vem do contrato; no banco a coluna é `text`, sem limite. |

#### CT-API-OWNERS-07 — Atualizar dono com dados válidos

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Atualização |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a atualização grava os novos valores na mesma linha, sem criar outro dono nem mexer nos pets. |
| **Pré-condições** | Dono padrão com um pet, criados via API. |
| **Dados de teste** | Novos valores para todos os campos do dono. |
| **Passos** | 1. Enviar PUT /api/owners/{id} com os novos valores.<br>2. Verificar a resposta.<br>3. Conferir no banco a linha do dono, a contagem de `owners` e o pet. |
| **Resultado esperado** | Passo 2: status 2xx.<br>Passo 3: a linha com o mesmo id tem os novos valores; a contagem de `owners` não mudou; o pet continua com o mesmo owner_id. |
| **Status** | Não executado |

#### CT-API-OWNERS-08 — Atualizar dono com telefone inválido

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Atualização |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a validação do telefone vale também na atualização e que a linha original fica como estava. |
| **Pré-condições** | Dono padrão criado via API. |
| **Dados de teste** | Telefone `'abc'` e telefone com 11 dígitos. |
| **Passos** | 1. Para cada telefone, enviar PUT /api/owners/{id} com o dono e esse telefone.<br>2. Verificar a resposta e a linha do dono no banco. |
| **Resultado esperado** | Status 400 e linha do dono igual à de antes da chamada. |
| **Status** | Não executado |

#### CT-API-OWNERS-09 — Apagar dono sem pets

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Exclusão |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a exclusão remove a linha do banco. |
| **Pré-condições** | Dono padrão sem pets, criado via API. |
| **Dados de teste** | Id do dono criado. |
| **Passos** | 1. Enviar DELETE /api/owners/{id}.<br>2. Verificar a resposta.<br>3. Buscar a linha no banco. |
| **Resultado esperado** | Passo 2: status 2xx.<br>Passo 3: nenhuma linha com esse id. |
| **Status** | Não executado |

#### CT-API-OWNERS-10 — Apagar dono que tem pets

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Exclusão |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API não apaga um dono que ainda tem pets e que não deixa remoção pela metade. |
| **Pré-condições** | Dono padrão com um pet e uma visita, criados via API. |
| **Dados de teste** | Id do dono criado. |
| **Passos** | 1. Enviar DELETE /api/owners/{id}.<br>2. Verificar a resposta.<br>3. Conferir no banco o dono, o pet e a visita. |
| **Resultado esperado** | Passo 2: status 4xx (409).<br>Passo 3: dono, pet e visita continuam no banco, sem alteração. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave estrangeira `pets_owner_id_fkey` recusa a exclusão no banco.<br>Regra a confirmar: a alternativa é apagar dono, pets e visitas juntos. Em qualquer regra, nunca 500 e nunca remoção parcial. |

#### CT-API-OWNERS-11 — Consultar dono inexistente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Consulta |
| **Tipo de teste** | Funcional – recurso inexistente |
| **Prioridade** | Média |
| **Objetivo** | Garantir que um id numérico que não existe responde 404. |
| **Dados de teste** | Id inexistente: o maior id de `owners` + 1, lido do banco na hora. |
| **Passos** | 1. Enviar GET /api/owners/{id inexistente}.<br>2. Verificar a resposta. |
| **Resultado esperado** | Status 404. |
| **Status** | Não executado |
| **Observações** | Id não numérico é o BUG-01 (CT-BUGS-HTTP-STATUS-01). |

#### CT-API-OWNERS-12 — Buscar donos por sobrenome

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Consulta |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a busca devolve exatamente os donos do banco cujo sobrenome começa com o termo. |
| **Pré-condições** | Dois donos com sobrenome começando pelo mesmo prefixo único e um com outro sobrenome, criados via API. |
| **Dados de teste** | Prefixo único do sobrenome. |
| **Passos** | 1. Enviar GET /api/owners?lastName=&lt;prefixo&gt;.<br>2. Buscar no banco os ids de `owners` com last_name começando pelo prefixo.<br>3. Comparar os ids da resposta com os do banco. |
| **Resultado esperado** | Status 200 e o mesmo conjunto de ids nos dois lados (os dois donos do prefixo, sem o terceiro). |
| **Status** | Não executado |
| **Observações** | Busca usa o índice `owners_last_name_idx`. |

#### CT-API-OWNERS-13 — Criar dono com id no corpo

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Donos › Criação |
| **Tipo de teste** | Segurança – atribuição em massa (campo somente leitura) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que o id enviado no corpo é ignorado: o banco gera o id, e nenhum dono existente é sobrescrito. |
| **Pré-condições** | Dono A criado via API. |
| **Dados de teste** | Dono padrão com id = id do dono A; dono padrão com id = maior id de `owners` + 1000, lido do banco na hora. |
| **Passos** | 1. Guardar a linha do dono A, lida do banco.<br>2. Enviar POST /api/owners com id = id do dono A.<br>3. Enviar POST /api/owners com id = maior id + 1000.<br>4. Conferir no banco o dono A, as linhas com os ids devolvidos e o id inexistente enviado. |
| **Resultado esperado** | Passos 2 e 3: status 201, com um id no corpo diferente do enviado.<br>Passo 4: o dono A está igual ao do passo 1; há uma linha nova para cada id devolvido, com os dados enviados; nenhuma linha tem o id inexistente enviado. |
| **Status** | Não executado |
| **Observações** | O contrato marca o id do dono como somente leitura (readOnly). Comportamento seguro: não é bug.<br>O id inexistente fica longe do maior id: com maior id + 1, o banco poderia gerar justamente esse id e mascarar a falha.<br>Conferido à mão em 2026-11-14 (Postman, e curl com consulta ao banco): id 1 e id 9999 no corpo → 201 com ids 13 e 14 gerados pelo banco; o dono 1 ficou intacto e nenhuma linha com id 9999. |

### tests/api/test_pets.py

**Notas gerais**

- Tabela `pets`. Contrato: `name` com 1 a 30 caracteres, `birthDate` no formato de data ISO (`aaaa-mm-dd`), `type` obrigatório. O contrato não limita a data.
- O pet é criado por POST /api/owners/{ownerId}/pets; o dono e o tipo usados são criados pelo próprio teste.

#### CT-API-PETS-01 — Criar pet com dados válidos

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que o pet é gravado com os dados enviados e ligado ao dono e ao tipo certos. |
| **Pré-condições** | Dono padrão e tipo de pet criados via API. |
| **Dados de teste** | Pet padrão: name, birthDate no passado, type = tipo criado. |
| **Passos** | 1. Enviar POST /api/owners/{ownerId}/pets com o pet padrão.<br>2. Verificar a resposta.<br>3. Buscar no banco a linha de `pets` com o id devolvido. |
| **Resultado esperado** | Passo 2: status 201.<br>Passo 3: name e birth_date iguais aos enviados, owner_id = id do dono, type_id = id do tipo. |
| **Status** | Não executado |
| **Observações** | Teardown: pet, depois dono e tipo; cada remoção aceita "já removido". |

#### CT-API-PETS-02 — Criar pet sem cada um dos campos obrigatórios

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API recusa pet sem nome, sem data de nascimento ou sem tipo e não grava nada. |
| **Pré-condições** | Dono padrão e tipo criados via API. |
| **Dados de teste** | Pet padrão, omitindo um campo por vez: name, birthDate, type. |
| **Passos** | 1. Para cada campo, enviar POST /api/owners/{ownerId}/pets sem esse campo.<br>2. Verificar cada resposta.<br>3. Contar os pets do dono no banco. |
| **Resultado esperado** | Passo 2: status 400 em todos.<br>Passo 3: zero pets. |
| **Status** | Não executado |
| **Observações** | No banco as três colunas são NOT NULL; sem validação na API, o erro chega ao banco e pode virar 500. |

#### CT-API-PETS-03 — Nome do pet vazio ou só com espaços

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa nome sem conteúdo. |
| **Pré-condições** | Dono padrão e tipo criados via API. |
| **Dados de teste** | name = `''` e name = `'   '`. |
| **Passos** | 1. Para cada nome, enviar POST /api/owners/{ownerId}/pets.<br>2. Verificar a resposta e os pets do dono no banco. |
| **Resultado esperado** | Status 400 e zero pets. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita nome vazio, mesmo com NOT NULL. O contrato barra `''` (minLength 1), mas não `'   '`. |

#### CT-API-PETS-04 — Nome do pet no limite de 30 caracteres

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que o limite do contrato vale e que o nome aceito é gravado inteiro. |
| **Pré-condições** | Dono padrão e tipo criados via API. |
| **Dados de teste** | name com 30 e com 31 caracteres. |
| **Passos** | 1. Para cada tamanho, enviar POST /api/owners/{ownerId}/pets.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 30: status 201 e nome gravado com 30 caracteres.<br>31: status 400 e nenhum pet novo. |
| **Status** | Não executado |

#### CT-API-PETS-05 — Data de nascimento no futuro

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que um pet não pode nascer depois de hoje. |
| **Pré-condições** | Dono padrão e tipo criados via API. |
| **Dados de teste** | birthDate = hoje, amanhã e 2099-01-01 (datas calculadas na hora do teste). |
| **Passos** | 1. Para cada data, enviar POST /api/owners/{ownerId}/pets.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Hoje: status 201 e data gravada igual.<br>Amanhã e 2099-01-01: status 400 e nenhum pet novo. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita 2099-01-01.<br>Regra a confirmar: o contrato não limita a data. |

#### CT-API-PETS-06 — Data de nascimento muito antiga

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que a API recusa uma data de nascimento sem sentido para um pet. |
| **Pré-condições** | Dono padrão e tipo criados via API. |
| **Dados de teste** | birthDate = 1800-01-01. |
| **Passos** | 1. Enviar POST /api/owners/{ownerId}/pets.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400 e nenhum pet novo. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita 1800-01-01.<br>Regra a confirmar: a data mínima aceita (o valor-limite exato) precisa ser definida antes de automatizar. O `populateDB` já tem pets de 31 anos (Samantha e Max, ids 7 e 8, nascidos em 1995-09-04; `sql/03_pets_invalid_birth_date.sql`): um limite que os torne inválidos deixa dados existentes fora da regra. |

#### CT-API-PETS-07 — Data de nascimento inexistente ou fora do formato ISO

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Robustez – entrada inválida |
| **Prioridade** | Média |
| **Objetivo** | Garantir que data inválida é recusada como erro do cliente (400), não como erro do servidor. |
| **Pré-condições** | Dono padrão e tipo criados via API. |
| **Dados de teste** | birthDate = `'2020-02-30'`, `'04/03/2010'`, `'ontem'`. |
| **Passos** | 1. Para cada data, enviar POST /api/owners/{ownerId}/pets.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400 em todos e nenhum pet novo. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco recusa 2020-02-30, mas lê `04/03/2010` como 3 de abril (DateStyle MDY). A API não pode repassar a data como texto ao banco. |

#### CT-API-PETS-08 — Criar pet para dono inexistente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – recurso inexistente |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API responde 404 e não grava pet sem dono. |
| **Pré-condições** | Tipo criado via API. |
| **Dados de teste** | ownerId inexistente: maior id de `owners` + 1, lido do banco na hora; pet padrão. |
| **Passos** | 1. Contar as linhas de `pets`.<br>2. Enviar POST /api/owners/{ownerId inexistente}/pets.<br>3. Verificar a resposta e contar de novo. |
| **Resultado esperado** | Status 404 e mesma contagem. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `pets_owner_id_fkey` recusa no banco; a API precisa barrar antes, sem 500. |

#### CT-API-PETS-09 — Criar pet com tipo inexistente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa um tipo que não existe como erro do cliente. |
| **Pré-condições** | Dono padrão criado via API. |
| **Dados de teste** | type.id inexistente: maior id de `types` + 1, lido do banco na hora. |
| **Passos** | 1. Enviar POST /api/owners/{ownerId}/pets com esse tipo.<br>2. Verificar a resposta e os pets do dono no banco. |
| **Resultado esperado** | Status 4xx (400 ou 404) e zero pets. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `pets_type_id_fkey` recusa no banco. Um 500 aqui indica que a validação ficou para o banco. |

#### CT-API-PETS-10 — Atualizar pet com dados válidos

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Atualização |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a atualização grava os novos valores e mantém o dono. |
| **Pré-condições** | Dono, dois tipos e um pet criados via API. |
| **Dados de teste** | Novo name, nova birthDate no passado e o segundo tipo. |
| **Passos** | 1. Enviar PUT /api/owners/{ownerId}/pets/{petId} com os novos valores.<br>2. Verificar a resposta.<br>3. Conferir a linha do pet no banco. |
| **Resultado esperado** | Passo 2: status 204.<br>Passo 3: name, birth_date e type_id novos; owner_id igual ao de antes. |
| **Status** | Não executado |

#### CT-API-PETS-11 — Mover pet para dono inexistente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Atualização |
| **Tipo de teste** | Funcional – recurso inexistente |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API não liga um pet a um dono que não existe. |
| **Pré-condições** | Dono, tipo e pet criados via API. |
| **Dados de teste** | ownerId inexistente: maior id de `owners` + 1, lido do banco na hora. |
| **Passos** | 1. Enviar PUT /api/owners/{ownerId inexistente}/pets/{petId} com os dados do pet.<br>2. Verificar a resposta e a linha do pet no banco. |
| **Resultado esperado** | Status 404 e linha do pet igual à de antes (mesmo owner_id). |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave estrangeira recusa trocar o dono para um inexistente. |

#### CT-API-PETS-12 — Apagar pet sem visitas

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Exclusão |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a exclusão remove o pet e mantém o dono. |
| **Pré-condições** | Dono, tipo e pet sem visitas criados via API. |
| **Dados de teste** | Id do pet. |
| **Passos** | 1. Enviar DELETE /api/pets/{petId}.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx; nenhuma linha de `pets` com esse id; o dono continua no banco. |
| **Status** | Não executado |

#### CT-API-PETS-13 — Apagar pet que tem visitas

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Pets › Exclusão |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API não apaga um pet que tem visitas e que não deixa remoção pela metade. |
| **Pré-condições** | Dono, tipo, pet e uma visita criados via API. |
| **Dados de teste** | Id do pet. |
| **Passos** | 1. Enviar DELETE /api/pets/{petId}.<br>2. Verificar a resposta.<br>3. Conferir no banco o pet e a visita. |
| **Resultado esperado** | Passo 2: status 4xx (409).<br>Passo 3: pet e visita continuam no banco. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `visits_pet_id_fkey` recusa no banco.<br>Regra a confirmar: a alternativa é apagar pet e visitas juntos. Em qualquer regra, nunca 500 e nunca remoção parcial. |

### tests/api/test_visits.py

**Notas gerais**

- Tabela `visits`. Contrato: `date` no formato de data ISO e `description` com 1 a 255 caracteres. No banco, `description` é `text`, sem limite.
- A visita é criada por POST /api/owners/{ownerId}/pets/{petId}/visits; dono, tipo e pet são criados pelo próprio teste, com o nascimento do pet numa data conhecida.

#### CT-API-VISITS-01 — Criar visita com dados válidos

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a visita é gravada com a data e a descrição enviadas, ligada ao pet certo. |
| **Pré-condições** | Dono, tipo e pet criados via API. |
| **Dados de teste** | Visita padrão: date entre o nascimento do pet e hoje, description com sufixo único. |
| **Passos** | 1. Enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Verificar a resposta.<br>3. Buscar no banco a linha de `visits` com o id devolvido. |
| **Resultado esperado** | Passo 2: status 201.<br>Passo 3: pet_id = id do pet; visit_date e description iguais aos enviados. |
| **Status** | Não executado |

#### CT-API-VISITS-02 — Criar visita sem data ou sem descrição

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API recusa visita sem campo obrigatório como erro do cliente. |
| **Pré-condições** | Dono, tipo e pet criados via API. |
| **Dados de teste** | Visita padrão, omitindo um campo por vez: date, description. |
| **Passos** | 1. Para cada campo, enviar POST /api/owners/{ownerId}/pets/{petId}/visits sem esse campo.<br>2. Verificar a resposta e as visitas do pet no banco. |
| **Resultado esperado** | Status 400 em todos e zero visitas. |
| **Status** | Não executado |
| **Observações** | Dicionário: o NOT NULL recusa no banco; sem validação na API, vira 500. |

#### CT-API-VISITS-03 — Descrição vazia ou só com espaços

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa descrição sem conteúdo. |
| **Pré-condições** | Dono, tipo e pet criados via API. |
| **Dados de teste** | description = `''` e `'   '`. |
| **Passos** | 1. Para cada descrição, enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Verificar a resposta e as visitas do pet no banco. |
| **Resultado esperado** | Status 400 e zero visitas. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita as duas (NOT NULL recusa ausente, não vazio). |

#### CT-API-VISITS-04 — Descrição no limite de 255 caracteres

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que o limite do contrato vale e que a descrição aceita é gravada inteira. |
| **Pré-condições** | Dono, tipo e pet criados via API. |
| **Dados de teste** | description com 255 e com 256 caracteres. |
| **Passos** | 1. Para cada tamanho, enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 255: status 201 e descrição gravada com 255 caracteres.<br>256: status 400 e nenhuma visita nova. |
| **Status** | Não executado |

#### CT-API-VISITS-05 — Visita antes do nascimento do pet

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API não aceita visita com data anterior ao nascimento do pet. |
| **Pré-condições** | Dono, tipo e pet com nascimento conhecido, criados via API. |
| **Dados de teste** | date = nascimento − 1 dia, nascimento e 1900-01-01. |
| **Passos** | 1. Para cada data, enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Dia do nascimento: status 201.<br>Nascimento − 1 dia e 1900-01-01: status 400 e nenhuma visita nova. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco não compara a data da visita com o nascimento do pet.<br>Regra a confirmar: o contrato não traz essa regra. |

#### CT-API-VISITS-06 — Visita com data no futuro (agendamento)

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Média |
| **Objetivo** | Garantir que uma visita futura pode ser agendada e é gravada com a data exata. |
| **Pré-condições** | Dono, tipo e pet criados via API. |
| **Dados de teste** | date = hoje + 30 dias, calculada na hora do teste. |
| **Passos** | 1. Enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 201 e visit_date gravada igual à enviada. |
| **Status** | Não executado |
| **Observações** | Exceção à regra geral de recusa: visita futura é agendamento (fase 6, "agendar visita").<br>Regra a confirmar: se haverá um limite máximo de antecedência. |

#### CT-API-VISITS-07 — 29 de fevereiro em ano bissexto e não bissexto

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API aceita 29/02 só em ano bissexto e recusa o resto como erro do cliente. |
| **Pré-condições** | Dono, tipo e pet nascido antes de 2020, criados via API. |
| **Dados de teste** | date = 2020-02-29 e 2021-02-29. |
| **Passos** | 1. Para cada data, enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 2020-02-29: status 201 e data gravada igual.<br>2021-02-29: status 400 e nenhuma visita nova. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita 2020-02-29 e recusa 2021-02-29. |

#### CT-API-VISITS-08 — Data fora do formato ISO

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Robustez – entrada inválida |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API não grava uma data diferente da que a pessoa quis dizer. |
| **Pré-condições** | Dono, tipo e pet nascido antes de 2010, criados via API. |
| **Dados de teste** | date = `'04/03/2010'`, `'yesterday'`, `'ontem'`. |
| **Passos** | 1. Para cada data, enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Verificar a resposta e as visitas do pet no banco. |
| **Resultado esperado** | Status 400 em todos e zero visitas (em particular, nenhuma com 2010-04-03 ou com a data de ontem). |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco grava `'04/03/2010'` como 3 de abril (DateStyle MDY) e `'yesterday'` como a data de ontem, sem erro. |

#### CT-API-VISITS-09 — Visita duplicada

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – negativo (regra de negócio) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que o mesmo envio repetido não cria duas visitas iguais. |
| **Pré-condições** | Dono, tipo e pet criados via API. |
| **Dados de teste** | A mesma visita (data e descrição) enviada duas vezes. |
| **Passos** | 1. Enviar POST /api/owners/{ownerId}/pets/{petId}/visits.<br>2. Enviar o mesmo POST de novo.<br>3. Contar as visitas do pet com essa data e descrição no banco. |
| **Resultado esperado** | Passo 1: status 201.<br>Passo 2: status 4xx (409).<br>Passo 3: uma linha. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita a duplicata.<br>Regra a confirmar: duas visitas iguais no mesmo dia podem ser legítimas. |

#### CT-API-VISITS-10 — Criar visita para pet inexistente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – recurso inexistente |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API responde 404 e não grava visita sem pet. |
| **Pré-condições** | Dono criado via API. |
| **Dados de teste** | petId inexistente: maior id de `pets` + 1, lido do banco na hora. |
| **Passos** | 1. Contar as linhas de `visits`.<br>2. Enviar POST /api/owners/{ownerId}/pets/{petId inexistente}/visits.<br>3. Verificar a resposta e contar de novo. |
| **Resultado esperado** | Status 404 e mesma contagem. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `visits_pet_id_fkey` recusa no banco. |

#### CT-API-VISITS-11 — Criar visita pelo dono errado

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Criação |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API confere se o pet é do dono informado no caminho. |
| **Pré-condições** | Dois donos (A e B), um tipo e um pet do dono B, criados via API. |
| **Dados de teste** | ownerId = A, petId = pet do dono B. |
| **Passos** | 1. Enviar POST /api/owners/{A}/pets/{pet de B}/visits.<br>2. Verificar a resposta e as visitas do pet no banco. |
| **Resultado esperado** | Status 4xx (404 ou 400) e zero visitas. |
| **Status** | Não executado |
| **Observações** | O banco só liga visita a pet; a ligação dono-pet no caminho é responsabilidade da API. |

#### CT-API-VISITS-12 — Apagar visita

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Visitas › Exclusão |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a exclusão remove só a visita, mantendo o pet. |
| **Pré-condições** | Dono, tipo, pet e uma visita criados via API. |
| **Dados de teste** | Id da visita. |
| **Passos** | 1. Enviar DELETE /api/visits/{visitId}.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx; nenhuma linha de `visits` com esse id; o pet continua no banco. |
| **Status** | Não executado |
| **Observações** | Dicionário: nada aponta para `visits`, então a exclusão é livre.<br>"Trocar o pet de uma visita" não tem caso: PUT /api/visits/{id} não recebe petId (contrato VisitFields). |

### tests/api/test_pet_types.py

**Notas gerais**

- Tabela `types`, pelos endpoints /api/pettypes. Contrato: `name` com 1 a 80 caracteres. No banco, `name` aceita NULL e não tem regra UNIQUE.

#### CT-API-PET-TYPES-01 — Criar tipo de pet com nome válido

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Média |
| **Objetivo** | Garantir que o tipo é gravado com o nome enviado. |
| **Dados de teste** | name com sufixo único. |
| **Passos** | 1. Enviar POST /api/pettypes.<br>2. Verificar a resposta.<br>3. Buscar no banco a linha de `types` com o id devolvido. |
| **Resultado esperado** | Passo 2: status 2xx de criação.<br>Passo 3: name igual ao enviado. |
| **Status** | Não executado |
| **Observações** | O contrato declara só 200 para o POST; o status exato de criação fica a confirmar na execução. |

#### CT-API-PET-TYPES-02 — Tipo sem nome, vazio ou só com espaços

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa tipo sem nome. |
| **Dados de teste** | Corpo sem name, name = null, `''` e `'   '`. |
| **Passos** | 1. Contar as linhas de `types`.<br>2. Para cada corpo, enviar POST /api/pettypes.<br>3. Verificar cada resposta e contar de novo. |
| **Resultado esperado** | Status 400 em todos e mesma contagem. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita NULL e `''`. |

#### CT-API-PET-TYPES-03 — Nome do tipo no limite de 80 caracteres

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que o limite do contrato vale e que o nome aceito é gravado inteiro. |
| **Dados de teste** | name com 80 e com 81 caracteres. |
| **Passos** | 1. Para cada tamanho, enviar POST /api/pettypes.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 80: status 2xx e nome gravado com 80 caracteres.<br>81: status 400 e nenhum tipo novo. |
| **Status** | Não executado |

#### CT-API-PET-TYPES-04 — Tipo com nome já existente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Criação |
| **Tipo de teste** | Funcional – negativo (regra de negócio) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que não há dois tipos com o mesmo nome. |
| **Pré-condições** | Tipo com nome único criado via API. |
| **Dados de teste** | O mesmo nome do tipo criado. |
| **Passos** | 1. Enviar POST /api/pettypes com o nome repetido.<br>2. Verificar a resposta.<br>3. Contar no banco os tipos com esse nome. |
| **Resultado esperado** | Status 4xx (409) e um tipo com esse nome. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita dois `cat`; o índice `types_name_idx` não é UNIQUE.<br>Regra a confirmar. |

#### CT-API-PET-TYPES-05 — Tipo com o mesmo nome em maiúsculas diferentes

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Criação |
| **Tipo de teste** | Funcional – negativo (regra de negócio) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que `gato` e `Gato` não viram dois tipos. |
| **Pré-condições** | Tipo com nome único em minúsculas criado via API. |
| **Dados de teste** | O mesmo nome com a primeira letra maiúscula. |
| **Passos** | 1. Enviar POST /api/pettypes com o nome em outra caixa.<br>2. Verificar a resposta.<br>3. Contar no banco os tipos com esse nome, sem diferenciar maiúsculas. |
| **Resultado esperado** | Status 4xx (409) e um tipo. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita `Cat` ao lado de `cat`.<br>Regra a confirmar. |

#### CT-API-PET-TYPES-06 — Atualizar nome do tipo

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Atualização |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que a atualização grava o novo nome na mesma linha. |
| **Pré-condições** | Tipo criado via API. |
| **Dados de teste** | Novo nome único. |
| **Passos** | 1. Enviar PUT /api/pettypes/{id} com o novo nome.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx e a linha com o mesmo id tem o novo nome. |
| **Status** | Não executado |

#### CT-API-PET-TYPES-07 — Apagar tipo sem pets

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Exclusão |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que a exclusão remove o tipo. |
| **Pré-condições** | Tipo sem pets criado via API. |
| **Dados de teste** | Id do tipo. |
| **Passos** | 1. Enviar DELETE /api/pettypes/{id}.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx e nenhuma linha de `types` com esse id. |
| **Status** | Não executado |

#### CT-API-PET-TYPES-08 — Apagar tipo em uso

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Tipos de pet › Exclusão |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API não apaga um tipo que algum pet usa. |
| **Pré-condições** | Tipo, dono e pet desse tipo criados via API. |
| **Dados de teste** | Id do tipo. |
| **Passos** | 1. Enviar DELETE /api/pettypes/{id}.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 4xx (409); o tipo e o pet continuam no banco, com o mesmo type_id. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `pets_type_id_fkey` recusa no banco. Um 500 indica que a regra ficou só no banco. |

### tests/api/test_specialties.py

**Notas gerais**

- Tabela `specialties`. Contrato: `name` com 1 a 80 caracteres. No banco, `name` aceita NULL e não tem regra UNIQUE.

#### CT-API-SPECIALTIES-01 — Criar especialidade com nome válido

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a especialidade é gravada com o nome enviado. |
| **Dados de teste** | name com sufixo único. |
| **Passos** | 1. Enviar POST /api/specialties.<br>2. Verificar a resposta.<br>3. Buscar no banco a linha de `specialties` com o id devolvido. |
| **Resultado esperado** | Passo 2: status 2xx de criação.<br>Passo 3: name igual ao enviado. |
| **Status** | Não executado |
| **Observações** | O contrato declara só 200 para o POST; o status exato fica a confirmar na execução. |

#### CT-API-SPECIALTIES-02 — Especialidade sem nome, vazia ou só com espaços

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa especialidade sem nome. |
| **Dados de teste** | Corpo sem name, name = null, `''` e `'   '`. |
| **Passos** | 1. Contar as linhas de `specialties`.<br>2. Para cada corpo, enviar POST /api/specialties.<br>3. Verificar cada resposta e contar de novo. |
| **Resultado esperado** | Status 400 em todos e mesma contagem. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita NULL e `''`. |

#### CT-API-SPECIALTIES-03 — Nome da especialidade no limite de 80 caracteres

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que o limite do contrato vale e que o nome aceito é gravado inteiro. |
| **Dados de teste** | name com 80 e com 81 caracteres. |
| **Passos** | 1. Para cada tamanho, enviar POST /api/specialties.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 80: status 2xx e nome gravado com 80 caracteres.<br>81: status 400 e nenhuma especialidade nova. |
| **Status** | Não executado |

#### CT-API-SPECIALTIES-04 — Especialidade com nome já existente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Criação |
| **Tipo de teste** | Funcional – negativo (regra de negócio) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que não há duas especialidades com o mesmo nome. |
| **Pré-condições** | Especialidade com nome único criada via API. |
| **Dados de teste** | O mesmo nome. |
| **Passos** | 1. Enviar POST /api/specialties com o nome repetido.<br>2. Verificar a resposta.<br>3. Contar no banco as especialidades com esse nome. |
| **Resultado esperado** | Status 4xx (409) e uma especialidade com esse nome. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita duas `surgery`.<br>Regra a confirmar. |

#### CT-API-SPECIALTIES-05 — Especialidade com o mesmo nome em maiúsculas diferentes

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Criação |
| **Tipo de teste** | Funcional – negativo (regra de negócio) |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que `cirurgia` e `Cirurgia` não viram duas especialidades. |
| **Pré-condições** | Especialidade com nome único em minúsculas criada via API. |
| **Dados de teste** | O mesmo nome com a primeira letra maiúscula. |
| **Passos** | 1. Enviar POST /api/specialties com o nome em outra caixa.<br>2. Verificar a resposta.<br>3. Contar no banco as especialidades com esse nome, sem diferenciar maiúsculas. |
| **Resultado esperado** | Status 4xx (409) e uma especialidade. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita `Surgery` ao lado de `surgery`.<br>Regra a confirmar. |

#### CT-API-SPECIALTIES-06 — Atualizar nome da especialidade

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Atualização |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que a atualização grava o novo nome na mesma linha. |
| **Pré-condições** | Especialidade criada via API. |
| **Dados de teste** | Novo nome único. |
| **Passos** | 1. Enviar PUT /api/specialties/{id} com o novo nome.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx e a linha com o mesmo id tem o novo nome. |
| **Status** | Não executado |

#### CT-API-SPECIALTIES-07 — Apagar especialidade sem veterinários

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Exclusão |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que a exclusão remove a especialidade. |
| **Pré-condições** | Especialidade sem veterinários criada via API. |
| **Dados de teste** | Id da especialidade. |
| **Passos** | 1. Enviar DELETE /api/specialties/{id}.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx e nenhuma linha de `specialties` com esse id. |
| **Status** | Não executado |

#### CT-API-SPECIALTIES-08 — Apagar especialidade em uso

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Especialidades › Exclusão |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API não apaga uma especialidade ligada a um veterinário e não deixa remoção pela metade. |
| **Pré-condições** | Especialidade e veterinário com essa especialidade, criados via API. |
| **Dados de teste** | Id da especialidade. |
| **Passos** | 1. Enviar DELETE /api/specialties/{id}.<br>2. Verificar a resposta.<br>3. Conferir no banco a especialidade e a ligação em `vet_specialties`. |
| **Resultado esperado** | Passo 2: status 4xx (409).<br>Passo 3: a especialidade e a ligação continuam no banco. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `vet_specialties_specialty_id_fkey` recusa no banco.<br>Regra a confirmar: a alternativa é remover a ligação junto. Em qualquer regra, nunca 500 e nunca remoção parcial. |

### tests/api/test_vets.py

**Notas gerais**

- Tabelas `vets` e `vet_specialties`. A tabela de ligação não tem endpoint próprio: é gravada pela lista `specialties` do veterinário (POST e PUT /api/vets).
- Contrato: `firstName` e `lastName` com 1 a 30 letras (até 3 palavras, separadas por espaço, `'` ou `-`). No banco, as duas colunas aceitam NULL.
- As especialidades usadas são criadas pelo próprio teste.

#### CT-API-VETS-01 — Criar veterinário com especialidades

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que o veterinário e as ligações com as especialidades são gravados. |
| **Pré-condições** | Duas especialidades criadas via API. |
| **Dados de teste** | Vet padrão: firstName, lastName e as duas especialidades. |
| **Passos** | 1. Enviar POST /api/vets.<br>2. Verificar a resposta.<br>3. Buscar no banco a linha de `vets` e as linhas de `vet_specialties` com o id devolvido. |
| **Resultado esperado** | Passo 2: status 2xx de criação.<br>Passo 3: first_name e last_name iguais aos enviados; exatamente duas ligações, com os ids das duas especialidades. |
| **Status** | Não executado |
| **Observações** | Teardown: vet (com as ligações), depois as especialidades; cada remoção aceita "já removido". |

#### CT-API-VETS-02 — Criar veterinário sem nome ou sobrenome

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa veterinário sem nome ou sobrenome. |
| **Dados de teste** | Vet padrão sem especialidades, omitindo um campo por vez (firstName, lastName) e com cada um como `''`. |
| **Passos** | 1. Contar as linhas de `vets`.<br>2. Para cada variação, enviar POST /api/vets.<br>3. Verificar cada resposta e contar de novo. |
| **Resultado esperado** | Status 400 em todos e mesma contagem. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita veterinário com nome e sobrenome NULL. |

#### CT-API-VETS-03 — Nome do veterinário fora do padrão ou do limite

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que o padrão e o limite de 30 letras do contrato valem. |
| **Dados de teste** | firstName com 30 letras (válido), com 31 letras, com dígitos (`'Ana2'`) e só com espaços. |
| **Passos** | 1. Para cada nome, enviar POST /api/vets.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 30 letras: status 2xx e nome gravado com 30 caracteres.<br>Demais: status 400 e nenhum vet novo. |
| **Status** | Não executado |

#### CT-API-VETS-04 — Veterinário com o mesmo nome de outro (homônimo)

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Criação |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que dois veterinários homônimos ficam como registros separados, sem um sobrescrever o outro. |
| **Pré-condições** | Vet com nome e sobrenome únicos criado via API. |
| **Dados de teste** | O mesmo nome e sobrenome. |
| **Passos** | 1. Enviar POST /api/vets com o mesmo nome e sobrenome.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx; duas linhas com esse nome, com ids diferentes; a primeira sem alteração. |
| **Status** | Não executado |
| **Observações** | Exceção à regra geral de recusa: pessoas diferentes podem ter o mesmo nome.<br>Dicionário: o banco aceita (sem UNIQUE).<br>Regra a confirmar. |

#### CT-API-VETS-05 — Criar veterinário com especialidade repetida na lista

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Especialidades |
| **Tipo de teste** | Robustez – entrada inválida |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a regra UNIQUE de `vet_specialties` não vira erro 500 nem gravação parcial. |
| **Pré-condições** | Especialidade criada via API. |
| **Dados de teste** | Vet padrão com a mesma especialidade duas vezes na lista. |
| **Passos** | 1. Enviar POST /api/vets.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400; nenhum vet novo e nenhuma ligação nova. |
| **Status** | Não executado |
| **Observações** | Dicionário: a regra `vet_specialties_vet_id_specialty_id_key` recusa a ligação repetida no banco.<br>Regra a confirmar: a alternativa é gravar uma ligação só. Em qualquer regra, nunca 500. |

#### CT-API-VETS-06 — Criar veterinário com especialidade inexistente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Especialidades |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API não grava vet nem ligação quando uma especialidade não existe. |
| **Dados de teste** | Vet padrão com specialty id inexistente: maior id de `specialties` + 1, lido do banco na hora. |
| **Passos** | 1. Contar as linhas de `vets` e `vet_specialties`.<br>2. Enviar POST /api/vets.<br>3. Verificar a resposta e contar de novo. |
| **Resultado esperado** | Status 4xx (400 ou 404) e mesmas contagens. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `vet_specialties_specialty_id_fkey` recusa no banco. Vet gravado sem a ligação seria gravação parcial. |

#### CT-API-VETS-07 — Trocar as especialidades do veterinário

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Atualização |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a atualização deixa em `vet_specialties` exatamente o novo conjunto, sem sobras nem repetição. |
| **Pré-condições** | Três especialidades (A, B, C) e um vet com A e B, criados via API. |
| **Dados de teste** | Nova lista: B e C. |
| **Passos** | 1. Enviar PUT /api/vets/{id} com a nova lista.<br>2. Verificar a resposta.<br>3. Buscar no banco as ligações do vet. |
| **Resultado esperado** | Status 2xx e exatamente duas ligações: B e C. |
| **Status** | Não executado |

#### CT-API-VETS-08 — Atualizar nome do veterinário

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Atualização |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que a atualização grava o novo nome na mesma linha e mantém as especialidades enviadas. |
| **Pré-condições** | Especialidade e vet com ela, criados via API. |
| **Dados de teste** | Novo nome e sobrenome, mesma especialidade. |
| **Passos** | 1. Enviar PUT /api/vets/{id}.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx; a linha com o mesmo id tem o novo nome; a ligação continua. |
| **Status** | Não executado |

#### CT-API-VETS-09 — Apagar veterinário sem especialidade

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Exclusão |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a exclusão remove o veterinário. |
| **Pré-condições** | Vet sem especialidades criado via API. |
| **Dados de teste** | Id do vet. |
| **Passos** | 1. Enviar DELETE /api/vets/{id}.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 2xx e nenhuma linha de `vets` com esse id. |
| **Status** | Não executado |

#### CT-API-VETS-10 — Apagar veterinário com especialidade

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Exclusão |
| **Tipo de teste** | Funcional – regra de negócio |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a exclusão de um vet com especialidade não vira 500 nem deixa ligação órfã. |
| **Pré-condições** | Especialidade e vet com ela, criados via API. |
| **Dados de teste** | Id do vet. |
| **Passos** | 1. Enviar DELETE /api/vets/{id}.<br>2. Verificar a resposta.<br>3. Conferir no banco o vet, a ligação e a especialidade. |
| **Resultado esperado** | Passo 2: status 4xx (409).<br>Passo 3: vet, ligação e especialidade continuam no banco. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `vet_specialties_vet_id_fkey` recusa no banco.<br>Regra a confirmar: a alternativa é apagar o vet e as ligações juntos, mantendo a especialidade. Em qualquer regra, nunca 500 e nunca remoção parcial. |

#### CT-API-VETS-11 — Consultar veterinário inexistente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Veterinários › Consulta |
| **Tipo de teste** | Funcional – recurso inexistente |
| **Prioridade** | Baixa |
| **Objetivo** | Garantir que um id que não existe responde 404. |
| **Dados de teste** | Id inexistente: maior id de `vets` + 1, lido do banco na hora. |
| **Passos** | 1. Enviar GET /api/vets/{id inexistente}.<br>2. Verificar a resposta. |
| **Resultado esperado** | Status 404. |
| **Status** | Não executado |

### tests/api/test_users.py

**Notas gerais**

- Tabelas `users` e `roles`, pelo POST /api/users (o usuário vem com a lista de papéis).
- O contrato diverge do banco: `username` e o nome do papel aceitam até 80 caracteres no contrato, mas o banco tem `varchar(20)`; `password` não é obrigatório no contrato, mas é NOT NULL no banco.
- Papéis que a API conhece: `ROLE_OWNER_ADMIN`, `ROLE_VET_ADMIN`, `ROLE_ADMIN`.
- A API não tem DELETE /api/users: a limpeza apaga papéis e usuário direto no banco, no teardown, aceitando "já removido".

#### CT-API-USERS-01 — Criar usuário com papel válido

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Criação |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que o usuário é gravado com a senha em hash, ativo, e com os papéis enviados. |
| **Dados de teste** | Usuário padrão: username único com até 20 caracteres, senha, papel `ROLE_OWNER_ADMIN`. |
| **Passos** | 1. Enviar POST /api/users.<br>2. Verificar a resposta.<br>3. Buscar no banco a linha de `users` e as linhas de `roles` desse username. |
| **Resultado esperado** | Passo 2: status 2xx de criação.<br>Passo 3: password diferente da senha enviada, no formato bcrypt (começa com `$2a$` ou `$2b$` e tem 60 caracteres); enabled = true; uma linha em `roles` com `ROLE_OWNER_ADMIN`. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita senha em texto puro; o hash é responsabilidade da API. |

#### CT-API-USERS-02 — Criar usuário sem username ou com username vazio

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a API recusa usuário sem nome de login. |
| **Dados de teste** | Usuário padrão sem username, com `''` e com `'   '`. |
| **Passos** | 1. Contar as linhas de `users`.<br>2. Para cada variação, enviar POST /api/users.<br>3. Verificar cada resposta e contar de novo. |
| **Resultado esperado** | Status 400 em todos e mesma contagem. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita username `''`. |

#### CT-API-USERS-03 — Username no limite de 20 caracteres

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Criação |
| **Tipo de teste** | Funcional – validação (valor-limite) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que o limite real (20 do banco) é validado pela API e não vira erro 500. |
| **Dados de teste** | username único com 20 e com 21 caracteres. |
| **Passos** | 1. Para cada tamanho, enviar POST /api/users.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | 20: status 2xx e username gravado com 20 caracteres.<br>21: status 400 e nenhum usuário novo. |
| **Status** | Não executado |
| **Observações** | O contrato aceita até 80 e o banco recusa acima de 20 (`varchar(20)`): de 21 a 80, o erro tende a chegar ao banco. |

#### CT-API-USERS-04 — Criar usuário sem senha

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Criação |
| **Tipo de teste** | Funcional – negativo (validação) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que a API recusa usuário sem senha como erro do cliente. |
| **Dados de teste** | Usuário padrão sem password e com password `''`. |
| **Passos** | 1. Para cada variação, enviar POST /api/users.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400 e nenhum usuário novo. |
| **Status** | Não executado |
| **Observações** | O contrato não exige password, mas o banco tem NOT NULL. Senha `''` viraria um hash válido de senha vazia. |

#### CT-API-USERS-05 — Criar usuário com username já cadastrado

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Criação |
| **Tipo de teste** | Funcional – negativo (regra de negócio) |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que não há usuário duplicado e que a senha e os papéis do original não são sobrescritos. |
| **Pré-condições** | Usuário padrão criado via API. |
| **Dados de teste** | O mesmo username, outra senha e outro papel. |
| **Passos** | 1. Guardar o hash da senha e os papéis do usuário original, lidos do banco.<br>2. Enviar POST /api/users com o username repetido.<br>3. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 4xx (409); uma linha com esse username, com o mesmo hash e os mesmos papéis do passo 1. |
| **Status** | Não executado |
| **Observações** | Dicionário: a chave `pk_users` recusa no banco. Um 500 indica que a regra ficou só no banco. |

#### CT-API-USERS-06 — Username com maiúsculas diferentes de um existente

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Criação |
| **Tipo de teste** | Segurança – personificação de usuário |
| **Prioridade** | Média |
| **Objetivo** | Garantir que não dá para criar `Fulano` ao lado de `fulano`. |
| **Pré-condições** | Usuário padrão com username em minúsculas criado via API. |
| **Dados de teste** | O mesmo username com a primeira letra maiúscula. |
| **Passos** | 1. Enviar POST /api/users com o username em outra caixa.<br>2. Verificar a resposta.<br>3. Contar no banco os usuários com esse username, sem diferenciar maiúsculas. |
| **Resultado esperado** | Status 4xx (409) e um usuário. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita `Admin` ao lado de `admin`.<br>Regra a confirmar. |

#### CT-API-USERS-07 — Criar usuário com papel desconhecido

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Papéis |
| **Tipo de teste** | Segurança – autorização |
| **Prioridade** | Alta |
| **Objetivo** | Garantir que só os papéis que a API conhece são aceitos e que a recusa não grava nem o usuário. |
| **Dados de teste** | Usuário padrão com papel: `'qualquer coisa'`, `'role_admin'` (minúsculas), `'ROLE_ADMIN_'` e um texto de 21 caracteres. |
| **Passos** | 1. Para cada papel, enviar POST /api/users com username único.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400 em todos; nenhum usuário novo e nenhum papel novo. |
| **Status** | Não executado |
| **Observações** | Dicionário: o banco aceita qualquer texto de até 20 caracteres e diferencia maiúsculas. O de 21 caracteres passa no contrato (80) e é recusado pelo banco.<br>Usuário gravado sem o papel seria gravação parcial. |

#### CT-API-USERS-08 — Papel repetido na mesma requisição

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Papéis |
| **Tipo de teste** | Robustez – entrada inválida |
| **Prioridade** | Média |
| **Objetivo** | Garantir que a regra UNIQUE de `roles` não vira erro 500 nem gravação parcial. |
| **Dados de teste** | Usuário padrão com `ROLE_ADMIN` duas vezes na lista. |
| **Passos** | 1. Enviar POST /api/users.<br>2. Verificar a resposta e o banco. |
| **Resultado esperado** | Status 400; nenhum usuário novo e nenhum papel novo. |
| **Status** | Não executado |
| **Observações** | Dicionário: a regra `uni_username_role` recusa no banco.<br>Regra a confirmar: a alternativa é gravar um papel só. Em qualquer regra, nunca 500. |

#### CT-API-USERS-09 — Criar usuário com vários papéis

| Campo | Descrição |
|---|---|
| **Módulo / Área** | API › Usuários › Papéis |
| **Tipo de teste** | Funcional – positivo |
| **Prioridade** | Média |
| **Objetivo** | Garantir que cada papel enviado vira uma linha em `roles`, ligada ao username. |
| **Dados de teste** | Usuário padrão com `ROLE_OWNER_ADMIN` e `ROLE_VET_ADMIN`. |
| **Passos** | 1. Enviar POST /api/users.<br>2. Verificar a resposta.<br>3. Buscar no banco os papéis desse username. |
| **Resultado esperado** | Status 2xx e exatamente duas linhas em `roles`: `ROLE_OWNER_ADMIN` e `ROLE_VET_ADMIN`. |
| **Status** | Não executado |

## Bugs conhecidos

### tests/api/known_bugs/test_http_status.py

#### CT-BUGS-HTTP-STATUS-01 — [BUG-01] Id de dono não numérico responde 400

| Campo | Descrição |
|---|---|
| **Módulo / Área** | Bugs conhecidos › API › Status HTTP |
| **Tipo de teste** | Contrato – status HTTP |
| **Prioridade** | Média |
| **Bug relacionado** | BUG-01 |
| **Objetivo** | Garantir que um id não numérico é tratado como erro do cliente, sem expor detalhes internos. |
| **Dados de teste** | ownerId = `abc`. |
| **Passos** | 1. Enviar GET /api/owners/abc.<br>2. Verificar o status e o corpo. |
| **Resultado esperado** | Status 400 (listado no contrato do endpoint), sem o nome de exceção Java no corpo. |
| **Resultado obtido** | Status 500, com `"title": "MethodArgumentTypeMismatchException"` no corpo (README, achados). |
| **Status** | Não executado |
| **Observações** | Reproduzido à mão; o teste ainda não existe. O erro acontece antes de qualquer consulta, então o banco não muda. |

### tests/api/known_bugs/test_schema_indexes.py

#### CT-BUGS-SCHEMA-INDEXES-01 — [BUG-02] Reiniciar a API não duplica os índices do banco

| Campo | Descrição |
|---|---|
| **Módulo / Área** | Bugs conhecidos › Banco › Índices |
| **Tipo de teste** | Funcional – efeito no servidor |
| **Prioridade** | Baixa |
| **Bug relacionado** | BUG-02 |
| **Objetivo** | Garantir que o script de inicialização da API é idempotente também para os índices. |
| **Pré-condições** | Ambiente recém-criado (`docker compose down -v` e `up -d --wait`). |
| **Dados de teste** | Nenhum. |
| **Passos** | 1. Rodar a consulta de índices duplicados (`sql/11_duplicate_indexes.sql`).<br>2. Reiniciar o serviço da API e esperar o healthcheck ficar saudável.<br>3. Rodar a consulta de novo. |
| **Resultado esperado** | Passos 1 e 3: nenhuma linha (nenhum índice duplicado). |
| **Resultado obtido** | Passo 1: nenhuma linha. Passo 3: 7 índices com 2 cópias em 6 tabelas (`owners`, `pets` ×2, `visits`, `types`, `vets`, `specialties`); cada novo reinício soma mais uma cópia (README, achados). |
| **Status** | Não executado |
| **Observações** | Reproduzido à mão em 2026-11-13; o teste ainda não existe. Chaves primárias e regras `UNIQUE` não duplicam. Um teste só de API não pega esse defeito. |
