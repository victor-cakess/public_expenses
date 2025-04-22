import json
import boto3
import urllib.request
from datetime import datetime
import traceback

s3 = boto3.client('s3')
BUCKET_NAME = "camara-api-dados-raw"
HEADERS = {'User-Agent': 'Mozilla/5.0'}

def fetch_json(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req) as response:
        raw = response.read()
        return json.loads(raw.decode('utf-8'))

def save_to_s3(data, folder, filename_prefix):
    now = datetime.utcnow()
    ano = now.year
    mes = f"{now.month:02d}"
    # Chave fixa: sobrescreve JSON anterior de mesma entidade/periodicidade
    file_key = f"{folder}/ano={ano}/mes={mes}/{filename_prefix}.json"
    
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=file_key,
        Body=json.dumps(data),
        ContentType='application/json'
    )
    print(f"✓ {file_key}")

def lambda_handler(event, context):
    try:
        # 1. Extrai /deputados e grava idempotente
        print("🔎 Ingerindo /deputados")
        deputados_data = fetch_json("https://dadosabertos.camara.leg.br/api/v2/deputados")
        save_to_s3(deputados_data, "deputados", "deputados")
        deputados_ids = [d['id'] for d in deputados_data['dados']]

        # 2. Extrai /proposicoes e grava idempotente
        print("🔎 Ingerindo /proposicoes")
        proposicoes_data = fetch_json("https://dadosabertos.camara.leg.br/api/v2/proposicoes?dataInicio=2024-01-01")
        save_to_s3(proposicoes_data, "proposicoes", "proposicoes")

        # 3. Extrai /votacoes e grava idempotente
        print("🔎 Ingerindo /votacoes")
        votacoes_data = fetch_json("https://dadosabertos.camara.leg.br/api/v2/votacoes")
        save_to_s3(votacoes_data, "votacoes", "votacoes")

        # Retorna IDs para Step Functions
        print("🔎 IDs extraídos:", deputados_ids)
        return {
            'statusCode': 200,
            'ids': deputados_ids
        }

    except Exception as e:
        print("❌ Erro na execução da Lambda:")
        print(traceback.format_exc())
        return {
            'statusCode': 500,
            'error': str(e)
        }
