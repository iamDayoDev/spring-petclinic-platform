# 🐾 Spring PetClinic Microservices — Complete AWS Deployment Teaching Guide

> **Prepared by:** Osenat Alonge — DevOps Engineer, DMI Cohort-2  
> **GitHub:** etaoko333 | **Domain:** eta-oko.com | **Region:** us-east-1 (N. Virginia)

---

## 📌 STAGES — Follow in This Exact Order

```
STAGE 1  → Local Testing with Docker Compose
STAGE 2  → Create Platform Repository
STAGE 3  → Provision AWS Infrastructure (Terraform + Claude Code)
STAGE 4  → Setup CI/CD with GitHub Actions  ← Builds & Pushes Images!
STAGE 5  → Setup Secrets (External Secrets Operator)
STAGE 6  → Deploy with Helm Chart
STAGE 7  → Setup GitOps with ArgoCD
STAGE 8  → Setup HTTPS with ALB Ingress + Route 53
STAGE 9  → Setup Monitoring (Prometheus + Grafana)
STAGE 10 → END OF DAY CLEANUP
```

### Why This Order?

```
STAGE 3: Terraform creates ECR repositories on AWS
              |
STAGE 4: GitHub Actions pipeline is configured
         Developer does: git push origin main
              |
         Pipeline AUTOMATICALLY:
           - Compiles Java code
           - Builds 8 Docker images
           - Pushes images to ECR
           - Updates Helm values.yaml with new tag
              |
STAGE 5+: Everything else uses images
          already in ECR from the pipeline!

NO MANUAL docker build or docker push needed!
```

---

## 🔧 Prerequisites — Check These First

```bash
# Verify all tools are installed
aws --version          # AWS CLI
terraform --version    # Terraform >= 1.3.0
kubectl version --client
helm version
docker --version
java --version         # Must be Java 17
claude --version       # Claude Code CLI

# Verify AWS is configured
aws sts get-caller-identity
```

**What each tool does:**

| Tool | Purpose |
|------|---------|
| AWS CLI | Talks to AWS from command line |
| Terraform | Creates AWS resources as code |
| kubectl | Controls Kubernetes cluster |
| Helm | Packages Kubernetes apps |
| Docker | Builds container images |
| Claude Code | AI that generates Terraform + Helm code |
| Java 17 | Compiles Spring Boot source code |

---

## STAGE 1: Local Testing with Docker Compose

### What is Docker Compose?
Docker Compose runs multiple containers together on your local machine.
We test the FULL application locally before touching AWS.
The repo already has a `docker-compose.yml` — no need to create anything.

### Step 1.1 — Start Docker
```bash
sudo service docker start
docker ps
```

### Step 1.2 — Start the full stack
```bash
cd ~/spring-petclinic-microservices

# Starts all services using pre-built images from DockerHub
docker compose up -d

# Check all containers are running
docker compose ps
```

### Step 1.3 — Verify in browser

| URL | Service | What to Check |
|-----|---------|---------------|
| http://localhost:8080 | api-gateway | Main app loads |
| http://localhost:8761 | discovery-server | All services registered |
| http://localhost:8888 | config-server | Config served |
| http://localhost:9090 | admin-server | All services green |
| http://localhost:3030 | grafana | Dashboards visible (admin/admin) |
| http://localhost:9091 | prometheus | Targets page |
| http://localhost:9411 | zipkin | Traces visible |

### Step 1.4 — Stop when done
```bash
docker compose down -v
```

---

## STAGE 2: Create the Platform Repository

### Why Two Repositories?
```
App Repo (READ ONLY)                  Platform Repo (YOU BUILD THIS)
────────────────────                  ──────────────────────────────
spring-petclinic-microservices        petclinic-platform
├── Java source code                  ├── terraform/     (AWS infra)
├── docker-compose.yml                ├── helm/          (K8s packaging)
└── .github/workflows/ci.yml         └── argocd/        (GitOps config)

GitHub Actions reads source code      ArgoCD watches this repo
and builds Docker images              and deploys to EKS automatically
```

