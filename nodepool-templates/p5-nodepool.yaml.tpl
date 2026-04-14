---
apiVersion: eks.amazonaws.com/v1
kind: NodeClass
metadata:
  name: p5-nodeclass
spec:
  role: ${node_iam_role_name}
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "automode-demo"
  securityGroupSelectorTerms:
    - tags:
        aws:eks:cluster-name: ${cluster_name}
  tags:
    karpenter.sh/discovery: "automode-demo"
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: p5-nodepool
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: p5-nodeclass
      requirements:
        - key: "eks.amazonaws.com/instance-family"
          operator: In
          values: [ "p5", "p5e", "p5en" ]
        - key: "eks.amazonaws.com/instance-size"
          operator: In
          values: [ "4xlarge", "48xlarge" ]
        - key: "karpenter.sh/capacity-type"
          operator: In
          # On-demand listed first to prioritize it over spot
          values: ["on-demand", "spot"]
      taints:
        - key: "nvidia.com/gpu"
          value: "true"
          effect: NoSchedule
  limits:
    # Limit to 1 instance to control costs
    # p5.48xlarge has 192 vCPUs, so this allows 1 node
    cpu: 200
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 30s
