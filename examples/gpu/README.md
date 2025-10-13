# GPU Workloads on EKS Auto Mode

## Table of Contents
- [Overview](#overview)
- [Part 1: Basic GPU Deployment](#part-1-basic-gpu-deployment)
- [Part 2: KEDA Prometheus-Based Autoscaling](#part-2-keda-prometheus-based-autoscaling)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

## Overview
This example demonstrates running GPU-accelerated AI workloads on EKS Auto Mode with KEDA autoscaling based on Prometheus metrics:

🚀 **GPU Acceleration**
- NVIDIA GPU instances (G5, G6, G6e)
- Optimized for ML/AI inference workloads
- Automatic GPU node provisioning with Karpenter

📊 **KEDA Prometheus Autoscaling**
- Scale based on vLLM GPU utilization metrics
- Scale based on request queue depth
- Zero-to-N scaling for cost optimization

🤖 **AI Model Serving**
- vLLM OpenAI-compatible API server
- Qwen3-4B-Instruct-FP8 model for high-performance inference
- Built-in Prometheus metrics export on port 8000

## Part 1: Basic GPU Deployment

### Prerequisites
- EKS Auto Mode cluster deployed
- GPU quota available in your AWS account
- kubectl configured

### Deploy GPU NodePool
```bash
kubectl apply -f ../../nodepools/gpu-nodepool.yaml
```

### Deploy vLLM Model with Metrics
```bash
# Create namespace
kubectl create namespace vllm-inference

# Create HuggingFace secret (if needed)
kubectl create secret generic hf-secret \
  --from-literal=token=your_hf_token \
  -n vllm-inference

# Deploy the model with metrics enabled
kubectl apply -f model-qwen3-4b-instruct-fp8.yaml
```

### Verify Deployment
```bash
kubectl get pods -n vllm-inference
kubectl logs -f deployment/qwen3-4b-instruct-fp8 -n vllm-inference
```

## Part 2: KEDA Prometheus-Based Autoscaling

### Architecture
KEDA scales the vLLM deployment based on Prometheus metrics from the model server, including GPU utilization and request queue depth.

### Setup Steps

#### 1. Install KEDA
```bash
# Add KEDA Helm repository
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

# Install KEDA
helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --version 2.17.0 \
  --values keda-helm-values.yaml
```

#### 2. Setup Prometheus Stack
```bash
# Install Prometheus using Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values prometheus-values.yaml
```

#### 3. Create KEDA ScaledObject
```bash
kubectl apply -f prometheus-scaledObject.yaml
```

#### 4. Test Scaling
```bash
# Generate load to trigger scaling
kubectl apply -f load-generator.yaml

# Monitor scaling
kubectl get scaledobject -n vllm-inference --watch
kubectl get deployment qwen3-4b-instruct-fp8 -n vllm-inference --watch
```

#### 5. Monitor Metrics
```bash
# Port-forward to Prometheus UI
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring

# Access Prometheus at http://localhost:9090
# Query: vllm:gpu_cache_usage_perc
# Query: vllm:num_requests_waiting
```

#### 6. View KEDA Metrics
```bash
# Check KEDA ScaledObject status
kubectl describe scaledobject -n vllm-inference

# View KEDA metrics API
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/vllm-inference/vllm_gpu_cache_usage_perc"
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/vllm-inference/vllm_num_requests_waiting"

# Check HPA created by KEDA
kubectl get hpa -n vllm-inference
kubectl describe hpa -n vllm-inference
```

## Cleanup

### Remove KEDA Resources
```bash
kubectl delete -f prometheus-scaledObject.yaml
helm uninstall keda -n keda
```

### Remove Prometheus
```bash
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring
```

### Remove vLLM Deployment
```bash
kubectl delete -f model-qwen3-4b-instruct-fp8.yaml
kubectl delete namespace vllm-inference
```

## Troubleshooting

### GPU Node Issues
```bash
# Check GPU nodes
kubectl get nodes -l node.kubernetes.io/instance-type

# Check GPU resources
kubectl describe node <gpu-node-name>
```

### KEDA Issues
```bash
# Check KEDA logs
kubectl logs -n keda deployment/keda-operator

# Check ScaledObject status
kubectl describe scaledobject -n vllm-inference

# Verify Prometheus service name
kubectl get svc -n monitoring | grep prometheus

# Check Prometheus connectivity (use actual service name)
kubectl exec -n keda deployment/keda-operator -- wget -qO- http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
```

### Model Loading Issues
```bash
# Check pod events
kubectl describe pod <pod-name> -n vllm-inference

# Check model download progress
kubectl logs <pod-name> -n vllm-inference -f
```

### Prometheus Metrics Issues
```bash
# Check if ServiceMonitor is created
kubectl get servicemonitor -n vllm-inference

# Verify service labels match ServiceMonitor selector
kubectl get svc vllm-service -n vllm-inference --show-labels

# Test metrics endpoint directly
kubectl exec -n vllm-inference deployment/qwen3-4b-instruct-fp8 -- curl -s http://localhost:8000/metrics | grep vllm

# Test Prometheus query (use correct syntax for colon in metric names)
kubectl run prometheus-test --rm -i --image=curlimages/curl:8.5.0 -n vllm-inference --restart=Never -- curl -s "http://prometheus-operated.monitoring.svc:9090/api/v1/query?query=sum({__name__=~\"vllm:gpu_cache_usage_perc\"})"

# Apply ServiceMonitor for metrics scraping
kubectl apply -f vllm-servicemonitor.yaml
```