### Step 2.1 — Create on GitHub
1. Go to github.com → New Repository
2. Name: `petclinic-platform`
3. Visibility: Public
4. Click Create repository

### Step 2.2 — Clone and create structure
```bash
cd ~
git clone https://github.com/etaoko333/petclinic-platform.git
cd petclinic-platform

# Create all folders
mkdir -p terraform/modules/{vpc,eks,ecr,rds}
mkdir -p helm/petclinic/templates
mkdir -p argocd
mkdir -p .github/workflows

# Add .gitignore
cat > .gitignore << 'EOF'
**/.terraform/
*.tfstate
*.tfstate.backup
.terraform.lock.hcl
target/
*.jar
.DS_Store
EOF

# Verify structure
tree .
```

---

## STAGE 3: Provision AWS Infrastructure (Terraform + Claude Code)

### What is Terraform?
Terraform is Infrastructure as Code. We write code that creates all
AWS resources automatically. One command creates everything,
one command destroys everything — no clicking in AWS console.

### What is Claude Code?
AI CLI that generates Terraform code from our descriptions.
We describe what we need → it writes the code → we review and apply.

### Step 3.1 — Create root Terraform files
```bash
cd ~/petclinic-platform/terraform

cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}
provider "aws" { region = var.aws_region }
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
output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}
output "ecr_urls" {
  value = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}
EOF
```

### Step 3.2 — Use Claude Code to generate modules
```bash
cd ~/petclinic-platform
claude
```

**Prompt 1 — VPC Module:**
```
Create a Terraform VPC module in terraform/modules/vpc/
Requirements:
- VPC CIDR 10.0.0.0/16 in us-east-1
- 2 public subnets only, no NAT gateway (saves $32/month)
- Internet Gateway for outbound traffic
- Availability zones: us-east-1a and us-east-1b
- EKS subnet tags:
  kubernetes.io/cluster/petclinic-eks = shared
  kubernetes.io/role/elb = 1
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
- EBS CSI driver addon with its own dedicated IRSA role
  (NOT the node role - this prevents 30min timeout)
- addon timeout: create = "30m"
- resolve_conflicts_on_create = "OVERWRITE"
- CoreDNS and kube-proxy addons
- OIDC provider for IRSA
- IAM roles: cluster role + node role
- Node role policies: AmazonEKSWorkerNodePolicy,
  AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly
- Files: main.tf, variables.tf, outputs.tf
- Outputs: cluster_name, cluster_endpoint, oidc_provider_arn
```

**Prompt 3 — ECR Module:**
```
Create a Terraform ECR module in terraform/modules/ecr/
Requirements:
- Create 8 repos: config-server, discovery-server, api-gateway,
  customers-service, vets-service, visits-service, admin-server,
  genai-service
- image_tag_mutability = MUTABLE
- force_delete = true (allows terraform destroy even with images)
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
- skip_final_snapshot = true
- deletion_protection = false
- Security group: allow port 3306 from VPC CIDR 10.0.0.0/16
- Store credentials in AWS Secrets Manager as JSON:
  { username, password, endpoint, port, dbname }
- Secret name: petclinic/db-credentials
- recovery_window_in_days = 0 (immediate delete on destroy)
- Outputs: db_endpoint, db_name, secret_arn, db_port
```

**Prompt 5 — Wire all modules in main.tf:**
```
Update terraform/main.tf to call all 4 modules:
module "vpc", module "eks", module "ecr", module "rds"
Pass vpc_id and subnet_ids between modules as needed.
```

### Step 3.3 — Validate and Apply
```bash
cd ~/petclinic-platform/terraform

terraform init
terraform validate
# Expected: Success! The configuration is valid.

terraform apply -auto-approve
# Takes 15-20 minutes
```

### Step 3.4 — Connect kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name petclinic-eks
kubectl get nodes
# Both nodes should show: Ready
```

---

## STAGE 4: Setup CI/CD with GitHub Actions

### Why CI/CD Comes Here (Before Manual Image Build)?
```
Terraform just created ECR repositories (Stage 3)
            |
