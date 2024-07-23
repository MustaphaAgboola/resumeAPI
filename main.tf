provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "resume" {
    name = "resumeTable"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "id"

    attribute {
      name = "id"
      type = "S"
    }
}

resource "aws_iam_role" "lambda_role" {
    name = "LambdaDynamoDBRole"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole",
                Effect = "Allow",
                Principal = {
                    Service = "lambda.amazonaws.com"
                }
            }
        ]
    } ) 
}

resource "aws_iam_role_policy" "lambda_policy" {
    name = "LambdaDynamoDBPolicy"
    role = aws_iam_role.lambda_role.id

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "logs:CreatedLogGroup",
                    "logs:CreatedLogStream",
                    "logs:PutLogEvents"
                ],
                Resource = "arn:aws:logs:*:*:*"
            },
            {
                Effect = "Allow",
                Action = "dynamodb:Scan",
                Resource = aws_dynamodb_table.resume.arn
            }
        ]
    })
  
}

resource "aws_lambda_function" "fetch_resume" {
    function_name = "FetchResumeFunction"
    role = aws_iam_role.lambda_role.arn
    handler = "index.handler"
    runtime = "nodejs18.x"
    filename = "resume_function.zip"
    source_code_hash = filebase64sha256("resume_function.zip")
}

resource "aws_api_gateway_rest_api" "api" {
  name = "resume-api"
}

resource "aws_api_gateway_resource" "items" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    parent_id = aws_api_gateway_rest_api.api.root_resource_id
    path_part = "items" 
}

resource "aws_api_gateway_method" "get_items" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.items.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
    rest_api_id = aws_api_gateway_rest_api.api.id
    resource_id = aws_api_gateway_resource.items.id
    http_method = aws_api_gateway_method.get_items.http_method
    integration_http_method = "POST"
    type = "AWS_PROXY"
    uri = aws_lambda_function.fetch_resume.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
    statement_id = "AllowAPIGatewayInvoke"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.fetch_resume.function_name
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [ aws_api_gateway_integration.lambda ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name = "prod"
}

output "api_url" {
    value = "${aws_api_gateway_deployment.deployment.invoke_url}/items"
  
}