# AWS EKS + ArgoCD 배포 가이드

이 가이드는 Spring Boot 애플리케이션을 AWS EKS에 ArgoCD를 사용하여 배포하는 전체 과정을 설명합니다.

## 📋 목차

1. [사전 준비사항](#사전-준비사항)
2. [애플리케이션 준비](#애플리케이션-준비)
3. [Docker 이미지 빌드 및 푸시](#docker-이미지-빌드-및-푸시)
4. [EKS 클러스터 설정](#eks-클러스터-설정)
5. [ArgoCD 설치](#argocd-설치)
6. [애플리케이션 배포](#애플리케이션-배포)
7. [확인 및 모니터링](#확인-및-모니터링)
8. [문제 해결](#문제-해결)

---

## 사전 준비사항

### 필요한 도구 설치

```bash
# AWS CLI
aws --version

# kubectl
kubectl version --client

# eksctl
eksctl version

# Docker
docker --version

# Helm (ArgoCD 설치용)
helm version
```

### AWS 계정 설정

```bash
# AWS 자격 증명 설정
aws configure

# 사용할 리전 확인
aws configure get region
```

---

## 애플리케이션 준비

### 1. Spring Boot Actuator 추가

`pom.xml`에 다음 의존성을 추가하세요:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

### 2. application.properties 설정

`src/main/resources/application.properties`에 다음 내용을 추가:

```properties
# Management endpoints
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=when-authorized
management.health.livenessState.enabled=true
management.health.readinessState.enabled=true
```

### 3. 애플리케이션 빌드 테스트

```bash
# Maven으로 빌드
./mvnw clean package

# 로컬에서 실행 테스트
java -jar target/restful-web-services-0.0.1-SNAPSHOT.jar

# Health check 확인
curl http://localhost:8080/actuator/health
```

---

## Docker 이미지 빌드 및 푸시

### 1. ECR 리포지토리 생성

```bash
# ECR 리포지토리 생성
aws ecr create-repository \
    --repository-name restful-web-services \
    --region ap-northeast-2

# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
    docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com
```

### 2. Docker 이미지 빌드

```bash
# 이미지 빌드
docker build -t restful-web-services:latest .

# 이미지 태그
docker tag restful-web-services:latest \
    <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest

# 이미지 푸시
docker push <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest
```

### 3. 로컬에서 Docker 컨테이너 테스트

```bash
# 컨테이너 실행
docker run -p 8080:8080 restful-web-services:latest

# Health check 확인
curl http://localhost:8080/actuator/health
```

---

## EKS 클러스터 설정

### 1. EKS 클러스터 생성

```bash
# EKS 클러스터 생성 (약 15-20분 소요)
eksctl create cluster \
    --name api-cluster \
    --region ap-northeast-2 \
    --nodegroup-name standard-workers \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 2 \
    --nodes-max 4 \
    --managed

# kubectl 컨텍스트 확인
kubectl config current-context

# 클러스터 노드 확인
kubectl get nodes
```

### 2. AWS Load Balancer Controller 설치

```bash
# IAM OIDC 공급자 생성
eksctl utils associate-iam-oidc-provider \
    --region ap-northeast-2 \
    --cluster my-cluster \
    --approve

# IAM 정책 다운로드
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# IAM 정책 생성
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json

# IAM 서비스 계정 생성
eksctl create iamserviceaccount \
    --cluster=my-cluster \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
    --override-existing-serviceaccounts \
    --approve

# Helm으로 AWS Load Balancer Controller 설치
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=my-cluster \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller

# 설치 확인
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 3. Metrics Server 설치 (HPA용)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

## ArgoCD 설치

### 1. ArgoCD 설치

```bash
# ArgoCD namespace 생성
kubectl create namespace argocd

# ArgoCD 설치
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD 서버가 실행될 때까지 대기
kubectl wait --for=condition=available --timeout=600s \
    deployment/argocd-server -n argocd
```

### 2. ArgoCD CLI 설치

**Windows (PowerShell):**
```powershell
# Chocolatey 사용
choco install argocd-cli

# 또는 직접 다운로드
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
$url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"
$output = "$HOME\Downloads\argocd.exe"
Invoke-WebRequest -Uri $url -OutFile $output
```

### 3. ArgoCD UI 접속

```bash
# 초기 admin 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forwarding으로 ArgoCD UI 접속
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 브라우저에서 https://localhost:8080 접속
# Username: admin
# Password: 위에서 확인한 비밀번호
```

### 4. ArgoCD 비밀번호 변경 (권장)

```bash
# ArgoCD CLI로 로그인
argocd login localhost:8080

# 비밀번호 변경
argocd account update-password
```

---

## 애플리케이션 배포

### 1. Git 리포지토리에 코드 푸시

```bash
# Git 초기화 (필요한 경우)
git init

# 모든 파일 추가
git add .

# 커밋
git commit -m "Add Kubernetes manifests and ArgoCD configuration"

# 원격 리포지토리 추가
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git

# 푸시
git push -u origin main
```

### 2. k8s/deployment.yaml 수정

`k8s/deployment.yaml` 파일에서 이미지 경로를 수정하세요:

```yaml
image: <AWS_ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest
```

### 3. argocd/application.yaml 수정

`argocd/application.yaml` 파일에서 Git 리포지토리 URL을 수정하세요:

```yaml
source:
  repoURL: https://github.com/YOUR_USERNAME/YOUR_REPO.git
  targetRevision: main
  path: k8s
```

### 4. ArgoCD Application 생성

```bash
# ArgoCD Application 배포
kubectl apply -f argocd/application.yaml

# 또는 ArgoCD CLI 사용
argocd app create restful-web-services \
    --repo https://github.com/YOUR_USERNAME/YOUR_REPO.git \
    --path k8s \
    --dest-server https://kubernetes.default.svc \
    --dest-namespace default \
    --sync-policy automated \
    --self-heal \
    --auto-prune
```

### 5. 필요한 경우 수동 동기화

```bash
# ArgoCD UI에서 또는 CLI로 수동 동기화
argocd app sync restful-web-services
```

---

## 확인 및 모니터링

### 1. 배포 상태 확인

```bash
# ArgoCD에서 애플리케이션 상태 확인
argocd app get restful-web-services

# Kubernetes 리소스 확인
kubectl get all

# Pod 상태 확인
kubectl get pods
kubectl describe pod <pod-name>

# Pod 로그 확인
kubectl logs <pod-name>
```

### 2. Service 및 Ingress 확인

```bash
# Service 확인
kubectl get svc

# Ingress 확인
kubectl get ingress

# ALB 주소 확인
kubectl get ingress restful-web-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 3. 애플리케이션 테스트

```bash
# ALB DNS 이름 가져오기
ALB_DNS=$(kubectl get ingress restful-web-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl http://$ALB_DNS/actuator/health

# API 테스트
curl http://$ALB_DNS/helloworld
curl http://$ALB_DNS/hello-world-bean
```

### 4. HPA 동작 확인

```bash
# HPA 상태 확인
kubectl get hpa

# 부하 테스트 (선택사항)
kubectl run -it --rm load-generator --image=busybox /bin/sh
# 컨테이너 안에서:
while true; do wget -q -O- http://restful-web-services/helloworld; done
```

---

## 문제 해결

### Pod가 시작되지 않는 경우

```bash
# Pod 상세 정보 확인
kubectl describe pod <pod-name>

# Pod 로그 확인
kubectl logs <pod-name>

# 이전 컨테이너 로그 확인 (재시작된 경우)
kubectl logs <pod-name> --previous

# 이벤트 확인
kubectl get events --sort-by='.lastTimestamp'
```

### ImagePullBackOff 오류

```bash
# ECR 접근 권한 확인
# EKS 노드의 IAM 역할에 ECR 읽기 권한이 있는지 확인

# ECR 리포지토리 정책 확인
aws ecr get-repository-policy --repository-name restful-web-services

# 필요한 경우 정책 추가
aws ecr set-repository-policy \
    --repository-name restful-web-services \
    --policy-text file://ecr-policy.json
```

### ArgoCD 동기화 실패

```bash
# ArgoCD 애플리케이션 상태 확인
argocd app get restful-web-services

# Git 리포지토리 접근 가능 여부 확인
argocd repo list

# 수동으로 재동기화
argocd app sync restful-web-services --force
```

### ALB가 생성되지 않는 경우

```bash
# AWS Load Balancer Controller 로그 확인
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Ingress 이벤트 확인
kubectl describe ingress restful-web-services

# Ingress annotations 확인
kubectl get ingress restful-web-services -o yaml
```

---

## 🔧 추가 설정

### 1. 도메인 연결 (Route 53)

```bash
# ALB DNS 이름 확인
ALB_DNS=$(kubectl get ingress restful-web-services -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Route 53에서 CNAME 레코드 생성
aws route53 change-resource-record-sets \
    --hosted-zone-id <HOSTED_ZONE_ID> \
    --change-batch file://route53-change.json
```

### 2. HTTPS 설정 (ACM)

```bash
# ACM 인증서 요청
aws acm request-certificate \
    --domain-name api.yourdomain.com \
    --validation-method DNS \
    --region ap-northeast-2

# 인증서 ARN을 k8s/ingress.yaml의 주석에 추가
# alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
```

### 3. Logging 설정 (CloudWatch)

```bash
# Fluent Bit 설치
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml
```

---

## 🚀 CI/CD 파이프라인 통합

### GitHub Actions 예제

`.github/workflows/deploy.yml`:

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ap-northeast-2
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build, tag, and push image to Amazon ECR
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: restful-web-services
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
    
    - name: Update Kubernetes manifests
      run: |
        sed -i "s|image:.*|image: $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG|" k8s/deployment.yaml
        git config --global user.email "github-actions@github.com"
        git config --global user.name "GitHub Actions"
        git add k8s/deployment.yaml
        git commit -m "Update image to $IMAGE_TAG"
        git push
```

---

## 📚 참고 자료

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

---

## 📝 체크리스트

배포 전 확인사항:

- [ ] AWS CLI 설정 완료
- [ ] kubectl 설치 및 설정 완료
- [ ] Docker 설치 완료
- [ ] ECR 리포지토리 생성
- [ ] EKS 클러스터 생성
- [ ] ArgoCD 설치 완료
- [ ] Git 리포지토리에 코드 푸시
- [ ] k8s/deployment.yaml에서 이미지 경로 수정
- [ ] argocd/application.yaml에서 Git 리포지토리 URL 수정
- [ ] pom.xml에 actuator 의존성 추가
- [ ] application.properties에 health check 설정 추가

배포 후 확인사항:

- [ ] Pod가 정상적으로 실행 중
- [ ] Service가 생성됨
- [ ] Ingress가 생성되고 ALB가 프로비저닝됨
- [ ] Health check 엔드포인트 응답 확인
- [ ] API 엔드포인트 정상 작동
- [ ] HPA가 설정됨
- [ ] ArgoCD에서 애플리케이션 상태가 Healthy

---

**작성일**: 2025-12-10
**버전**: 1.0
