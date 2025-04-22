import json
import boto3
import urllib.request
from datetime import datetime

s3 = boto3.client('s3')
BUCKET_NAME = "camara-api-dados-raw"
HEADERS = {'User-Agent': 'Mozilla/5.0'}

def lambda_handler(event, context):
    try:
        # Identifica o ID do deputado
        dep_id = event if isinstance(event, int) else event.get('id', None)
        ano = 2024

        # Busca as despesas via API
        url = f"https://dadosabertos.camara.leg.br/api/v2/deputados/{dep_id}/despesas?ano={ano}"
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req) as response:
            raw = response.read()
            data = json.loads(raw.decode('utf-8'))

        # Gera partições de ano e mês para o bucket
        now = datetime.utcnow()
        ano_str = now.strftime("%Y")
        mes_str = now.strftime("%m")

        # Chave fixa: sobrescreve JSON anterior de mesmo deputado/mes
        file_key = f"despesas/ano={ano_str}/mes={mes_str}/deputado-{dep_id}.json"

        # Upload para S3
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=file_key,
            Body=json.dumps(data),
            ContentType='application/json'
        )

        return {
            'statusCode': 200,
            'message': f'Despesas do deputado {dep_id} salvas em {file_key}'
        }

    except Exception as e:
        print(f"Erro deputado {dep_id}: {e}")
        return {
            'statusCode': 500,
            'error': str(e)
        }