Now we set up GitHub Actions pipeline
            |
Developer does: git push origin main
            |
Pipeline AUTOMATICALLY:
  ✅ Builds all 8 Docker images (no manual ./mvnw needed!)
  ✅ Pushes all images to ECR (no manual docker push needed!)
  ✅ Updates Helm chart values.yaml with new image tag
  ✅ Triggers ArgoCD to deploy automatically

We NEVER need to manually build or push images again!
```

### Step 4.1 — Add GitHub Secrets to app repo
Go to:
```
github.com/etaoko333/spring-petclinic-microservices
→ Settings → Secrets and Variables → Actions
→ New repository secret
```

Add these 5 secrets:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret access key |
| `AWS_REGION` | us-east-1 |
| `AWS_ACCOUNT_ID` | 139561979448 |
| `PLATFORM_REPO_PAT` | GitHub Personal Access Token |

**How to get your AWS credentials:**
```bash
cat ~/.aws/credentials
```

**How to create GitHub PAT:**
1. github.com → Settings → Developer Settings
2. Personal Access Tokens → Tokens (classic)
3. Generate new token → select `repo` scope
4. Copy the token — paste as PLATFORM_REPO_PAT

### Step 4.2 — Create the CI/CD pipeline file
```bash
mkdir -p ~/spring-petclinic-microservices/.github/workflows
```

Create `.github/workflows/ci.yml`:

```yaml
name: CI - Build and Deploy to EKS via ArgoCD

on:
  push:
    branches: [main]   # Runs automatically on every git push

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 139561979448.dkr.ecr.us-east-1.amazonaws.com

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      # 1. Get the source code from GitHub
      - name: Checkout code
        uses: actions/checkout@v4

      # 2. Install Java 17 (needed to compile Spring Boot)
      - name: Set up Java 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: temurin

      # 3. Connect pipeline to AWS using secrets
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      # 4. Login to ECR to allow image push
      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2

      # 5. Build all 8 Docker images using Maven
      # This replaces our manual: ./mvnw clean install -P buildDocker
      - name: Build Docker images
        run: ./mvnw clean install -P buildDocker -Dmaven.test.skip=true

      # 6. Tag each image with git SHA and push to ECR
      # git SHA = unique identifier for this exact code version
      # Example: abc123def456 (never same twice)
      - name: Tag and push images to ECR
        run: |
          IMAGE_TAG=${{ github.sha }}
          for SERVICE in config-server discovery-server api-gateway \
            customers-service vets-service visits-service \
            admin-server genai-service; do
            # Tag with ECR URL + unique git SHA
            docker tag springcommunity/spring-petclinic-$SERVICE:latest \
              $ECR_REGISTRY/$SERVICE:$IMAGE_TAG
            # Push to ECR
            docker push $ECR_REGISTRY/$SERVICE:$IMAGE_TAG
            echo "Pushed: $SERVICE:$IMAGE_TAG"
          done
          echo "IMAGE_TAG=$IMAGE_TAG" >> $GITHUB_ENV

      # 7. Update Helm chart with new image tag
      # This triggers ArgoCD to deploy the new version
      - name: Update image tag in platform repo
        run: |
          git clone https://etaoko333:${{ secrets.PLATFORM_REPO_PAT }}@\
            github.com/etaoko333/petclinic-platform.git /tmp/platform
          cd /tmp/platform
          # Replace old tag with new git SHA tag
          sed -i "s/tag: .*/tag: $IMAGE_TAG/" helm/petclinic/values.yaml
          git config user.email "ci@github.com"
          git config user.name "GitHub Actions"
          git add helm/petclinic/values.yaml
          git commit -m "ci: update image tag to $IMAGE_TAG [skip ci]"
          git push
          echo "ArgoCD will now auto-sync and deploy new version"
```

### Step 4.3 — Push to trigger the pipeline
```bash
cd ~/spring-petclinic-microservices

