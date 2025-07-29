serviceAccount:
  operator:
    create: false
    name: keda-sa
    annotations:
      eks.amazonaws.com/role-arn: ${keda_role_arn}
