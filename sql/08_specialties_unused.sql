-- Pergunta: há especialidades que nenhum veterinário usa?
SELECT s.id, s.name
FROM specialties s
LEFT JOIN vet_specialties vs ON vs.specialty_id = s.id
WHERE vs.specialty_id IS NULL
ORDER BY s.id;
