# Public expenses Data Pipeline

## Sumário

- [Visão geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Stack](#stack)
- [Pré‑requisitos](#pré-requisitos)
- [Instalação e configuração](#instalação-e-configuração)
- [Estrutura de diretórios](#estrutura-de-diretórios)
- [Snowflake setup](#snowflake-setup)
- [AWS setup e Orquestração](#aws-setup-e-orquestração)
- [Fluxo de dados e execução](#fluxo-de-dados-e-execução)
- [Melhorias Futuras](#melhorias-futuras)
---

## Visão geral

Este projeto implementa um pipeline de dados para coletar, armazenar e processar informações de gastos de deputados federais brasileiros. O fluxo principal:

1. **Ingestão**: Lambdas AWS extraem JSONs da API da Câmara dos Deputados.
2. **Armazenamento bruto**: JSONs são salvos em **S3**.
3. **Transformação**: **AWS Glue** converte despesas em **Parquet**, particionando por ano/mês.
4. **Data Warehouse**: **Snowflake** lê Parquets e JSONs via **Stages** e popula tabelas raw, dimensões e fato.
5. **Visualização**: **QuickSight** consome views/tabelas em Snowflake para dashboards públicos.
6. **Agendamento & orquestração**: **EventBridge** agenda e dispara **Step Functions**, que coordenam Lambda e Glue. **Snowflake Tasks** executam carga secundária semanal.

O objetivo é fornecer uma base robusta para análises de gastos e relatórios interativos.

---

## Arquitetura

    EventBridge (cron) ──▶ Step Functions State Machine ──▶ Lambda: ExtrairDadosGerais
                                               ├─▶ Map State: IterarDespesas ──▶ Lambda: ColetarDespesas
                                               └─▶ Glue Job: TransformarEmParquet

    Snowflake:
      Stages → raw_variant tables → parsed tables
        → dim_data, dim_deputado
        → fact_despesas (clustered)
    Snowflake Task ● cron semanal ● chama procedure de load

    QuickSight:
      Dashboards conectados a views/tabelas Snowflake

- **EventBridge**: dispara a máquina de estados semanalmente.
- **Step Functions**: gerencia fluxo, usa Map State para paralelizar coleta de despesas.
- **Snowflake Tasks**: garante recarga interna semanal.
- **Idempotência**: Lambdas/Glue sobrescrevem por partição.
- **Segurança**: IAM Roles controlam acesso S3; Storage Integration no Snowflake.

---

## Tecnologias Utilizadas

- AWS: Lambda, Glue, S3, IAM, EventBridge, Step Functions, QuickSight
- Snowflake: File Formats, Stages, VARIANT tables, Procedures, Tasks, Clustering
- Linguagens: Python (Lambda), JavaScript (Procedure Snowflake), SQL Snowflake
- Ferramentas: Git, AWS CLI, SnowSQL, QuickSight console

---

## Pré‑requisitos

1. Conta AWS com permissões para S3, Lambda, Glue, Step Functions, EventBridge, QuickSight e IAM.
2. Conta Snowflake com role de SYSADMIN ou equivalente.
3. AWS CLI e SnowSQL configurados localmente.
4. Chave SSH para GitHub e repositório clonado.
5. Variáveis de ambiente definidas:

        export BUCKET_NAME=camara-api-dados-raw
        export ROLE_ARN=arn:aws:iam::503561429803:role/snowflake_s3_access
        export SNOW_CONN='<connection_string>'

---

## Instalação e Configuração

1. Clone o repositório via SSH:

        git clone git@github.com:victor-cakess/public_expenses.git
        cd public_expenses

2. Crie diretórios:

        mkdir -p lambdas/extrair_deputados lambdas/extrair_despesas glue queries_snowflake docs quicksight

3. Configure variáveis de ambiente conforme Pré‑requisitos.

4. Deploy Lambdas (exemplo AWS CLI):

        aws lambda update-function-code --function-name ExtrairDadosGerais --zip-file fileb://lambdas/extrair_deputados.zip
        aws lambda update-function-code --function-name ColetarDespesas   --zip-file fileb://lambdas/extrair_despesas.zip

5. Configure Step Functions:
   - Importe definição de máquina de estados em infrastructure/stepfunctions/definition.json.
   - Associe role AWS Step Functions.

6. Configure EventBridge:

        aws events put-rule --name ScheduleDespesasLoad --schedule-expression "cron(0 3 ? * FRI *)"
        aws events put-targets --rule ScheduleDespesasLoad --targets "Id"="1","Arn"="<StepFunctionsStateMachineArn>"

7. Execute Glue Job via console ou AWS CLI (nome em glue/TransformarEmParquet).

8. Configuração Snowflake:

        snowsql -c $SNOW_CONN -f queries_snowflake/permissions.sql
        snowsql -c $SNOW_CONN -f queries_snowflake/structure.sql
        snowsql -c $SNOW_CONN -f queries_snowflake/procedure_task.sql

9. QuickSight:
   - Crie fonte de dados apontando para Snowflake.
   - Importe visões e configure dashboards em quicksight/.

---

## Estrutura de Diretórios

    public_expenses/
    ├── infrastructure/
    │   ├── stepfunctions/       # Definições e roles
    │   └── eventbridge/         # Config rules e targets scripts
    ├── lambdas/
    │   ├── extrair_deputados/   # Lambda: ExtrairDadosGerais
    │   └── extrair_despesas/    # Lambda: ColetarDespesas
    ├── glue/                    # Glue Job: TransformarEmParquet
    ├── queries_snowflake/       # SQL: permissões, estrutura, procedure_task
    ├── quicksight/              # Templates de dashboards
    ├── docs/                    # Diagramas e documentação adicional
    └── README.md                # Documentação principal

---

## Snowflake Setup

1. Execute permissions.sql para storage integration e grants.
2. Execute structure.sql para file formats, stages e tabelas brutas.
3. Execute procedure_task.sql para criar procedure e agendar task semanal.

> Arquivos em queries_snowflake/.

---

## AWS Setup e Orquestração

Consulte seção Instalação e Configuração para detalhes sobre EventBridge, Step Functions,
Lambda, Glue e QuickSight.

---

## Fluxo de Dados e Execução

1. EventBridge dispara Step Functions semanalmente.
2. Step Functions:
   - Invoca Lambda ExtrairDadosGerais
   - Map State itera IDs e chama Lambda ColetarDespesas
   - Após coleta, inicia Glue Job TransformarEmParquet
3. Snowflake procedure de carga finaliza ingestão interna.
4. QuickSight reflete dados atualizados automaticamente.
5. Snowflake Task garante recarga extra semanal.

---

## Como Testar

- Teste Lambdas com SAM ou mocks.
- Simule Step Functions localmente com AWS Toolkit.
- Verifique eventos no EventBridge.
- Verifique S3, Snowflake e QuickSight após execução.

---

## Monitoramento e Alertas

- CloudWatch Logs para Lambdas, Glue e Step Functions.
- EventBridge métricas de invocação.
- Snowflake Task History para falhas.
- QuickSight Dashboard Refresh Logs.
- SNS/Slack notificações via CloudWatch Alarms.

---

## Melhorias Futuras

- CI/CD completo para infraestrutura (CloudFormation/CDK).
- Versionamento de Step Functions e EventBridge via CDK.
- Testes end-to-end automatizados.
- Alertas refinados e relatórios de SLA.

---

## Contribuição

1. Fork este repositório.
2. Crie branch: git checkout -b feature/xyz.
3. Commit e push.
4. Abra Pull Request.

---

## Licença

Licenciado sob [MIT License](LICENSE)
```

