# 🐾 Spring PetClinic Microservices — AWS Production Deployment

> **DMI Cohort-2 Final Group Project**  
> **DevOps Engineer:** Osenat Alonge | GitHub: [etaoko333](https://github.com/etaoko333)  
> **Live URL:** https://eta-oko.com  
> **Platform Repo:** [petclinic-platform](https://github.com/etaoko333/petclinic-platform)  
> **App Repo:** [spring-petclinic-microservices](https://github.com/etaoko333/spring-petclinic-microservices)

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Tools & Technologies](#tools--technologies)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Phase A — Local Testing with Docker Compose](#phase-a--local-testing-with-docker-compose)
- [Phase B — Provision AWS with Terraform + Claude Code](#phase-b--provision-aws-with-terraform--claude-code)
- [Phase C — Build & Push Docker Images to ECR](#phase-c--build--push-docker-images-to-ecr)
- [Phase D — Secrets Manager + External Secrets Operator](#phase-d--secrets-manager--external-secrets-operator)
- [Phase E — Helm Chart Deployment](#phase-e--helm-chart-deployment)
- [Phase F — GitOps with ArgoCD](#phase-f--gitops-with-argocd)
- [Phase G — GitHub Actions CI/CD Pipeline](#phase-g--github-actions-cicd-pipeline)
- [Phase H — ALB Ingress + Route 53 (HTTPS)](#phase-h--alb-ingress--route-53-https)
- [Phase I — Monitoring with Prometheus & Grafana](#phase-i--monitoring-with-prometheus--grafana)
- [Cleanup — Destroy All AWS Resources](#cleanup--destroy-all-aws-resources)
- [Golden Rules](#golden-rules)

---

## Project Overview

This project deploys the [Spring PetClinic Microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) application to AWS using a fully automated, production-grade GitOps pipeline.

**Claude Code CLI** is used to generate all Terraform modules, Kubernetes manifests, and Helm charts. The DevOps Engineer reviews, understands, and applies the generated code.

The application consists of **7 microservices**:

| Service | Purpose | Port |
|---|---|---|
| config-server | Centralised configuration | 8888 |
| discovery-server | Eureka service registry | 8761 |
| api-gateway | Public entry point | 8080 |
| customers-service | Owner & pet management (MySQL) | 8081 |
| vets-service | Veterinarian data (MySQL) | 8083 |
| visits-service | Pet visit records (MySQL) | 8082 |
| admin-server | Spring Boot Admin dashboard | 9090 |

---

## Architecture

```
Developer pushes code to GitHub
        │
GitHub Actions CI Pipeline
  - Build Docker images (Maven -P buildDocker)
  - Push images to ECR with git SHA tag
  - Update Helm values.yaml with new tag
  - Push to petclinic-platform repo
        │
ArgoCD detects change → auto-syncs to EKS
        │
Amazon EKS Cluster (us-east-1)
+--------------------------------------------------+
|  ALB Ingress ← eta-oko.com (HTTPS/443)          |
|      │                                           |
|  api-gateway    admin-server                     |
|  config-server  discovery-server                 |
|  customers      vets       visits                |
|                                                  |
|  Prometheus   Grafana   Zipkin   Fluent Bit      |
|  ArgoCD       External Secrets Operator          |
+--------------------------------------------------+
        │
Amazon RDS MySQL (db.t3.micro)
  credentials synced from AWS Secrets Manager
```

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| Claude Code CLI | Generate all Terraform + K8s + Helm code |
| Terraform | Infrastructure as Code (VPC, EKS, RDS, ECR) |
| Amazon EKS v1.32 | Managed Kubernetes cluster |
| Amazon RDS MySQL | Managed database |
| Amazon ECR | Private container registry |
| ArgoCD | GitOps continuous delivery |
| Helm | Kubernetes package manager |
| GitHub Actions | CI pipeline (build + push) |
| AWS Secrets Manager | Secure credential storage |
| External Secrets Operator | Sync secrets to Kubernetes |
| AWS Load Balancer Controller | ALB Ingress creation |
| AWS ACM | SSL/TLS certificate |
| Route 53 | DNS routing (eta-oko.com) |
| Prometheus + Grafana | Metrics & dashboards |
| Fluent Bit | Log aggregation |
| Zipkin | Distributed tracing |
| Docker Compose | Local testing |

---

## Prerequisites

Ensure these are installed on your WSL2 Ubuntu machine:

```bash
# Verify all tools
aws --version          # AWS CLI
terraform --version    # Terraform >= 1.3.0
kubectl version --client
helm version
docker --version
java --version         # Java 17
claude --version       # Claude Code CLI

# Verify AWS credentials
aws sts get-caller-identity
```

**Required:**
- AWS Account with admin access
- AWS CLI configured (`aws configure`)
- GitHub account with PAT (Personal Access Token)
- Domain name in Route 53 (eta-oko.com)
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)

---

## Repository Structure

This project uses **two repositories** following the GitOps pattern:

```
# App Repo (READ ONLY - source code only)
spring-petclinic-microservices/
  ├── spring-petclinic-api-gateway/
  ├── spring-petclinic-customers-service/
  ├── spring-petclinic-vets-service/
  ├── spring-petclinic-visits-service/
  ├── spring-petclinic-config-server/
  ├── spring-petclinic-discovery-server/
  ├── spring-petclinic-admin-server/
  ├── docker-compose.yml
  └── .github/workflows/ci.yml  ← CI pipeline

# Platform Repo (YOU OWN THIS - infrastructure)
petclinic-platform/
  ├── terraform/
  │   ├── main.tf
  │   ├── variables.tf
  │   ├── outputs.tf
  │   └── modules/
  │       ├── vpc/
  │       ├── eks/
  │       ├── ecr/
  │       └── rds/
  ├── helm/
  │   └── petclinic/
  │       ├── Chart.yaml
  │       ├── values.yaml
  │       └── templates/
  │           ├── _helpers.tpl
  │           ├── deployment.yaml
  │           └── service.yaml
  └── argocd/
      ├── application.yml
      ├── secret-store.yml
      └── external-secret.yml
```

### Create the platform repo:

```bash
# Create on GitHub then clone
git clone https://github.com/etaoko333/petclinic-platform.git
cd petclinic-platform

mkdir -p terraform/modules/{vpc,eks,ecr,rds,secrets}
mkdir -p helm/petclinic/templates
mkdir -p argocd
mkdir -p .github/workflows
```

---

## Phase A — Local Testing with Docker Compose

> Test the full application stack locally before touching AWS.

### Step A1 — Start Docker

```bash
sudo service docker start
docker ps
```

### Step A2 — Review docker-compose.yml

The project already has a complete `docker-compose.yml` with all services + Prometheus + Grafana + Zipkin:

```bash
cat ~/spring-petclinic-microservices/docker-compose.yml
```

### Step A3 — Start the full stack

```bash
cd ~/spring-petclinic-microservices
docker compose up -d
docker compose ps
```

### Step A4 — Verify in browser

| URL | What to Check |
|---|---|
| http://localhost:8080 | PetClinic main app |
| http://localhost:8761 | Eureka — all services registered |
| http://localhost:9090 | Admin Server |
| http://localhost:3030 | Grafana (admin/admin) |
| http://localhost:9091 | Prometheus targets |
| http://localhost:9411 | Zipkin traces |

### Step A5 — Stop when done

```bash
docker compose down -v
```

---

## Phase B — Provision AWS with Terraform + Claude Code

> Use Claude Code CLI to generate all Terraform modules. Review before applying.

### Step B1 — Create root Terraform files

```bash
cd ~/petclinic-platform/terraform

cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
provider "aws" {
  region = var.aws_region
}
EOF

cat > variables.tf << 'EOF'
variable "aws_region"   { default = "us-east-1" }
variable "cluster_name" { default = "petclinic-eks" }
variable "environment"  { default = "production" }
variable "domain"       { default = "eta-oko.com" }
EOF

cat > outputs.tf << 'EOF'
output "cluster_name"      { value = aws_eks_cluster.petclinic.name }
output "cluster_endpoint"  { value = aws_eks_cluster.petclinic.endpoint }
output "configure_kubectl" { value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}" }
output "ecr_urls"          { value = { for k, v in aws_ecr_repository.services : k => v.repository_url } }
output "db_endpoint"       { value = module.rds.db_endpoint }
output "secret_arn"        { value = module.rds.secret_arn }
EOF
```

### Step B2 — Use Claude Code to generate all modules

```bash
cd ~/petclinic-platform
claude
```

**Prompt 1 — VPC Module:**
```
Create a Terraform VPC module in terraform/modules/vpc/
Requirements:
- VPC CIDR 10.0.0.0/16 in us-east-1
- 2 public subnets only, no NAT gateway
- Internet Gateway for outbound traffic
- Availability zones: us-east-1a and us-east-1b
- EKS subnet tags: kubernetes.io/cluster/petclinic-eks=shared
  and kubernetes.io/role/elb=1
- All resources tagged Environment=production
- Files: main.tf, variables.tf, outputs.tf
- Outputs: vpc_id, public_subnet_ids, vpc_cidr
```

**Prompt 2 — EKS Module:**
```
Create a Terraform EKS module in terraform/modules/eks/
Requirements:
- EKS cluster version 1.32 named petclinic-eks
- Managed node group: 2x t3.medium in public subnets
- EBS CSI driver addon, CoreDNS, kube-proxy addons
- OIDC provider for IRSA
- IAM roles: cluster role + node role
- Node role policies: AmazonEKSWorkerNodePolicy,
  AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly,
  AmazonEBSCSIDriverPolicy
- force_detach_policies = true on all roles
- Outputs: cluster_name, cluster_endpoint, oidc_provider_arn
```

**Prompt 3 — ECR Module:**
```
Create a Terraform ECR module in terraform/modules/ecr/
Requirements:
- Create 7 repos: config-server, discovery-server, api-gateway,
  customers-service, vets-service, visits-service, admin-server
- image_tag_mutability = MUTABLE
- force_delete = true (critical for clean terraform destroy)
- scan_on_push = true
- Lifecycle policy: keep last 10 images, expire untagged after 1 day
- Outputs: repository_urls map
```

**Prompt 4 — RDS Module:**
```
Create a Terraform RDS module in terraform/modules/rds/
Requirements:
- RDS MySQL 8.0, instance class db.t3.micro
- Database name: petclinic, Username: petclinic
- Random password 16 chars, special=false
- Allocated storage: 20GB gp2
- skip_final_snapshot = true, deletion_protection = false
- Security group: allow port 3306 from VPC CIDR 10.0.0.0/16
- Store credentials in AWS Secrets Manager as JSON:
  { username, password, endpoint, port, dbname }
- Secret name: petclinic/db-credentials
- recovery_window_in_days = 0
- Outputs: db_endpoint, db_name, secret_arn, db_port
```

**Prompt 5 — Wire all modules:**
```
Update terraform/main.tf to call all 4 modules:
module "vpc", module "eks", module "ecr", module "rds"
Pass vpc_id and subnet_ids between modules as needed.
Add required providers: aws and random.
```

### Step B3 — Apply Terraform

```bash
cd ~/petclinic-platform/terraform

terraform init
terraform validate
terraform plan
terraform apply -auto-approve
# Takes 15-20 minutes
```

### Step B4 — Connect kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name petclinic-eks
kubectl get nodes
# Both nodes should show: Ready
```

---

## Phase C — Build & Push Docker Images to ECR

### Step C1 — Build all images

```bash
cd ~/spring-petclinic-microservices
sudo service docker start

./mvnw clean install -P buildDocker -Dmaven.test.skip=true
# Takes 10-15 minutes

# Verify all 7 images built
docker images | grep springcommunity
```

### Step C2 — Login and push to ECR

```bash
export AWS_ACCOUNT_ID=139561979448
export AWS_REGION=us-east-1
export ECR_REGISTRY=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# Tag and push all 7 images
for SERVICE in config-server discovery-server api-gateway \
  customers-service vets-service visits-service admin-server; do
  echo "Pushing: $SERVICE"
  docker tag springcommunity/spring-petclinic-$SERVICE:latest \
    $ECR_REGISTRY/$SERVICE:latest
  docker push $ECR_REGISTRY/$SERVICE:latest
  echo "Done: $SERVICE"
done
```

### Step C3 — Verify all images in ECR

```bash
for SERVICE in config-server discovery-server api-gateway \
  customers-service vets-service visits-service admin-server; do
  COUNT=$(aws ecr describe-images --repository-name $SERVICE \
    --region us-east-1 --query 'length(imageDetails)' --output text 2>/dev/null)
  echo "$SERVICE: $COUNT image(s)"
done
```

---

## Phase D — Secrets Manager + External Secrets Operator

> Store DB credentials in AWS Secrets Manager. ESO syncs them into Kubernetes Secrets automatically.

### Step D1 — Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true \
  --wait

kubectl get pods -n external-secrets
```

### Step D2 — Create IAM Role for ESO (IRSA)

```bash
export OIDC_PROVIDER=$(aws eks describe-cluster \
  --name petclinic-eks --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text | sed 's|https://||')

export AWS_ACCOUNT_ID=139561979448

# Create trust policy
cat > /tmp/eso-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "${OIDC_PROVIDER}:sub": "system:serviceaccount:external-secrets:external-secrets",
        "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
      }
    }
  }]
}
EOF

# Create role and attach policy
aws iam create-role \
  --role-name petclinic-eso-role \
  --assume-role-policy-document file:///tmp/eso-trust-policy.json

aws iam attach-role-policy \
  --role-name petclinic-eso-role \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite

# Annotate service account
kubectl annotate serviceaccount external-secrets \
  --namespace external-secrets \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-eso-role

kubectl rollout restart deployment/external-secrets -n external-secrets
```

### Step D3 — Create petclinic namespace

```bash
kubectl create namespace petclinic
```

### Step D4 — Create ClusterSecretStore

```bash
kubectl apply -f - << 'EOF'
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
EOF

kubectl get clustersecretstore
```

### Step D5 — Create ExternalSecret

```bash
kubectl apply -f - << 'EOF'
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: petclinic-db-secret
  namespace: petclinic
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: mysql-secret
    creationPolicy: Owner
  data:
  - secretKey: MYSQL_PASSWORD
    remoteRef:
      key: petclinic/db-credentials
      property: password
  - secretKey: MYSQL_USER
    remoteRef:
      key: petclinic/db-credentials
      property: username
  - secretKey: MYSQL_HOST
    remoteRef:
      key: petclinic/db-credentials
      property: endpoint
  - secretKey: MYSQL_DATABASE
    remoteRef:
      key: petclinic/db-credentials
      property: dbname
EOF

sleep 15
kubectl get externalsecret -n petclinic
kubectl get secret mysql-secret -n petclinic
```

**Expected output:**
```
NAME                  STORE                 STATUS         READY
petclinic-db-secret   aws-secrets-manager   SecretSynced   True

NAME           TYPE     DATA   AGE
mysql-secret   Opaque   4      15s
```

---

## Phase E — Helm Chart Deployment

> Use Claude Code to generate the complete Helm chart for all 7 microservices.

### Step E1 — Generate Helm chart with Claude Code

```bash
cd ~/petclinic-platform
claude
```

**Prompt:**
```
Create a Helm chart at helm/petclinic/ for Spring PetClinic microservices.
Requirements:
- Chart.yaml: name=petclinic, version=1.0.0
- values.yaml with image.registry, image.tag, per-service config
- Services: config-server(8888), discovery-server(8761),
  api-gateway(8080), customers-service(8081),
  vets-service(8083), visits-service(8082), admin-server(9090)
- templates/deployment.yaml:
  - mysql services: SPRING_PROFILES_ACTIVE=docker,mysql
  - mysql services get MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD,
    MYSQL_DATABASE from secret mysql-secret (keys: MYSQL_HOST etc)
  - Add SPRING_DATASOURCE_URL, SPRING_DATASOURCE_USERNAME,
    SPRING_DATASOURCE_PASSWORD for mysql services
  - Readiness probe on /actuator/health
  - resources: requests 256Mi/250m limits 512Mi/500m
  - initContainers: all services wait for config-server;
    mysql services also wait for discovery-server
- templates/service.yaml:
  - api-gateway: LoadBalancer port 80 -> 8080
  - all others: ClusterIP
```

### Step E2 — Fix RDS Security Group

The RDS security group must allow connections from EKS nodes:

```bash
EKS_NODE_SG=$(aws eks describe-cluster \
  --name petclinic-eks --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

RDS_SG=$(aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --source-group $EKS_NODE_SG \
  --region us-east-1
```

### Step E3 — Deploy Helm chart

```bash
kubectl create namespace petclinic

helm install petclinic helm/petclinic/ \
  --namespace petclinic \
  --set image.registry=139561979448.dkr.ecr.us-east-1.amazonaws.com \
  --set image.tag=latest

# Watch pods come up
kubectl get pods -n petclinic -w
```

**Expected final state:**
```
NAME                                 READY   STATUS    RESTARTS
config-server-xxx                    1/1     Running   0
discovery-server-xxx                 1/1     Running   0
api-gateway-xxx                      1/1     Running   0
admin-server-xxx                     1/1     Running   0
customers-service-xxx                1/1     Running   0
vets-service-xxx                     1/1     Running   0
visits-service-xxx                   1/1     Running   0
```

### Step E4 — Get the LoadBalancer URL

```bash
kubectl get svc api-gateway -n petclinic
# Copy EXTERNAL-IP and open in browser
```

---

## Phase F — GitOps with ArgoCD

> ArgoCD watches petclinic-platform GitHub repo and auto-deploys on every change.

### Step F1 — Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# Expose ArgoCD UI
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Get URL
kubectl get svc argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Step F2 — Create ArgoCD Application

```bash
kubectl apply -f - << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: petclinic
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/etaoko333/petclinic-platform
    targetRevision: main
    path: helm/petclinic
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: petclinic
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

kubectl get application petclinic -n argocd
```

**Expected:** `SYNC STATUS: Synced` | `HEALTH STATUS: Healthy`

Open ArgoCD UI at the LoadBalancer URL: **admin / [password from above]**

---

## Phase G — GitHub Actions CI/CD Pipeline

> Automatically build, push, and deploy on every push to main.

### Step G1 — Add GitHub Secrets

Go to: `github.com/etaoko333/spring-petclinic-microservices` → Settings → Secrets → Actions

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret access key |
| `AWS_REGION` | us-east-1 |
| `AWS_ACCOUNT_ID` | 139561979448 |
| `PLATFORM_REPO_PAT` | GitHub Personal Access Token (repo scope) |

### Step G2 — Create CI pipeline

```bash
mkdir -p ~/spring-petclinic-microservices/.github/workflows
```

Create `.github/workflows/ci.yml`:

```yaml
name: CI - Build and Deploy to EKS via ArgoCD

on:
  push:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 139561979448.dkr.ecr.us-east-1.amazonaws.com

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: temurin

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build Docker images
        run: ./mvnw clean install -P buildDocker -Dmaven.test.skip=true

      - name: Tag and push images to ECR
        run: |
          IMAGE_TAG=${{ github.sha }}
          for SERVICE in config-server discovery-server api-gateway \
            customers-service vets-service visits-service admin-server; do
            docker tag springcommunity/spring-petclinic-$SERVICE:latest \
              $ECR_REGISTRY/$SERVICE:$IMAGE_TAG
            docker push $ECR_REGISTRY/$SERVICE:$IMAGE_TAG
          done
          echo "IMAGE_TAG=$IMAGE_TAG" >> $GITHUB_ENV

      - name: Update Helm values in platform repo
        run: |
          git clone https://etaoko333:${{ secrets.PLATFORM_REPO_PAT }}@\
            github.com/etaoko333/petclinic-platform.git /tmp/platform
          cd /tmp/platform
          sed -i "s/tag: .*/tag: $IMAGE_TAG/" helm/petclinic/values.yaml
          git config user.email "ci@github.com"
          git config user.name "GitHub Actions"
          git add helm/petclinic/values.yaml
          git commit -m "ci: update image tag to $IMAGE_TAG [skip ci]"
          git push
```

### Step G3 — Push to trigger pipeline

```bash
cd ~/spring-petclinic-microservices
git add .github/
git commit -m "ci: add GitHub Actions CI/CD pipeline"
git push origin main
```

Watch pipeline: `https://github.com/etaoko333/spring-petclinic-microservices/actions`

ArgoCD will auto-sync when GitHub Actions updates the image tag in `petclinic-platform`.

---

## Phase H — ALB Ingress + Route 53 (HTTPS)

> Expose the app on https://eta-oko.com using AWS ALB + ACM certificate.

### Step H1 — Install AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=petclinic-vpc" \
  --query 'Vpcs[0].VpcId' --output text --region us-east-1)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-eks \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID

kubectl get pods -n kube-system | grep aws-load-balancer
```

### Step H2 — Create IAM Role for ALB Controller

```bash
export OIDC_PROVIDER=$(aws eks describe-cluster \
  --name petclinic-eks --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text | sed 's|https://||')

# Download and create IAM policy
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

aws iam create-role \
  --role-name petclinic-alb-role \
  --assume-role-policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Principal\": {
        \"Federated\": \"arn:aws:iam::139561979448:oidc-provider/${OIDC_PROVIDER}\"
      },
      \"Action\": \"sts:AssumeRoleWithWebIdentity\",
      \"Condition\": {
        \"StringEquals\": {
          \"${OIDC_PROVIDER}:sub\": \"system:serviceaccount:kube-system:aws-load-balancer-controller\"
        }
      }
    }]
  }"

aws iam attach-role-policy \
  --role-name petclinic-alb-role \
  --policy-arn arn:aws:iam::139561979448:policy/AWSLoadBalancerControllerIAMPolicy

kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-alb-role

kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
```

### Step H3 — Request ACM Certificate

```bash
aws acm request-certificate \
  --domain-name eta-oko.com \
  --subject-alternative-names '*.eta-oko.com' \
  --validation-method DNS \
  --region us-east-1
# Note the CertificateArn
```

Add DNS validation record to Route 53:

```bash
# Get validation record
aws acm describe-certificate \
  --certificate-arn YOUR_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'

# Add to Route 53 (replace values from above output)
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "_xxx.eta-oko.com.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "_xxx.acm-validations.aws."}]
      }
    }]
  }'

# Wait for ISSUED status
aws acm describe-certificate \
  --certificate-arn YOUR_CERT_ARN \
  --region us-east-1 \
  --query 'Certificate.Status' --output text
```

### Step H4 — Create ALB Ingress

```bash
kubectl apply -f - << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: petclinic-ingress
  namespace: petclinic
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: YOUR_CERT_ARN
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  rules:
  - host: eta-oko.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
EOF

# Wait for ALB address
kubectl get ingress petclinic-ingress -n petclinic
```

### Step H5 — Create Route 53 A Record

```bash
ALB_HOST=$(kubectl get ingress petclinic-ingress -n petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch "{
    \"Changes\": [{
      \"Action\": \"UPSERT\",
      \"ResourceRecordSet\": {
        \"Name\": \"eta-oko.com\",
        \"Type\": \"A\",
        \"AliasTarget\": {
          \"HostedZoneId\": \"Z35SXDOTRQ7X7K\",
          \"DNSName\": \"$ALB_HOST\",
          \"EvaluateTargetHealth\": true
        }
      }
    }]
  }"

