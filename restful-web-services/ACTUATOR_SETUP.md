# Spring Boot Actuator 추가 안내

## ⚠️ 중요: pom.xml 수정 필요

Kubernetes Health Check를 위해 `pom.xml`에 다음 의존성을 수동으로 추가해주세요.

### 추가할 위치

`pom.xml` 파일의 `<dependencies>` 섹션에서 `lombok` 의존성 바로 아래에 추가:

### 추가할 코드

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

### 전체 예시

```xml
<dependencies>
    <!-- 기존 의존성들... -->
    
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>1.18.30</version>
    </dependency>
    
    <!-- 👇 여기에 추가 -->
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    
</dependencies>
```

### 추가 후 확인

```bash
# 의존성 다운로드
./mvnw dependency:resolve

# 빌드 테스트
./mvnw clean package

# 실행 후 health check 확인
curl http://localhost:8080/actuator/health
```

## application.properties도 업데이트 필요

`src/main/resources/application.properties`에 다음 내용을 추가:

```properties
# Management endpoints
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=when-authorized
management.health.livenessState.enabled=true
management.health.readinessState.enabled=true
```

이 설정들은 Kubernetes의 Liveness와 Readiness Probe에서 사용됩니다.
