# 🐾 Spring PetClinic — Tomorrow's Deployment Commands
**Prepared by:** Osenat Alonge | DMI Cohort-2 | DevOps Engineer

> Run each stage **one after the other**. Do NOT skip any stage!

---

## 📋 Stage Order
```
STAGE 1  → Terraform (Provision AWS)
STAGE 2  → CI/CD (GitHub Actions builds images automatically)
STAGE 3  → External Secrets Operator (ESO)
STAGE 4  → Fix RDS Security Group
STAGE 5  → Deploy with Helm Chart
STAGE 6  → ArgoCD GitOps
STAGE 7  → ALB Ingress + Route 53 (HTTPS)
STAGE 8  → Monitoring (Prometheus + Grafana)
STAGE 9  → End of Day Cleanup
```

---

## STAGE 1 — Terraform (Provision AWS Infrastructure)

> Creates everything on AWS: VPC, EKS cluster, ECR repos, RDS MySQL, IAM roles. Takes 15-20 minutes.

```bash
cd ~/petclinic-platform/terraform
terraform apply -auto-approve
```

When done, connect kubectl to the new cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name petclinic-eks
kubectl get nodes
```

✅ Both nodes should show: `Ready`

---

## STAGE 2 — CI/CD (GitHub Actions Builds & Pushes Images)

> Instead of manually building Docker images, we push code to GitHub. The pipeline automatically builds all 8 images, pushes them to ECR, and updates the Helm values.yaml.

First verify these 5 secrets exist at:
`github.com/etaoko333/spring-petclinic-microservices → Settings → Secrets → Actions`

```
AWS_ACCESS_KEY_ID      → your AWS access key
AWS_SECRET_ACCESS_KEY  → your AWS secret key
AWS_REGION             → us-east-1
AWS_ACCOUNT_ID         → 139561979448
PLATFORM_REPO_PAT      → your GitHub personal access token
```

Trigger the pipeline with a git push:

```bash
cd ~/spring-petclinic-microservices
sudo service docker start
echo "# rebuild $(date)" >> README.md
git add .
git commit -m "ci: trigger pipeline to build and push images"
git push origin main
```

Watch pipeline at: `github.com/etaoko333/spring-petclinic-microservices/actions`

When pipeline finishes, verify all 8 images are in ECR:

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

✅ All 8 should show: `1 image(s)`

---

## STAGE 3 — External Secrets Operator (ESO)

> ESO reads DB credentials from AWS Secrets Manager and creates a Kubernetes Secret. Passwords are NEVER hardcoded in YAML files.

### Step 3a — Install ESO

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

✅ All 3 pods should show: `Running`

### Step 3b — Update OIDC Trust Policy for ESO

> ⚠️ IMPORTANT: The OIDC URL changes every time EKS is recreated. You MUST run this every time!

```bash
export OIDC_PROVIDER=$(aws eks describe-cluster \
  --name petclinic-eks \
  --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text | sed 's|https://||')

echo "OIDC Provider: $OIDC_PROVIDER"

aws iam update-assume-role-policy \
  --role-name petclinic-eso-role \
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
          \"${OIDC_PROVIDER}:sub\": \"system:serviceaccount:external-secrets:external-secrets\",
          \"${OIDC_PROVIDER}:aud\": \"sts.amazonaws.com\"
        }
      }
    }]
  }"
```

### Step 3c — Create Namespace and Annotate Service Account

```bash
kubectl create namespace petclinic

kubectl annotate serviceaccount external-secrets \
  --namespace external-secrets \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-eso-role \
  --overwrite

