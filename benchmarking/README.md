# LLM Benchmarking for EKS Auto Mode

## Overview
This directory contains benchmarking tools for testing LLM performance on EKS Auto Mode clusters using [llmperf](https://github.com/ray-project/llmperf). The benchmarking suite is designed to test OpenAI-compatible endpoints deployed on your EKS cluster through port-forwarding.

## Prerequisites

- EKS cluster with deployed LLM service
- `kubectl` configured to access your cluster
- Python 3.10+
- Port-forwarding access to your LLM service

## Installation

The benchmark script automatically handles installation:

1. **Creates Python virtual environment** in `./venv/`
2. **Clones and installs llmperf** from the official repository
3. **Manages dependencies** within the isolated environment

No manual installation required - just run the script!

## Quick Start

1. **Port-forward your LLM service**:
```bash
kubectl port-forward service/your-llm-service 8080:80
```

2. **Run the benchmark**:
```bash
./run_benchmark.sh
```

> **Note**: The script automatically creates a Python virtual environment and installs llmperf on first run.

## Environment Variables

Configure the following environment variables before running benchmarks:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `OPENAI_API_BASE` | Base URL for the OpenAI-compatible API | `http://localhost:8080/v1` | No |
| `OPENAI_API_KEY` | API key (use dummy value for local testing) | `` | No |
| `MODEL_NAME` | Model name to benchmark | `meta-llama/Llama-2-7b-chat-hf` | No |
| `MAX_REQUESTS` | Maximum number of requests to send | `10` | No |
| `CONCURRENT_REQUESTS` | Number of concurrent requests | `2` | No |
| `MEAN_INPUT_TOKENS` | Average input tokens per request | `550` | No |
| `MEAN_OUTPUT_TOKENS` | Average output tokens per request | `150` | No |
| `TIMEOUT` | Request timeout in seconds | `600` | No |

## Usage Examples

### Basic Load Test
```bash
export OPENAI_API_BASE="http://localhost:8001/v1"
export MODEL_NAME="Llama-3.2-3B-Instruct"
./run_benchmark.sh
```

### Custom Configuration
```bash
export OPENAI_API_BASE="http://localhost:8080/v1"
export MODEL_NAME="Llama-3.2-3B-Instruct"
export MAX_REQUESTS="50"
export CONCURRENT_REQUESTS="5"
export MEAN_INPUT_TOKENS="1000"
export MEAN_OUTPUT_TOKENS="200"
./run_benchmark.sh
```

### GPU Workload Testing
For GPU-accelerated models:
```bash
export MODEL_NAME="your-gpu-model"
export CONCURRENT_REQUESTS="1"  # Lower concurrency for GPU models
export MEAN_OUTPUT_TOKENS="500"  # Longer outputs for GPU testing
./run_benchmark.sh
```

## Results

Benchmark results are saved in the `results/` directory with:
- Summary metrics file
- Individual request metrics
- Timestamp-based organization

## Port-Forwarding Examples

### Standard Service
```bash
kubectl port-forward service/llm-service 8080:80
```

### GPU Service with Load Balancer
```bash
kubectl port-forward service/gpu-llm-service 8080:8080
```

### Neuron Inference Service
```bash
kubectl port-forward service/neuron-service 8080:8000
```

## Troubleshooting

### Connection Issues
- Verify port-forwarding is active: `curl http://localhost:8080/v1/models`
- Check service status: `kubectl get svc`
- Verify pod readiness: `kubectl get pods`

### Performance Issues
- Reduce concurrent requests for resource-constrained deployments
- Adjust timeout values for slower models
- Monitor cluster resources: `kubectl top nodes`

## Integration with EKS Examples

This benchmarking suite works with all EKS Auto Mode examples:

- **Graviton workloads**: ARM64-optimized performance testing
- **GPU workloads**: ML/AI model performance validation
- **Neuron workloads**: Inferentia2 inference benchmarking
- **Spot workloads**: Cost-effective deployment testing