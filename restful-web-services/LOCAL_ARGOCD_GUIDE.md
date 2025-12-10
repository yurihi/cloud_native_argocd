# 로컬 Kubernetes + ArgoCD 완벽 가이드

이 가이드는 **Docker Desktop Kubernetes**에서 **ArgoCD**를 설치하고 GitOps 방식으로 애플리케이션을 배포하는 방법을 설명합니다.

**💰 비용: 완전 무료!**

---

## 📋 목차

1. [사전 요구사항](#사전-요구사항)
2. [Docker Desktop Kubernetes 설정](#docker-desktop-kubernetes-설정)
3. [ArgoCD 설치](#argocd-설치)
4. [애플리케이션 배포](#애플리케이션-배포)
5. [ArgoCD UI 접속](#argocd-ui-접속)
6. [GitOps 워크플로우 테스트](#gitops-워크플로우-테스트)
7. [문제 해결](#문제-해결)

---

## 사전 요구사항

### 필수 도구

- [x] **Docker Desktop** (Kubernetes 포함)
- [x] **kubectl**
- [x] **Git**

### 설치 확인

```powershell
# Docker 확인
docker --version

# Kubernetes 확인
kubectl version --client

# Git 확인
git --version
```

---

## Docker Desktop Kubernetes 설정

### 1. Docker Desktop 설치

아직 설치하지 않았다면:

1. **다운로드:** https://www.docker.com/products/docker-desktop
2. **설치 실행**
3. **재시작** (필요 시)

### 2. Kubernetes 활성화

1. **Docker Desktop 실행**
2. **설정 열기** (우측 상단 톱니바퀴 ⚙️)
3. **Kubernetes 메뉴 선택**
4. **"Enable Kubernetes" 체크**
5. **"Apply & Restart" 클릭**

⏱️ **첫 활성화 시 5-10분 소요** (Kubernetes 이미지 다운로드)

### 3. 설정 확인

```powershell
# Kubernetes 컨텍스트 확인
kubectl config current-context
# 출력: docker-desktop

# 노드 확인
kubectl get nodes
# NAME             STATUS   ROLES           AGE   VERSION
# docker-desktop   Ready    control-plane   XXX   vX.XX.X

# 모든 Pod 확인
kubectl get pods -A
```

**"docker-desktop" 컨텍스트가 보이면 성공!** ✅

---

## ArgoCD 설치

### 1. ArgoCD Namespace 생성

```powershell
kubectl create namespace argocd
```

### 2. ArgoCD 설치

```powershell
# ArgoCD 매니페스트 적용
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

이 명령어는 다음을 설치합니다:
- ArgoCD API Server
- Repository Server
- Application Controller
- Redis
- Dex (SSO)
- ApplicationSet Controller

### 3. 설치 확인

```powershell
# ArgoCD Pod 상태 확인
kubectl get pods -n argocd

# 모든 Pod가 Running 상태가 될 때까지 대기 (2-5분)
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=600s
```

**출력 예시:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          2m
argocd-dex-server-xxx                 1/1     Running   0          2m
argocd-redis-xxx                      1/1     Running   0          2m
argocd-repo-server-xxx                1/1     Running   0          2m
argocd-server-xxx                     1/1     Running   0          2m
```

### 4. ArgoCD CLI 설치 (선택사항)

**Windows (PowerShell):**

```powershell
# 최신 릴리스 다운로드
$version = (Invoke-RestMethod https://api.github.com/repos/argoproj/argo-cd/releases/latest).tag_name
$url = "https://github.com/argoproj/argo-cd/releases/download/" + $version + "/argocd-windows-amd64.exe"

# 다운로드
Invoke-WebRequest -Uri $url -OutFile "$env:USERPROFILE\bin\argocd.exe"

# 확인
& "$env:USERPROFILE\bin\argocd.exe" version --client
```

---

## ArgoCD UI 접속

### 1. Port Forwarding

ArgoCD Server를 로컬 포트로 포워딩:

```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**이 명령어는 실행 상태로 유지되어야 합니다.** 새 터미널을 열어서 다른 작업을 하세요.

### 2. 초기 Admin 비밀번호 확인

**새 PowerShell 창에서:**

```powershell
# Base64 디코딩하여 비밀번호 추출
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
```

**출력 예시:**
```
AbCdEfGh1234XyZ
```

이 비밀번호를 **복사**하세요!

### 3. ArgoCD UI 접속

1. **브라우저 열기:** https://localhost:8080
2. **보안 경고 무시** ("고급" → "계속 진행" 클릭)
3. **로그인:**
   - Username: `admin`
   - Password: 위에서 복사한 비밀번호

**로그인 성공!** 🎉

### 4. 비밀번호 변경 (권장)

ArgoCD CLI로:

```powershell
# ArgoCD 로그인
& "$env:USERPROFILE\bin\argocd.exe" login localhost:8080

# 비밀번호 변경
& "$env:USERPROFILE\bin\argocd.exe" account update-password
```

---

## 애플리케이션 배포

### 방법 1: Git 리포지토리 사용 (실제 GitOps)

#### 1단계: Git 리포지토리 생성

**GitHub에서 리포지토리 생성 후:**

```powershell
# 프로젝트를 Git 리포지토리로 초기화
git init
git add .
git commit -m "Initial commit with K8s manifests"

# GitHub 리포지토리 연결
git remote add origin https://github.com/yurihi/cloud_native_argocd.git
git branch -M main
git push -u origin main
```

#### 2단계: ArgoCD Application 매니페스트 수정

`argocd/application.yaml`이 이미 준비되어 있습니다:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: restful-web-services
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/yurihi/cloud_native_argocd.git
    targetRevision: main
    path: k8s
  
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### 3단계: ArgoCD Application 생성

```powershell
kubectl apply -f argocd\application.yaml
```

#### 4단계: 동기화 확인

ArgoCD UI에서 또는 CLI로:

```powershell
# CLI로 확인
& "$env:USERPROFILE\bin\argocd.exe" app get restful-web-services

# 수동 동기화 (자동 동기화가 활성화되어 있으면 불필요)
& "$env:USERPROFILE\bin\argocd.exe" app sync restful-web-services
```

### 방법 2: 로컬 파일 직접 배포 (빠른 테스트)

Git 없이 바로 테스트하려면:

```powershell
# 로컬 Kubernetes에 직접 배포
kubectl apply -f k8s\deployment.yaml
kubectl apply -f k8s\service.yaml
kubectl apply -f k8s\configmap.yaml

# 배포 확인
kubectl get all
```

**주의:** Ingress는 로컬에서 작동하지 않으므로 제외합니다.

---

## 로컬 환경용 매니페스트 조정

### 1. Deployment 이미지 변경

로컬에서는 ECR 대신 로컬 이미지 사용:

**`k8s/deployment-local.yaml` 생성:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: restful-web-services
  labels:
    app: restful-web-services
spec:
  replicas: 1  # 로컬에서는 1개만
  selector:
    matchLabels:
      app: restful-web-services
  template:
    metadata:
      labels:
        app: restful-web-services
    spec:
      containers:
      - name: restful-web-services
        image: restful-web-services:latest  # 로컬 이미지
        imagePullPolicy: Never  # 로컬 이미지 사용
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "local"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### 2. Service 생성 (NodePort)

**`k8s/service-local.yaml` 생성:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: restful-web-services
spec:
  type: NodePort  # 로컬 접속용
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # localhost:30080으로 접속
  selector:
    app: restful-web-services
```

### 3. 배포

```powershell
# 로컬 Docker 이미지 빌드
docker build -t restful-web-services:latest .

# Kubernetes에 배포
kubectl apply -f k8s\deployment-local.yaml
kubectl apply -f k8s\service-local.yaml

# 확인
kubectl get pods
kubectl get svc
```

### 4. 접속

```powershell
# NodePort로 접속
curl http://localhost:30080/helloworld
curl http://localhost:30080/actuator/health

# 또는 Port Forward 사용
kubectl port-forward svc/restful-web-services 8080:80
curl http://localhost:8080/helloworld
```

---

## GitOps 워크플로우 테스트

### 1. 코드 변경

`HelloWorldController.java` 수정:

```java
@GetMapping("/helloworld")
public String helloWorld() {
    return "Hello from ArgoCD!";  // 변경
}
```

### 2. Docker 이미지 재빌드

```powershell
# 빌드
.\mvnw.cmd clean package -DskipTests

# Docker 이미지 빌드
docker build -t restful-web-services:v2 .

# Deployment 매니페스트 업데이트
# k8s/deployment-local.yaml에서 image: restful-web-services:v2로 변경
```

### 3. Git에 푸시

```powershell
git add .
git commit -m "Update hello message"
git push
```

### 4. ArgoCD 자동 동기화 확인

- ArgoCD UI에서 변경사항 감지 확인
- 자동으로 새 버전 배포
- Pod 재시작 확인

```powershell
# Pod 상태 확인
kubectl get pods -w

# 새 메시지 확인
curl http://localhost:30080/helloworld
# 출력: Hello from ArgoCD!
```

---

## ArgoCD 주요 기능 테스트

### 1. Self-Healing (자동 복구)

```powershell
# Pod 수동 삭제
kubectl delete pod -l app=restful-web-services

# ArgoCD가 자동으로 재생성함
kubectl get pods
```

### 2. Rollback (롤백)

ArgoCD UI에서:
1. **History 탭** 클릭
2. **이전 버전 선택**
3. **Rollback** 클릭

CLI로:
```powershell
& "$env:USERPROFILE\bin\argocd.exe" app rollback restful-web-services
```

### 3. 동기화 상태 확인

```powershell
# 현재 상태
& "$env:USERPROFILE\bin\argocd.exe" app get restful-web-services

# 동기화
& "$env:USERPROFILE\bin\argocd.exe" app sync restful-web-services

# 차이점 확인
& "$env:USERPROFILE\bin\argocd.exe" app diff restful-web-services
```

---

## 로컬 vs AWS 비교

| 기능 | 로컬 (Docker Desktop) | AWS EKS |
|------|---------------------|---------|
| **Kubernetes** | ✅ 동일 | ✅ 동일 |
| **ArgoCD** | ✅ 동일 | ✅ 동일 |
| **GitOps** | ✅ 동일 | ✅ 동일 |
| **Deployment** | ✅ 동일 | ✅ 동일 |
| **Service** | ✅ NodePort/ClusterIP | ✅ 모든 타입 |
| **Ingress/ALB** | ❌ 작동 안 함 | ✅ 작동 |
| **외부 접속** | ❌ localhost만 | ✅ 인터넷 |
| **비용** | ✅ **무료** | ❌ $159/월 |
| **학습** | ✅ **완벽** | ✅ 완벽 |

**결론:** 학습 목적이라면 로컬에서 충분합니다!

---

## 문제 해결

### Q: "docker-desktop" 컨텍스트가 없어요
**A:** Docker Desktop에서 Kubernetes를 활성화하세요:
- Settings → Kubernetes → Enable Kubernetes

### Q: ArgoCD Pod가 시작되지 않아요
**A:** 리소스 부족일 수 있습니다. Docker Desktop 설정 확인:
- Settings → Resources → Memory를 최소 4GB로 설정

### Q: 이미지를 찾을 수 없다고 해요
**A:** `imagePullPolicy: Never` 설정 확인:
```yaml
imagePullPolicy: Never  # 로컬 이미지 사용
```

### Q: Port Forwarding이 끊겨요
**A:** 백그라운드로 실행:
```powershell
Start-Job -ScriptBlock {
    kubectl port-forward svc/argocd-server -n argocd 8080:443
}
```

### Q: Git 리포지토리 접근 안 돼요
**A:** Public 리포지토리 사용 또는 SSH 키 설정:
```powershell
# SSH 키 생성
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# GitHub에 SSH 키 등록
```

---

## 정리 및 제거

### ArgoCD Application 삭제

```powershell
kubectl delete -f argocd\application.yaml
```

### 배포된 리소스 삭제

```powershell
kubectl delete -f k8s\deployment-local.yaml
kubectl delete -f k8s\service-local.yaml
```

### ArgoCD 완전 제거

```powershell
kubectl delete namespace argocd
```

### Kubernetes 리셋

Docker Desktop → Settings → Kubernetes → Reset Kubernetes Cluster

---

## 빠른 참조

### ArgoCD CLI 명령어

```powershell
# 로그인
& "$env:USERPROFILE\bin\argocd.exe" login localhost:8080

# 앱 목록
& "$env:USERPROFILE\bin\argocd.exe" app list

# 앱 상태
& "$env:USERPROFILE\bin\argocd.exe" app get restful-web-services

# 동기화
& "$env:USERPROFILE\bin\argocd.exe" app sync restful-web-services

# 삭제
& "$env:USERPROFILE\bin\argocd.exe" app delete restful-web-services
```

### kubectl 명령어

```powershell
# 컨텍스트 전환
kubectl config use-context docker-desktop

# Pod 확인
kubectl get pods
kubectl get pods -n argocd

# 로그 확인
kubectl logs <pod-name>
kubectl logs -f <pod-name>  # 실시간

# 서비스 확인
kubectl get svc

# 전체 리소스
kubectl get all
```

---

## 학습 체크리스트

로컬에서 완전히 익히기:

- [ ] Docker Desktop Kubernetes 활성화
- [ ] ArgoCD 설치
- [ ] ArgoCD UI 접속 및 로그인
- [ ] 로컬 이미지로 애플리케이션 배포
- [ ] Git 리포지토리와 연동
- [ ] GitOps 워크플로우 테스트
- [ ] Self-Healing 확인
- [ ] Rollback 테스트
- [ ] ConfigMap 변경 및 자동 동기화

**모두 완료하면 AWS EKS로 이동할 준비 완료!** 🚀

---

**작성일:** 2025-12-10  
**대상:** 로컬 Kubernetes + ArgoCD  
**비용:** 무료
