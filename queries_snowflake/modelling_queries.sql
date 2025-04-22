-- 1.1) Formato para Parquet
CREATE OR REPLACE FILE FORMAT ff_parquet
  TYPE = PARQUET;

-- 1.2) Formato para JSON (descompacta arrays externos)
CREATE OR REPLACE FILE FORMAT ff_json
  TYPE = JSON
  STRIP_OUTER_ARRAY = TRUE;

-- 2.1) Stage para arquivos Parquet de despesas
CREATE OR REPLACE STAGE stg_despesas_parquet
  URL = 's3://camara-api-dados-raw/despesas-parquet/'
  STORAGE_INTEGRATION = camara_s3_int
  FILE_FORMAT = ff_parquet
  COMMENT = 'Stage de Parquets de despesas';

-- 2.2) Stage para JSON de deputados
CREATE OR REPLACE STAGE stg_deputados_json
  URL = 's3://camara-api-dados-raw/deputados/'
  STORAGE_INTEGRATION = camara_s3_int
  FILE_FORMAT = ff_json
  COMMENT = 'JSONs de deputados';

-- 3.1) Tabela staging para Parquet de despesas
CREATE OR REPLACE TABLE raw_despesas_variant (v VARIANT);

COPY INTO raw_despesas_variant
  FROM @stg_despesas_parquet
  FILE_FORMAT = (FORMAT_NAME = ff_parquet)
  ON_ERROR = 'CONTINUE';

-- 3.2) Tabela staging para JSON de deputados
CREATE OR REPLACE TABLE raw_deputados_variant (v VARIANT);

COPY INTO raw_deputados_variant
  FROM @stg_deputados_json
  FILE_FORMAT = (FORMAT_NAME = ff_json)
  ON_ERROR = 'CONTINUE';

-- 4) Extrair e tipar colunas de despesas

CREATE OR REPLACE TABLE parsed_despesas AS
SELECT
  v:"deputado_id"    ::NUMBER   AS deputado_id,
  v:"codDocumento"   ::NUMBER   AS cod_documento,
  v:"codLote"        ::NUMBER   AS cod_lote,
  TO_TIMESTAMP_NTZ(v:"dataDocumento"::STRING) AS data_despesa,
  v:"tipoDespesa"    ::STRING   AS categoria,
  v:"tipoDocumento"  ::STRING   AS tipo_documento,
  v:"nomeFornecedor" ::STRING   AS fornecedor,
  v:"valorDocumento" ::NUMBER   AS valor_bruto,
  v:"valorGlosa"     ::NUMBER   AS valor_glosa,
  v:"valorLiquido"   ::NUMBER   AS valor_liquido,
  CURRENT_TIMESTAMP()            AS carga_ts
FROM raw_despesas_variant;

-- 5) Extrair e explodir JSON de deputados

CREATE OR REPLACE TABLE raw_deputados AS
SELECT
  doc.value:id::NUMBER           AS deputado_id,
  doc.value:nome::STRING         AS nome,
  doc.value:siglaPartido::STRING AS partido,
  doc.value:siglaUf::STRING      AS estado,
  CURRENT_TIMESTAMP()            AS carga_ts
FROM raw_deputados_variant,
     LATERAL FLATTEN(input => v:dados) AS doc;
