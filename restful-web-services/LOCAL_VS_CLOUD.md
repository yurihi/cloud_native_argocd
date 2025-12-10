# 로컬 개발 vs AWS 배포 가이드

이 문서는 **로컬에서 개발/테스트**하는 것과 **AWS에 배포**하는 것의 차이를 명확히 설명합니다.

---

## 📊 비교표

| 작업 | 실행 위치 | 비용 | 용도 |
|------|-----------|------|------|
| Spring Boot 앱 실행 | 로컬 PC | 무료 | 개발/테스트 |
| Docker 컨테이너 실행 | 로컬 PC | 무료 | 로컬 테스트 |
| Maven 빌드 | 로컬 PC | 무료 | 개발 |
| AWS CLI 명령어 | **로컬에서 입력하지만<br/>AWS에서 실행** | **💰 비용 발생** | 프로덕션 배포 |
| EKS 클러스터 | AWS 클라우드 | **💰 $73/월+** | 프로덕션 |
| ALB | AWS 클라우드 | **💰 $16/월+** | 프로덕션 |

---

## 🏠 시나리오 1: 로컬 개발 (무료, 학습용)

### 목적
- 코드 개발 및 테스트
- 비용 없이 학습
- 빠른 피드백

### 실행 방법

#### A. Spring Boot만 실행 (가장 간단)

```bash
# 빌드
./mvnw clean package

# 실행
./mvnw spring-boot:run

# 또는 JAR 파일로
java -jar target/restful-web-services-0.0.1-SNAPSHOT.jar
```

**접속:**
```bash
curl http://localhost:8080/helloworld
curl http://localhost:8080/hello-world-bean
curl http://localhost:8080/actuator/health
```

**브라우저:** http://localhost:8080/helloworld

#### B. Docker로 실행 (컨테이너 테스트)

```bash
# Docker 이미지 빌드
docker build -t restful-web-services:latest .

# 컨테이너 실행
docker run -p 8080:8080 restful-web-services:latest

# 다른 포트로 실행
docker run -p 9090:8080 restful-web-services:latest
```

**접속:**
```bash
curl http://localhost:8080/helloworld
# 또는 9090 포트
curl http://localhost:9090/helloworld
```

#### C. Kubernetes 로컬 테스트 (Docker Desktop 필요)

**Windows Docker Desktop에서 Kubernetes 활성화:**
1. Docker Desktop → Settings → Kubernetes
2. "Enable Kubernetes" 체크
3. Apply & Restart

```bash
# 로컬 Kubernetes에 배포
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 포트 포워딩으로 접속
kubectl port-forward svc/restful-web-services 8080:80

# 테스트
curl http://localhost:8080/helloworld
```

**정리:**
```bash
kubectl delete -f k8s/deployment.yaml
kubectl delete -f k8s/service.yaml
```

---

## ☁️ 시나리오 2: AWS 배포 (💰 비용 발생)

### ⚠️ 경고
- **비용이 발생합니다!**
- EKS 클러스터: **약 $73/월**
- ALB: **약 $16/월**
- 기타 리소스: 사용량에 따라

### 실행 위치
- **명령어 입력:** 로컬 PC (PowerShell, Terminal)
- **실제 실행:** AWS 클라우드
- **리소스 생성:** AWS 리전 (예: ap-northeast-2)

### 전체 프로세스

```bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1단계: ECR 리포지토리 생성
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🖥️ 실행 위치: 로컬 PC
# ☁️ 생성 위치: AWS ECR (ap-northeast-2)
# 💰 비용: 저장 용량에 따라 ($0.10/GB/월)

aws ecr create-repository \
    --repository-name restful-web-services \
    --region ap-northeast-2

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2단계: Docker 이미지 빌드 및 푸시
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🖥️ 빌드: 로컬 PC
# ☁️ 저장: AWS ECR
# 💰 비용: 스토리지 비용

# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
    docker login --username AWS --password-stdin \
    521730717515.dkr.ecr.ap-northeast-2.amazonaws.com

# 이미지 빌드 (로컬)
docker build -t restful-web-services:latest .

# 이미지 태그
docker tag restful-web-services:latest \
    521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/cloud_native:latest

# AWS로 푸시
docker push 521730717515.dkr.ecr.ap-northeast-2.amazonaws.com/cloud_native:latest

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3단계: EKS 클러스터 생성
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🖥️ 명령어 입력: 로컬 PC
# ☁️ 클러스터 생성: AWS (ap-northeast-2)
# 💰 비용: $0.10/시간 = 약 $73/월
# ⏱️ 소요 시간: 15-20분

eksctl create cluster \
    --name my-cluster \
    --region ap-northeast-2 \
    --nodegroup-name standard-workers \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 2 \
    --nodes-max 4 \
    --managed

# ⚠️ 이 명령어는 로컬에서 타이핑하지만
# 실제로는 AWS에 다음이 생성됩니다:
# - EKS Control Plane
# - EC2 Worker Nodes (2개)
# - VPC, Subnets, Security Groups
# - IAM Roles

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4단계: AWS Load Balancer Controller 설치
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🖥️ 명령어 입력: 로컬 PC
# ☁️ 설치 위치: AWS EKS 클러스터
# 💰 비용: 무료 (ALB 생성 시 비용 발생)

# ... (DEPLOYMENT_GUIDE.md 참조)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5단계: ArgoCD 설치
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🖥️ 명령어 입력: 로컬 PC
# ☁️ 설치 위치: AWS EKS 클러스터
# 💰 비용: 무료 (EKS 클러스터 비용에 포함)

kubectl create namespace argocd
kubectl apply -n argocd -f \
    https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6단계: 애플리케이션 배포
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 🖥️ 명령어 입력: 로컬 PC
# ☁️ 배포 위치: AWS EKS 클러스터
# 💰 비용: ALB 생성 시 $16/월 추가

kubectl apply -f argocd/application.yaml
```

---

## 💡 어떤 방법을 선택해야 할까요?

### 🎓 학습 중이거나 테스트만 하고 싶다면
→ **시나리오 1 (로컬 개발)** 선택

```bash
# 가장 간단한 방법
./mvnw spring-boot:run
```

**장점:**
- ✅ 완전 무료
- ✅ 즉시 시작 가능
- ✅ 빠른 피드백
- ✅ AWS 계정 불필요

**단점:**
- ❌ 프로덕션 환경 아님
- ❌ 스케일링 불가
- ❌ 로드 밸런싱 없음
- ❌ 외부 접속 불가 (localhost만)

### 💼 실제 서비스를 운영하거나 포트폴리오용
→ **시나리오 2 (AWS 배포)** 선택

**장점:**
- ✅ 실제 프로덕션 환경
- ✅ 자동 스케일링
- ✅ 고가용성
- ✅ 외부 접속 가능
- ✅ 도메인 연결 가능

**단점:**
- ❌ **비용 발생** (월 $89~)
- ❌ AWS 계정 필요
- ❌ 설정 복잡
- ❌ 학습 곡선

---

## 🆓 비용 절감 팁

### 1. **AWS 프리 티어 활용**
- 신규 계정: 12개월 무료 (제한적)
- EC2 750시간/월 무료 (t2.micro, t3.micro)
- **주의:** EKS는 프리 티어 대상 아님

### 2. **로컬 Kubernetes 사용**
- Docker Desktop Kubernetes (무료)
- Minikube (무료)
- Kind (무료)

```bash
# Minikube 설치 (Windows)
choco install minikube

# 시작
minikube start

# 배포
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 접속
minikube service restful-web-services

# 정리
minikube stop
minikube delete
```

### 3. **필요할 때만 EKS 사용**
```bash
# 사용 후 즉시 삭제
eksctl delete cluster --name my-cluster --region ap-northeast-2

# ⚠️ 삭제하지 않으면 계속 비용 발생!
```