# Test
curl -I https://eta-oko.com
```

✅ App should now be live at **https://eta-oko.com**

---

## Phase I — Monitoring with Prometheus & Grafana

### Step I1 — Install kube-prometheus-stack

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=petclinic123 \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl get pods -n monitoring
kubectl get svc -n monitoring | grep grafana
```

### Step I2 — Create ServiceMonitor for PetClinic

```bash
kubectl apply -f - << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: petclinic-monitor
  namespace: monitoring
  labels:
    release: monitoring
spec:
  namespaceSelector:
    matchNames:
      - petclinic
  selector:
    matchLabels:
      monitoring: enabled
  endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 15s
EOF
```

### Step I3 — Deploy Zipkin

```bash
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zipkin
  namespace: petclinic
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zipkin
  template:
    metadata:
      labels:
        app: zipkin
    spec:
      containers:
      - name: zipkin
        image: openzipkin/zipkin:latest
        ports:
        - containerPort: 9411
---
apiVersion: v1
kind: Service
metadata:
  name: zipkin
  namespace: petclinic
spec:
  type: LoadBalancer
  selector:
    app: zipkin
  ports:
  - port: 9411
    targetPort: 9411
EOF
```

### Step I4 — Import Grafana Dashboards

1. Open Grafana LoadBalancer URL in browser
2. Login: `admin` / `petclinic123`
3. Go to **Dashboards → Import**
4. Import these dashboard IDs:
   - `4701` — Micrometer / Spring Boot
   - `315` — Kubernetes cluster overview
   - `12740` — Spring Boot Observability

