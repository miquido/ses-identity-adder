data "aws_caller_identity" "default" {}
data "aws_region" "default" {}


locals {
  ses_identity_adder_lambda_name         = "${var.project}-${var.environment}-ses_identity_adder"
  ses_identity_adder_lambda_zip_filename = "${path.module}/ses_identity_adder.zip"
}

data "archive_file" "ses_identity_adder" {
  type             = "zip"
  source_file      = "${path.module}/main.py"
  output_path      = local.ses_identity_adder_lambda_zip_filename
  output_file_mode = "0755"
}

resource "aws_lambda_function" "ses_identity_adder" {
  function_name    = local.ses_identity_adder_lambda_name
  role             = aws_iam_role.ses_identity_adder.arn
  filename         = local.ses_identity_adder_lambda_zip_filename
  handler          = "main.lambda_handler"
  runtime          = "python3.9"
  timeout          = 3
  memory_size      = 128
  tags             = var.tags
  source_code_hash = data.archive_file.ses_identity_adder.output_base64sha256

  depends_on = [
    aws_iam_role.ses_identity_adder,
    aws_cloudwatch_log_group.ses_identity_adder
  ]
  environment {
    variables = {
      KEY = random_password.labmda_key.result
    }
  }
}

resource "aws_cloudwatch_log_group" "ses_identity_adder" {
  name              = "/aws/lambda/${local.ses_identity_adder_lambda_name}"
  retention_in_days = var.log_retention
  tags              = var.tags
}


################################################
#### IAM                                    ####
################################################

resource "aws_iam_role" "ses_identity_adder" {
  name               = "${local.ses_identity_adder_lambda_name}-role"
  description        = "Role used for lambda function ${local.ses_identity_adder_lambda_name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_ses_identity_adder.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "ses_identity_adder" {
  name   = "${local.ses_identity_adder_lambda_name}-policy"
  policy = data.aws_iam_policy_document.role_ses_identity_adder.json
  role   = aws_iam_role.ses_identity_adder.id
}

data "aws_iam_policy_document" "assume_role_ses_identity_adder" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "role_ses_identity_adder" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "${aws_cloudwatch_log_group.ses_identity_adder.arn}*"
    ]
  }
  statement {
    actions = [
      "ses:CreateEmailIdentity"
    ]

    resources = [
      "*"
    ]
  }

}

resource "aws_lambda_function_url" "function" {
  function_name      = aws_lambda_function.ses_identity_adder.function_name
  authorization_type = "NONE"
}

resource "random_password" "labmda_key" {
  length = 16
}