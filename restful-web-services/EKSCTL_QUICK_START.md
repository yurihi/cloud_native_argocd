# eksctl 설치 완료! 🎉

## ✅ 설치 성공

**eksctl 버전:** `0.220.0`  
**설치 위치:** `C:\Users\김유리\bin\eksctl.exe`  
**상태:** 정상 작동

---

## 🚀 이제 할 수 있는 것

### 1. EKS 클러스터 생성 (💰 비용 발생!)

```powershell
# PowerShell 명령어 (백틱 사용)
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
**💰 예상 비용:** 약 $159/월

### 2. 클러스터 확인

```powershell
# 기존 클러스터 목록
eksctl get cluster --region ap-northeast-2

# 특정 클러스터 정보
eksctl get cluster --name api-cluster --region ap-northeast-2

# Node group 확인
eksctl get nodegroup --cluster=api-cluster --region ap-northeast-2
```

### 3. 클러스터 삭제 (비용 절감)

```powershell
# 클러스터 완전 삭제
eksctl delete cluster --name api-cluster --region ap-northeast-2

# Node group만 삭제
eksctl delete nodegroup --cluster=api-cluster --name=standard-workers --region ap-northeast-2
```

---

## ⚠️ 중요: 비용 관리

### 클러스터 생성 전 확인사항

- [ ] AWS 계정에 충분한 권한 확인
- [ ] AWS CLI 설정 완료 (`aws configure`)
- [ ] 예상 비용 확인 ($159/월)
- [ ] 사용 후 삭제 계획 수립

### 비용 발생 시점

| 작업 | 비용 발생 | 시작 시점 |
|------|----------|----------|
| `eksctl create cluster` | ✅ 발생 | 명령어 실행 즉시 |
| `eksctl get cluster` | ❌ 없음 | 조회만 |
| `eksctl delete cluster` | ⏹️ 중지 | 삭제 완료 후 |

---

## 💡 학습용 대안 (무료)

비용 부담 없이 Kubernetes를 학습하려면:

### Docker Desktop Kubernetes (권장)

1. **Docker Desktop 설치**
   - https://www.docker.com/products/docker-desktop

2. **Kubernetes 활성화**
   - Docker Desktop → Settings → Kubernetes
   - "Enable Kubernetes" 체크
   - Apply & Restart

3. **로컬에서 배포**
   ```powershell
   kubectl apply -f k8s\deployment.yaml
   kubectl apply -f k8s\service.yaml
   kubectl get pods
   kubectl port-forward svc/restful-web-services 8080:80
   ```

4. **테스트**
   ```powershell
   curl http://localhost:8080/helloworld
   ```

**장점:**
- ✅ 완전 무료
- ✅ 즉시 시작
- ✅ AWS 계정 불필요
- ✅ 오프라인 작업 가능

**단점:**
- ❌ 실제 클라우드 환경 아님
- ❌ 외부 접속 불가
- ❌ 일부 AWS 기능 사용 불가

---

## 📝 다음 단계

### 학습 단계라면:

1. ✅ **Docker Desktop Kubernetes 사용** (무료)
2. ✅ 모든 k8s 매니페스트 로컬 테스트
3. ✅ Kubernetes 개념 완전히 익히기
4. ✅ 준비되면 AWS EKS 시도

### 실제 배포가 필요하다면:

1. ⚠️ AWS 비용 예산 확보
2. ⚠️ `aws configure` 설정 확인
3. ⚠️ EKS 클러스터 생성
4. ⚠️ **사용 후 반드시 삭제!**

---

## 🔧 AWS CLI 설정 확인

EKS 클러스터를 생성하기 전에:

```powershell
# AWS CLI 설치 확인
aws --version

# AWS 자격 증명 확인
aws sts get-caller-identity

# 출력 예시:
# {
#     "UserId": "AIDAXXXXXXXXXXXXXX",
#     "Account": "521730717515",
#     "Arn": "arn:aws:iam::521730717515:user/username"
# }
```

설정이 안 되어 있다면:

```powershell
aws configure
# AWS Access Key ID [None]: YOUR_ACCESS_KEY
# AWS Secret Access Key [None]: YOUR_SECRET_KEY
# Default region name [None]: ap-northeast-2
# Default output format [None]: json
```

---

## 📚 유용한 eksctl 명령어

### 클러스터 관리

```powershell
# 클러스터 목록
eksctl get cluster --region ap-northeast-2

# 클러스터 생성 (최소 구성)
eksctl create cluster --name test-cluster --region ap-northeast-2

# 클러스터 정보
eksctl get cluster --name api-cluster --region ap-northeast-2 -o yaml

# kubectl 설정 업데이트
eksctl utils write-kubeconfig --cluster=api-cluster --region ap-northeast-2
```

### Node Group 관리

```powershell
# Node group 목록
eksctl get nodegroup --cluster=api-cluster --region ap-northeast-2

# Node group 스케일링
eksctl scale nodegroup --cluster=api-cluster --name=standard-workers --nodes=3

# Node group 추가
eksctl create nodegroup `
    --cluster=api-cluster `
    --region ap-northeast-2 `
    --name=new-workers `
    --node-type=t3.small `
    --nodes=2
```

### IAM 관리

```powershell
# OIDC 공급자 연결
eksctl utils associate-iam-oidc-provider `
    --cluster=api-cluster `
    --region ap-northeast-2 `
    --approve

# IAM 서비스 계정 생성
eksctl create iamserviceaccount `
    --cluster=api-cluster `
    --namespace=kube-system `
    --name=aws-load-balancer-controller `
    --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/PolicyName `
    --approve
```

---

## 🆘 문제 해결

### Q: "eksctl version" 명령어가 안 돼요
**A:** 새 PowerShell 창을 열어보세요. PATH 환경 변수가 업데이트되려면 새 세션이 필요합니다.

### Q: AWS 자격 증명 오류
**A:** AWS CLI 설정 확인:
```powershell
aws configure list
aws sts get-caller-identity
```

### Q: 클러스터 생성이 실패해요
**A:** 일반적인 원인:
- AWS 권한 부족
- 리전의 리소스 한도 초과
- VPC CIDR 충돌

로그 확인:
```powershell
eksctl create cluster ... --verbose 4
```

### Q: 클러스터 삭제가 안 돼요
**A:** 강제 삭제:
```powershell
eksctl delete cluster --name api-cluster --region ap-northeast-2 --wait
```

수동으로 AWS Console에서 확인 후 삭제

---

## 📖 참고 자료

- **eksctl 공식 문서:** https://eksctl.io/
- **AWS EKS 문서:** https://docs.aws.amazon.com/eks/
- **Kubernetes 문서:** https://kubernetes.io/docs/

---

**설치일:** 2025-12-10  
**eksctl 버전:** 0.220.0  
**설치 방법:** 직접 다운로드 (관리자 권한 불필요)
