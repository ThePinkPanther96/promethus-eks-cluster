# Create the cluster: 
eksctl create cluster -f cluster-config.yml

# Verify access
aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $CLUSTER_NAME
kubectl get nodes -o wide
kubectl get ns

# Deploy and test the namespaces
kubectl apply -f ns.yml
kubectl get ns observability-ns

# Verify OIDC
eksctl utils associate-iam-oidc-provider --cluster monitoring-eks --region eu-central-1 --approve

# Download the service account policy:
curl -o alb-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create the ALB controller IAM policy 
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://alb-iam-policy.json

# Take note of the policy ARN

# Creats an IAM role with this command that trusts the cluster’s OIDC, and binds it to a K8s service account kube-system/aws-load-balancer-controller.
eksctl create iamserviceaccount \
  --cluster=monitoring-eks \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn="arn:aws:iam::021891580761:policy/AWSLoadBalancerControllerIAMPolicy" \
  --override-existing-serviceaccounts \
  --region=eu-central-1 \
  --approve

#  Install ALB controller CRDs
cd infra/iam   # or anywhere you keep third-party assets
wget https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds # install controller
kubectl apply -f crds.yaml
kubectl get crd | grep elbv2.k8s.aws

# Install the ALB controller to manifests and apply
kubectl apply -f manifests/system/alb-controller.yaml
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller

# Create the IRSA role & service account for the EBS CSI driver. 
# create a service account in kube-system with an IAM role that has the AmazonEBSCSIDriverPolicy attached.
eksctl create iamserviceaccount \
  --cluster monitoring-eks \
  --namespace kube-system \
  --name ebs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --region eu-central-1 \
  --approve

# Install the EBS CSI driver (rendered to manifests) - Add the repo, render to a single YAML, and apply:
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo update

mkdir -p manifests/system
helm template ebs-csi aws-ebs-csi-driver/aws-ebs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=ebs-csi-controller-sa \
  > manifests/system/ebs-csi-driver.yaml

kubectl apply -n kube-system -f manifests/system/ebs-csi-driver.yaml

kubectl apply -f manifests/system/ebs-csi-csidriver.yaml

kubectl apply -f manifests/storage/sc-gp3-default.yaml

kubectl apply -f manifests/storage/pvcs/grafana-pvc.yaml

# kube-prometheus-stack (Prometheus + Alertmanager + Grafana) with persistence + ALB: 
# Create grafana admin secret, writ values (persistence, retention, Grafana Ingress via ALB), install the Prometheus Operator CRDs:
