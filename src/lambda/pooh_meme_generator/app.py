import json
import boto3
import os
import requests
from botocore.exceptions import ClientError

# --- Environment Variables ---
MODEL_ID = os.environ.get('MODEL_ID')
APP_REGION = os.environ.get('APP_REGION')
TABLE_NAME = os.environ.get('TABLE_NAME')
PROVIDER = os.environ.get("PROVIDER", "bedrock")  # bedrock | openai
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-5-nano")
DYNAMO_DB_CACHE = os.environ.get('DYNAMO_DB_CACHE', 'true').lower() == 'true'

def lambda_handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    # --- 1. Parse the input string from the event ---
    # The input is expected to be a JSON string in the 'body' of the event.
    try:
        if 'body' in event:
            # Assuming the input is a JSON string
            body = json.loads(event['body'])
            input_text = body.get('prompt', '')  # Use a key like 'prompt' for clarity
        else:
            if 'queryStringParameters' in event:
                # If it's a GET request, parse the query string parameters
                input_text = event.get('queryStringParameters').get('prompt', '')
            else:
                # If not in 'body', assume it's a direct string input
                input_text = event.get('prompt', '')

        if not input_text:
            return {
                'statusCode': 400,
                'headers': cors_headers, # Add CORS headers to error response
                'body': json.dumps({'error': 'No input string provided. Please provide a "prompt" in the request body.'})
            }

    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': cors_headers, # Add CORS headers to error response
            'body': json.dumps({'error': 'Invalid JSON format in the request body.'})
        }

    # --- DynamoDB Cache Check ---
    if DYNAMO_DB_CACHE:
        dynamodb = boto3.resource('dynamodb', region_name=APP_REGION)
        table = dynamodb.Table(TABLE_NAME)

        response = table.get_item(
            Key={
                'input_text': input_text
            }
        )

        if response and 'Item' in response:

            item = response['Item']
            generated_text = item['generated_text']

            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({
                    'input_text': input_text,
                    'generated_text': generated_text
                }) 
            }

    # --- Prompt ---
    prompt = f"""
Dada a frase original: '{input_text}', reescreva-a em duas versões crescentemente formais e cômicas, mantendo o mesmo significado:

1. "complex":
Reformule a frase de maneira formal, elegante e levemente pomposa.

2. "sophisticated":
Transforme a frase em algo exagerado, pseudo-filosófico e absurdamente acadêmico.

Importante:
- Retorne apenas um objeto JSON com "complex" e "sophisticated"
- Não inclua texto fora do JSON
"""

    # --- Call Provider ---
    try:

        if PROVIDER == "openai":

            response = requests.post(
                "https://api.openai.com/v1/responses",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {OPENAI_API_KEY}"
                },
                json={
                    "model": OPENAI_MODEL,
                    "input": prompt,
                    "temperature": 1
                }
            )

            data = response.json()

            generated_text = data["output"][1]["content"][0]["text"]

        else:  # Bedrock

            bedrock_runtime_client = boto3.client(
                service_name='bedrock-runtime',
                region_name=APP_REGION
            )

            # Prepare the payload for the Bedrock model. This format is specific to the model.
            # The example below is for Anthropic Claude.
            payload = json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt}
                        ]
                    }
                ],
                "max_tokens": 512,
                "temperature": 1
            })

            # Invoke the model
            response = bedrock_runtime_client.invoke_model(
                modelId=MODEL_ID,
                body=payload,
                contentType='application/json',
                accept='application/json'
            )

            # --- 3. Process the response from Bedrock ---
            # The response body is a streaming payload, so we read it.
            response_body = json.loads(response['body'].read())

            # Extract the text from the response based on the model's output format.
            # This is specific to Anthropic Claude.
            generated_text = response_body['content'][0]['text']

    except Exception as e:

        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }

    # --- Store Cache ---
    if DYNAMO_DB_CACHE:
        table.put_item(
            Item={
                'input_text': input_text,
                'generated_text': generated_text
            }
        )

    # --- 4. Return the output ---
    return {
        'statusCode': 200,
        'headers': cors_headers,
        'body': json.dumps({
            'input_text': input_text,
            'generated_text': generated_text,
            'provider': PROVIDER
        })
    }