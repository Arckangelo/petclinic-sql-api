-- Pergunta: há visitas duplicadas (mesmo pet, mesma data e mesma descrição)?
-- Não há regra UNIQUE em visits.
SELECT pet_id, visit_date, description, count(*) AS quantas
FROM visits
GROUP BY pet_id, visit_date, description
HAVING count(*) > 1;
