#!/bin/bash

# ALB와 Route 53 DNS 레코드 연결 스크립트
# 사용법: ./create-dns-record.sh yourcompany.com api

set -e

# 컬러 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOMAIN=$1
SUBDOMAIN=$2
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

if [ -z "$DOMAIN" ] || [ -z "$SUBDOMAIN" ]; then
    echo -e "${RED}사용법: $0 <domain> <subdomain>${NC}"
    echo "예시: $0 yourcompany.com api"
    exit 1
fi

echo -e "${GREEN}DNS 레코드 생성을 시작합니다...${NC}"
echo "도메인: $FULL_DOMAIN"
echo ""

# 1. Hosted Zone ID 확인
echo -e "${YELLOW}[1/4] Hosted Zone 확인 중...${NC}"
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
    --output text | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo -e "${RED}Hosted Zone을 찾을 수 없습니다: $DOMAIN${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Hosted Zone ID: $HOSTED_ZONE_ID${NC}"
echo ""

# 2. ALB DNS 이름 가져오기
echo -e "${YELLOW}[2/4] ALB DNS 이름 확인 중...${NC}"
ALB_DNS=$(kubectl get ingress restful-web-services \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$ALB_DNS" ]; then
    echo -e "${RED}Ingress에서 ALB를 찾을 수 없습니다.${NC}"
    echo "다음 명령으로 Ingress를 먼저 생성하세요:"
    echo "kubectl apply -f k8s/ingress.yaml"
    exit 1
fi

echo -e "${GREEN}✓ ALB DNS: $ALB_DNS${NC}"
echo ""

# 3. ALB Hosted Zone ID 확인 (리전별)
echo -e "${YELLOW}[3/4] ALB Hosted Zone ID 확인 중...${NC}"

# ALB DNS에서 리전 추출
if [[ $ALB_DNS == *"ap-northeast-2"* ]]; then
    ALB_HOSTED_ZONE_ID="Z3W03O7B5YMIYP"  # Seoul
    REGION="ap-northeast-2"
elif [[ $ALB_DNS == *"us-east-1"* ]]; then
    ALB_HOSTED_ZONE_ID="Z35SXDOTRQ7X7K"  # N. Virginia
    REGION="us-east-1"
elif [[ $ALB_DNS == *"ap-northeast-1"* ]]; then
    ALB_HOSTED_ZONE_ID="Z14GRHDCWA56QT"  # Tokyo
    REGION="ap-northeast-1"
else
    echo -e "${RED}알 수 없는 리전입니다.${NC}"
    echo "ALB DNS: $ALB_DNS"
    echo "Hosted Zone ID를 수동으로 확인하세요:"
    echo "https://docs.aws.amazon.com/general/latest/gr/elb.html"
    exit 1
fi

echo -e "${GREEN}✓ ALB Hosted Zone ID: $ALB_HOSTED_ZONE_ID (Region: $REGION)${NC}"
echo ""

# 4. Route 53 레코드 생성
echo -e "${YELLOW}[4/4] Route 53 A 레코드 생성 중...${NC}"

cat > /tmp/route53-record.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$FULL_DOMAIN",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ALB_HOSTED_ZONE_ID",
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file:///tmp/route53-record.json \
    --query 'ChangeInfo.Id' \
    --output text)

echo -e "${GREEN}✓ DNS 레코드 생성 요청 완료${NC}"
echo "Change ID: $CHANGE_ID"
echo ""

# 5. 변경 상태 확인
echo -e "${YELLOW}DNS 변경 사항 전파 대기 중...${NC}"
for i in {1..12}; do
    STATUS=$(aws route53 get-change \
        --id $CHANGE_ID \
        --query 'ChangeInfo.Status' \
        --output text)
    
    if [ "$STATUS" == "INSYNC" ]; then
        echo -e "${GREEN}✓ DNS 변경 사항 전파 완료!${NC}"
        break
    fi
    
    echo -n "."
    sleep 5
done
echo ""

# 6. DNS 확인
echo -e "${YELLOW}DNS 레코드 확인 중...${NC}"
sleep 5

echo ""
echo "Google DNS로 조회:"
nslookup $FULL_DOMAIN 8.8.8.8 || true

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}DNS 레코드 생성 완료!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "설정 정보:"
echo "  도메인: $FULL_DOMAIN"
echo "  ALB DNS: $ALB_DNS"
echo "  Hosted Zone ID: $HOSTED_ZONE_ID"
echo ""
echo -e "${YELLOW}참고:${NC}"
echo "- DNS 전파는 최대 48시간이 걸릴 수 있습니다."
echo "- 보통 5-10분 내에 완료됩니다."
echo ""
echo "DNS 전파 확인:"
echo "  nslookup $FULL_DOMAIN"
echo "  dig $FULL_DOMAIN"
echo ""
echo "온라인 도구:"
echo "  https://dnschecker.org/#A/$FULL_DOMAIN"
echo "  https://www.whatsmydns.net/#A/$FULL_DOMAIN"
echo ""
echo "HTTPS 접속 테스트:"
echo "  curl https://$FULL_DOMAIN/actuator/health"
echo "  curl https://$FULL_DOMAIN/helloworld"
echo ""
