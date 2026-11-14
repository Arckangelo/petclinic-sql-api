-- Pergunta: há usuários com senha que não parece hash bcrypt ($2a$/$2b$/$2y$, 60 caracteres)?
-- O banco aceita senha em texto puro.
SELECT username, length(password) AS tamanho, left(password, 4) AS prefixo
FROM users
WHERE length(password) <> 60
   OR password !~ '^\$2[aby]\$'
ORDER BY username;
