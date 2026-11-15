-- Limpeza automática das cópias de índice criadas pelo BUG-02.
-- Roda pelo serviço db-index-cleanup do docker-compose.yml, toda vez que o ambiente sobe com `docker compose up`.
-- Não corrige o bug: a API continua criando as cópias a cada início; este script só apaga as que sobraram.
--
-- TODO: consulta (escrita pela pessoa, regra 1 do CLAUDE.md)
-- Pergunta: para cada grupo de índices duplicados (o mesmo agrupamento de sql/11_duplicate_indexes.sql),
-- como apagar todas as cópias e manter só o índice original (o de nome sem número no fim, ex.: owners_last_name_idx)?
-- Requisitos:
--   - nunca apagar chave primária nem índice de regra UNIQUE;
--   - rodar de novo sem cópias não pode dar erro (idempotente);
--   - depois de rodar, sql/11_duplicate_indexes.sql volta sem linhas.

DO $$
DECLARE
  r record;
  total int := 0;
BEGIN
  FOR r IN
    SELECT i.indexrelid::regclass AS indice
    FROM pg_index i
    JOIN pg_class c     ON c.oid = i.indexrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND NOT i.indisprimary
      AND NOT i.indisunique
      AND NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = i.indexrelid)
      AND EXISTS (
        SELECT 1
        FROM pg_index o
        WHERE o.indrelid     = i.indrelid
          AND o.indexrelid   < i.indexrelid
          AND o.indkey       = i.indkey
          AND o.indclass     = i.indclass
          AND o.indcollation = i.indcollation
          AND o.indoption    = i.indoption
          AND o.indisunique  = i.indisunique
          AND COALESCE(pg_get_expr(o.indexprs, o.indrelid), '') = COALESCE(pg_get_expr(i.indexprs, i.indrelid), '')
          AND COALESCE(pg_get_expr(o.indpred,  o.indrelid), '') = COALESCE(pg_get_expr(i.indpred,  i.indrelid), '')
      )
  LOOP
    RAISE NOTICE 'Removendo índice duplicado: %', r.indice;
    EXECUTE format('DROP INDEX IF EXISTS %s', r.indice);
    total := total + 1;
  END LOOP;
  RAISE NOTICE 'Limpeza concluída: % índice(s) duplicado(s) removido(s).', total;
END $$;
