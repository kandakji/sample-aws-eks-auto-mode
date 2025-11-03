#!/bin/bash

set -e

# Default environment variables
OPENAI_API_BASE="${OPENAI_API_BASE:-http://localhost:8080/v1}"
OPENAI_API_KEY="${OPENAI_API_KEY:-dummy-key}"
MODEL_NAME="${MODEL_NAME:-meta-llama/Llama-2-7b-chat-hf}"
MAX_REQUESTS="${MAX_REQUESTS:-10}"
CONCURRENT_REQUESTS="${CONCURRENT_REQUESTS:-2}"
MEAN_INPUT_TOKENS="${MEAN_INPUT_TOKENS:-550}"
MEAN_OUTPUT_TOKENS="${MEAN_OUTPUT_TOKENS:-150}"
TIMEOUT="${TIMEOUT:-600}"
ADDITIONAL_SAMPLING_PARAMS="${ADDITIONAL_SAMPLING_PARAMS:-{}}"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"
RESULTS_DIR="${SCRIPT_DIR}/results"

echo "🚀 Starting LLM Benchmark for EKS Auto Mode"
echo "============================================"

# Create results directory
mkdir -p "${RESULTS_DIR}"

# Create virtual environment if it doesn't exist
if [ ! -d "${VENV_DIR}" ]; then
    echo "📦 Creating virtual environment..."
    python3.10 -m venv "${VENV_DIR}"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source "${VENV_DIR}/bin/activate"

# Install llmperf if not already installed
if ! python -c "import llmperf" 2>/dev/null; then
    echo "📥 Installing llmperf..."
    pip install --upgrade pip
    git clone https://github.com/ray-project/llmperf.git "${SCRIPT_DIR}/llmperf-repo" 2>/dev/null || true
    cd "${SCRIPT_DIR}/llmperf-repo"
    pip install -e .
    cd "${SCRIPT_DIR}"
fi

# Export environment variables
export OPENAI_API_BASE
export OPENAI_API_KEY

echo "⚙️  Configuration:"
echo "   API Base: ${OPENAI_API_BASE}"
echo "   Model: ${MODEL_NAME}"
echo "   Max Requests: ${MAX_REQUESTS}"
echo "   Concurrent Requests: ${CONCURRENT_REQUESTS}"
echo "   Input Tokens: ${MEAN_INPUT_TOKENS}"
echo "   Output Tokens: ${MEAN_OUTPUT_TOKENS}"
echo "   Timeout: ${TIMEOUT}s"
echo ""

# Test connection
echo "🔍 Testing connection to API endpoint..."
if curl -s -f "${OPENAI_API_BASE%/v1}/health" >/dev/null 2>&1 || curl -s -f "${OPENAI_API_BASE}/models" >/dev/null 2>&1; then
    echo "✅ Connection successful"
else
    echo "⚠️  Warning: Could not verify connection to ${OPENAI_API_BASE}"
    echo "   Make sure your service is port-forwarded and accessible"
fi

# Run benchmark
echo "🏃 Running load test benchmark..."
cd "${SCRIPT_DIR}/llmperf-repo"

python token_benchmark_ray.py \
    --model "${MODEL_NAME}" \
    --mean-input-tokens "${MEAN_INPUT_TOKENS}" \
    --stddev-input-tokens 150 \
    --mean-output-tokens "${MEAN_OUTPUT_TOKENS}" \
    --stddev-output-tokens 10 \
    --max-num-completed-requests "${MAX_REQUESTS}" \
    --timeout "${TIMEOUT}" \
    --num-concurrent-requests "${CONCURRENT_REQUESTS}" \
    --results-dir "${RESULTS_DIR}" \
    --llm-api openai \
    --additional-sampling-params "${ADDITIONAL_SAMPLING_PARAMS}"

echo ""
echo "✅ Benchmark completed successfully!"
echo "📊 Results saved to: ${RESULTS_DIR}"
echo ""
echo "📈 Quick summary:"
ls -la "${RESULTS_DIR}"/*.json 2>/dev/null | tail -2 || echo "   No result files found"

# Deactivate virtual environment
deactivate