kubectl rollout restart deployment/external-secrets -n external-secrets
sleep 25
kubectl get pods -n external-secrets
```

### Step 3d — Apply SecretStore and ExternalSecret

```bash
kubectl apply -f ~/petclinic-platform/argocd/secret-store.yml
sleep 10
kubectl get clustersecretstore
```

✅ Should show: `STATUS=Valid` `READY=True`

```bash
kubectl apply -f ~/petclinic-platform/argocd/external-secret.yml
sleep 15
kubectl get externalsecret -n petclinic
kubectl get secret mysql-secret -n petclinic
```

✅ ExternalSecret should show: `SecretSynced = True`
✅ mysql-secret should show: `DATA = 4`

---

## STAGE 4 — Fix RDS Security Group

> RDS MySQL blocks all connections by default. We open port 3306 so EKS pods can connect to the database.

```bash
EKS_NODE_SG=$(aws eks describe-cluster \
  --name petclinic-eks \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

RDS_SG=$(aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

echo "EKS SG: $EKS_NODE_SG"
echo "RDS SG: $RDS_SG"

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --source-group $EKS_NODE_SG \
  --region us-east-1

echo "RDS security group updated"
```

---

## STAGE 5 — Deploy with Helm Chart

> Helm deploys all 8 microservices to EKS using the images GitHub Actions pushed to ECR. InitContainers ensure services start in the correct order.

### Step 5a — Create OpenAI Secret for AI Chatbot

```bash
kubectl create secret generic openai-secret \
  --namespace petclinic \
  --from-literal=SPRING_AI_OPENAI_API_KEY=YOUR_OPENAI_KEY_HERE
```

### Step 5b — Deploy the Helm Chart

```bash
cd ~/petclinic-platform

helm install petclinic helm/petclinic/ \
  --namespace petclinic \
  --set image.registry=139561979448.dkr.ecr.us-east-1.amazonaws.com \
  --set image.tag=latest
```

### Step 5c — Watch Pods Come Up (3-5 minutes)

```bash
kubectl get pods -n petclinic -w
```

✅ Expected — ALL 8 pods showing `1/1 Running`:
```
admin-server-xxx        1/1     Running
api-gateway-xxx         1/1     Running
config-server-xxx       1/1     Running
customers-service-xxx   1/1     Running
discovery-server-xxx    1/1     Running
genai-service-xxx       1/1     Running
vets-service-xxx        1/1     Running
visits-service-xxx      1/1     Running
```

### Step 5d — Get the App URL

```bash
kubectl get svc api-gateway -n petclinic
```

Copy the `EXTERNAL-IP` and open in browser.

---

## STAGE 6 — ArgoCD GitOps

> ArgoCD watches the petclinic-platform GitHub repo. When GitHub Actions updates the image tag, ArgoCD automatically redeploys on EKS. No manual kubectl apply needed for future deployments!

### Step 6a — Install ArgoCD

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s
```

### Step 6b — Expose ArgoCD UI and Get Password

```bash
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

kubectl get svc argocd-server -n argocd

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Copy the URL and password. Open in browser:
- **Username:** `admin`
- **Password:** from command above

### Step 6c — Connect ArgoCD to Platform Repo

```bash
kubectl apply -f ~/petclinic-platform/argocd/application.yml

kubectl get application petclinic -n argocd
```

✅ Should show: `SYNC STATUS=Synced` `HEALTH STATUS=Healthy`

---

## STAGE 7 — ALB Ingress + Route 53 (HTTPS)

> ALB Controller creates an AWS Load Balancer from the Ingress manifest. Route 53 points eta-oko.com to the ALB. ACM certificate handles HTTPS.

### Step 7a — Install AWS Load Balancer Controller

```bash
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=petclinic-vpc" \
  --query 'Vpcs[0].VpcId' --output text --region us-east-1)

echo "VPC ID: $VPC_ID"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=petclinic-eks \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId=$VPC_ID

kubectl get pods -n kube-system | grep aws-load-balancer
```

### Step 7b — Update ALB Role OIDC Trust Policy

> ⚠️ IMPORTANT: OIDC changes every time EKS is recreated. Must update every time!

```bash
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

kubectl annotate serviceaccount aws-load-balancer-controller \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-alb-role \
  --overwrite

kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
sleep 20
kubectl get pods -n kube-system | grep aws-load-balancer
```

✅ Both pods should show: `Running`

### Step 7c — Apply Ingress

```bash
kubectl apply -f ~/petclinic-platform/argocd/ingress.yml

watch -n 15 'kubectl get ingress petclinic-ingress -n petclinic'
```

Wait until `ADDRESS` column shows the ALB hostname.

### Step 7d — Update Route 53

```bash
ALB_HOST=$(kubectl get ingress petclinic-ingress -n petclinic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "ALB Host: $ALB_HOST"

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
```

Wait 2-5 minutes then test:

```bash
curl -I https://eta-oko.com
```

✅ Should show: `HTTP/1.1 200 OK`

---

## STAGE 8 — Monitoring (Prometheus + Grafana)

> Prometheus collects metrics from services every 15 seconds. Grafana displays them as dashboards. Spring PetClinic services automatically expose `/actuator/prometheus`.

### Step 8a — Scale to 3 Nodes

```bash
NODEGROUP=$(aws eks list-nodegroups \
  --cluster-name petclinic-eks \
  --region us-east-1 \
  --query 'nodegroups[0]' --output text)

echo "Node group: $NODEGROUP"

aws eks update-nodegroup-config \
  --cluster-name petclinic-eks \
  --nodegroup-name $NODEGROUP \
  --scaling-config minSize=1,maxSize=4,desiredSize=3 \
  --region us-east-1

watch -n 20 'kubectl get nodes'
```

Wait until 3 nodes show: `Ready`

### Step 8b — Install Prometheus + Grafana

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
```

### Step 8c — Apply PodMonitor

```bash
kubectl apply -f ~/petclinic-platform/argocd/pod-monitor.yml

kubectl get podmonitor -n monitoring
```

✅ Should show: `petclinic-pods`

### Step 8d — Access Grafana

> Use port-forward — Grafana LoadBalancer has subnet tagging issues.

```bash
pkill -f "port-forward" 2>/dev/null || true

kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &
```

Open in browser:
- **Grafana:** http://localhost:3000 → `admin / petclinic123`
- **Prometheus:** http://localhost:9090/targets

### Step 8e — Import Spring PetClinic Dashboard

> Use local file — avoids internet connectivity issues with dashboard ID 4701.

```bash
cp ~/spring-petclinic-microservices/docker/grafana/dashboards/grafana-petclinic-dashboard.json \
  /tmp/petclinic-dashboard.json
```

In Grafana browser:
1. Click **Dashboards → Import**
2. Click **Upload dashboard JSON file**
3. Select `/tmp/petclinic-dashboard.json`
4. Select **Prometheus** as data source
5. Click **Import**

✅ You will see: HTTP Request Latency, HTTP Request Activity, SPC Business Histogram

### Step 8f — Verify Prometheus Targets

Open: `http://localhost:9090/targets`

```
✅ customers-service   UP
✅ vets-service        UP
✅ visits-service      UP
✅ api-gateway         UP
✅ genai-service       UP
❌ admin-server        DOWN (no Micrometer dependency in code)
❌ config-server       DOWN (no Micrometer dependency in code)
❌ discovery-server    DOWN (no Micrometer dependency in code)
```

---

## ✅ Verification — Check Everything is Working

```bash
kubectl get pods -n petclinic
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n external-secrets
kubectl get application petclinic -n argocd
kubectl get secret mysql-secret -n petclinic
```

Open in browser:
```
https://eta-oko.com           → Main app + AI chatbot
http://localhost:3000         → Grafana dashboards
http://localhost:9090/targets → Prometheus targets
```

---

## STAGE 9 — End of Day Cleanup ⚠️ EVERY DAY!

> EKS + RDS costs money every hour. Run this before sleeping every single day!

```bash
cd ~/petclinic-platform/terraform
terraform destroy -auto-approve
```

Verify everything is deleted:

```bash
aws eks list-clusters --region us-east-1
aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[].DBInstanceStatus' --output text
aws ecr describe-repositories --region us-east-1 \
  --query 'repositories[].repositoryName' --output table
```

✅ All should return empty.

---

## 🔑 Quick Reference Values

```
AWS Account ID  : 139561979448
AWS Region      : us-east-1
EKS Cluster     : petclinic-eks
ECR Registry    : 139561979448.dkr.ecr.us-east-1.amazonaws.com
Domain          : eta-oko.com
Hosted Zone ID  : Z082555627EV8NAU07JQ4
ALB Zone ID     : Z35SXDOTRQ7X7K
ACM Cert ARN    : arn:aws:acm:us-east-1:139561979448:certificate/ff9d81a7-4b2b-4f81-9816-254bc50482cb
ESO IAM Role    : petclinic-eso-role
ALB IAM Role    : petclinic-alb-role
Grafana Login   : admin / petclinic123
ArgoCD Login    : admin / (get from kubectl command in Stage 6b)
App Repo        : github.com/etaoko333/spring-petclinic-microservices
Platform Repo   : github.com/etaoko333/petclinic-platform
```

---

## ⚠️ Important Reminders

```
1. OIDC changes every new EKS cluster:
   → Update petclinic-eso-role trust policy (Stage 3b)
   → Update petclinic-alb-role trust policy (Stage 7b)

2. GitHub Actions builds images automatically:
   → No manual docker build or docker push needed!

3. Grafana → use port-forward (not LoadBalancer URL)

4. Import dashboard from local JSON file (not ID 4701)

5. terraform destroy EVERY day before sleeping!

6. If helm install fails → try helm upgrade instead

7. Always follow stages in exact order!
```