---

## Cleanup — Destroy All AWS Resources

> ⚠️ **ALWAYS RUN THIS WHEN DONE — EVERY SINGLE DAY**

```bash
cd ~/petclinic-platform/terraform

# Destroy EVERYTHING: EKS, RDS, ECR, VPC, IAM roles
terraform destroy -auto-approve

# Verify all gone
aws eks list-clusters --region us-east-1
# Expected: { "clusters": [] }

aws rds describe-db-instances --region us-east-1
# Expected: { "DBInstances": [] }

aws ecr describe-repositories --region us-east-1
# Expected: { "repositories": [] }
```

> EKS + RDS + ALB running overnight costs ~$8-12. One command removes everything.

---

## Golden Rules

1. **Use Claude Code to GENERATE code, then REVIEW before applying**
2. **Always test with Docker Compose locally before going to AWS**
3. **Two repos: app repo (read-only) + platform repo (you own)**
4. **Never create AWS resources manually — everything in Terraform**
5. **`force_delete=true` on ECR, `skip_final_snapshot=true` on RDS**
6. **ArgoCD is the only thing that deploys to EKS**
7. **`terraform destroy` every day — no exceptions**
8. **Deploy in order: MySQL → config → discovery → all others**
9. **EKS version must be 1.32 — v1.29 is no longer supported**
10. **EBS CSI addon must be created before the node group**

---

## Deployment Summary

| Phase | Task | Status |
|---|---|---|
| A | Docker Compose local testing | ✅ Complete |
| B | Terraform + Claude Code (VPC+EKS+ECR+RDS) | ✅ Complete |
| C | Build & Push Docker images to ECR | ✅ Complete |
| D | Secrets Manager + External Secrets Operator | ✅ Complete |
| E | Helm Chart deployed to EKS | ✅ Complete |
| F | ArgoCD GitOps (Synced + Healthy) | ✅ Complete |
| G | GitHub Actions CI/CD pipeline | ✅ Complete |
| H | ALB Ingress + Route 53 (https://eta-oko.com) | ✅ Complete |
| I | Prometheus + Grafana monitoring | ✅ Complete |

---

*Prepared by **Osenat Alonge** — DevOps Engineer, DMI Cohort-2, TOVADEL Academy*
