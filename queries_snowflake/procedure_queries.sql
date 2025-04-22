-- 1) Cria ou substitui a procedure que faz todo o load
CREATE OR REPLACE PROCEDURE proc_load_camara_despesas()
  RETURNS STRING
  LANGUAGE JAVASCRIPT
  EXECUTE AS CALLER
AS
$$
  // === 1.1) Staging de despesas Parquet em tabela VARIANT ===
  snowflake.createStatement({
    sqlText: `
      -- Cria a tabela staging (VARIANT) limpa
      CREATE OR REPLACE TABLE raw_despesas_variant (v VARIANT);
      -- Copia todos os arquivos Parquet do stage para a tabela
      COPY INTO raw_despesas_variant
        FROM @stg_despesas_parquet
        FILE_FORMAT=(FORMAT_NAME=ff_parquet)
        ON_ERROR='CONTINUE';
    `
  }).execute();

  // === 1.2) Parsing e tipagem das colunas de despesas ===
  snowflake.createStatement({
    sqlText: `
      CREATE OR REPLACE TABLE parsed_despesas AS
      SELECT
        v:"deputado_id"::NUMBER    AS deputado_id,
        v:"codDocumento"::NUMBER   AS cod_documento,
        v:"codLote"::NUMBER        AS cod_lote,
        TO_TIMESTAMP_NTZ(v:"dataDocumento"::STRING) AS data_despesa,
        v:"tipoDespesa"::STRING    AS categoria,
        v:"tipoDocumento"::STRING  AS tipo_documento,
        v:"nomeFornecedor"::STRING AS fornecedor,
        v:"valorDocumento"::NUMBER AS valor_bruto,
        v:"valorGlosa"::NUMBER     AS valor_glosa,
        v:"valorLiquido"::NUMBER   AS valor_liquido,
        CURRENT_TIMESTAMP()        AS carga_ts
      FROM raw_despesas_variant;
    `
  }).execute();

  // === 1.3) Staging de deputados JSON em tabela final ===
  snowflake.createStatement({
    sqlText: `
      CREATE OR REPLACE TABLE raw_deputados AS
      SELECT
        doc.value:id::NUMBER           AS deputado_id,
        doc.value:nome::STRING         AS nome,
        doc.value:siglaPartido::STRING AS partido,
        doc.value:siglaUf::STRING      AS estado,
        CURRENT_TIMESTAMP()            AS carga_ts
      FROM raw_deputados_variant,
           LATERAL FLATTEN(input => v:dados) AS doc;
    `
  }).execute();

  // === 1.4) Geração da dimensão de datas ===
  snowflake.createStatement({
    sqlText: `
      CREATE OR REPLACE TABLE dim_data AS
      SELECT DISTINCT
        CAST(data_despesa::DATE AS DATE) AS full_date,
        YEAR(data_despesa)               AS ano,
        MONTH(data_despesa)              AS mes,
        DAY(data_despesa)                AS dia,
        TO_VARCHAR(data_despesa,'DY')    AS dia_semana
      FROM parsed_despesas;
    `
  }).execute();

  // === 1.5) Geração da dimensão de deputados ===
  snowflake.createStatement({
    sqlText: `
      CREATE OR REPLACE TABLE dim_deputado AS
      SELECT DISTINCT
        deputado_id,
        nome,
        partido,
        estado
      FROM raw_deputados;
    `
  }).execute();

  // === 1.6) Construção da tabela fato de despesas ===
  snowflake.createStatement({
    sqlText: `
      CREATE OR REPLACE TABLE fact_despesas AS
      SELECT
        p.cod_documento  AS documento_id,
        p.cod_lote       AS lote_id,
        p.deputado_id    AS deputado_id,
        dd.full_date     AS data,
        p.valor_bruto,
        p.valor_glosa,
        p.valor_liquido,
        p.carga_ts
      FROM parsed_despesas p
      JOIN dim_deputado d ON p.deputado_id = d.deputado_id
      JOIN dim_data dd    ON CAST(p.data_despesa::DATE AS DATE) = dd.full_date;
    `
  }).execute();

  // === 1.7) Retorna confirmação com timestamp local ===
  return 'Carga concluída em ' + new Date();
$$;


-- 2) Cria ou substitui a task para agendar execuções semanais
CREATE OR REPLACE TASK weekly_load_camara
  WAREHOUSE = COMPUTE_WH              -- warehouse que rodará o load
  SCHEDULE  = 'USING CRON 0 3 * * FRI UTC'  -- toda sexta às 03:00 UTC
  COMMENT   = 'Carga semanal de despesas de deputados'
AS
  CALL proc_load_camara_despesas();    -- chama a procedure acima

-- 3) Habilita a task
ALTER TASK weekly_load_camara RESUME;

-- 4) Verifica as tasks criadas que comecem com “WEEKLY_LOAD_”
SHOW TASKS LIKE 'WEEKLY_LOAD_%';
