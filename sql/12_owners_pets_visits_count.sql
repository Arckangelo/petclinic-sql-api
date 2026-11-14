-- Pergunta: quantos pets e quantas visitas tem cada dono?
-- LEFT JOIN para incluir donos sem pets e pets sem visitas.
SELECT o.id, o.first_name, o.last_name,
       count(DISTINCT p.id) AS pets,
       count(v.id) AS visitas
FROM owners o
LEFT JOIN pets p ON p.owner_id = o.id
LEFT JOIN visits v ON v.pet_id = p.id
GROUP BY o.id, o.first_name, o.last_name
ORDER BY o.id;
