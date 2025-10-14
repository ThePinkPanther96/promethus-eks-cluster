# EKS Monitoring & Apps
----
Production-ready, manifest-first **EKS** setup: a two-AZ cluster with **ALB Ingress (TLS/ACM)**, persistent storage via **EBS CSI (gp3)**, and full observability using **kube-prometheus-stack** (Prometheus, Alertmanager, Grafana). It deploys two sample apps (Rick & Morty, Weather) exposed by host-based Ingress and autoscaled with **HPA** using **metrics-server**. **ServiceMonitors** connect the apps to Prometheus, while Grafana provides dashboards—everything rendered to YAML and applied with kubectl.

![Alt desc](https://github.com/ThePinkPanther96/promethus-eks-cluster/blob/main/diagram.png)

## Project Structure
---
```
.
├── eks
│   ├── cluster-config.yml
│   └── ns.yml
├── infra
│   └── iam
│       ├── alb-iam-policy.json
│       └── crds.yaml
├── manifests
│   ├── apps
│   │   ├── as-hpa.yaml
│   │   ├── ingress.yml
│   │   ├── ns-apps.yml
│   │   ├── rick-n-morty
│   │   │   └── deploy.yml
│   │   └── weather
│   │       └── deploy.yml
│   ├── observability
│   │   ├── kube-prometheus-crds.yml
│   │   ├── kube-prometheus-stack.yml
│   │   ├── servicemonitors.yml
│   │   └── values-kps.yml
│   ├── storage
│   │   ├── pvcs
│   │   │   └── grafana-pvc.yaml
│   │   └── sc-gp3-default.yaml
│   └── system
│       ├── alb-controller.yaml
│       ├── ebs-csi-csidriver.yaml
│       ├── ebs-csi-driver.yaml
│       └── metrics-server.yml
└── README.md
```

- ` eks/ – EKS/eksctl` configs used to create and manage the cluster.
    
- `eks/cluster-config.yml` – `eksctl` cluster spec (region/AZs/nodegroup min–max, addons).
    
- `eks/ns.yml `– creates observability-ns (and/or base namespaces as needed).
    
- `infra/iam/` – IAM artifacts for controllers.
    
- `infra/iam/alb-iam-policy.json` – AWSLoadBalancerController IAM policy document.
    
- `infra/iam/crds.yaml` – ALB controller CRDs (IngressClassParams/TargetGroupBinding).
    
- `manifests/` – all Kubernetes YAML applied to the cluster.
    
- `manifests/apps/` – application layer (namespaces, Deployments, Services, Ingress, HPAs).
    
- `manifests/apps/as-hpa.yaml `– HPAs for rick-n-morty & weather (CPU 70%, min/max replicas).
    
- `manifests/apps/ingress.yml` – ALB Ingress with TLS + host rules to the two Services.
    
- `manifests/apps/ns-apps.yml` – creates apps namespace.
    
- `manifests/apps/rick-n-morty/deploy.yml` – Deployment (port 5002) + Service (:80→5002) for Rick & Morty API.
    
- `manifests/apps/weather/deploy.yml` – Deployment (port 5001) + Service (:80→5001) for Weather app.
    
- `manifests/observability/` – Prometheus/Alertmanager/Grafana stack.
    
- `manifests/observability/kube-prometheus-crds.yml` – Prometheus Operator CRDs (server-side applied).
    
- `manifests/observability/kube-prometheus-stack.yml` – rendered kube-prometheus-stack (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics, Grafana Ingress/Service).
    
- `manifests/observability/servicemonitors.yml `– ServiceMonitors pointing Prometheus at the app Services.
    
- `manifests/observability/values-kps.yml `– Helm values used to render the stack YAML.
    
- `manifests/storage/ `– storage configuration.
    
- `manifests/storage/pvcs/grafana-pvc.yaml` – PVC for Grafana data (gp3 via EBS CSI).
    
- `manifests/storage/sc-gp3-default.yaml `– default gp3 StorageClass (dynamic EBS provisioning).
    
- `manifests/system/ `– cluster system controllers.
    
- `manifests/system/alb-controller.yaml` – AWS Load Balancer Controller (IRSA-bound Deployment + webhooks/RBAC).
    
- `manifests/system/ebs-csi-csidriver.yaml` – CSIDriver object for AWS EBS CSI.
    
- `manifests/system/ebs-csi-driver.yaml` – rendered EBS CSI controller + node DaemonSet and RBAC.
    
- `manifests/system/metrics-server.yml `– rendered metrics-server for HPA CPU/memory metrics.
## Prerequisites
---
- AWS account + IAM permissions
    
- **CLI tools**: `aws, kubectl, eksctl, helm`
    
- An **EKS cluster** named monitoring-eks in eu-central-1
    
- A public domain in **Route53**, and an **ACM certificate** in eu-central-1
    
- Local `kubeconfig` pointing at the cluster:

	```sh
	aws eks update-kubeconfig --region eu-central-1 --name monitoring-eks
	```

## Setup
---
The following commands were used during the original setup.

**Namespaces & OIDC**
```sh
kubectl apply -f ns.yml
eksctl utils associate-iam-oidc-provider --cluster monitoring-eks --region eu-central-1 --approve
```

**ALB Ingress Controller (IRSA + controller)**
```sh
# Create IAM policy (once)
curl -o infra/iam/alb-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://infra/iam/alb-iam-policy.json

# Bind the role to the serviceaccount (IRSA)
eksctl create iamserviceaccount \
  --cluster monitoring-eks \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --region eu-central-1 \
  --override-existing-serviceaccounts \
  --approve

# CRDs (for IngressClassParams/TargetGroupBinding)
kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml

# Controller manifests
kubectl apply -f manifests/system/alb-controller.yaml
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
```

**EBS CSI + default gp3**
```sh
# IRSA for EBS CSI controller
eksctl create iamserviceaccount \
  --cluster monitoring-eks \
  --namespace kube-system \
  --name ebs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --region eu-central-1 \
  --approve

# Rendered driver + CSIDriver
kubectl apply -n kube-system -f manifests/system/ebs-csi-driver.yaml
kubectl apply -f manifests/system/ebs-csi-csidriver.yaml

# Default StorageClass
kubectl apply -f manifests/storage/sc-gp3-default.yaml
```

**kube-prometheus-stack (Prometheus/Alertmanager/Grafana)**
```sh
# CRDs 
kubectl apply --server-side -f manifests/observability/kube-prometheus-crds.yml

# Rendered stack
kubectl apply -f manifests/observability/kube-prometheus-stack.yml
kubectl -n observability-ns get pods
```

**Grafana admin secret (On-time):**
```sh
kubectl -n observability-ns create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="YOUR_PASSWORD"
```

**Apps and Ingress deployment**
```sh
# Deploy apps (container ports: rick-n-morty=5002, weather=5001)
kubectl apply -f manifests/apps/rick-n-morty/deploy.yml
kubectl apply -f manifests/apps/weather/deploy.yml

# Host-based Ingress + TLS (ACM)
kubectl apply -f manifests/apps/ingress.yml
kubectl -n apps get ingress apps-ing
```
>[!tip]
>**Route53**: create CNAMEs rick-n-morty.<domain> and weather.<domain> to the ALB DNS shown by the Ingress.

**ServiceMonitors & metrics-server & HPAs**
```sh
# Tell Prometheus to scrape the app Services
kubectl apply -f manifests/observability/servicemonitors.yml

# metrics-server
kubectl apply -f manifests/system/metrics-server.yml
kubectl get apiservice v1beta1.metrics.k8s.io -o wide

# Horizontal Pod Autoscalers (CPU 70%, 2–6 replicas)
kubectl apply -f manifests/apps/as-hpa.yaml
kubectl -n apps get hpa
```

## Sanity checks
---
```sh
# Nodes & pods
kubectl get nodes -o wide
kubectl -n observability-ns get pods -o wide
kubectl -n apps get deploy,svc,endpoints

# Ingress & ALB
kubectl -n apps get ingress apps-ing -o wide
kubectl get targetgroupbindings.elbv2.k8s.aws -A
kubectl -n kube-system logs deploy/aws-load-balancer-controller -f

# Storage
kubectl get storageclass
kubectl -n observability-ns get pvc
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-ebs-csi-driver

# HPAs & metrics
kubectl -n apps get hpa
kubectl top nodes
kubectl -n apps top pods
```

## URLs
---

- **Grafana**: `https://grafana.<your-domain>`
    
- **Rick and Morty App**: `https://rick-n-morty.<your-domain>`

- **Weather App**: `https://weather.<your-domain>`

## Troubleshooting  notes
---

- **ALB not created**
  Ensure ALB CRDs are installed and `aws-load-balancer-controller` is healthy. Check logs.

- **ALB has empty target groups / 503**
  Confirm Service selectors match Pod labels, container containerPort matches Service targetPort, `probes/healthcheck` path are correct.
    
- **Pods Pending (Too many pods)**
  Scale node group (e.g., `eksctl scale nodegroup --cluster monitoring-eks --name ng-general --nodes 3`).
    
- **PVC Pending**
  EBS CSI controller/daemonset running? gp3 set as default? Check `kubectl` describe pvc.
    
- **HPA says “unable to fetch metrics”**
  Verify `v1beta1.metrics.k8s.io` APIServer is **Available: True**.

## Cleanup
---
```sh
# Apps + Ingress
kubectl delete -f manifests/apps

# Observability
kubectl delete -f manifests/observability/servicemonitors.yml
kubectl delete -f manifests/observability/kube-prometheus-stack.yml
kubectl delete -f manifests/observability/kube-prometheus-crds.yml --ignore-not-found

# System
kubectl delete -f manifests/system/metrics-server.yml
kubectl delete -f manifests/system/ebs-csi-csidriver.yaml
kubectl delete -f manifests/system/ebs-csi-driver.yaml
kubectl delete -f manifests/storage/sc-gp3-default.yaml
kubectl delete -f manifests/system/alb-controller.yaml

# Namespaces
kubectl delete -f ns.yml
```
