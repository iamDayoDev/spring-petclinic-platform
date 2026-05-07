# 🐾 Spring PetClinic - Tomorrow's Deployment Commands
# Run each stage one after the other - DO NOT skip any stage!
# Prepared by: Osenat Alonge - DevOps Engineer, DMI Cohort-2

===================================================
STAGE 1: TERRAFORM - Provision AWS Infrastructure
===================================================
EXPLANATION: Terraform creates ALL AWS resources automatically.
This creates: VPC, EKS cluster, ECR repos, RDS MySQL, IAM roles.
Takes 15-20 minutes. Open a second terminal for Stage 2 while this runs.

cd ~/petclinic-platform/terraform
terraform apply -auto-approve

---------------------------------------------
When done, connect kubectl to the new cluster:
---------------------------------------------
aws eks update-kubeconfig --region us-east-1 --name petclinic-eks
kubectl get nodes
# Both nodes should show: Ready


===================================================
STAGE 2: CI/CD - GitHub Actions Builds the Images
===================================================
EXPLANATION: Instead of manually building images, we push code to GitHub.
GitHub Actions pipeline automatically:
  - Builds all 8 Docker images
  - Pushes them to ECR
  - Updates values.yaml with new image tag
  - ArgoCD will deploy the new images automatically

---------------------------------------------
First verify GitHub Secrets are set at:
github.com/etaoko333/spring-petclinic-microservices
→ Settings → Secrets → Actions
---------------------------------------------
Secrets needed:
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  AWS_REGION          = us-east-1
  AWS_ACCOUNT_ID      = 139561979448
  PLATFORM_REPO_PAT   = your GitHub token

---------------------------------------------
Trigger the pipeline with a git push:
---------------------------------------------
cd ~/spring-petclinic-microservices
sudo service docker start
echo "# rebuild $(date)" >> README.md
git add .
git commit -m "ci: trigger pipeline to build and push images"
git push origin main

---------------------------------------------
Watch pipeline at:
github.com/etaoko333/spring-petclinic-microservices/actions
---------------------------------------------

---------------------------------------------
When pipeline finishes, verify images in ECR:
---------------------------------------------
for SERVICE in config-server discovery-server api-gateway \
  customers-service vets-service visits-service admin-server genai-service; do
  COUNT=$(aws ecr describe-images \
    --repository-name $SERVICE \
    --region us-east-1 \
    --query 'length(imageDetails)' \
    --output text 2>/dev/null)
  echo "$SERVICE: $COUNT image(s)"
done
# All 8 should show: 1 image(s)


===================================================
STAGE 3: EXTERNAL SECRETS OPERATOR (ESO)
===================================================
EXPLANATION: ESO reads DB credentials from AWS Secrets Manager
and creates a Kubernetes Secret that pods can use.
This means passwords are NEVER hardcoded in YAML files.

---------------------------------------------
Step 3a - Install ESO:
---------------------------------------------
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --set installCRDs=true \
  --wait

kubectl get pods -n external-secrets
# All 3 pods should show: Running

---------------------------------------------
Step 3b - Update OIDC trust policy for ESO:
IMPORTANT: OIDC URL changes every time EKS is recreated!
Always run this after new EKS cluster.
---------------------------------------------
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

---------------------------------------------
Step 3c - Create namespace and annotate service account:
---------------------------------------------
kubectl create namespace petclinic

kubectl annotate serviceaccount external-secrets \
  --namespace external-secrets \
  eks.amazonaws.com/role-arn=arn:aws:iam::139561979448:role/petclinic-eso-role \
  --overwrite

kubectl rollout restart deployment/external-secrets -n external-secrets
sleep 25
kubectl get pods -n external-secrets

---------------------------------------------
Step 3d - Apply SecretStore and ExternalSecret:
---------------------------------------------
kubectl apply -f ~/petclinic-platform/argocd/secret-store.yml
sleep 10

kubectl get clustersecretstore
# Should show: STATUS=Valid, READY=True

kubectl apply -f ~/petclinic-platform/argocd/external-secret.yml
sleep 15

kubectl get externalsecret -n petclinic
# Should show: STATUS=SecretSynced, READY=True

kubectl get secret mysql-secret -n petclinic
# Should show: TYPE=Opaque, DATA=4


===================================================
STAGE 4: FIX RDS SECURITY GROUP
===================================================
EXPLANATION: RDS MySQL is in a security group that blocks
connections by default. We must allow EKS pods to connect
on port 3306 (MySQL port).

EKS_NODE_SG=$(aws eks describe-cluster \
  --name petclinic-eks \
  --region us-east-1 \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text)

