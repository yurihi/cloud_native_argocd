# Windows PowerShell 명령어 가이드

## ⚠️ 중요: PowerShell vs Bash 차이점

Windows PowerShell에서는 Bash와 다른 문법을 사용합니다.

### 줄바꿈 문자 차이

| Shell | 줄바꿈 문자 | 예시 |
|-------|------------|------|
| **Bash** (Linux/Mac) | `\` (백슬래시) | `command \`<br/>`  --option value` |
| **PowerShell** (Windows) | `` ` `` (백틱) | ``command ` ``<br/>``  --option value`` |

---

## 🔧 명령어 변환 예시

### ❌ Bash 스타일 (PowerShell에서 오류)

```bash
eksctl create cluster \
    --name api-cluster \
    --region ap-northeast-2
```

### ✅ PowerShell 스타일 (올바름)

```powershell
eksctl create cluster `
    --name api-cluster `
    --region ap-northeast-2
```

**주의:** 백틱(`` ` ``)은 키보드에서 `~` 키와 같은 키입니다 (Shift 누르지 않고)

---

## 📦 필수 도구 설치 (Windows)

### 1. Chocolatey 설치 (패키지 관리자)

**PowerShell을 관리자 권한으로 실행** 후:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### 2. eksctl 설치

```powershell
# Chocolatey로 설치 (권장)
choco install eksctl -y

# 또는 직접 다운로드
# https://github.com/weaveworks/eksctl/releases
```

설치 확인:
```powershell
eksctl version
```

### 3. AWS CLI 설치

```powershell
# Chocolatey로 설치
choco install awscli -y

# 또는 MSI 설치 프로그램
# https://aws.amazon.com/cli/
```

설치 확인 및 설정:
```powershell
aws --version
aws configure
```

### 4. kubectl 설치

```powershell
# Chocolatey로 설치
choco install kubernetes-cli -y
```

설치 확인:
```powershell
kubectl version --client
```

---

## 🚀 EKS 클러스터 생성 (PowerShell)

### 한 줄 명령어 (간단)

```powershell
eksctl create cluster --name api-cluster --region ap-northeast-2 --nodegroup-name standard-workers --node-type t3.medium --nodes 2 --nodes-min 2 --nodes-max 4 --managed
```

### 여러 줄 명령어 (가독성)

```powershell
eksctl create cluster `
    --name api-cluster `
    --region ap-northeast-2 `
    --nodegroup-name standard-workers `
    --node-type t3.medium `
    --nodes 2 `
    --nodes-min 2 `
    --nodes-max 4 `
    --managed
```

**⏱️ 소요 시간:** 15-20분  
**💰 비용:** 약 $73/월 (EKS) + $60/월 (EC2)

---

## 🔄 가이드의 Bash 명령어들 → PowerShell 변환

### ECR 로그인

**Bash:**
```bash
aws ecr get-login-password --region ap-northeast-2 | \
    docker login --username AWS --password-stdin \
    521730717515.dkr.ecr.ap-northeast-2.amazonaws.com
```

**PowerShell:**
```powershell
aws ecr get-login-password --region ap-northeast-2 | `
    docker login --username AWS --password-stdin `
    521730717515.dkr.ecr.ap-northeast-2.amazonaws.com
```

또는 더 안전하게:
```powershell
$password = aws ecr get-login-password --region ap-northeast-2
$password | docker login --username AWS --password-stdin 521730717515.dkr.ecr.ap-northeast-2.amazonaws.com
```

### Docker 이미지 빌드 및 태그

**Bash:**
```bash
docker tag restful-web-services:latest \
    521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest
```

**PowerShell:**
```powershell
docker tag restful-web-services:latest `
    521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest
```

또는 한 줄로:
```powershell
docker tag restful-web-services:latest 521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest
```

### kubectl 명령어

**kubectl은 동일하게 작동:**
```powershell
kubectl get pods
kubectl apply -f k8s\deployment.yaml
kubectl get ingress
```

---

## 💡 PowerShell 팁

### 1. 변수 사용

```powershell
# 변수 정의
$ECR_REPO = "521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services"
$REGION = "ap-northeast-2"

# 변수 사용
docker tag restful-web-services:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest
```

### 2. ALB DNS 가져오기

```powershell
# Bash
# ALB_DNS=$(kubectl get ingress restful-web-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# PowerShell
$ALB_DNS = kubectl get ingress restful-web-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "ALB DNS: $ALB_DNS"

# 테스트
curl http://$ALB_DNS/actuator/health
```

### 3. for 루프

```powershell
# Bash
# for i in {1..10}; do echo $i; done

# PowerShell
1..10 | ForEach-Object { Write-Host $_ }
```

### 4. 환경 변수

```powershell
# 설정
$env:AWS_REGION = "ap-northeast-2"

# 사용
aws eks list-clusters --region $env:AWS_REGION
```

---

## 📋 전체 배포 과정 (PowerShell)

### 1단계: ECR 리포지토리 생성

```powershell
aws ecr create-repository `
    --repository-name restful-web-services `
    --region ap-northeast-2
