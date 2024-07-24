provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "resume" {
  name           = "ResumeTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "LambdaDynamoDBRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "LambdaDynamoDBPolicy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Scan"
        ],
        Resource = aws_dynamodb_table.resume.arn
      }
    ]
  })
}

resource "aws_lambda_function" "fetch_data" {
  function_name = "FetchDataFunction"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  filename      = "fetch_data_lambda.zip"
  source_code_hash = filebase64sha256("fetch_data_lambda.zip")
}

resource "aws_lambda_function" "upload_data" {
  function_name = "UploadDataFunction"
  role          = aws_iam_role.lambda_role.arn
  handler       = "upload.handler"
  runtime       = "nodejs14.x"
  filename      = "upload_data_lambda.zip"
  source_code_hash = filebase64sha256("upload_data_lambda.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.resume.name
    }
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name = "resume-api"
}

resource "aws_api_gateway_resource" "items" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "items"
}

resource "aws_api_gateway_method" "get_items" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.items.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.items.id
  http_method             = aws_api_gateway_method.get_items.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.fetch_data.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_data.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.lambda]

  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

output "api_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}/items"
}

resource "aws_lambda_invocation" "upload_invocation" {
  function_name = aws_lambda_function.upload_data.arn
  input         = jsonencode({})
  depends_on    = [aws_lambda_function.upload_data, aws_dynamodb_table.resume]
}
