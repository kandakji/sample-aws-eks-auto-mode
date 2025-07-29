resource "kubernetes_namespace" "keda" {
  metadata { name = "keda" }
  timeouts { delete = "15m" }

  depends_on = [module.eks]
}

resource "aws_sqs_queue" "keda" {
  name = "${var.name}-keda"
}

output "sqs_url" {
  value = aws_sqs_queue.keda.url
}

resource "aws_iam_policy" "keda" {
  name = "${var.name}-keda"

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

  role_name = "${var.name}-keda-irsa"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["keda:keda-sa","keda:keda-operator"]
    }
  }
  role_policy_arns = { main = aws_iam_policy.keda.arn }

  depends_on = [aws_iam_policy.keda, resource.kubernetes_namespace.keda]
}

resource "kubernetes_service_account_v1" "keda" {
  metadata {
    name        = "keda-sa"
    namespace   = "keda"
    annotations = { "eks.amazonaws.com/role-arn" : module.irsa_keda.iam_role_arn }
  }
  automount_service_account_token = true

  depends_on = [resource.kubernetes_namespace.keda]
}

resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = "2.17.0"
  namespace        = "keda"
  create_namespace = false
  values           = [
    <<EOF
    serviceAccount:
      operator:
        create: false
        name: keda-sa
    serviceAccount:
      operator:
        name: keda-operator
        annotations:
          eks.amazonaws.com/role-arn : "${module.irsa_keda.iam_role_arn}"
    EOF
  ]

  depends_on = [module.irsa_keda]
}

resource "aws_iam_policy" "sqs_reader" {
  name = "${var.name}-sqs-reader"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
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

  role_name = "${var.name}-sqs-reader-irsa"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["keda:sqs-reader-sa","keda:keda-operator"]
    }
  }
  role_policy_arns = { main = aws_iam_policy.sqs_reader.arn }

  depends_on = [aws_iam_policy.sqs_reader, resource.kubernetes_namespace.keda]
}

resource "kubernetes_service_account_v1" "sqs_reader" {
  metadata {
    name        = "sqs-reader-sa"
    namespace   = "keda"
    annotations = { "eks.amazonaws.com/role-arn" : module.irsa_sqs_reader.iam_role_arn }
  }
  automount_service_account_token = true

  depends_on = [resource.kubernetes_namespace.keda]
}
