-- Pergunta: há pets nascidos no futuro ou com idade improvável?
-- O tipo date só confere se a data existe. O corte de 30 anos é uma escolha, não regra da aplicação.
SELECT id, name, birth_date, age(current_date, birth_date) AS idade
FROM pets
WHERE birth_date > current_date
   OR birth_date < current_date - interval '30 years'
ORDER BY birth_date;