git add .github/
git commit -m "ci: add GitHub Actions CI/CD pipeline"
git push origin main
```

### Step 4.4 — Watch the pipeline run
Open in browser:
```
https://github.com/etaoko333/spring-petclinic-microservices/actions
```

**What you will see:**
```
✅ Checkout code          (1s)
✅ Set up Java 17         (5s)
✅ Configure AWS          (2s)
✅ Login to ECR           (3s)
✅ Build Docker images    (10-15 mins)
✅ Push images to ECR     (5-10 mins)
✅ Update platform repo   (30s)
```

### Step 4.5 — Verify images are in ECR
```bash
for SERVICE in config-server discovery-server api-gateway \
  customers-service vets-service visits-service admin-server genai-service; do
  COUNT=$(aws ecr describe-images \
    --repository-name $SERVICE \
    --region us-east-1 \
    --query 'length(imageDetails)' \
    --output text 2>/dev/null)
  echo "$SERVICE: $COUNT image(s)"
done
```

**Expected:** All 8 services show `1 image(s)` — pushed automatically by pipeline!

---

## STAGE 5: Setup Secrets (External Secrets Operator)

### Why External Secrets Operator?
```
Without ESO (BAD):                With ESO (GOOD):
──────────────────                ────────────────────────
password: petclinic123            AWS Secrets Manager
hardcoded in YAML file!           (encrypted, secure)
Anyone can see it!                       |
                              External Secrets Operator
                              (reads from AWS, creates K8s secret)
                                         |
                              Kubernetes Secret "mysql-secret"
                              (pods use it as env variable)
```

### Step 5.1 — Install ESO
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
# All 3 pods should be Running
```

### Step 5.2 — Create IAM Role for ESO

**IMPORTANT:** Every time EKS is recreated, the OIDC provider URL changes.
You must always update the trust policy with the NEW OIDC URL.

```bash
# Get NEW OIDC provider URL for this EKS cluster
export OIDC_PROVIDER=$(aws eks describe-cluster \
  --name petclinic-eks --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text | sed 's|https://||')

echo "OIDC Provider: $OIDC_PROVIDER"

export AWS_ACCOUNT_ID=139561979448

# Create trust policy with new OIDC URL
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

# First time: create the role
aws iam create-role \
  --role-name petclinic-eso-role \
  --assume-role-policy-document file:///tmp/eso-trust-policy.json 2>/dev/null || \
# Subsequent times: just update the trust policy
aws iam update-assume-role-policy \
  --role-name petclinic-eso-role \
  --policy-document file:///tmp/eso-trust-policy.json

# Attach Secrets Manager permission
aws iam attach-role-policy \
  --role-name petclinic-eso-role \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite 2>/dev/null || true

# Link role to ESO Kubernetes service account
kubectl annotate serviceaccount external-secrets \
  --namespace external-secrets \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-eso-role

# Restart to use new role
kubectl rollout restart deployment/external-secrets -n external-secrets
sleep 20
kubectl get pods -n external-secrets
```

### Step 5.3 — Create namespace and apply saved manifests
```bash
# Create petclinic namespace
kubectl create namespace petclinic

# Apply ClusterSecretStore (tells ESO where AWS secrets are)
kubectl apply -f ~/petclinic-platform/argocd/secret-store.yml

# Verify Ready=True
kubectl get clustersecretstore

# Apply ExternalSecret (tells ESO what to sync)
kubectl apply -f ~/petclinic-platform/argocd/external-secret.yml

sleep 15

# Verify secret was synced from AWS to Kubernetes
kubectl get externalsecret -n petclinic
kubectl get secret mysql-secret -n petclinic
```

**Expected:**
```
NAME                  STATUS         READY
petclinic-db-secret   SecretSynced   True

NAME           TYPE     DATA
mysql-secret   Opaque   4
```

---

## STAGE 6: Deploy with Helm Chart

### What is Helm?
Helm packages all 8 Kubernetes deployments + services into one reusable chart.
Instead of 8 separate YAML files, we manage everything through `values.yaml`.

### Step 6.1 — Generate Helm chart with Claude Code
```bash
cd ~/petclinic-platform
claude
```

