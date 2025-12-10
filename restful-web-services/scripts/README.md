# 스크립트 사용 가이드

이 디렉토리에는 AWS Route 53 도메인 설정 및 DNS 레코드 생성을 자동화하는 스크립트가 포함되어 있습니다.

## 📁 파일 목록

### Linux/Mac용 (Bash)
- `setup-domain.sh` - 도메인, ACM 인증서, Ingress 설정
- `create-dns-record.sh` - Route 53 DNS 레코드 생성

### Windows용 (PowerShell)
- `setup-domain.ps1` - 도메인, ACM 인증서, Ingress 설정
- `create-dns-record.ps1` - Route 53 DNS 레코드 생성

---

## 🚀 사용 방법

### 1단계: 도메인 및 인증서 설정

#### Linux/Mac:
```bash
chmod +x scripts/*.sh
./scripts/setup-domain.sh yourcompany.com api
```

#### Windows PowerShell:
```powershell
# 실행 정책 설정 (한 번만)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 스크립트 실행
.\scripts\setup-domain.ps1 -Domain "yourcompany.com" -Subdomain "api"
```

**이 스크립트는:**
- Route 53 Hosted Zone 확인
- ACM에서 SSL 인증서 요청
- DNS 검증 레코드 자동 생성
- 인증서 발급 대기
- `k8s/ingress.yaml` 자동 업데이트

### 2단계: Ingress 배포

```bash
kubectl apply -f k8s/ingress.yaml
```

### 3단계: DNS 레코드 생성

#### Linux/Mac:
```bash
./scripts/create-dns-record.sh yourcompany.com api
```

#### Windows PowerShell:
```powershell
.\scripts\create-dns-record.ps1 -Domain "yourcompany.com" -Subdomain "api"
```

**이 스크립트는:**
- Kubernetes Ingress에서 ALB DNS 자동 추출
- Route 53에 A 레코드 (Alias) 자동 생성
- DNS 전파 상태 확인

---

## 📋 사전 요구사항

### 필수 도구
- AWS CLI (설정 완료 상태)
- kubectl (EKS 클러스터 연결 상태)
- jq (Linux/Mac, JSON 파싱용)

### AWS 리소스
- Route 53 Hosted Zone (도메인이 등록되어 있어야 함)
- EKS 클러스터 (실행 중)
- AWS Load Balancer Controller (설치 완료)

### 권한
AWS CLI에 다음 권한이 필요합니다:
- `route53:ListHostedZones`
- `route53:ChangeResourceRecordSets`
- `route53:GetChange`
- `acm:RequestCertificate`
- `acm:DescribeCertificate`
- `acm:ListCertificates`

---

## 🔧 스크립트 파라미터

### setup-domain.sh / setup-domain.ps1

**파라미터:**
- `domain` (필수): 루트 도메인 (예: `yourcompany.com`)
- `subdomain` (필수): 서브도메인 (예: `api`)
- `region` (선택): AWS 리전 (기본값: `ap-northeast-2`)

**예시:**
```bash
# Bash
./scripts/setup-domain.sh example.com api

# PowerShell
.\scripts\setup-domain.ps1 -Domain "example.com" -Subdomain "api" -Region "ap-northeast-2"
```

### create-dns-record.sh / create-dns-record.ps1

**파라미터:**
- `domain` (필수): 루트 도메인
- `subdomain` (필수): 서브도메인

**예시:**
```bash
# Bash
./scripts/create-dns-record.sh example.com api

# PowerShell
.\scripts\create-dns-record.ps1 -Domain "example.com" -Subdomain "api"
```

---

## 📝 주요 기능

### setup-domain 스크립트

1. **Hosted Zone 검증**
   - 지정된 도메인의 Route 53 Hosted Zone 확인
   - 없으면 생성 방법 안내

2. **ACM 인증서 요청**
   - 루트 도메인 및 와일드카드 인증서 요청
   - 기존 인증서가 있으면 재사용

3. **DNS 검증**
   - ACM DNS 검증 레코드 자동 추출
   - Route 53에 CNAME 레코드 자동 생성