### 4. **테스트용으로 저렴한 대안**
- **AWS Lightsail:** $3.50/월부터
- **Heroku:** 무료 티어 (제한적)
- **Render:** 무료 티어
- **Railway:** 무료 티어

---

## 🎯 권장 학습 경로

### 1단계: 로컬 개발 (1-2주)
```bash
# Spring Boot 로컬 실행
./mvnw spring-boot:run
```
- Spring Boot 개념 학습
- REST API 개발
- 로컬 테스트

### 2단계: Docker 학습 (1주)
```bash
# Docker 로컬 실행
docker build -t app .
docker run -p 8080:8080 app
```
- 컨테이너 개념 이해
- Dockerfile 작성
- 이미지 빌드

### 3단계: 로컬 Kubernetes (1-2주)
```bash
# Docker Desktop Kubernetes
kubectl apply -f k8s/
```
- Kubernetes 기본 개념
- Pod, Service, Deployment
- 로컬에서 무료로 연습

### 4단계: AWS 배포 (필요시)
```bash
# 실제 프로덕션 환경
eksctl create cluster ...
```
- 실제 클라우드 환경
- 비용 발생 주의
- 포트폴리오용

---

## ❓ FAQ

### Q1: "로컬에서 실행해도 되는거야??"
**A:** 두 가지 의미가 있습니다:

1. **Spring Boot 앱을 로컬에서 실행** → ✅ 네, 권장합니다! (무료)
   ```bash
   ./mvnw spring-boot:run
   ```

2. **AWS CLI 명령어를 로컬에서 입력** → ⚠️ 네, 가능하지만 AWS에 리소스가 생성됩니다! (비용 발생)
   ```bash
   eksctl create cluster ...  # AWS에 클러스터 생성
   ```

### Q2: "EKS 클러스터 생성 명령어도 로컬에서 실행하나요?"
**A:** 네, 명령어는 로컬 PC에서 입력하지만, 실제 클러스터는 AWS 클라우드에 생성됩니다.

```
[로컬 PC] → eksctl 명령어 → [AWS 클라우드]
                              ↓
                         EKS 클러스터 생성
                         (비용 발생!)
```

### Q3: "비용 없이 Kubernetes를 배울 수 있나요?"
**A:** 네! 로컬 Kubernetes를 사용하세요:

```bash
# Windows: Docker Desktop Kubernetes (추천)
Docker Desktop → Settings → Kubernetes → Enable

# 또는 Minikube
choco install minikube
minikube start
```

### Q4: "AWS에 배포하면 얼마나 드나요?"
**A:** 최소 구성:
- EKS Control Plane: **$73/월**
- EC2 Worker Nodes (t3.medium x2): **$60/월**
- ALB: **$16/월**
- 기타: **$10/월**
- **총: 약 $159/월** (23만원)

### Q5: "잠깐만 테스트하고 싶은데..."
**A:** 로컬에서 테스트하세요! (무료)

```bash
# 방법 1: Spring Boot만
./mvnw spring-boot:run

# 방법 2: Docker
docker run -p 8080:8080 restful-web-services

# 방법 3: Docker Desktop Kubernetes
kubectl apply -f k8s/deployment.yaml
```

---

## 🚀 빠른 시작 가이드

### 지금 바로 시작하기 (무료)

```powershell
# 1. 프로젝트 디렉토리로 이동
cd c:\Users\김유리\develop\cloud_native\restful-web-services

# 2. Spring Boot 실행
.\mvnw.cmd spring-boot:run

# 3. 다른 터미널에서 테스트
curl http://localhost:8080/helloworld
curl http://localhost:8080/hello-world-bean
curl http://localhost:8080/actuator/health

# 4. 브라우저에서 확인
# http://localhost:8080/helloworld
```

완료! 🎉

---

**작성일**: 2025-12-10  
**버전**: 1.0