**Prompt:**
```
Create a Helm chart at helm/petclinic/ for Spring PetClinic on EKS.

Requirements:
- Chart.yaml: name=petclinic, version=1.0.0
- values.yaml with image.registry, image.tag, per-service config
- Services: config-server(8888), discovery-server(8761),
  api-gateway(8080), customers-service(8081),
  vets-service(8083), visits-service(8082),
  admin-server(9090), genai-service(8084)

- templates/deployment.yaml:
  - mysql services: SPRING_PROFILES_ACTIVE=docker,mysql
  - mysql services get env vars from secret mysql-secret:
    MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE
  - mysql services also need SPRING_DATASOURCE_URL:
    jdbc:mysql://$(MYSQL_HOST):3306/$(MYSQL_DATABASE)?useSSL=false&allowPublicKeyRetrieval=true
  - genai-service gets SPRING_AI_OPENAI_API_KEY from openai-secret
  - Readiness probe on /actuator/health for each service
  - Resources: requests 256Mi/250m, limits 512Mi/500m
  - Prometheus annotations:
    prometheus.io/scrape: "true"
    prometheus.io/path: "/actuator/prometheus"
    prometheus.io/port: "<correct port per service>"
  - initContainers: all services wait for config-server
  - mysql + genai services also wait for discovery-server

- templates/service.yaml:
  - api-gateway: LoadBalancer port 80 -> 8080
  - all others: ClusterIP with named port "http"
```

### Step 6.2 — Fix RDS Security Group
Allow EKS pods to connect to RDS on port 3306:
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

echo "RDS security group updated"
```

### Step 6.3 — Create OpenAI secret
```bash
kubectl create secret generic openai-secret \
  --namespace petclinic \
  --from-literal=SPRING_AI_OPENAI_API_KEY=YOUR_OPENAI_KEY_HERE
```

### Step 6.4 — Deploy Helm chart
```bash
cd ~/petclinic-platform

helm install petclinic helm/petclinic/ \
  --namespace petclinic \
  --set image.registry=139561979448.dkr.ecr.us-east-1.amazonaws.com \
  --set image.tag=latest

# Watch pods come up
kubectl get pods -n petclinic -w
```

**Deployment order (controlled by initContainers):**
```
1. config-server starts first (no init container)
2. All others wait for config-server to be healthy
3. mysql services + genai also wait for discovery-server
4. Then all remaining services start together
```

**Expected final state:**
```
NAME                    READY   STATUS    RESTARTS
admin-server-xxx        1/1     Running   0
api-gateway-xxx         1/1     Running   0
config-server-xxx       1/1     Running   0
customers-service-xxx   1/1     Running   0
discovery-server-xxx    1/1     Running   0
genai-service-xxx       1/1     Running   0
vets-service-xxx        1/1     Running   0
visits-service-xxx      1/1     Running   0
```

### Step 6.5 — Get app URL
```bash
kubectl get svc api-gateway -n petclinic
# Copy EXTERNAL-IP and open in browser
```

---

## STAGE 7: Setup GitOps with ArgoCD

### What is ArgoCD?
ArgoCD watches the `petclinic-platform` GitHub repo.
When GitHub Actions updates the image tag in `values.yaml`,
ArgoCD automatically redeploys the new version on EKS.

```
git push code
      |
GitHub Actions builds + pushes image to ECR
      |
GitHub Actions updates values.yaml tag: abc123
      |
ArgoCD detects values.yaml changed
      |
ArgoCD runs: helm upgrade petclinic
      |
New pods with new image roll out
      |
https://eta-oko.com shows new version!
```

### Step 7.1 — Install ArgoCD
```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD server
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

# Expose as LoadBalancer
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Get URL and password
kubectl get svc argocd-server -n argocd
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Step 7.2 — Apply ArgoCD Application
```bash
# This tells ArgoCD which repo to watch and where to deploy
kubectl apply -f ~/petclinic-platform/argocd/application.yml

# Check status
kubectl get application petclinic -n argocd
```

**Expected:** `SYNC STATUS: Synced | HEALTH STATUS: Healthy`