4. **인증서 발급 대기**
   - 최대 5분간 발급 상태 모니터링
   - 발급 완료 시 자동 진행

5. **Ingress 설정 업데이트**
   - `k8s/ingress.yaml` 자동 수정
   - 인증서 ARN 및 도메인 설정
   - 원본 파일 백업 (.backup)

### create-dns-record 스크립트

1. **ALB DNS 추출**
   - Kubernetes Ingress에서 ALB 정보 자동 추출

2. **리전별 Hosted Zone ID**
   - ALB DNS에서 리전 자동 감지
   - 해당 리전의 ALB Hosted Zone ID 사용

3. **A 레코드 생성**
   - Alias 레코드로 ALB 연결
   - Health check 활성화

4. **전파 확인**
   - DNS 변경 상태 모니터링
   - 완료 시 자동 알림

---

## ⚠️ 주의사항

### 1. Hosted Zone 미리 생성
스크립트 실행 전에 Route 53 Hosted Zone이 생성되어 있어야 합니다.

```bash
# Hosted Zone 생성
aws route53 create-hosted-zone \
    --name yourcompany.com \
    --caller-reference $(date +%s)
```

### 2. ACM 리전
ACM 인증서는 반드시 **ALB와 같은 리전**에서 발급해야 합니다.
- EKS 클러스터가 `ap-northeast-2`에 있다면
- ACM 인증서도 `ap-northeast-2`에서 발급

### 3. DNS 전파 시간
- Route 53 내부: 즉시~수 분
- 글로벌 DNS: 최대 48시간 (보통 5-10분)

### 4. 백업 파일
스크립트는 자동으로 백업을 생성합니다:
- `k8s/ingress.yaml.backup`

변경사항을 되돌리려면 백업 파일을 복원하세요.

---

## 🐛 문제 해결

### "Hosted Zone을 찾을 수 없습니다"

**원인:** Route 53에 Hosted Zone이 없음

**해결:**
```bash
aws route53 create-hosted-zone \
    --name yourcompany.com \
    --caller-reference $(date +%s)
```

### "Ingress에서 ALB를 찾을 수 없습니다"

**원인:** Ingress가 아직 생성되지 않았거나 ALB 생성 중

**해결:**
```bash
# Ingress 적용
kubectl apply -f k8s/ingress.yaml

# ALB 생성 확인 (2-5분 소요)
kubectl get ingress restful-web-services -w
```

### "인증서가 아직 발급되지 않았습니다"

**원인:** DNS 검증이 완료되지 않음

**해결:**
1. AWS Console → ACM → 인증서 확인
2. DNS 검증 레코드가 Route 53에 있는지 확인
3. 5-10분 대기 후 재시도

### PowerShell 실행 정책 오류

**원인:** PowerShell 스크립트 실행이 차단됨

**해결:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 💡 팁

### 여러 환경 설정
개발, 스테이징, 프로덕션 환경별로 다른 서브도메인 사용:

```bash
# 개발
./scripts/setup-domain.sh yourcompany.com dev-api

# 스테이징
./scripts/setup-domain.sh yourcompany.com staging-api

# 프로덕션
./scripts/setup-domain.sh yourcompany.com api
```

### 빠른 테스트
도메인 없이 테스트하려면:

```bash
# ALB DNS 직접 사용
ALB_DNS=$(kubectl get ingress restful-web-services \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://$ALB_DNS/actuator/health
```

### DNS 전파 확인
여러 도구로 확인:

```bash
# nslookup
nslookup api.yourcompany.com 8.8.8.8

# dig
dig api.yourcompany.com

# 온라인
# https://dnschecker.org
# https://www.whatsmydns.net
```

---

## 📚 참고 링크

- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [AWS Certificate Manager](https://docs.aws.amazon.com/acm/)
- [ALB Hosted Zone IDs](https://docs.aws.amazon.com/general/latest/gr/elb.html)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

**작성일**: 2025-12-10
**버전**: 1.0
