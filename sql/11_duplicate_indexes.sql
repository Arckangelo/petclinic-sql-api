-- Pergunta: há índices duplicados (mesma tabela, mesmas colunas, mesma definição)?
-- Pega o BUG-02: cada reinício da API cria mais uma cópia de 7 índices.
-- Agrupa por tabela, colunas (indkey), classes de operador (indclass), expressão e filtro parcial.
SELECT indrelid::regclass AS tabela,
       string_agg(indexrelid::regclass::text, ', ' ORDER BY indexrelid::regclass::text) AS indices,
       count(*) AS quantos
FROM pg_index
GROUP BY indrelid, indkey::text, indclass::text, coalesce(indexprs::text, ''), coalesce(indpred::text, '')
HAVING count(*) > 1;
