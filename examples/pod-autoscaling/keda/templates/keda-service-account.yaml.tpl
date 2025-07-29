apiVersion: v1
kind: ServiceAccount
metadata:
  name: keda-sa
  namespace: keda
  annotations:
    eks.amazonaws.com/role-arn: ${keda_role_arn}
automountServiceAccountToken: true
