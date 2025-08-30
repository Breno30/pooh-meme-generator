import json
import boto3
from botocore.exceptions import ClientError

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
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': cors_headers, # Add CORS headers to error response
            'body': json.dumps({'error': f'An error occurred while parsing the input: {str(e)}'})
        }

    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('${table_name}')

    response = table.get_item(
        Key={
            'input_text': input_text
        }
    )

    if response is not None and 'Item' in response:
        item = response.get('Item')
        generated_text = item.get('generated_text')

        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'input_text': input_text,
                'generated_text': generated_text
            }) 
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
                        Dada a frase original: '{input_text}', reescreva-a em duas versões crescentemente formais e cômicas, mantendo o mesmo significado:

                        1. **"sophisticated"**:  
                        Reformule a frase de maneira formal, elegante e levemente pomposa, como se estivesse tentando parecer sério e educado. Use vocabulário culto, mas ainda compreensível.

                        2. **"complex"**:  
                        Transforme a frase em algo deliberadamente exagerado, pseudo-filosófico, cheio de palavras longas, construções rebuscadas e um tom ridiculamente acadêmico. Pode parecer algo dito por alguém que estudou demais para justificar algo simples. Humor é essencial.

                        **Importante:**  
                        - Retorne apenas um objeto JSON com as chaves `"sophisticated"` e `"complex"`.  
                        - Não inclua nenhum texto extra fora do JSON.  
                        - Ambas as versões devem ter o exato mesmo significado da frase original.  
                        - A complexidade e o tom absurdo devem escalar da primeira para a segunda versão.
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

        table.put_item(
            Item={
                'input_text': input_text,
                'generated_text': generated_text
            }
        )

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