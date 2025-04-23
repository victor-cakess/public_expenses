# Public Expenses Data Pipeline

## Sumário

- [Visão geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Stack](#stack)
- [Pré-requisitos](#pré-requisitos)
- [Instalação e configuração](#instalação-e-configuração)
- [Estrutura de diretórios](#estrutura-de-diretórios)
- [Snowflake setup](#snowflake-setup)
- [AWS Setup e orquestração](#aws-setup-e-orquestração)
- [Fluxo de dados e execução](#fluxo-de-dados-e-execução)
- [Melhorias futuras](#melhorias-futuras)

---

## Visão Geral

Este projeto implementa um pipeline de dados para coletar, armazenar e processar informações de gastos de deputados federais brasileiros. O fluxo principal:

1. **Ingestão**: Lambdas AWS extraem JSONs da API da Câmara dos Deputados.
2. **Armazenamento Bruto**: JSONs são salvos em **S3**.
3. **Transformação**: **AWS Glue** converte despesas em **Parquet**, particionando por ano/mês.
4. **Data Warehouse**: **Snowflake** lê Parquets e JSONs via **Stages** e popula tabelas raw, dimensões e fato.
5. **Visualização**: **QuickSight** consome views/tabelas em Snowflake para dashboards.
6. **Agendamento & orquestração**: **EventBridge** agenda e dispara **Step Functions**, que coordenam a coleta e transformação das despesas. **Snowflake Tasks** executam cargas internas periódicas.

O objetivo é fornecer uma base robusta para análises de gastos e relatórios interativos.

---

## Arquitetura

    EventBridge (cron semanal) ▶ Step Functions ▶
      ├── ExtrairDadosGerais (Lambda) ▶ retorna lista de IDs de deputados
      ├── IterarDespesas (Map State) ▶ para cada ID invoca ColetarDespesas (Lambda)
      └── TransformarEmParquet (Glue Job)

    Snowflake:
      • Stages (S3 JSON/Parquet)
      • Tabelas raw_variant, parsed
      • Dimensões: dim_data, dim_deputado
      • Fato: fact_despesas (clustered)
      • Tasks (cron) ▶ chama procedure de carga

    QuickSight:
      • Dashboards públicos conectados ao Snowflake

- **EventBridge**: agenda o fluxo semanalmente.
- **Step Functions**: gerencia sequência e paralelismo da ingestão.
- **Snowflake Tasks**: garante recarga regular.
- **Idempotência**: Lambdas e Glue sobrescrevem dados por partição.
- **Segurança**: IAM Roles controlam acesso a S3 e recursos AWS; Storage Integration no Snowflake.

---

## Stack

- **AWS**: Lambda, Glue, S3, IAM, EventBridge, Step Functions, QuickSight
- **Snowflake**: File Formats, Stages, VARIANT tables, Procedures, Tasks, Clustering
- **Linguagens**: Python (Lambda), JavaScript (Procedure Snowflake), SQL Snowflake
- **Ferramentas**: Git, AWS CLI, SnowSQL, QuickSight console

---

## Pré-requisitos

1. Conta AWS com permissões para S3, Lambda, Glue, Step Functions, EventBridge, QuickSight e IAM.
2. Conta Snowflake com role SYSADMIN ou equivalente.
3. AWS CLI e SnowSQL configurados localmente.
4. Chave SSH para GitHub e repositório clonado.

---

## Instalação e configuração

1. Clone o repositório via SSH:

    git clone git@github.com:victor-cakess/public_expenses.git
    cd public_expenses

4. Deploy das Lambdas:

    aws lambda update-function-code --function-name ExtrairDadosGerais \
      --zip-file fileb://lambdas/extrair_deputados.zip
    aws lambda update-function-code --function-name ColetarDespesas \
      --zip-file fileb://lambdas/extrair_despesas.zip

5. Configure Step Functions:

    - Crie máquina de estados em `infrastructure/stepfunctions/LoopDespesasDeputados.json`, importando no console ou via CLI.
    - Para versionar definição atual:
      ```bash
      aws stepfunctions describe-state-machine \
        --state-machine-arn <ARN> \
        --query 'definition' --output json \
        > infrastructure/stepfunctions/LoopDespesasDeputados.json
      ```

6. Configure EventBridge para disparar a máquina de estados semanalmente:

    aws events put-rule --name ScheduleDespesasLoad \
      --schedule-expression "cron(0 3 ? * FRI *)"
    aws events put-targets --rule ScheduleDespesasLoad \
      --targets "Id"="1","Arn"="<StateMachineArn>"

7. Execute o Glue Job:

    aws glue start-job-run --job-name despesas_json_to_parquet

8. Configure Snowflake:

    snowsql -c $SNOW_CONN -f queries_snowflake/permission_queries.sql
    snowsql -c $SNOW_CONN -f queries_snowflake/modelling_queries.sql
    snowsql -c $SNOW_CONN -f queries_snowflake/procedure_queries.sql

9. Configure QuickSight:

    - Crie uma fonte de dados para Snowflake.
    - Importe e publique dashboards em `quicksight/`.

---

## Estrutura de Diretórios

    public_expenses/
    ├── stepfunctions/
    │   └── LoopDespesasDeputados.json   # definição da state machine
    ├── lambdas/
    │   ├── extrair_deputados/             # Lambda: ExtrairDadosGerais
    │   └── extrair_despesas/              # Lambda: ColetarDespesas
    ├── glue/
    │   └── despesas_json_to_parquet.py    # Glue job script
    ├── queries_snowflake/
    │   ├── modelling_queries.sql
    │   ├── permission_queries.sql
    │   └── procedure_queries.sql
    └── README.md                          # este arquivo

---

## Snowflake Setup

1. Execute `permission_queries.sql` para criar storage integration e grants.
2. Execute `modelling_queries.sql` para criar file formats, stages e tabelas.
3. Execute `procedure_queries.sql` para criar procedure e agendar tasks.

---

## Fluxo de dados e execução

1. **EventBridge** dispara **Step Functions** semanalmente.
2. **Step Functions**:
   - Executa **ExtrairDadosGerais** (Lambda) → retorna lista de IDs
   - Mapeia **IterarDespesas** (Map State) → chama **ColetarDespesas** (Lambda) para cada ID
   - Chama **TransformarEmParquet** (Glue Job) após coleta
3. **Snowflake** carrega e transforma dados internamente via procedure agendada.
4. **QuickSight** apresenta dashboards atualizados.

---


## Monitoramento e alertas

- CloudWatch Logs para Lambdas, Glue e Step Functions.
- CloudWatch Metrics e Alarms para EventBridge.
- Snowflake Task History para falhas.
- QuickSight Dashboard Refresh Logs.

---

## Melhorias futuras

- CI/CD completo com Terraform
- Versionamento automatizado de definições de Step Functions e EventBridge.