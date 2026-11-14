-- Pergunta: há veterinários sem nenhuma especialidade?
SELECT v.id, v.first_name, v.last_name
FROM vets v
LEFT JOIN vet_specialties vs ON vs.vet_id = v.id
WHERE vs.vet_id IS NULL
ORDER BY v.id;
