apiVersion: v1
kind: ServiceAccount
metadata:
  name: sqs-reader-sa
  namespace: keda
  annotations:
    eks.amazonaws.com/role-arn: ${sqs_reader_role_arn}
automountServiceAccountToken: true
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sqs-reader-sa
  namespace: vllm
  annotations:
    eks.amazonaws.com/role-arn: ${sqs_reader_role_arn}
automountServiceAccountToken: true
