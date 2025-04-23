## Explicação da stack

### AWS S3  
Armazena todos os arquivos JSON brutos e Parquet convertidos.  
- **Por que usar?**  
  - Alta durabilidade e disponibilidade.  
  - Permite particionamento por ano/mês para acesso eficiente.  
  - Serve de “data lake” barato e escalável para dados brutos e transformados.

### AWS Lambda  
Funções serverless para extrair dados da API da Câmara e salvar JSON em S3.  
- **Por que usar?**  
  - Custo zero quando ocioso, escala automaticamente.  
  - Execução sob demanda e idempotente.  
  - Isola lógica de coleta por domínio (deputados vs. despesas).

### AWS Glue  
Job gerenciado Spark para converter JSON de despesas em Parquet particionado.  
- **Por que usar?**  
  - Infraestrutura serverless para ETL em grande volume.  
  - Integração nativa com S3 e catálogo de dados (Glue Data Catalog).  
  - Suporte a particionamento e otimização de leitura no Snowflake.

### AWS IAM  
Gerenciamento de permissões para recursos AWS.  
- **Por que usar?**  
  - Controle granular de quem pode ler/escrever buckets, executar Lambdas, Glue e Step Functions.  
  - Garante segurança e princípio de menor privilégio.

### AWS EventBridge  
Agendador cron para disparar o pipeline semanal.  
- **Por que usar?**  
  - Substitui CRON tradicional, é serverless e integrado ao AWS.  
  - Permite regras baseadas em eventos e filtros avançados.

### AWS Step Functions  
Orquestra fluxo de trabalho: invoca Lambdas em série e paraleliza com Map State.  
- **Por que usar?**  
  - Visualização clara do pipeline.  
  - Permite paralelismo controlado (MaxConcurrency) para chamadas de API.  
  - Gerencia falhas e retries de cada etapa.

### AWS QuickSight  
Ferramenta de BI para criar dashboards públicos conectados ao Snowflake.  
- **Por que usar?**  
  - Console simplificado para visualização embutida.  
  - Suporta compartilhamento de relatórios via link.  
  - Conexão direta a Snowflake, sem mover dados.

### Snowflake File Formats & Stages  
Define formatos (JSON, Parquet) e “stages” apontando para S3.  
- **Por que usar?**  
  - Abstração de leitura/escrita de arquivos externos.  
  - Simplifica carregamento com `COPY INTO` para tabelas VARIANT.

### Snowflake VARIANT Tables  
Tabelas staging que armazenam JSON/Parquet bruto em coluna VARIANT.  
- **Por que usar?**  
  - Flexibilidade para ingerir esquemas semi-estruturados.  
  - Permite transformação incremental antes de tipar colunas.

### Snowflake Procedures & Tasks  
Procedure em JavaScript para orquestrar cargas internas e Task agendada.  
- **Por que usar?**  
  - Agrupa múltiplos comandos SQL em rotina única.  
  - Task cron interna para recargas periódicas sem intervenção manual.

### Snowflake Clustering  
Cluster em `fact_despesas` por deputado_id e data.  
- **Por que usar?**  
  - Melhora performance de queries filtradas por parlamentar e data.  
  - Reduz custo de varreduras em grandes volumes.

### Python & JavaScript  
- **Python**: lógica de coleta nas Lambdas e script Glue.  
- **JavaScript**: stored procedure no Snowflake.  
- **Por que?**  
  - Cada ambiente (AWS, Glue, Snowflake) tem suporte nativo à sua linguagem recomendada.

### SQL Snowflake  
Modelagem de tabelas, joins, CTAS, FLATTEN e agregações.  
- **Por que usar?**  
  - Linguagem universal de data warehouse.  
  - Permite tipagem, transformações e consultas analíticas diretas.

### Git, AWS CLI, SnowSQL  
Ferramentas de versão e deploy:  
- **Git**: versionamento de código e definições (Step Functions, queries).  
- **AWS CLI**: deploy de Lambdas, Step Functions e EventBridge.  
- **SnowSQL**: execução de scripts SQL no Snowflake.  
- **Por que usar?**  
  - Automação de deploy e versionamento de infraestrutura e código.

---