Open ArgoCD UI at the LoadBalancer URL:
- Username: `admin`
- Password: from command above

### Step 7.3 — Test the full CI/CD flow
```bash
cd ~/spring-petclinic-microservices

# Make any small change
echo "# Test $(date)" >> README.md

git add .
git commit -m "test: verify CI/CD pipeline works end to end"
git push origin main
```

Watch:
1. GitHub Actions at: `github.com/etaoko333/spring-petclinic-microservices/actions`
2. ArgoCD UI — should show new sync after pipeline completes

---

## STAGE 8: HTTPS with ALB Ingress + Route 53

### What is ALB Ingress?
```
Without Ingress:
  api-gateway → own LoadBalancer ($0.008/hr each)
  grafana     → own LoadBalancer
  argocd      → own LoadBalancer
  (many LoadBalancers = expensive)

With ALB Ingress:
  One ALB handles all traffic
  Routes based on hostname:
  eta-oko.com → api-gateway
  (cheaper + professional)
```

### Step 8.1 — Install AWS Load Balancer Controller
```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=petclinic-vpc" \
  --query 'Vpcs[0].VpcId' --output text --region us-east-1)

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-eks \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID
```

### Step 8.2 — Create IAM Role for ALB Controller

**IMPORTANT:** Like ESO, the OIDC URL changes every time EKS is recreated.
Always update the trust policy!

```bash
export OIDC_PROVIDER=$(aws eks describe-cluster \
  --name petclinic-eks --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text | sed 's|https://||')

# Download policy from AWS
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

# Create policy (first time only)
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json 2>/dev/null || true

# Create role (first time) or update trust policy (subsequent times)
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
  }" 2>/dev/null || \
aws iam update-assume-role-policy \
  --role-name petclinic-alb-role \
  --policy-document "{
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
  --policy-arn arn:aws:iam::139561979448:policy/AWSLoadBalancerControllerIAMPolicy 2>/dev/null || true

# Annotate ALB controller service account
kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-alb-role

kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
sleep 20
kubectl get pods -n kube-system | grep aws-load-balancer
```

### Step 8.3 — Request SSL Certificate (first time only)
```bash
# Only run if certificate doesn't exist
aws acm request-certificate \
  --domain-name eta-oko.com \
  --subject-alternative-names '*.eta-oko.com' \
  --validation-method DNS \
  --region us-east-1

# Note the CertificateArn
# Complete DNS validation in Route 53 console
# Wait for status: ISSUED
```

**Note:** The certificate `ff9d81a7-4b2b-4f81-9816-254bc50482cb` from today
is still valid — no need to request a new one tomorrow!

### Step 8.4 — Apply Ingress
```bash
kubectl apply -f ~/petclinic-platform/argocd/ingress.yml

# Watch for ALB address (2-3 minutes)
watch -n 15 'kubectl get ingress petclinic-ingress -n petclinic'
```

### Step 8.5 — Update Route 53
```bash
ALB_HOST=$(kubectl get ingress petclinic-ingress -n petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

aws route53 change-resource-record-sets \
  --hosted-zone-id Z082555627EV8NAU07JQ4 \
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

# Test after 2-5 minutes
curl -I https://eta-oko.com
```

---

## STAGE 9: Monitoring with Prometheus + Grafana

### What is Prometheus + Grafana?
```
Spring Boot services
(automatically expose metrics at /actuator/prometheus)
        |
Prometheus (collects metrics every 15 seconds)
Stores: HTTP latency, request rate, JVM heap, errors
        |
Grafana (visualises metrics as dashboards)
Shows: Real-time HTTP traffic, business metrics
```

### Step 9.1 — Scale nodes to 3 (monitoring needs resources)
```bash
NODEGROUP=$(aws eks list-nodegroups \
  --cluster-name petclinic-eks \
  --region us-east-1 \
  --query 'nodegroups[0]' --output text)

aws eks update-nodegroup-config \
  --cluster-name petclinic-eks \
  --nodegroup-name $NODEGROUP \
  --scaling-config minSize=1,maxSize=4,desiredSize=3 \
  --region us-east-1

# Wait for 3rd node
watch -n 20 'kubectl get nodes'
```

