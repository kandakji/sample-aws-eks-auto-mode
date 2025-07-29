resource "aws_sqs_queue" "keda" {
  name = "${data.terraform_remote_state.main.outputs.name}-keda"
}

output "sqs_url" {
  value = aws_sqs_queue.keda.url
}

resource "aws_iam_policy" "keda" {
  name = "${data.terraform_remote_state.main.outputs.name}-keda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.keda.arn
      }
    ]
  })
}

module "irsa_keda" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.11.2"

  role_name = "${data.terraform_remote_state.main.outputs.name}-keda-irsa"
  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.main.outputs.oidc_provider_arn
      namespace_service_accounts = ["keda:keda-sa","keda:keda-operator"]
    }
  }
  role_policy_arns = { main = aws_iam_policy.keda.arn }

  depends_on = [aws_iam_policy.keda]
}


resource "aws_iam_policy" "sqs_reader" {
  name = "${data.terraform_remote_state.main.outputs.name}-sqs-reader"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

module "irsa_sqs_reader" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.11.2"

  role_name = "${data.terraform_remote_state.main.outputs.name}-sqs-reader-irsa"
  oidc_providers = {
    main = {
      provider_arn               = data.terraform_remote_state.main.outputs.oidc_provider_arn
      namespace_service_accounts = ["keda:sqs-reader-sa","keda:keda-operator","vllm:sqs-reader-sa"]
    }
  }
  role_policy_arns = { main = aws_iam_policy.sqs_reader.arn }

  depends_on = [aws_iam_policy.sqs_reader]
}

#### Yaml Manifest File Generation ####

resource "local_file" "keda_service_account" {
  content = templatefile("${path.module}/../templates/keda-service-account.yaml.tpl", {
    keda_role_arn = module.irsa_keda.iam_role_arn
  })
  filename = "${path.module}/../keda-service-account.yaml"

  depends_on = [module.irsa_keda]
}

resource "local_file" "sqs_reader_service_account" {
  content = templatefile("${path.module}/../templates/sqs-reader-service-account.yaml.tpl", {
    sqs_reader_role_arn = module.irsa_sqs_reader.iam_role_arn
  })
  filename = "${path.module}/../sqs-reader-service-account.yaml"

  depends_on = [module.irsa_sqs_reader]
}

resource "local_file" "keda_helm_values" {
  content = templatefile("${path.module}/../templates/keda-helm-values.yaml.tpl", {
    keda_role_arn = module.irsa_keda.iam_role_arn
  })
  filename = "${path.module}/../keda-helm-values.yaml"

  depends_on = [module.irsa_keda]
}

resource "local_file" "scaled_object" {
  content = templatefile("${path.module}/../templates/scaledObject.yaml.tpl", {
    sqs_queue_url = aws_sqs_queue.keda.url
    aws_region    = data.terraform_remote_state.main.outputs.region
  })
  filename = "${path.module}/../scaledObject.yaml"

  depends_on = [aws_sqs_queue.keda]
}

resource "local_file" "prompt_generator_job" {
  content = templatefile("${path.module}/../templates/prompt-generator-job.yaml.tpl", {
    sqs_queue_url = aws_sqs_queue.keda.url
    aws_region    = data.terraform_remote_state.main.outputs.region
  })
  filename = "${path.module}/../prompt-generator-job.yaml"

  depends_on = [aws_sqs_queue.keda]
}

resource "local_file" "model_deployment_with_sqs" {
  content = templatefile("${path.module}/../templates/model-qwen3-4b-fp8-with-sqs.yaml.tpl", {
    sqs_queue_url = aws_sqs_queue.keda.url
    aws_region    = data.terraform_remote_state.main.outputs.region
  })
  filename = "${path.module}/../vllm-qwen3/model-qwen3-4b-fp8-with-sqs.yaml"

  depends_on = [aws_sqs_queue.keda]
}
