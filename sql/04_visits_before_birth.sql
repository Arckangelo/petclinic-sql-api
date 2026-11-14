-- Pergunta: há visitas com data anterior ao nascimento do pet?
-- O banco não compara visits.visit_date com pets.birth_date.
SELECT v.id AS visit_id, p.id AS pet_id, p.name, p.birth_date, v.visit_date
FROM visits v
JOIN pets p ON p.id = v.pet_id
WHERE v.visit_date < p.birth_date
ORDER BY v.id;
