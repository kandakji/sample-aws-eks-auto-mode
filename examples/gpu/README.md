# GPU Workloads on EKS Auto Mode

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Implementation Steps](#implementation-steps)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

## Overview
[NVIDIA GPUs on Amazon EC2](https://aws.amazon.com/ec2/instance-types/#Accelerated_Computing) supercharge your workloads with powerful GPU acceleration. Key benefits include:

🚀 **High Performance Computing**
- GPU accelerators from g3, g4, g5, g6, p3, and p4 families
- Optimized for machine learning and graphics workloads
- Ideal for running large language models

🤖 **AI/ML Capabilities**
- Perfect for GenAI model deployment
- Supports complex deep learning tasks
- Accelerated model inference

⚙️ **Flexible Configuration**
- Customizable instance types
- Scalable GPU resources
- EKS Auto Mode integration

This example demonstrates deploying a GenAI model ([Qwen 3 32b fp8](https://huggingface.co/Qwen/Qwen3-32B-FP8)) on EKS Auto Mode.

> ⚠️ **Prerequisites**: 
> - You must have a Hugging Face account with an access token!
> - **GPU Instance Availability**: Many AWS accounts have a default service quota of 0 for p* and g* GPU instance types. You may need to request a quota increase through the AWS Service Quotas console before deploying GPU workloads. This process can take 24-48 hours for approval.

## Architecture
This example showcases GPU-accelerated workloads on EKS Auto Mode using the following components:

### 🖥️ Instance Types
- **Default**: G5, G6 or G6e instances (optimized for ML workloads)
- **Customization**: Available in [gpu-nodepool.yaml.tpl](../../nodepool-templates/gpu-nodepool.yaml.tpl)

### 🔧 Key Components
📦 **Infrastructure**
- NodePool and NodeClass for GPU workload management
- Network Load Balancer for external access

🧠 **AI Components**
- Hugging Face model deployment ([Qwen 3 32b fp8](https://huggingface.co/Qwen/Qwen3-32B-FP8))
- Interactive Web UI for model interaction

## Implementation Steps

### 1. Get Hugging Face Access Token
Create a Hugging Face account and generate a FINEGRAINED [Access Token](https://huggingface.co/settings/tokens)

### 2. Setup EKS Auto Mode Cluster
Deploy the cluster using Terraform:
```bash
cd sample-aws-eks-auto-mode/terraform
terraform init
terraform apply -auto-approve
$(terraform output -raw configure_kubectl)
```

### 3. Deploy GPU NodePool
Deploy the NodePool that will manage our GPU instances:

```bash
cd ../nodepools
kubectl apply -f gpu-nodepool.yaml
```

> ⚠️ The GPU NodePool applies the following taint to ensure only GPU-compatible workloads are scheduled on these nodes:
>
> ```yaml
> taints:
>   - key: "nvidia.com/gpu"
>     value: "true"
>     effect: "NoSchedule"   # Prevents non-GPU pods from scheduling
> ```
>
> Any pods that need to run on GPU nodes must include matching tolerations in their specifications.

### 4. Configure Namespace and Secrets

1. **Create Namespace**:
```bash
cd ../examples/gpu
kubectl apply -f namespace.yaml
```

2. **Add Hugging Face Token**:
```bash
# Replace <your_actual_hugging_face_token> with your token
kubectl create secret generic hf-secret \
  -n vllm-inference \
  --from-literal=hf_api_token=<your_actual_hugging_face_token>
```

### 5. Deploy Model and UI

1. **Deploy the Model**:
Following command will deploy Qwen3 32b (fp8). We also have another manifest file that allows you to deploy [Deepseek](vllm-deepseek-gpu.yaml) instead.

```bash
kubectl apply -f model-qwen3-32b-fp8.yaml
```

> ✅ The model deployment includes the required toleration to run on GPU nodes:
>
> ```yaml
> tolerations:
>   - key: "nvidia.com/gpu"     # Matches the GPU node taint
>     value: "true"
>     effect: "NoSchedule"      # Allows scheduling on tainted nodes
> ```
>
> This toleration enables the pods to be scheduled on our GPU-enabled instances.

2. **Deploy the Web UI**:
```bash
kubectl apply -f open-webui.yaml
```

### 6. Configure Load Balancer
Set up the Network Load Balancer for external access:

```bash
# Deploy NLB service
kubectl apply -f lb-service.yaml
```

> ⚠️ **Security Note**: The default configuration creates a GenAI public endpoint with unrestricted access. To enhance security by restricting access to your IP address only, modify the lb-service.yaml file to add the `loadBalancerSourceRanges` field:
>
> 1. Get your current public IP address:
> ```bash
> MY_IP=$(curl -s https://checkip.amazonaws.com)
> echo "Your IP address is: $MY_IP"
> ```
>
> 2. Edit the lb-service.yaml file to add IP restriction. The file should look like this:
> ```yaml
> apiVersion: v1
> kind: Service
> metadata:
>   name: open-webui-service
>   namespace: vllm-inference
>   annotations:
>     service.beta.kubernetes.io/aws-load-balancer-type: external
>     service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
>     service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
> spec:
>   selector:
>     app: open-webui-server
>   type: LoadBalancer
>   loadBalancerClass: eks.amazonaws.com/nlb
>   loadBalancerSourceRanges:
>     - "${MY_IP}/32"    # Restrict to your current IP address
>   ports:
>   - protocol: TCP
>     port: 80
>     targetPort: 8080
> ```
>
> 3. Apply the updated service configuration:
> ```bash
> kubectl apply -f lb-service.yaml
> ```
>
> This approach is recommended over directly modifying the Load Balancer security group, as changes to the security group may be rolled back by Auto Mode functionality.

### 7. Access the Application
After the NLB is provisioned (usually takes 5-10 minutes):

1. **Get the NLB hostname**:
```bash
kubectl get service open-webui-service \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  -n vllm-inference
```

2. Open the URL in your browser to interact with the model! 🤖
> ⚠️ **Select a Model**: If you are unable to select a model, it means the model is still being downloaded as is not yet being served by our inferencing server pod. Just refresh until you see a model available.


## Cleanup

🧹 Follow these steps to clean up all resources:

### 1. Remove Kubernetes Resources
First, remove the application components and node pool:

```bash
# Remove application components
kubectl delete -f lb-service.yaml
kubectl delete -f open-webui.yaml
kubectl delete -f model-qwen3-32b-fp8.yaml
kubectl delete -f namespace.yaml

# Remove GPU node pool
kubectl delete -f ../../nodepools/gpu-nodepool.yaml
```

### 2. Remove Cluster (Optional)
If you're done with the entire cluster:

```bash
# Navigate to Terraform directory
cd ../../terraform

# Initialize and destroy infrastructure
terraform init
terraform destroy --auto-approve
```

> ⚠️ **Warning**: This will delete the entire EKS cluster and all associated resources. Make sure you want to proceed.

## Troubleshooting

🔧 Common issues and their solutions:

### 🎯 Model Deployment Issues
1. **GPU Node Provisioning**
   - Verify nodes are properly labeled for GPU
   - Check node status with `kubectl get nodes`
   - Ensure GPU drivers are initialized

2. **Model Initialization**
   - Check pod logs for startup errors:
     ```bash
     kubectl logs -n vllm-inference deployment/qwen3-32b-fp8
     ```
   - Verify Hugging Face token is valid

### 🔄 Load Balancer Issues
1. **NLB Status**
   - Monitor provisioning progress
   - Check service endpoints
   - Verify security group settings

### 💻 Resource Constraints
1. **GPU Capacity**
   - Ensure sufficient GPU quota in your AWS account
   - Monitor GPU utilization:
     ```bash
     kubectl describe node <node-name>
     ```
   - Check for pod scheduling events:
     ```bash
     kubectl get events -n vllm-inference
     ```

> 💡 **Tip**: Always check pod logs and events first when troubleshooting deployment issues.
