import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    explode, col, year, month, to_timestamp,
    input_file_name, regexp_extract
)
from awsglue.utils import getResolvedOptions

# 1) Setup Glue/Spark contexts
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# 2) Leitura recursiva de todos os JSONs (multiLine)
input_path = "s3://camara-api-dados-raw/despesas/"
raw_df = (
    spark.read
         .option("multiLine", True)
         .option("recursiveFileLookup", True)
         .json(input_path)
)

# DEBUG: confirme que a coluna `dados` existe
raw_df.printSchema()
raw_df.show(5, False)

# 3) Explode a coluna `dados` e captura o filepath
df = (
    raw_df
    .select(explode(col("dados")).alias("despesa"))
    .select("despesa.*")
    .withColumn("filepath", input_file_name())
)

# 4) Extrai o deputado_id do nome do arquivo (deputado-<id>.json)
df = df.withColumn(
    "deputado_id",
    regexp_extract(col("filepath"), r"deputado-(\d+)(?:\.json)?$", 1).cast("int")
).drop("filepath")

# 5) Parse de data e extração de ano/mês
df = (
    df
    .withColumn(
        "dataDocumento",
        to_timestamp(col("dataDocumento"), "yyyy-MM-dd'T'HH:mm:ss")
    )
    .withColumn("ano", year(col("dataDocumento")))
    .withColumn("mes", month(col("dataDocumento")))
)

# 6) Escrita idempotente em Parquet, particionada
output_path = "s3://camara-api-dados-raw/despesas-parquet/"
(
    df.write
      .mode("overwrite")
      .partitionBy("ano", "mes")
      .parquet(output_path)
)

job.commit()