RDS_SG=$(aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

echo "EKS Security Group: $EKS_NODE_SG"
echo "RDS Security Group: $RDS_SG"

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --source-group $EKS_NODE_SG \
  --region us-east-1

echo "RDS security group updated - EKS pods can now connect to MySQL"


===================================================
STAGE 5: DEPLOY WITH HELM CHART
===================================================
EXPLANATION: Helm deploys all 8 microservices to EKS.
The chart uses the images that GitHub Actions pushed to ECR.
InitContainers ensure services start in the correct order.

---------------------------------------------
Step 5a - Create OpenAI secret for AI chatbot:
---------------------------------------------
kubectl create secret generic openai-secret \
  --namespace petclinic \
  --from-literal=SPRING_AI_OPENAI_API_KEY=YOUR_OPENAI_API_KEY_HERE

---------------------------------------------
Step 5b - Deploy the Helm chart:
---------------------------------------------
cd ~/petclinic-platform

helm install petclinic helm/petclinic/ \
  --namespace petclinic \
  --set image.registry=139561979448.dkr.ecr.us-east-1.amazonaws.com \
  --set image.tag=latest

---------------------------------------------
Step 5c - Watch pods come up (takes 3-5 minutes):
---------------------------------------------
kubectl get pods -n petclinic -w

# Expected final state - ALL 8 pods showing 1/1 Running:
# admin-server-xxx        1/1     Running
# api-gateway-xxx         1/1     Running
# config-server-xxx       1/1     Running
# customers-service-xxx   1/1     Running
# discovery-server-xxx    1/1     Running
# genai-service-xxx       1/1     Running
# vets-service-xxx        1/1     Running
# visits-service-xxx      1/1     Running

---------------------------------------------
Step 5d - Get the app URL:
---------------------------------------------
kubectl get svc api-gateway -n petclinic
# Copy EXTERNAL-IP and open in browser


===================================================
STAGE 6: ARGOCD - GitOps Continuous Deployment
===================================================
EXPLANATION: ArgoCD watches the petclinic-platform GitHub repo.
When GitHub Actions updates the image tag in values.yaml,
ArgoCD automatically redeploys the new version on EKS.
No manual kubectl apply needed for future deployments!

---------------------------------------------
Step 6a - Install ArgoCD:
---------------------------------------------
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

---------------------------------------------
Step 6b - Expose ArgoCD UI:
---------------------------------------------
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

kubectl get svc argocd-server -n argocd
# Copy EXTERNAL-IP for ArgoCD UI

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
# Copy this password

---------------------------------------------
Step 6c - Connect ArgoCD to platform repo:
---------------------------------------------
kubectl apply -f ~/petclinic-platform/argocd/application.yml

kubectl get application petclinic -n argocd
# Should show: SYNC STATUS=Synced, HEALTH STATUS=Healthy

# Open ArgoCD UI: http://EXTERNAL-IP
# Username: admin
# Password: from command above


===================================================
STAGE 7: ALB INGRESS + ROUTE 53 (HTTPS)
===================================================
EXPLANATION: AWS Load Balancer Controller creates an ALB
from our Ingress manifest. Route 53 points eta-oko.com to the ALB.
ACM certificate provides HTTPS encryption.

---------------------------------------------
Step 7a - Install AWS Load Balancer Controller:
---------------------------------------------
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

---------------------------------------------
Step 7b - Update ALB role OIDC trust policy:
IMPORTANT: OIDC changes every time! Must update.
---------------------------------------------
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
# Both pods should show: Running

---------------------------------------------
Step 7c - Apply Ingress (creates the ALB):
---------------------------------------------
kubectl apply -f ~/petclinic-platform/argocd/ingress.yml

# Wait 2-3 minutes for ALB to be provisioned
watch -n 15 'kubectl get ingress petclinic-ingress -n petclinic'
# Wait until ADDRESS column shows the ALB hostname

---------------------------------------------
Step 7d - Update Route 53 to point to ALB:
---------------------------------------------
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

# Wait 2-5 minutes then test:
curl -I https://eta-oko.com
# Should show: HTTP/1.1 200 OK


===================================================
STAGE 8: MONITORING - Prometheus + Grafana
===================================================
EXPLANATION: Prometheus collects metrics from all services.
Grafana displays them as dashboards.
Spring PetClinic already has Micrometer built in -
services automatically expose /actuator/prometheus endpoint.

---------------------------------------------
Step 8a - Scale to 3 nodes (monitoring needs resources):
---------------------------------------------
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

# Wait for 3rd node to join
watch -n 20 'kubectl get nodes'
# Wait until 3 nodes show: Ready

---------------------------------------------
Step 8b - Install Prometheus + Grafana:
---------------------------------------------
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

# Wait for all pods (2-3 minutes)
kubectl get pods -n monitoring

---------------------------------------------
Step 8c - Apply PodMonitor (tells Prometheus what to scrape):
---------------------------------------------
kubectl apply -f ~/petclinic-platform/argocd/pod-monitor.yml

kubectl get podmonitor -n monitoring
# Should show: petclinic-pods

---------------------------------------------
Step 8d - Access Grafana via port-forward:
NOTE: We use port-forward because LoadBalancer has subnet issues
---------------------------------------------
pkill -f "port-forward" 2>/dev/null || true
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring &
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring &

echo "Grafana:    http://localhost:3000"
echo "Login:      admin / petclinic123"
echo "Prometheus: http://localhost:9090"

---------------------------------------------
Step 8e - Import Spring PetClinic dashboard:
NOTE: Use local file - avoids internet connectivity issues
---------------------------------------------
cp ~/spring-petclinic-microservices/docker/grafana/dashboards/grafana-petclinic-dashboard.json \
  /tmp/petclinic-dashboard.json

echo "Now in Grafana browser:"
echo "1. Click Dashboards → Import"
echo "2. Click Upload dashboard JSON file"
echo "3. Select /tmp/petclinic-dashboard.json"
echo "4. Select Prometheus as data source"
echo "5. Click Import"

---------------------------------------------
Step 8f - Verify Prometheus is scraping:
Open: http://localhost:9090/targets
---------------------------------------------
# Expected: 5/8 petclinic services showing UP
# customers-service, vets-service, visits-service,
# api-gateway, genai-service = UP
# admin-server, config-server, discovery-server = DOWN
# (they don't have Micrometer Prometheus dependency)


===================================================
VERIFICATION - Check everything is working
===================================================

# Check all pods are running
kubectl get pods -n petclinic
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n external-secrets

# Check ArgoCD is synced
kubectl get application petclinic -n argocd

# Check secret is synced
kubectl get secret mysql-secret -n petclinic

# Test the app
curl -I https://eta-oko.com

# Open in browser:
# https://eta-oko.com              - Main app
# http://localhost:3000            - Grafana
# http://localhost:9090/targets    - Prometheus targets
# ArgoCD UI from Stage 6


===================================================
STAGE 9: END OF DAY CLEANUP - RUN EVERY DAY!
===================================================
EXPLANATION: EKS + RDS costs money every hour.
One command destroys everything and stops all charges.
Tomorrow we just run terraform apply again to rebuild.

cd ~/petclinic-platform/terraform
terraform destroy -auto-approve

# Verify everything deleted:
aws eks list-clusters --region us-east-1
# Expected: { "clusters": [] }

aws rds describe-db-instances --region us-east-1 \
  --query 'DBInstances[].DBInstanceStatus' --output text
# Expected: empty

aws ecr describe-repositories --region us-east-1 \
  --query 'repositories[].repositoryName' --output table
# Expected: empty


===================================================
QUICK REFERENCE - Key Values
===================================================

AWS Account ID:   139561979448
AWS Region:       us-east-1
EKS Cluster:      petclinic-eks
ECR Registry:     139561979448.dkr.ecr.us-east-1.amazonaws.com
Domain:           eta-oko.com
Hosted Zone ID:   Z082555627EV8NAU07JQ4
ALB Zone ID:      Z35SXDOTRQ7X7K
ACM Cert ARN:     arn:aws:acm:us-east-1:139561979448:certificate/ff9d81a7-4b2b-4f81-9816-254bc50482cb
ESO IAM Role:     petclinic-eso-role
ALB IAM Role:     petclinic-alb-role
Grafana Login:    admin / petclinic123
ArgoCD Login:     admin / (get from kubectl command)
App Repo:         github.com/etaoko333/spring-petclinic-microservices
Platform Repo:    github.com/etaoko333/petclinic-platform


===================================================
IMPORTANT REMINDERS
===================================================

1. OIDC changes every new EKS cluster - always update:
   - petclinic-eso-role trust policy (Stage 3b)
   - petclinic-alb-role trust policy (Stage 7b)

2. GitHub Actions builds images - no manual docker commands!

3. Grafana - use port-forward not LoadBalancer URL

4. Import dashboard from local file not dashboard ID 4701

5. terraform destroy EVERY day before sleeping!

6. If helm install fails try helm upgrade instead

7. Deploy stages in exact order - never skip a stage!
