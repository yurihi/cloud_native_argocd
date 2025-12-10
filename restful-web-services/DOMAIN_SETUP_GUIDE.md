# AWS Route 53 도메인 설정 및 EKS Ingress 연동 가이드

이 가이드는 AWS Route 53을 사용하여 도메인을 설정하고, EKS Ingress (ALB)와 연동하는 전체 과정을 설명합니다.

## 📋 목차

1. [도메인 선택 옵션](#도메인-선택-옵션)
2. [Route 53에서 도메인 구매](#route-53에서-도메인-구매)
3. [기존 도메인 Route 53으로 이전](#기존-도메인-route-53으로-이전)
4. [SSL/TLS 인증서 발급 (ACM)](#ssltls-인증서-발급-acm)
5. [Ingress와 도메인 연동](#ingress와-도메인-연동)
6. [DNS 레코드 생성](#dns-레코드-생성)
7. [HTTPS 설정](#https-설정)
8. [확인 및 테스트](#확인-및-테스트)

---

## 도메인 선택 옵션

### 옵션 1: Route 53에서 새 도메인 구매 (권장)
- AWS 콘솔에서 직접 구매 가능
- 자동으로 Route 53 Hosted Zone 생성
- AWS 서비스와 완벽 통합
- 비용: 도메인 종류에 따라 다름 (예: .com 약 $12/년)

### 옵션 2: 기존 도메인을 Route 53으로 이전
- 다른 레지스트라에서 구매한 도메인 사용
- DNS를 Route 53으로 변경

### 옵션 3: 임시 테스트용 - ALB DNS 직접 사용
- 도메인 없이 ALB의 기본 DNS 이름 사용
- 개발/테스트 환경에 적합
- 비용: 무료

### 옵션 4: 무료 서비스 사용 (테스트용)
- FreeDNS, DuckDNS 등의 무료 DNS 서비스
- 프로덕션 환경에는 비추천

---

## Route 53에서 도메인 구매

### 1. AWS Console에서 도메인 검색

```bash
# AWS CLI로 도메인 가용성 확인
aws route53domains check-domain-availability \
    --domain-name yourcompany.com \
    --region us-east-1
```

**또는 AWS Console 사용:**

1. AWS Console → Route 53 → Registered domains
2. "Register Domain" 클릭
3. 원하는 도메인 이름 입력 (예: `myapp.com`)
4. 가용한 도메인 확인 및 선택
5. 연락처 정보 입력
6. 결제 정보 입력 및 구매

### 2. 도메인 등록 확인

```bash
# 등록된 도메인 목록 확인
aws route53domains list-domains --region us-east-1
```

도메인 등록은 몇 분에서 몇 시간이 걸릴 수 있습니다.

### 3. Hosted Zone 확인

도메인이 등록되면 자동으로 Hosted Zone이 생성됩니다.

```bash
# Hosted Zone 확인
aws route53 list-hosted-zones

# 특정 Hosted Zone의 레코드 확인
aws route53 list-resource-record-sets \
    --hosted-zone-id Z1234567890ABC
```

---

## 기존 도메인 Route 53으로 이전

### 1. Route 53 Hosted Zone 생성

```bash
# Hosted Zone 생성
aws route53 create-hosted-zone \
    --name yourcompany.com \
    --caller-reference $(date +%s)
```

**또는 AWS Console:**

1. Route 53 → Hosted zones → Create hosted zone
2. Domain name 입력 (예: `yourcompany.com`)
3. Type: Public hosted zone 선택
4. Create 클릭

### 2. Name Server 정보 확인

```bash
# Name Server 확인
aws route53 list-resource-record-sets \
    --hosted-zone-id Z1234567890ABC \
    --query "ResourceRecordSets[?Type=='NS']"
```

출력 예시:
```
ns-123.awsdns-12.com
ns-456.awsdns-45.net
ns-789.awsdns-78.org
ns-012.awsdns-01.co.uk
```

### 3. 기존 도메인 레지스트라에서 Name Server 변경

기존 도메인 제공업체 (GoDaddy, Namecheap 등):
1. 도메인 관리 페이지 접속
2. DNS 설정 또는 Name Server 설정 찾기
3. Route 53의 Name Server로 변경
4. 변경사항 저장

**⚠️ 주의:** DNS 전파에 최대 48시간이 걸릴 수 있습니다.

### 4. DNS 전파 확인

```bash
# Name Server 확인
nslookup -type=ns yourcompany.com

# 또는 dig 사용
dig NS yourcompany.com
```

---

## SSL/TLS 인증서 발급 (ACM)

HTTPS를 사용하려면 AWS Certificate Manager (ACM)에서 SSL 인증서를 발급받아야 합니다.

### 1. ACM 인증서 요청

```bash
# 인증서 요청
aws acm request-certificate \
    --domain-name yourcompany.com \
    --subject-alternative-names "*.yourcompany.com" \
    --validation-method DNS \
    --region ap-northeast-2

# 출력에서 CertificateArn 확인
# arn:aws:acm:ap-northeast-2:521730717515:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**또는 AWS Console:**

1. AWS Console → Certificate Manager (ACM)
2. **리전을 `ap-northeast-2` (서울)로 변경** ⚠️ 중요!
3. "Request a certificate" 클릭
4. "Request a public certificate" 선택
5. 도메인 이름 입력:
   - `yourcompany.com`
   - `*.yourcompany.com` (와일드카드, 서브도메인용)
6. Validation method: DNS validation 선택
7. Request 클릭

### 2. DNS 검증 레코드 추가

#### 자동 추가 (권장):

```bash
# 인증서 세부 정보 확인
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:ap-northeast-2:521730717515:certificate/xxx \
    --region ap-northeast-2
```

**AWS Console에서:**

1. ACM → 생성된 인증서 클릭
2. Domains 섹션에서 "Create records in Route 53" 버튼 클릭
3. Create records 클릭 (자동으로 CNAME 레코드 생성)

#### 수동 추가:

인증서 세부 정보에서 CNAME 이름과 값을 확인하고 Route 53에 수동 추가:

```bash
# CNAME 레코드 생성 (JSON 파일 사용)
cat > acm-validation.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "_abc123def456.yourcompany.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "_xyz789abc012.acm-validations.aws."
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id Z1234567890ABC \
    --change-batch file://acm-validation.json
```

### 3. 인증서 발급 확인

```bash
# 인증서 상태 확인
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:ap-northeast-2:521730717515:certificate/xxx \
    --region ap-northeast-2 \
    --query 'Certificate.Status'
```

상태가 `ISSUED`가 되면 사용 가능합니다 (보통 5-10분 소요).

### 4. 인증서 ARN 복사

발급된 인증서의 ARN을 복사해두세요. Ingress 설정에 사용됩니다.

```
arn:aws:acm:ap-northeast-2:521730717515:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

## Ingress와 도메인 연동

### 1. 서브도메인 결정

사용할 서브도메인을 결정합니다:

- `api.yourcompany.com` - API 서버용
- `app.yourcompany.com` - 웹 애플리케이션용
- `admin.yourcompany.com` - 관리자 페이지용

### 2. Ingress 파일 수정

`k8s/ingress.yaml` 파일을 수정합니다:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: restful-web-services
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    # 👇 인증서 ARN 추가
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-northeast-2:521730717515:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
spec:
  rules:
  # 👇 도메인 수정
  - host: api.yourcompany.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: restful-web-services
            port:
              number: 80
```

### 3. Ingress 적용

```bash
# Ingress 업데이트
kubectl apply -f k8s/ingress.yaml

# Ingress 상태 확인
kubectl get ingress restful-web-services

# 상세 정보 확인
kubectl describe ingress restful-web-services
```

### 4. ALB DNS 이름 확인

```bash
# ALB의 DNS 이름 가져오기
ALB_DNS=$(kubectl get ingress restful-web-services \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "ALB DNS: $ALB_DNS"
```

출력 예시:
```
k8s-default-restfulw-abc123def456-1234567890.ap-northeast-2.elb.amazonaws.com
```

**이 DNS 이름을 메모해두세요!** 다음 단계에서 사용합니다.

---

## DNS 레코드 생성

### 방법 1: AWS CLI 사용

```bash
# Hosted Zone ID 확인
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='yourcompany.com.'].Id" \
    --output text | cut -d'/' -f3)

# ALB DNS 이름 가져오기
ALB_DNS=$(kubectl get ingress restful-web-services \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Route 53 변경 배치 파일 생성
cat > route53-record.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.yourcompany.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z3W03O7B5YMIYP",
          "DNSName": "${ALB_DNS}",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

# DNS 레코드 생성
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://route53-record.json
```

**⚠️ 주의:** `HostedZoneId`는 ALB의 리전에 따라 다릅니다:
- `ap-northeast-2` (서울): `Z3W03O7B5YMIYP`
- `us-east-1` (버지니아): `Z35SXDOTRQ7X7K`
- `ap-northeast-1` (도쿄): `Z14GRHDCWA56QT`

전체 목록: https://docs.aws.amazon.com/general/latest/gr/elb.html

### 방법 2: AWS Console 사용 (더 쉬움)

1. **Route 53 Console 접속**
   - AWS Console → Route 53 → Hosted zones
   - 도메인 선택 (예: `yourcompany.com`)

2. **레코드 생성**
   - "Create record" 클릭
   - Record name: `api` (또는 원하는 서브도메인)
   - Record type: `A - Routes traffic to an IPv4 address and some AWS resources`
   - Alias 토글: **ON** (중요!)
   - Route traffic to:
     - "Alias to Application and Classic Load Balancer" 선택
     - Region: `Asia Pacific (Seoul) ap-northeast-2`
     - Load balancer: ALB 선택 (자동으로 표시됨)
   - Routing policy: Simple routing
   - Evaluate target health: **Checked** (권장)
   - Create records 클릭

### 3. DNS 레코드 확인

```bash
# Route 53 레코드 확인
aws route53 list-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query "ResourceRecordSets[?Name=='api.yourcompany.com.']"

# DNS 조회 테스트
nslookup api.yourcompany.com

# 또는 dig 사용
dig api.yourcompany.com
```

---

## HTTPS 설정

### 1. Ingress에서 HTTPS 활성화

이미 `k8s/ingress.yaml`에 다음 설정이 포함되어 있습니다:

```yaml
annotations:
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/ssl-redirect: '443'  # HTTP를 HTTPS로 리다이렉트
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...:certificate/...
```

### 2. HTTP to HTTPS 리다이렉션 동작 확인

```bash
# HTTP로 접속 시 HTTPS로 리다이렉트되는지 확인
curl -I http://api.yourcompany.com

# 출력 예시:
# HTTP/1.1 301 Moved Permanently
# Location: https://api.yourcompany.com/
```

### 3. SSL 인증서 확인

브라우저에서 확인:
1. `https://api.yourcompany.com` 접속
2. 주소창의 자물쇠 아이콘 클릭
3. 인증서 정보 확인

명령줄에서 확인:
```bash
# SSL 인증서 확인
openssl s_client -connect api.yourcompany.com:443 -servername api.yourcompany.com

# 또는 간단하게
curl -vI https://api.yourcompany.com 2>&1 | grep -A 10 "SSL certificate"
```

---

## 확인 및 테스트

### 1. DNS 전파 확인

DNS 변경사항이 전파되는 데 시간이 걸릴 수 있습니다.

```bash
# 여러 DNS 서버에서 확인
# Google DNS
nslookup api.yourcompany.com 8.8.8.8

# Cloudflare DNS
nslookup api.yourcompany.com 1.1.1.1

# 로컬 DNS
nslookup api.yourcompany.com
```

**온라인 도구:**
- https://dnschecker.org
- https://www.whatsmydns.net

### 2. 엔드포인트 테스트

```bash
# Health check
curl https://api.yourcompany.com/actuator/health

# API 테스트
curl https://api.yourcompany.com/helloworld
curl https://api.yourcompany.com/hello-world-bean

# HTTP로 접속 시 HTTPS로 리다이렉트 확인
curl -L http://api.yourcompany.com/helloworld
```

### 3. 전체 연결 테스트

```bash
# 상세한 연결 정보 확인
curl -v https://api.yourcompany.com/actuator/health

# 응답 시간 측정
time curl https://api.yourcompany.com/helloworld
```

### 4. 브라우저 테스트

1. Chrome/Edge에서 `https://api.yourcompany.com/helloworld` 접속
2. F12 개발자 도구 → Network 탭
3. 요청/응답 확인
4. Security 탭에서 인증서 확인

---

## 옵션 3: 도메인 없이 ALB DNS 직접 사용 (테스트용)

도메인이 필요 없다면 ALB의 기본 DNS를 사용할 수 있습니다.

### 1. Ingress 수정 (host 제거)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: restful-web-services
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'  # HTTPS 제거
    # SSL 관련 설정 제거
    alb.ingress.kubernetes.io/healthcheck-path: /actuator/health
spec:
  rules:
  - http:  # host 제거
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: restful-web-services
            port:
              number: 80
```

### 2. ALB DNS로 접속

```bash
# ALB DNS 확인
ALB_DNS=$(kubectl get ingress restful-web-services \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# HTTP로 접속
curl http://$ALB_DNS/helloworld
curl http://$ALB_DNS/actuator/health
```

---

## 문제 해결

### ALB가 생성되지 않는 경우

```bash
# AWS Load Balancer Controller 로그 확인
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Ingress 이벤트 확인
kubectl describe ingress restful-web-services

# Ingress Controller가 설치되어 있는지 확인
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### DNS가 해석되지 않는 경우

```bash
# Route 53 레코드 확인
aws route53 list-resource-record-sets \
    --hosted-zone-id Z1234567890ABC

# DNS 캐시 삭제 (Windows)
ipconfig /flushdns

# DNS 캐시 삭제 (Mac/Linux)
sudo dscacheutil -flushcache  # Mac
sudo systemd-resolve --flush-caches  # Linux
```

### SSL 인증서가 적용되지 않는 경우

```bash
# 인증서 상태 확인
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:... \
    --region ap-northeast-2

# Ingress annotations 확인
kubectl get ingress restful-web-services -o yaml | grep certificate-arn

# ALB의 리스너 확인 (AWS Console)
# EC2 → Load Balancers → 생성된 ALB 선택 → Listeners 탭
```

### 503 Service Unavailable 오류

```bash
# Pod 상태 확인
kubectl get pods

# Pod 로그 확인
kubectl logs <pod-name>

# Service 확인
kubectl get svc restful-web-services

# Endpoints 확인
kubectl get endpoints restful-web-services
```

---

## 비용 정보

### Route 53
- Hosted Zone: $0.50/월
- 쿼리: 처음 10억 건/월 $0.40 per million

### ACM (Certificate Manager)
- 퍼블릭 인증서: **무료**

### Application Load Balancer
- 시간당: ~$0.0225/hour (~$16/월)
- LCU (Load Balancer Capacity Units): 사용량에 따라

### 도메인 등록
- .com: ~$12/년
- .net: ~$11/년
- .kr: ~$35/년

---

## 요약 체크리스트

**1단계: 도메인 준비**
- [ ] Route 53에서 도메인 구매 또는
- [ ] 기존 도메인의 DNS를 Route 53으로 변경
- [ ] Hosted Zone 확인

**2단계: SSL 인증서**
- [ ] ACM에서 인증서 요청 (ap-northeast-2 리전)
- [ ] DNS 검증 레코드 추가
- [ ] 인증서 발급 확인 (ISSUED)
- [ ] 인증서 ARN 복사

**3단계: Kubernetes 설정**
- [ ] `k8s/ingress.yaml`에 도메인 설정
- [ ] `k8s/ingress.yaml`에 인증서 ARN 추가
- [ ] Ingress 적용 (`kubectl apply`)
- [ ] ALB DNS 이름 확인

**4단계: DNS 레코드**
- [ ] Route 53에 A 레코드 생성 (Alias)
- [ ] ALB를 타겟으로 설정
- [ ] DNS 전파 확인

**5단계: 테스트**
- [ ] `https://api.yourcompany.com/actuator/health` 접속
- [ ] SSL 인증서 확인
- [ ] API 엔드포인트 테스트

---

**작성일**: 2025-12-10  
**버전**: 1.0
