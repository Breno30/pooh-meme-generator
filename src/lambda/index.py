import json
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    # return {
    #     'statusCode': 200,
    #     'headers': cors_headers, # Use the defined CORS headers
    #     'body': json.dumps({
    #         'input_text': 'que dia lindo',
    #         'generated_text': '{\n\"simple\": \"Cara, que dia lindo pra ficar na cama o dia todo!\",\n\"complex\": \"Façamos das horas matutinas testemunhas da fruição dos esplendores naturais que hoje se descortinam ante nossos sentidos.\",\n\"sophisticated\": \"Proponho uma reflexão quanto ao inexorável fluxo da temporalidade em sua manifestação cíclica matinal, tomando como vestígio fenomenológico a suntuosa conjunção de atributos meteorológicos e luminosos que, em seu esplendor arrebatador, dão ensejo a uma contemplação sublime da grandiosidade do cosmos e da natureza mesma de nossa existência.\"\n}'
    #     })
    # }

    # --- 1. Parse the input string from the event ---
    # The input is expected to be a JSON string in the 'body' of the event.
    try:
        if 'body' in event:
            # Assuming the input is a JSON string
            body = json.loads(event['body'])
            input_text = body.get('prompt', '')  # Use a key like 'prompt' for clarity
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
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': cors_headers, # Add CORS headers to error response
            'body': json.dumps({'error': f'An error occurred while parsing the input: {str(e)}'})
        }

    # --- 2. Invoke the Bedrock model ---
    # model_id = "anthropic.claude-3-sonnet-20240229-v1:0" # You can change this to your desired model ID
    model_id = "anthropic.claude-3-haiku-20240307-v1:0" # You can change this to your desired model ID

    # Create a Bedrock Runtime client
    try:
        bedrock_runtime_client = boto3.client(
            service_name='bedrock-runtime',
            region_name='us-east-1' # Change to the region where your Bedrock model is available
        )
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': cors_headers, # Add CORS headers to error response
            'body': json.dumps({'error': f'Failed to create Bedrock Runtime client: {str(e)}'})
        }

    # Prepare the payload for the Bedrock model. This format is specific to the model.
    # The example below is for Anthropic Claude.
    payload = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": f"""
                        Baseado na frase '{input_text}', gere três versões com o exato mesmo significado, seguindo este padrão:

                        Versão Simples (informal e direta):
                        Gere uma frase casual e cotidiana

                        Versão Sofisticada (formal e elaborada):
                        Gere uma versão mais rebuscada e formal da mesma ideia

                        Versão Exagerada (absurdamente formal/filosófica):
                        Gere uma versão extremamente exagerada, pseudo-intelectual e cômica da mesma ideia

                        Mantenha o tom humorístico e crescente em complexidade.

                        o output deve ser um único json, sem mais nenhum texto ao redor, keys: simple, complex, sophisticated
                        """
                    }
                ]
            }
        ],
        "max_tokens": 512,
        "temperature": 1
    })

    try:
        # Invoke the model
        response = bedrock_runtime_client.invoke_model(
            modelId=model_id,
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

        # --- 4. Return the output ---
        return {
            'statusCode': 200,
            'headers': cors_headers, # Use the defined CORS headers
            'body': json.dumps({
                'input_text': input_text,
                'generated_text': generated_text
            })
        }

    except ClientError as e:
        error_message = e.response['Error']['Message']
        print(f"Bedrock API error: {error_message}")
        return {
            'statusCode': 500,
            'headers': cors_headers, # Add CORS headers to error response
            'body': json.dumps({'error': f'Bedrock API error: {error_message}'})
        }
    except Exception as e:
        print(f"An unexpected error occurred: {str(e)}")
        return {
            'statusCode': 500,
            'headers': cors_headers, # Add CORS headers to error response
            'body': json.dumps({'error': f'An unexpected error occurred: {str(e)}'})
        }