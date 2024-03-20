import json
import os
import boto3

ses = boto3.client('sesv2')
key = os.environ['KEY']


def lambda_handler(event, context):
    print(json.dumps(event))

    if 'key' not in event['headers'] or key != event['headers']['key']:
        return {
            'statusCode': 403,
            'body': 'wrong key'
        }

    body = json.loads(event['body'])
    email = body['email']
    ses.create_email_identity(EmailIdentity=email)

    return {
        'statusCode': 200,
        'body': 'ok'
    }