```

### 2단계: Docker 이미지 빌드 및 푸시

```powershell
# 로그인
$password = aws ecr get-login-password --region ap-northeast-2
$password | docker login --username AWS --password-stdin 521730717515.dkr.ecr.ap-northeast-2.amazonaws.com

# 빌드
docker build -t restful-web-services:latest .

# 태그
docker tag restful-web-services:latest 521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest

# 푸시
docker push 521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest
```

### 3단계: EKS 클러스터 생성

```powershell
eksctl create cluster `
    --name api-cluster `
    --region ap-northeast-2 `
    --nodegroup-name standard-workers `
    --node-type t3.medium `
    --nodes 2 `
    --nodes-min 2 `
    --nodes-max 4 `
    --managed
```

### 4단계: AWS Load Balancer Controller 설치

```powershell
# OIDC 공급자 생성
eksctl utils associate-iam-oidc-provider `
    --region ap-northeast-2 `
    --cluster api-cluster `
    --approve

# IAM 정책 다운로드
Invoke-WebRequest `
    -Uri "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json" `
    -OutFile "iam-policy.json"

# IAM 정책 생성
aws iam create-policy `
    --policy-name AWSLoadBalancerControllerIAMPolicy `
    --policy-document file://iam-policy.json

# IAM 서비스 계정 생성
$ACCOUNT_ID = aws sts get-caller-identity --query Account --output text

eksctl create iamserviceaccount `
    --cluster=api-cluster `
    --namespace=kube-system `
    --name=aws-load-balancer-controller `
    --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy `
    --override-existing-serviceaccounts `
    --approve

# Helm 설치 (Chocolatey)
choco install kubernetes-helm -y

# AWS Load Balancer Controller 설치
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
    -n kube-system `
    --set clusterName=api-cluster `
    --set serviceAccount.create=false `
    --set serviceAccount.name=aws-load-balancer-controller
```

### 5단계: ArgoCD 설치

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 대기
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
```

### 6단계: 애플리케이션 배포

```powershell
kubectl apply -f argocd\application.yaml
```

---

## 🔍 확인 명령어 (PowerShell)

```powershell
# 클러스터 확인
kubectl config current-context
kubectl get nodes

# Pod 확인
kubectl get pods
kubectl get pods -o wide

# Service 확인
kubectl get svc

# Ingress 확인
kubectl get ingress

# ALB DNS 추출
$ALB_DNS = kubectl get ingress restful-web-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "ALB DNS: $ALB_DNS"

# 헬스 체크
Invoke-WebRequest -Uri "http://$ALB_DNS/actuator/health" -UseBasicParsing

# ArgoCD 비밀번호
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

---

## 🧹 리소스 정리 (비용 절감)

```powershell
# ArgoCD Application 삭제
kubectl delete -f argocd\application.yaml

# Ingress 삭제 (ALB 삭제)
kubectl delete -f k8s\ingress.yaml

# ArgoCD 삭제
kubectl delete namespace argocd

# EKS 클러스터 삭제 (⚠️ 모든 리소스 삭제)
eksctl delete cluster --name api-cluster --region ap-northeast-2

# ECR 이미지 삭제
aws ecr batch-delete-image `
    --repository-name restful-web-services `
    --region ap-northeast-2 `
    --image-ids imageTag=latest

# ECR 리포지토리 삭제
aws ecr delete-repository `
    --repository-name restful-web-services `
    --region ap-northeast-2 `
    --force
```

---

## 📚 추가 리소스

### PowerShell 학습
- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [PowerShell Gallery](https://www.powershellgallery.com/)

### 도구 설치 가이드
- [Chocolatey](https://chocolatey.org/)
- [eksctl Windows](https://eksctl.io/introduction/#installation)
- [AWS CLI Windows](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-windows.html)

---

## ❓ FAQ

### Q: Bash 스크립트를 PowerShell에서 실행할 수 있나요?
**A:** 직접 실행은 불가능하지만, Git Bash나 WSL을 사용하면 됩니다.

```powershell
# Git Bash 설치
choco install git -y

# WSL 설치
wsl --install

# WSL에서 스크립트 실행
wsl bash ./scripts/setup-domain.sh yourcompany.com api
```

### Q: 백틱(`) 대신 다른 방법은?
**A:** 세미콜론으로 구분하거나 한 줄로 작성:

```powershell
eksctl create cluster --name api-cluster --region ap-northeast-2 --nodes 2
```

### Q: 변수 전달이 안 돼요
**A:** PowerShell은 `$변수명` 형식 사용:

```bash
# Bash
export REGION=ap-northeast-2
aws eks list-clusters --region $REGION

# PowerShell
$REGION = "ap-northeast-2"
aws eks list-clusters --region $REGION
```

---

**작성일**: 2025-12-10  
**버전**: 1.0
