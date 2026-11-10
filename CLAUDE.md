# Regras para agentes de IA neste projeto

Testes de API com validação no banco de dados para o Spring PetClinic REST
(https://github.com/spring-petclinic/spring-petclinic-rest), rodando localmente em Docker Compose com
PostgreSQL. O banco é o oráculo: o teste chama a API e confere o efeito direto no banco.

Estrutura: `sql/` (consultas exploratórias de integridade), `docs/` (dicionário de dados), `postman/`
(coleção e environment do Newman), `tests/api` (pytest com banco como oráculo), `tests/contract`
(validação contra o OpenAPI da aplicação), `tests/bdd` (Gherkin e pytest-bdd), `k6/` (carga leve),
`.github/workflows/` (CI). Detalhes e decisões em `README.md`.

As regras estão em ordem de prioridade. **P1** nunca se quebra; **P2** vale em toda mudança; **P3** é
para quando o assunto aparecer.

## P1 · Crítico

1. **O SQL é escrito pela pessoa, não pelo agente.** Isso vale para `sql/`, para as consultas dentro dos
   testes e fixtures e para o `docs/dicionario-de-dados.md`. O agente pode explicar conceitos, apontar
   onde está o erro e por quê, e sugerir o que estudar, mas não escreve, completa nem reescreve
   consultas. Quando um teste precisar de SQL, deixe um marcador `# TODO: consulta` com a pergunta que
   ela deve responder. Motivo: a pessoa precisa explicar cada consulta ao vivo numa entrevista.
2. **Nada irreversível sem pedido explícito:** commit, push, PR, merge, issue (principalmente no
   repositório oficial do PetClinic), comentário no GitHub, mudança no board do Jira ou apagar branch
   remota só quando a pessoa pedir. Antes do commit, mostre o que mudou e o resultado dos testes.
3. **Prove antes de afirmar:** rode os testes afetados antes de dizer que algo funciona. Uma proteção
   nova (fixture de limpeza, checagem, regra de CI) só vale depois de simular a falha que ela deveria
   pegar.
4. **Nunca afrouxe uma asserção para o teste passar.** Se a API se comporta diferente do esperado,
   investigue; se for defeito da aplicação, é bug novo (regra 7).
5. **"Ambiente fora do ar" não é resultado:** API ou banco que não subiu não é aprovação nem bug.
   Corrija o ambiente e rode de novo.
6. **Só o ambiente local:** testes, Newman e k6 apontam apenas para o Docker Compose desta máquina (ou
   do CI). Nunca para um servidor de terceiros.
7. **Bug novo, antes do commit:**
   - reproduza do zero (`docker compose down -v` e `up`) para descartar dado sujo;
   - registre no README, na seção de achados, com passos, esperado, obtido e a evidência no banco;
   - deixe um teste que falha pela asserção do bug, com `[BUG-NN]` no nome;
   - Jira e issue no repositório oficial só quando a pessoa pedir; antes da issue, confira se já
     existe e reproduza na versão mais recente da imagem.

## P2 · Importante

8. **Ambiente sempre pelo `docker compose`.** Espere a API ficar pronta por healthcheck ou por laço
   com curl, nunca por `sleep` com tempo fixo.
9. **Idioma:** identificadores em inglês (variáveis, funções, fixtures, arquivos de código, variáveis
   do Postman). Em português: nomes de funções de teste, comentários, docstrings, mensagens de
   asserção, cenários Gherkin, documentação, commits e PRs.
10. **Como escrever testes:**
    - formato preparar, agir, verificar: dados preparados por SQL na fixture, uma chamada na API, e
      verificação da resposta **e** do estado do banco;
    - o valor esperado vem do que o teste enviou ou de uma consulta ao banco, nunca da própria resposta
      da API;
    - cada teste cria e apaga os próprios dados (fixture com `yield`); a limpeza aceita "já removido";
    - nenhum teste depende da ordem de execução nem de dado criado por outro teste;
    - não dependa dos dados do `populateDB.sql` além do que for necessário; quando depender, diga qual
      registro e por quê;
    - valor-limite e partição com `pytest.mark.parametrize`; a tabela de partições fica no README;
    - fixtures compartilhadas em `tests/conftest.py`; não duplique fixtures entre pastas.
11. **Rastreabilidade:** todo teste tem um ID `CT-<ÁREA>-NN` na docstring (ex.: `CT-OWNERS-03`).
    Requests do Postman levam o mesmo padrão no nome.
12. **Dependências:** versão exata em `requirements.txt` (e no `package.json`, se houver), publicada
    há pelo menos duas semanas. Instalar ou atualizar dependência só com o ok da pessoa.
13. **Commits pequenos e ao longo dos dias:** um assunto por commit, nunca uma fase inteira de uma vez.
    O histórico precisa mostrar a evolução do projeto.

## P3 · Complementar

14. **Escopo:** as fases 1 a 4 (ambiente, SQL, Postman, pytest) são o núcleo. Não adiante as fases 5 a
    8 (contrato, BDD, Jira, k6) sem a pessoa pedir.
15. **Documentação enxuta:** um README com as decisões e o porquê de cada uma. Não crie outros `.md` sem
    pedido.
16. **k6:** carga leve (poucos usuários virtuais, pouco tempo), só contra o ambiente local.
17. **Commits e PRs:** em português, explicando o porquê; o PR traz a validação feita.

## Comandos (previstos; atualize quando existirem)

```bash
docker compose up -d                 # sobe API e PostgreSQL
docker compose down -v               # derruba e apaga os dados do banco
pytest tests/api                     # testes com banco como oráculo
pytest tests/contract                # contrato OpenAPI
pytest tests/bdd                     # cenários Gherkin automatizados
npx newman run postman/petclinic.postman_collection.json -e postman/local.postman_environment.json
k6 run k6/carga-leve.js
```