### Step 9.2 — Install kube-prometheus-stack
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

# Wait for all pods
kubectl get pods -n monitoring
```

### Step 9.3 — Apply PodMonitor (tells Prometheus what to scrape)
```bash
# This is saved in argocd/ folder - just apply!
kubectl apply -f ~/petclinic-platform/argocd/pod-monitor.yml

# Verify created
kubectl get podmonitor -n monitoring
```

### Step 9.4 — Access Grafana

**Use port-forward** (Grafana LoadBalancer has subnet issues):
```bash
# Kill any existing port-forwards first
pkill -f "port-forward" 2>/dev/null

# Start port-forward
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &

echo "Grafana:    http://localhost:3000 (admin/petclinic123)"
echo "Prometheus: http://localhost:9090"
```

### Step 9.5 — Import Spring PetClinic Dashboard

**Use the local JSON file** (avoids internet connectivity issues):
```bash
# Copy dashboard JSON from project
cp ~/spring-petclinic-microservices/docker/grafana/dashboards/grafana-petclinic-dashboard.json \
  /tmp/petclinic-dashboard.json

echo "Now import /tmp/petclinic-dashboard.json in Grafana UI"
```

In Grafana browser:
1. Dashboards → Import
2. Click **"Upload dashboard JSON file"**
3. Select `/tmp/petclinic-dashboard.json`
4. Select **Prometheus** as data source
5. Click Import

**You will see:**
- HTTP Request Latency (ms)
- HTTP Request Activity (ops/s)
- SPC Business Histogram
- Owners Created, Pets Created counters

### Step 9.6 — Verify Prometheus targets
Open http://localhost:9090/targets

**Expected:** 5/8 petclinic services showing UP
(admin-server, config-server, discovery-server show DOWN
because they don't have Micrometer Prometheus dependency in code)

---

## STAGE 10: End of Day Cleanup

### CRITICAL — Run Every Day Without Fail!

```bash
cd ~/petclinic-platform/terraform

# Destroys EVERYTHING: EKS, RDS, ECR, VPC, Subnets, IAM
terraform destroy -auto-approve

# Verify everything deleted
aws eks list-clusters --region us-east-1
# Expected: { "clusters": [] }

aws rds describe-db-instances --region us-east-1
# Expected: { "DBInstances": [] }

aws ecr describe-repositories --region us-east-1
# Expected: { "repositories": [] }
```

**If terraform destroy fails** (e.g. ALB still exists):
```bash
# Delete ALB manually in console
# EC2 → Load Balancers → Delete
# Then retry: terraform destroy -auto-approve
```

---

## 📋 Quick Reference — Tomorrow's Commands

```bash
# ── STAGE 3: Terraform ────────────────────────────────
cd ~/petclinic-platform/terraform
terraform apply -auto-approve
aws eks update-kubeconfig --region us-east-1 --name petclinic-eks
kubectl get nodes

# ── STAGE 4: CI/CD (triggers image build automatically) ──
# Secrets already set in GitHub from today
# Just push any change to trigger:
cd ~/spring-petclinic-microservices
echo "# rebuild $(date)" >> README.md
git add . && git commit -m "ci: rebuild images" && git push origin main
# Watch: github.com/etaoko333/spring-petclinic-microservices/actions

# ── STAGE 5: ESO ──────────────────────────────────────
helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set installCRDs=true --wait

# Update OIDC trust policy (MUST DO every time!)
export OIDC_PROVIDER=$(aws eks describe-cluster \
  --name petclinic-eks --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text | sed 's|https://||')
aws iam update-assume-role-policy \
  --role-name petclinic-eso-role \
  --policy-document "{ ... }"   # (see Stage 5.2 above)

kubectl create namespace petclinic
kubectl annotate serviceaccount external-secrets \
  -n external-secrets \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-eso-role
kubectl rollout restart deployment/external-secrets -n external-secrets
sleep 20
kubectl apply -f ~/petclinic-platform/argocd/secret-store.yml
kubectl apply -f ~/petclinic-platform/argocd/external-secret.yml

