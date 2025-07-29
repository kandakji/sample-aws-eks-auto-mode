# Pod Autoscaling on EKS Auto Mode

## Table of Contents
- [Overview](#overview)
- [Part 1: Horizontal Pod Autoscaler (HPA)](#part-1-horizontal-pod-autoscaler-hpa)
  - [HPA Architecture](#hpa-architecture)
  - [HPA Implementation Steps](#hpa-implementation-steps)
  - [HPA Cleanup](#hpa-cleanup)
- [Part 2: KEDA Event-Driven Autoscaling](#part-2-keda-event-driven-autoscaling)
- [Troubleshooting](#troubleshooting)

## Overview
Pod autoscaling is essential for maintaining optimal performance and cost efficiency in Kubernetes clusters. This example demonstrates two complementary approaches:

📊 **Horizontal Pod Autoscaler (HPA)**
- CPU and memory-based scaling
- Built-in Kubernetes functionality
- Ideal for traditional web applications

🎯 **KEDA (Kubernetes Event-Driven Autoscaling)**
- Event-driven scaling based on external metrics
- Supports 60+ scalers (SQS, Kafka, Redis, etc.)
- Perfect for event-driven and batch workloads

⚡ **Key Benefits**
- Automatic scaling based on demand
- Cost optimization through right-sizing
- Improved application performance and availability

## Part 1: Horizontal Pod Autoscaler (HPA)

### HPA Architecture
The HPA automatically scales the number of pods in a deployment based on observed CPU utilization, memory usage, or custom metrics.

**How it works**:
1. 📈 **Metrics Collection**: Metrics Server collects resource usage from pods
2. 🔍 **Evaluation**: HPA controller evaluates metrics against target thresholds
3. ⚖️ **Scaling Decision**: Calculates desired replica count based on current vs target metrics
4. 🔄 **Pod Adjustment**: Updates deployment replica count to match demand

**Key Components**:
- **Metrics Server**: Collects resource metrics from kubelets
- **HPA Controller**: Makes scaling decisions based on metrics
- **Target Deployment**: The workload being scaled
- **Load Generator**: Simulates traffic to trigger scaling

### HPA Implementation Steps

#### 1. Setup EKS Auto Mode Cluster
First, deploy your EKS cluster using Terraform:

```bash
cd sample-aws-eks-auto-mode/terraform

terraform init
terraform apply -auto-approve

$(terraform output -raw configure_kubectl)
```

#### 2. Install Metrics Server
The HPA requires the Metrics Server to collect resource metrics from pods:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

> 📘 **Note**: The Metrics Server collects resource metrics from kubelets and exposes them through the Kubernetes API. It may take a minute or two to become ready.

Verify the Metrics Server is running:
```bash
kubectl get pods -n kube-system | grep metrics-server
```

#### 3. Deploy the Sample Application
Deploy a PHP Apache server that will serve as our scaling target:

```bash
cd ../examples/pod-autoscaling/hpa

kubectl apply -f php-apache.yaml
```

> ✅ **Application Details**: The php-apache deployment includes:
> - **CPU Request**: 200m (200 millicores)
> - **CPU Limit**: 500m (500 millicores)
> - **Container**: `registry.k8s.io/hpa-example` - a simple PHP server
> - **Service**: Exposes the application on port 80

#### 4. Create the HorizontalPodAutoscaler
Create an HPA that maintains between 1 and 10 replicas based on CPU utilization:

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

Alternatively, you can use the declarative approach:

```bash
kubectl apply -f hpa.yaml
```

#### 5. Verify HPA Status
Check the current status of the HPA:

```bash
kubectl get hpa
```

Expected output:
```
NAME         REFERENCE                     TARGET    MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   0% / 50%  1         10        1          18s
```

> 📘 **Note**: The current CPU consumption shows 0% because there's no load on the server yet.

#### 6. Generate Load to Trigger Scaling
Start a load generator to increase CPU utilization:

```bash
# Run this in a separate terminal
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```

#### 7. Watch the Scaling in Action
In another terminal, monitor the HPA scaling behavior:

```bash
# Press Ctrl+C to stop watching when ready
kubectl get hpa php-apache --watch
```

Within a minute, you should see increased CPU load:
```
NAME         REFERENCE                     TARGET      MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   305% / 50%  1         10        1          3m
```

Then observe the replica count increase (will stabilize between 6-8):
```
NAME         REFERENCE                     TARGET      MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   305% / 50%  1         10        8          3m
```

Verify the deployment scaling:
```bash
kubectl get deployment php-apache
```

Expected output:
```
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   8/8     8            8           19m
```

#### 8. Stop Load Generation and Observe Scale-Down
Stop the load generator by pressing `Ctrl+C` in the load generator terminal.

Monitor the scale-down process:
```bash
kubectl get hpa php-apache --watch
```

After a few minutes, you'll see the CPU utilization drop and replicas scale back down:
```
NAME         REFERENCE                     TARGET       MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache/scale   0% / 50%     1         10        1          11m
```

> ⏱️ **Scaling Timing**: 
> - **Scale-up**: Typically occurs within 1-2 minutes of increased load
> - **Scale-down**: Takes 5-10 minutes to ensure stability before reducing replicas

### HPA Cleanup

Remove the HPA resources:

```bash
kubectl delete pod load-generator

# Remove the HPA
kubectl delete hpa php-apache

# Remove the application
kubectl delete -f php-apache.yaml
```

> 📚 **Attribution**: This HPA demo was adapted from the [Kubernetes HorizontalPodAutoscaler Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/).

## Part 2: KEDA Event-Driven Autoscaling

> 🚧 **Coming Soon**: The KEDA section will demonstrate:
> - Installing KEDA on EKS Auto Mode
> - Setting up SQS-based scaling for GPU workloads
> - Event-driven autoscaling with custom metrics
> - Integration with Karpenter for node-level scaling

### Quick Setup (Basic Steps)

```bash
# 1. Deploy AWS resources and generate manifests
cd terraform
terraform init
terraform apply -auto-approve

# 2. Apply Kubernetes manifests (go back to keda directory)
cd ..
kubectl apply -f namespace.yaml
kubectl apply -f keda-service-account.yaml
kubectl apply -f sqs-reader-service-account.yaml

# 3. Install KEDA with Helm
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --version 2.17.0 --values keda-helm-values.yaml

# 4. Deploy the model application with SQS consumer
kubectl apply -f ../../../nodepools/gpu-nodepool.yaml
kubectl apply -f vllm-qwen3/namespace.yaml
kubectl apply -f vllm-qwen3/model-qwen3-4b-fp8-with-sqs.yaml

# 5. Deploy the ScaledObject for autoscaling
kubectl apply -f scaledObject.yaml

# 6. (Optional) Generate test prompts to trigger scaling
kubectl apply -f prompt-generator-job.yaml
```

Check how many messages in queue:
```bash
cd terraform
QUEUE_URL=$(terraform output -raw sqs_url)
aws sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names ApproximateNumberOfMessages
```

### KEDA Cleanup

To clean up the KEDA autoscaling components:

```bash
# 1. Remove Kubernetes resources
kubectl delete job prompt-generator -n keda --ignore-not-found
kubectl delete -f scaledObject.yaml --ignore-not-found
kubectl delete -f vllm-qwen3/model-qwen3-4b-fp8-with-sqs.yaml --ignore-not-found

# 2. Uninstall KEDA
helm uninstall keda -n keda

# 3. Remove service accounts and namespace resources
kubectl delete -f sqs-reader-service-account.yaml --ignore-not-found
kubectl delete -f keda-service-account.yaml --ignore-not-found
kubectl delete namespace keda --ignore-not-found
kubectl delete namespace vllm --ignore-not-found

# 4. Destroy AWS resources (SQS, IAM roles)
cd terraform
terraform destroy -auto-approve
```
