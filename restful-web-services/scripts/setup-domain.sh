#!/bin/bash

# AWS Route 53 및 ACM 설정 자동화 스크립트
# 사용법: ./setup-domain.sh yourcompany.com api

set -e

# 컬러 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 변수 설정
DOMAIN=$1
SUBDOMAIN=$2
REGION="ap-northeast-2"
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

if [ -z "$DOMAIN" ] || [ -z "$SUBDOMAIN" ]; then
    echo -e "${RED}사용법: $0 <domain> <subdomain>${NC}"
    echo "예시: $0 yourcompany.com api"
    exit 1
fi

echo -e "${GREEN}도메인 설정을 시작합니다...${NC}"
echo "도메인: $DOMAIN"
echo "서브도메인: $SUBDOMAIN"
echo "전체 도메인: $FULL_DOMAIN"
echo ""

# 1. Hosted Zone 확인
echo -e "${YELLOW}[1/6] Hosted Zone 확인 중...${NC}"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
    --output text 2>/dev/null | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}Hosted Zone을 찾을 수 없습니다.${NC}"
    echo "다음 명령으로 Hosted Zone을 생성하세요:"
    echo "aws route53 create-hosted-zone --name $DOMAIN --caller-reference $(date +%s)"
    exit 1
fi

echo -e "${GREEN}✓ Hosted Zone ID: $HOSTED_ZONE_ID${NC}"
echo ""

# 2. ACM 인증서 요청
echo -e "${YELLOW}[2/6] ACM 인증서 요청 중...${NC}"
CERT_ARN=$(aws acm request-certificate \
    --domain-name "$DOMAIN" \
    --subject-alternative-names "*.$DOMAIN" \
    --validation-method DNS \
    --region $REGION \
    --query 'CertificateArn' \
    --output text 2>/dev/null)

if [ -z "$CERT_ARN" ]; then
    # 기존 인증서 확인
    echo "기존 인증서를 확인하는 중..."
    CERT_ARN=$(aws acm list-certificates \
        --region $REGION \
        --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" \
        --output text | head -1)
    
    if [ -n "$CERT_ARN" ]; then
        echo -e "${GREEN}✓ 기존 인증서 사용: $CERT_ARN${NC}"
    else
        echo -e "${RED}인증서 요청 실패${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ 인증서 ARN: $CERT_ARN${NC}"
fi
echo ""

# 3. DNS 검증 레코드 정보 가져오기
echo -e "${YELLOW}[3/6] DNS 검증 레코드 확인 중...${NC}"
sleep 5  # ACM이 검증 레코드를 생성할 시간을 주기

VALIDATION_RECORD=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --region $REGION \
    --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
    --output json)

VALIDATION_NAME=$(echo $VALIDATION_RECORD | jq -r '.Name')
VALIDATION_VALUE=$(echo $VALIDATION_RECORD | jq -r '.Value')

if [ -z "$VALIDATION_NAME" ] || [ "$VALIDATION_NAME" == "null" ]; then
    echo -e "${YELLOW}⚠ DNS 검증 레코드가 아직 준비되지 않았습니다.${NC}"
    echo "AWS Console에서 수동으로 확인하세요:"
    echo "https://console.aws.amazon.com/acm/home?region=$REGION#/certificates/$CERT_ARN"
else
    echo -e "${GREEN}✓ 검증 레코드:${NC}"
    echo "  Name: $VALIDATION_NAME"
    echo "  Value: $VALIDATION_VALUE"
    
    # 4. DNS 검증 레코드 생성
    echo -e "${YELLOW}[4/6] DNS 검증 레코드 생성 중...${NC}"
    
    cat > /tmp/acm-validation.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$VALIDATION_NAME",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$VALIDATION_VALUE"
          }
        ]
      }
    }
  ]
}
EOF
    
    aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch file:///tmp/acm-validation.json > /dev/null
    
    echo -e "${GREEN}✓ DNS 검증 레코드 생성됨${NC}"
fi
echo ""

# 5. 인증서 발급 대기
echo -e "${YELLOW}[5/6] 인증서 발급 대기 중... (최대 5분)${NC}"
for i in {1..30}; do
    STATUS=$(aws acm describe-certificate \
        --certificate-arn "$CERT_ARN" \
        --region $REGION \
        --query 'Certificate.Status' \
        --output text)
    
    if [ "$STATUS" == "ISSUED" ]; then
        echo -e "${GREEN}✓ 인증서 발급 완료!${NC}"
        break
    fi
    
    echo -n "."
    sleep 10
done
echo ""

if [ "$STATUS" != "ISSUED" ]; then
    echo -e "${YELLOW}⚠ 인증서가 아직 발급되지 않았습니다. (현재 상태: $STATUS)${NC}"
    echo "AWS Console에서 확인하세요:"
    echo "https://console.aws.amazon.com/acm/home?region=$REGION"
fi
echo ""

# 6. Ingress 설정 파일 업데이트
echo -e "${YELLOW}[6/6] Ingress 설정 파일 업데이트 중...${NC}"

INGRESS_FILE="k8s/ingress.yaml"

if [ -f "$INGRESS_FILE" ]; then
    # 백업 생성
    cp $INGRESS_FILE ${INGRESS_FILE}.backup
    
    # 인증서 ARN 업데이트
    sed -i "s|# alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: $CERT_ARN|" $INGRESS_FILE
    sed -i "s|alb.ingress.kubernetes.io/certificate-arn:.*|alb.ingress.kubernetes.io/certificate-arn: $CERT_ARN|" $INGRESS_FILE
    
    # 도메인 업데이트
    sed -i "s|host:.*yourdomain.*|host: $FULL_DOMAIN|" $INGRESS_FILE
    
    echo -e "${GREEN}✓ Ingress 설정 파일 업데이트 완료${NC}"
    echo "  - 인증서 ARN: $CERT_ARN"
    echo "  - 도메인: $FULL_DOMAIN"
else
    echo -e "${YELLOW}⚠ Ingress 파일을 찾을 수 없습니다: $INGRESS_FILE${NC}"
fi
echo ""

# 요약 출력
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}설정 완료!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "다음 정보를 기록하세요:"
echo ""
echo "도메인: $FULL_DOMAIN"
echo "Hosted Zone ID: $HOSTED_ZONE_ID"
echo "인증서 ARN: $CERT_ARN"
echo "인증서 상태: $STATUS"
echo ""
echo -e "${YELLOW}다음 단계:${NC}"
echo ""
echo "1. Ingress 적용:"
echo "   kubectl apply -f k8s/ingress.yaml"
echo ""
echo "2. ALB DNS 확인:"
echo "   kubectl get ingress restful-web-services"
echo ""
echo "3. ALB DNS를 Route 53에 추가 (자동으로 수행하려면 다음 스크립트 실행):"
echo "   ./scripts/create-dns-record.sh $DOMAIN $SUBDOMAIN"
echo ""
echo "4. DNS 전파 확인 (5-10분 소요):"
echo "   nslookup $FULL_DOMAIN"
echo ""
echo "5. HTTPS 접속 테스트:"
echo "   curl https://$FULL_DOMAIN/actuator/health"
echo ""