# ── STAGE 6: Helm Deploy ──────────────────────────────
# Fix RDS security group first
EKS_NODE_SG=$(aws eks describe-cluster --name petclinic-eks \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
RDS_SG=$(aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG --protocol tcp --port 3306 \
  --source-group $EKS_NODE_SG --region us-east-1

kubectl create secret generic openai-secret \
  --namespace petclinic \
  --from-literal=SPRING_AI_OPENAI_API_KEY=YOUR_KEY

cd ~/petclinic-platform
helm install petclinic helm/petclinic/ \
  --namespace petclinic \
  --set image.registry=139561979448.dkr.ecr.us-east-1.amazonaws.com \
  --set image.tag=latest
kubectl get pods -n petclinic -w

# ── STAGE 7: ArgoCD ───────────────────────────────────
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'
kubectl apply -f ~/petclinic-platform/argocd/application.yml

# ── STAGE 8: ALB + Route 53 ───────────────────────────
# (See Stage 8 above for full commands)
# Remember: update OIDC trust policy for ALB role too!
kubectl apply -f ~/petclinic-platform/argocd/ingress.yml

# ── STAGE 9: Monitoring ───────────────────────────────
helm install monitoring \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=petclinic123 \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
kubectl apply -f ~/petclinic-platform/argocd/pod-monitor.yml
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &

# ── STAGE 10: CLEANUP ─────────────────────────────────
cd ~/petclinic-platform/terraform
terraform destroy -auto-approve
```

---

## 🚨 Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| EBS CSI addon timeout | Node role used instead of IRSA | Create dedicated IRSA role for EBS CSI |
| ESO AccessDenied | OIDC URL changed (new EKS cluster) | Update trust policy with new OIDC |
| ALB controller AccessDenied | OIDC URL changed | Update ALB trust policy with new OIDC |
| MySQL connection refused | RDS security group | Add EKS cluster SG to RDS inbound rules |
| CreateContainerConfigError | Wrong secret key names | Check secret keys match MYSQL_HOST not "host" |
| terraform destroy fails ECR | Images exist in repos | Add force_delete = true to ECR Terraform |
| Secret already exists | Previous run not cleaned | Use recovery_window_in_days = 0 |
| Grafana LoadBalancer pending | Subnet tags missing | Use kubectl port-forward instead |
| Dashboard 4701 not loading | No internet in Grafana | Use local JSON from docker/grafana/dashboards/ |
| Prometheus no targets | PodMonitor not applied | kubectl apply -f argocd/pod-monitor.yml |

---

## ✅ Deployment Checklist

- [ ] Stage 1: Docker Compose — all services accessible in browser
- [ ] Stage 2: petclinic-platform repo created with correct structure
- [ ] Stage 3: terraform apply — EKS + RDS + ECR + VPC created
- [ ] Stage 3: kubectl get nodes shows 2x Ready
- [ ] Stage 4: GitHub Actions pipeline configured with 5 secrets
- [ ] Stage 4: git push triggers pipeline automatically
- [ ] Stage 4: All 8 images pushed to ECR by pipeline
- [ ] Stage 5: mysql-secret shows SecretSynced=True with DATA=4
- [ ] Stage 6: All 8 pods show 1/1 Running
- [ ] Stage 6: App accessible via LoadBalancer URL
- [ ] Stage 7: ArgoCD shows Synced + Healthy
- [ ] Stage 7: git push → pipeline → ArgoCD auto-deploys
- [ ] Stage 8: https://eta-oko.com loads with HTTPS padlock
- [ ] Stage 8: AI chatbot responds to messages
- [ ] Stage 9: Grafana shows HTTP Request Latency and Activity
- [ ] Stage 9: Prometheus shows 5/8 petclinic targets UP
- [ ] Stage 10: terraform destroy -auto-approve completed

---

*Prepared by Osenat Alonge — DevOps Engineer, DMI Cohort-2*
*TOVADEL Academy | GitHub: etaoko333 | Domain: eta-oko.com*
