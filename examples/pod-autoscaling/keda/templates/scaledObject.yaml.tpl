apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: model-qwen3-4b-fp8-scaler
  namespace: vllm
  labels:
    app: model-qwen3-4b-fp8
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: model-qwen3-4b-fp8
  pollingInterval:  5   # Default: 30 seconds
  cooldownPeriod:  10   # Default: 300 seconds
  idleReplicaCount: 0   # Default: ignored
  minReplicaCount:  0   # Default: 0
  maxReplicaCount:  10   # Default: 100
  triggers:
  - type: aws-sqs-queue
    metadata:
      queueURL: ${sqs_queue_url}
      queueLength: "5"
      awsRegion: ${aws_region}
      identityOwner: operator
