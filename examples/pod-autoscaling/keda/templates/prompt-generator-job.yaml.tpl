apiVersion: batch/v1
kind: Job
metadata:
  name: prompt-generator
  namespace: keda
spec:
  template:
    spec:
      serviceAccountName: sqs-reader-sa
      restartPolicy: Never
      containers:
      - name: prompt-generator
        image: python:3.9-slim
        command: ["/bin/bash"]
        args:
          - -c
          - |
            pip install boto3
            python /app/prompt-generator.py
        env:
        - name: SQS_QUEUE_URL
          value: "${sqs_queue_url}"
        - name: AWS_REGION
          value: "${aws_region}"
        - name: NUM_MESSAGES
          value: "50"  # Generate 50 messages
        - name: DELAY_SECONDS
          value: "0.5"  # 0.5 second delay between messages
        volumeMounts:
        - name: script-volume
          mountPath: /app
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: script-volume
        configMap:
          name: prompt-generator-script
          defaultMode: 0755
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prompt-generator-script
  namespace: keda
data:
  prompt-generator.py: |
    #!/usr/bin/env python3
    import boto3
    import json
    import random
    import time
    import os
    from datetime import datetime

    # Sample prompts for testing
    SAMPLE_PROMPTS = [
        "Explain quantum computing in simple terms",
        "Write a short story about a robot learning to paint",
        "What are the benefits of renewable energy?",
        "Describe the process of photosynthesis",
        "How does machine learning work?",
        "Write a poem about the ocean",
        "Explain the theory of relativity",
        "What is the future of artificial intelligence?",
        "Describe the water cycle",
        "Write a recipe for chocolate chip cookies",
        "How do neural networks function?",
        "What are the causes of climate change?",
        "Explain blockchain technology",
        "Write a dialogue between two characters meeting for the first time",
        "What is the importance of biodiversity?",
        "Describe the structure of an atom",
        "How does the internet work?",
        "Write a summary of the solar system",
        "What are the principles of sustainable development?",
        "Explain the concept of time dilation"
    ]

    def send_prompt_to_sqs(sqs_client, queue_url, prompt, message_id):
        """Send a prompt to the SQS queue"""
        message_body = {
            "id": message_id,
            "prompt": prompt,
            "timestamp": datetime.utcnow().isoformat(),
            "parameters": {
                "max_tokens": 150,
                "temperature": 0.7
            }
        }
        
        try:
            response = sqs_client.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(message_body),
                MessageAttributes={
                    'prompt_type': {
                        'StringValue': 'text_generation',
                        'DataType': 'String'
                    }
                }
            )
            return response['MessageId']
        except Exception as e:
            print(f"Error sending message: {e}")
            return None

    def main():
        # Get configuration from environment variables
        queue_url = os.getenv('SQS_QUEUE_URL')
        aws_region = os.getenv('AWS_REGION', 'us-west-2')
        num_messages = int(os.getenv('NUM_MESSAGES', '10'))
        delay_seconds = float(os.getenv('DELAY_SECONDS', '1.0'))
        
        if not queue_url:
            print("Error: SQS_QUEUE_URL environment variable is required")
            return
        
        # Initialize SQS client
        sqs_client = boto3.client('sqs', region_name=aws_region)
        
        print(f"Starting prompt generator...")
        print(f"Queue URL: {queue_url}")
        print(f"Region: {aws_region}")
        print(f"Number of messages: {num_messages}")
        print(f"Delay between messages: {delay_seconds} seconds")
        print("-" * 50)
        
        successful_sends = 0
        
        for i in range(num_messages):
            # Select a random prompt
            prompt = random.choice(SAMPLE_PROMPTS)
            message_id = f"msg-{i+1:04d}-{int(time.time())}"
            
            print(f"Sending message {i+1}/{num_messages}: {prompt[:50]}...")
            
            # Send to SQS
            sqs_message_id = send_prompt_to_sqs(sqs_client, queue_url, prompt, message_id)
            
            if sqs_message_id:
                successful_sends += 1
                print(f"✓ Sent successfully (SQS ID: {sqs_message_id[:8]}...)")
            else:
                print(f"✗ Failed to send message {i+1}")
            
            # Wait before sending next message (except for the last one)
            if i < num_messages - 1:
                time.sleep(delay_seconds)
        
        print("-" * 50)
        print(f"Completed: {successful_sends}/{num_messages} messages sent successfully")

    if __name__ == "__main__":
        main()
