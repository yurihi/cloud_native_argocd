# RESTful Web Services - Cloud Native Application

Spring Boot 기반의 RESTful API 서버로, AWS EKS와 ArgoCD를 사용한 GitOps 방식의 배포를 지원합니다.

## 🚀 기술 스택

- **Backend**: Spring Boot 3.5.0, Java 17
- **Build Tool**: Maven
- **Container**: Docker, Multi-stage build
- **Orchestration**: Kubernetes (AWS EKS)
- **GitOps**: ArgoCD
- **CI/CD**: GitHub Actions
- **Cloud Provider**: AWS (ECR, EKS, ALB)

## 📁 프로젝트 구조

```
restful-web-services/
├── src/                        # Spring Boot 소스 코드
│   ├── main/
│   │   ├── java/
│   │   └── resources/
│   └── test/
├── k8s/                        # Kubernetes 매니페스트
│   ├── deployment.yaml         # Deployment 설정
│   ├── service.yaml            # Service 설정
│   ├── ingress.yaml            # ALB Ingress 설정
│   ├── configmap.yaml          # ConfigMap
│   ├── hpa.yaml                # HorizontalPodAutoscaler
│   └── kustomization.yaml      # Kustomize 설정
├── argocd/                     # ArgoCD 설정
│   └── application.yaml        # ArgoCD Application
├── .github/                    # GitHub Actions
│   └── workflows/
│       └── deploy.yaml         # CI/CD 파이프라인
├── Dockerfile                  # Multi-stage Dockerfile
├── .dockerignore
├── DEPLOYMENT_GUIDE.md         # 배포 가이드
└── pom.xml

```

## 🏃 로컬 실행

### 필수 요구사항
- Java 17+
- Maven 3.6+

### 실행 방법

```bash
# 빌드
./mvnw clean package

# 실행
./mvnw spring-boot:run

# 또는 JAR 파일로 실행
java -jar target/restful-web-services-0.0.1-SNAPSHOT.jar
```

### API 테스트

```bash
# Hello World
curl http://localhost:8080/helloworld

# Hello World Bean
curl http://localhost:8080/hello-world-bean

# Health Check
curl http://localhost:8080/actuator/health
```

## 🐳 Docker로 실행

```bash
# 이미지 빌드
docker build -t restful-web-services:latest .

# 컨테이너 실행
docker run -p 8080:8080 restful-web-services:latest

# API 테스트
curl http://localhost:8080/helloworld
```

## ☁️ AWS EKS 배포

자세한 배포 가이드는 [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)를 참조하세요.

### 빠른 시작

1. **사전 준비**
   ```bash
   # AWS CLI, kubectl, eksctl 설치 확인
   aws --version
   kubectl version --client
   eksctl version
   ```

2. **EKS 클러스터 생성**
   ```bash
   eksctl create cluster --name my-cluster --region ap-northeast-2
   ```

3. **Docker 이미지 빌드 및 푸시**
   ```bash
   # ECR 로그인
   aws ecr get-login-password --region ap-northeast-2 | \
       docker login --username AWS --password-stdin <AWS_ACCOUNT>.dkr.ecr.ap-northeast-2.amazonaws.com
   
   # 이미지 빌드 및 푸시
   docker build -t <AWS_ACCOUNT>.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest .
   docker push <AWS_ACCOUNT>.dkr.ecr.ap-northeast-2.amazonaws.com/restful-web-services:latest
   ```

4. **ArgoCD 설치**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

5. **애플리케이션 배포**
   ```bash
   kubectl apply -f argocd/application.yaml
   ```

## 🔧 설정

### 환경 변수

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `SERVER_PORT` | 서버 포트 | 8080 |
| `SPRING_PROFILES_ACTIVE` | Spring 프로파일 | default |
| `JAVA_OPTS` | JVM 옵션 | `-Xmx512m -Xms256m` |

### Kubernetes 리소스

- **CPU**: 요청 250m, 제한 500m
- **Memory**: 요청 512Mi, 제한 1Gi
- **Replicas**: 최소 2, 최대 10 (HPA)
- **Auto-scaling**: CPU 70%, Memory 80% 기준

## 📊 모니터링

### Health Check Endpoints

- **Liveness**: `/actuator/health/liveness`
- **Readiness**: `/actuator/health/readiness`
- **General Health**: `/actuator/health`
- **Metrics**: `/actuator/metrics`

### ArgoCD UI

```bash
# Port forwarding
kubectl port-forward svc/argocd-server -n argocd 8080:443

# https://localhost:8080 접속
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 🔐 보안

- **Non-root 사용자**: 컨테이너는 `spring` 사용자로 실행
- **이미지 스캔**: GitHub Actions에서 Trivy를 사용한 보안 스캔
- **최소 권한**: Kubernetes RBAC 적용
- **Health Check**: Liveness 및 Readiness Probe 설정

## 🚦 CI/CD

GitHub Actions를 사용한 자동화된 CI/CD 파이프라인:

1. **빌드 및 테스트**: Maven을 사용한 빌드 및 유닛 테스트
2. **이미지 빌드**: Multi-stage Docker 빌드
3. **보안 스캔**: Trivy를 사용한 취약점 스캔
4. **ECR 푸시**: AWS ECR에 이미지 푸시
5. **매니페스트 업데이트**: Kubernetes 배포 매니페스트 자동 업데이트
6. **ArgoCD 동기화**: GitOps를 통한 자동 배포

## 📝 API 문서

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/helloworld` | 간단한 Hello World 메시지 반환 |
| GET | `/hello-world-bean` | Hello World JSON 객체 반환 |
| GET | `/actuator/health` | 애플리케이션 상태 확인 |
| GET | `/actuator/info` | 애플리케이션 정보 |
| GET | `/actuator/metrics` | 메트릭 정보 |

## 🤝 기여

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 라이선스

This project is licensed under the MIT License.

## 📞 문의

프로젝트 관련 문의사항이 있으시면 이슈를 등록해주세요.

---

**Last Updated**: 2025-12-10
