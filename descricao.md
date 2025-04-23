## Explicação da stack

### AWS S3
Armazena todos os arquivos JSON brutos e os Parquet gerados pelo Glue.
- **Por que usar?**
  - **Alta durabilidade e disponibilidade**
  - **Particionamento por ano/mês**: com centenas de despesas por deputado, usar chaves como `despesas/ano=2024/mes=06/...` acelera buscas específicas de um período, evitando varredura completa.
  - **Escalabilidade e baixo custo**: mantendo dados brutos e transformados lado a lado, o custo de armazenamento é otimizado sem esforço operacional.

### AWS Lambda
Funções sem servidor para extrair dados da API e gravar JSON em S3.
- **Por que usar?**
  - **Escala automática**: ao iterar 500 IDs de deputados em paralelo, cada invocação é isolada e responde rapidamente, sem necessidade de gerenciar servidores.
  - **Custo zero em repouso**: fora das janelas de execução (que duram poucos minutos por semana), não há cobrança de EC2 ocioso.
  - **Idempotência e isolamento de domínio**: separar a lógica de `ExtrairDadosGerais` e `ColetarDespesas` simplifica manutenção e depuração.

### AWS Glue
Job Spark gerenciado para converter JSON em Parquet.
- **Por que usar?**
  - **ETL serverless para grandes volumes**: processa centenas de GB de JSON mensal, particionando por `ano` e `mês`, sem provisionamento manual de cluster.
  - **Otimização de leitura**: Parquet colunar e particionado reduz em ~80% o tempo de leitura no Snowflake, comprovado em consultas de análise de despesas agrupadas por mês.

### AWS IAM
Define papéis e políticas de acesso aos recursos.
- **Por que usar?**
  - **Princípio de menor privilégio**: somente a Lambda de despesas pode escrever no prefixo `despesas/`; Glue só pode ler `despesas/` e escrever em `despesas-parquet/`.

### AWS EventBridge
Agenda o pipeline semanalmente com expressões cron.
- **Por que usar?**
  - **Serverless e integrado**: define `cron(0 3 ? * FRI *)` para rodar toda sexta às 03h UTC, sem instâncias EC2 dedicadas.
  - **Flexibilidade de evento**: além de cron, poderia facilmente reagir a eventos de S3 ou SNS no futuro.

### AWS Step Functions
Orquestra de ponta a ponta, com paralelismo controlado.
- **Por que usar?**
  - **Map State para paralelismo**: permite invocar `ColetarDespesas` até `MaxConcurrency=5`, equilibrando taxa de chamadas à API e limites de Lambda.
  - **Visualização e monitoração**: cada execução detalha status de cada etapa, facilitando rastreamento de falhas em specific IDs.
  - **Retries automáticos**: falhas intermitentes na API da Câmara são reexecutadas sem intervenção manual.

### AWS QuickSight
Painéis BI conectados diretamente ao Snowflake.
- **Por que usar?**
  - **Conexão nativa**: atualizações no pipeline refletem-se em dashboards em minutos, sem exportar dados.

### Snowflake File Formats & Stages
Configuração de formatos e pointers para S3.
- **Por que usar?**
  - **File Format Parquet e JSON**: Snowflake reconhece metadados dos arquivos, simplificando o `COPY INTO`.
  - **Stages externos**: apontam diretamente para buckets, sem camada da AWS intermediária.

### Snowflake VARIANT Tables
Tabelas staging para JSON/Parquet brutos.
- **Por que usar?**
  - **Flexibilidade de Schema**: adapta-se a mudanças na API (novos campos) sem alteração de tabela.
  - **Processamento em duas etapas**: primeiro armazena o objeto completo (`v VARIANT`), depois extrai e digita colunas específicas.

### Snowflake Stored Procedures & Tasks
Automatização da carga interna.
- **Por que usar?**
  - **Procedure JavaScript**: agrupa etapas de staging, parsing e joins em uma única rotina, simplificando deploy.
  - **Tasks agendadas**: recarga diária/semanal sem scripts externos, mantendo histórico no Snowflake Task History.

### Snowflake Clustering
Clusteriza `fact_despesas` por `deputado_id` e `data`.
- **Por que usar?**
  - **Consultas rápidas**: dashboards que filtram por parlamentar e mês executam até 5x mais rápido.
  - **Redução de custos**: evita varreduras completas em tabelas que já alcançaram muitas linhas.

### Python & JavaScript
Linguagens para lógica AWS e Snowflake.
- **Por que usar?**
  - **Python**: boto3 na Lambda e Glue, fácil manipulação de JSON e datas.
  - **JavaScript**: ambiente nativo de Stored Procedures no Snowflake, sem necessidade de transpiler.

### SQL Snowflake
Definição de tabelas, transformações, agregações.
- **Por que usar?**
  - **Expertise de data warehouse**: queries `FLATTEN`, CTAS e joins implementam dimensões e fato de forma declarativa.
  - **Performance**: aproveita otimizações internas do Snowflake em consultas analíticas.

### Git, SnowSQL
Ferramentas de versionamento e deploy.
- **Por que usar?**
  - **Git**: controla versões das definições de Step Functions e queries.
  - **SnowSQL**: execução de scripts de Snowflake dentro de pipelines CI/CD.
```

