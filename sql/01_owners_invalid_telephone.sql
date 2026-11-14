-- Pergunta: há donos com telefone fora do formato de 10 dígitos (com letras, vazio, curto)?
-- O banco só garante o tamanho máximo (varchar(10)); o formato fica por conta da API.
SELECT id, first_name, last_name, telephone
FROM owners
WHERE telephone !~ '^[0-9]{10}$'
ORDER BY id;
