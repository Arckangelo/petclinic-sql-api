-- Pergunta: há papéis fora dos três que a API conhece?
-- role é varchar(20) sem lista de valores permitidos, e diferencia maiúsculas.
SELECT id, username, role
FROM roles
WHERE role NOT IN ('ROLE_OWNER_ADMIN', 'ROLE_VET_ADMIN', 'ROLE_ADMIN')
ORDER BY id;
