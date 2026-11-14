-- Pergunta: há tipos de pet ou especialidades sem nome ou com nome repetido
-- (inclusive com maiúsculas ou espaços diferentes)?
-- name aceita NULL e não tem regra UNIQUE nas duas tabelas.
SELECT 'types' AS tabela, string_agg(id::text, ', ' ORDER BY id) AS ids,
       min(name) AS nome, count(*) AS quantos
FROM types
GROUP BY lower(btrim(coalesce(name, '')))
HAVING count(*) > 1 OR lower(btrim(coalesce(name, ''))) = ''
UNION ALL
SELECT 'specialties', string_agg(id::text, ', ' ORDER BY id),
       min(name), count(*)
FROM specialties
GROUP BY lower(btrim(coalesce(name, '')))
HAVING count(*) > 1 OR lower(btrim(coalesce(name, ''))) = '';
