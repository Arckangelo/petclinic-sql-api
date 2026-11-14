-- Pergunta: há donos sem nome ou sobrenome, ou com nome só de espaços?
-- first_name e last_name aceitam NULL no banco.
SELECT id, first_name, last_name
FROM owners
WHERE first_name IS NULL OR btrim(first_name) = ''
   OR last_name IS NULL OR btrim(last_name) = ''
ORDER BY id;
