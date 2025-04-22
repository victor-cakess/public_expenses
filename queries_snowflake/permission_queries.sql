-- 1) CRIAÇÃO DA STORAGE INTEGRATION
-- Permite que o Snowflake acesse o bucket S3 via IAM Role

CREATE OR REPLACE STORAGE INTEGRATION camara_s3_int
  TYPE = EXTERNAL_STAGE                     -- tipo para stages externos
  STORAGE_PROVIDER = S3                     -- provedor S3
  ENABLED = TRUE                            -- ativa imediatamente
  STORAGE_AWS_ROLE_ARN =                     -- ARN da role com acesso ao bucket
    'arn:aws:iam::xxxxxxxxxx:role/snowflake_s3_access'
  STORAGE_ALLOWED_LOCATIONS = (             -- define quais paths são acessíveis
    's3://camara-api-dados-raw/despesas-parquet/',
    's3://camara-api-dados-raw/deputados/'
  )
  COMMENT = 'Integração S3 → Snowflake';    -- descrição para referência

-- Por que cada parâmetro?
-- • TYPE/PROVIDER: diz que é um stage externo no S3.
-- • ROLE_ARN: role do IAM que concede leitura no bucket.
-- • ALLOWED_LOCATIONS: restringe acesso apenas às pastas listadas.

--------------------------------------------------------------------------------

-- 2) CONCEDER USAGE NA INTEGRAÇÃO
-- Permite que o role especificado utilize a integração

GRANT USAGE
  ON INTEGRATION camara_s3_int
  TO ROLE SYSADMIN;   -- substitua por outro role se necessário

--------------------------------------------------------------------------------

-- 3) CONCEDER PRIVILÉGIOS NO SCHEMA
-- Garante que o role possa criar objetos no schema CAMARA_DB.DESPESAS

GRANT USAGE
  ON SCHEMA CAMARA_DB.DESPESAS
  TO ROLE SYSADMIN;

GRANT CREATE TABLE
  ON SCHEMA CAMARA_DB.DESPESAS
  TO ROLE SYSADMIN;

GRANT CREATE FILE FORMAT
  ON SCHEMA CAMARA_DB.DESPESAS
  TO ROLE SYSADMIN;

GRANT CREATE STAGE
  ON SCHEMA CAMARA_DB.DESPESAS
  TO ROLE SYSADMIN;

-- Por que?
-- • USAGE no schema: permite referenciar o schema.
-- • CREATE TABLE/FILE FORMAT/STAGE: autoriza criação dos objetos usados na pipeline.

--------------------------------------------------------------------------------

-- 4) ATUALIZAR LOCAIS PERMITIDOS
-- Adiciona novas pastas do bucket que a integração pode acessar

ALTER STORAGE INTEGRATION camara_s3_int
  SET STORAGE_ALLOWED_LOCATIONS = (
    's3://camara-api-dados-raw/despesas-parquet/',
    's3://camara-api-dados-raw/deputados/',
    's3://camara-api-dados-raw/proposicoes/',
    's3://camara-api-dados-raw/votacoes/'
  );

-- Isso expande o escopo para staging de propostas e votações.
