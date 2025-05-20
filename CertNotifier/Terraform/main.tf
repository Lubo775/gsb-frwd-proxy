terraform {
    backend "s3" {
        bucket  = "${var.s3_bucket_name}"
        key     = "${var.s3_tf_location}"
        region  = "${var.s3_bucket_region}"
        encrypt = "${var.s3_bucket_encrypt}"
    }
}

resource "random_string" "rng" {
    length  = 8
    special = false
    upper   = false
    lower   = true
    numeric = true
}

resource "aws_cloudwatch_log_group" "certNotifierLogGroup" {
    name = "/aws/lambda/CertNotifier"

    tags = {
        Service = "GSB Proxy"
    }
}

resource "aws_iam_policy" "lambdaPolicy" {
    name = "CertNotifier"
    path        = "/"
    description = "Custom policy for CertNotifier Lambda fn"
    policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "logs:CreateLogGroup",
                "Resource": "arn:aws:logs:eu-west-1:${var.account_number}:*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": [
                    "${aws_cloudwatch_log_group.certNotifierLogGroup.arn}:*"
                ]
            },
            {
                "Sid": "AccessTos3",
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::bkt.${var.org_scope}.sharedservices.gsbproxy-certnotifier.${var.environment}",
                    "arn:aws:s3:::bkt.${var.org_scope}.sharedservices.gsbproxy-certnotifier.${var.environment}/*"
                ]
            },
            {
                "Sid": "AccessTosns",
                "Effect": "Allow",
                "Action": [
                    "sns:Publish",
                    "sns:CreateTopic",
                    "sns:TagResource"
                ],
                "Resource": [
                    "*"
                ]
            }
        ]
    })

    tags = {
        Service = "GSB Proxy"
    }
}

resource "aws_iam_role" "CertNotifierLambdaRole" {
    name = "CertNotifierRole-${random_string.rng.result}"
    assume_role_policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "sts:AssumeRole"
                ],
                "Principal": {
                    "Service": [
                        "lambda.amazonaws.com"
                    ]
                }
            }
        ]
    })

    tags = {
        Service = "GSB Proxy"
    }
}

resource "aws_iam_role_policy_attachment" "attachLambdaPolicy" {
    role       = aws_iam_role.CertNotifierLambdaRole.name
    policy_arn = aws_iam_policy.lambdaPolicy.arn
}

data "archive_file" "lambda" {
    type        = "zip"
    source_file = "../source_code/CertNotifier.py"
    output_path = "../CertNotifier.zip"
}

resource "aws_lambda_function" "CertNotifier" {
    function_name = "CertNotifier"
    description   = "This function will check validity of server/client certificates and subsequently sent notifications to corresponding mailboxes. GSB Proxy owns this function"  
    role          = aws_iam_role.CertNotifierLambdaRole.arn
    filename      = "CertNotifier.zip"
    handler       = "CertNotifier.lambda_handler"

    source_code_hash = data.archive_file.lambda.output_base64sha256

    runtime = "python3.11"

    environment {
        variables = {
            bucketName       = "bkt.${var.org_scope}.${var.func_scope}.${var.module_name}-certnotifier.${var.environment}"
            daysLeftToExpire = "92"
            stage            = "${var.environment}"
        }
    }

    layers = ["arn:aws:lambda:eu-west-1:770693421928:layer:Klayers-p311-cryptography:3"]
}

resource "aws_cloudwatch_event_rule" "eventBridgeRule" {
    name                = "Trigger-CertNotifier-Lambda"
    description         = "Trigger lambda based on specific pattern"
    schedule_expression = "rate(1 day)"
    event_bus_name      = "default"

    tags = {
        Service = "GSB Proxy"
    }
}

resource "aws_cloudwatch_event_target" "eventBridgeRuleTarget" {
    arn = aws_lambda_function.CertNotifier.arn
    rule = aws_cloudwatch_event_rule.eventBridgeRule.name
}

resource "aws_lambda_permission" "allow_eventbridge" {
    statement_id  = "AllowExecutionFromEventBridgeRule"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.CertNotifier.function_name
    principal     = "events.amazonaws.com"
    source_arn    = aws_cloudwatch_event_rule.eventBridgeRule.arn
}