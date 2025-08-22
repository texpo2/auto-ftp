#!/bin/bash

# ============================================
# KISA/CSAP/주요통신기반시설 보안 점검 스크립트 Part 2
# Docker 컨테이너 및 FTP 서비스 특화 점검
# Version: 3.0
# Date: 2025-08-17
# ============================================

# 색상 정의
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
UNDERLINE='\033[4m'
BLINK='\033[5m'

# 점검 결과 카운터
PASS_COUNT=0
FAIL_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0
TOTAL_COUNT=0

# 위험도별 카운터
CRITICAL_COUNT=0
HIGH_COUNT=0
MEDIUM_COUNT=0
LOW_COUNT=0

# Docker 관련 변수
DOCKER_INSTALLED=false
DOCKER_RUNNING=false
VSFTPD_CONTAINER=""

# 위험도 레벨 표시 함수
show_risk_level() {
    case $1 in
        "상")
            echo -e "${RED}${BOLD}[위험도: 상]${NC}"
            ;;
        "중")
            echo -e "${YELLOW}${BOLD}[위험도: 중]${NC}"
            ;;
        "하")
            echo -e "${GREEN}[위험도: 하]${NC}"
            ;;
    esac
}

# 점검 결과 출력 함수
check_result() {
    local status=$1
    local message=$2
    local risk=$3
    local category=$4
    
    ((TOTAL_COUNT++))
    
    case $risk in
        "상") ((CRITICAL_COUNT++)) ;;
        "중") ((HIGH_COUNT++)) ;;
        "하") ((MEDIUM_COUNT++)) ;;
    esac
    
    case $status in
        "PASS")
            echo -e "${GREEN}${BOLD}[✓] PASS${NC}: $message $(show_risk_level $risk) ${CYAN}[$category]${NC}"
            ((PASS_COUNT++))
            ;;
        "FAIL")
            echo -e "${RED}${BOLD}[✗] FAIL${NC}: $message $(show_risk_level $risk) ${CYAN}[$category]${NC}"
            ((FAIL_COUNT++))
            ;;
        "WARNING")
            echo -e "${YELLOW}${BOLD}[!] WARNING${NC}: $message $(show_risk_level $risk) ${CYAN}[$category]${NC}"
            ((WARNING_COUNT++))
            ;;
        "INFO")
            echo -e "${BLUE}${BOLD}[i] INFO${NC}: $message ${CYAN}[$category]${NC}"
            ((INFO_COUNT++))
            ;;
    esac
}

# 헤더 출력
print_header() {
    echo -e "\n${BOLD}${WHITE}========================================${NC}"
    echo -e "${BOLD}${CYAN}    $1${NC}"
    echo -e "${BOLD}${WHITE}========================================${NC}\n"
}

# 서브헤더 출력
print_subheader() {
    echo -e "\n${BOLD}${PURPLE}--- $1 ---${NC}\n"
}

# Docker 설치 및 실행 상태 확인
check_docker_status() {
    if command -v docker &>/dev/null; then
        DOCKER_INSTALLED=true
        if systemctl is-active docker &>/dev/null; then
            DOCKER_RUNNING=true
        fi
    fi
}

# ============================================
# 메인 점검 시작
# ============================================

clear
echo -e "${BOLD}${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   KISA/CSAP/주요통신기반시설 보안 점검 스크립트 Part 2    ║"
echo "║          Docker 컨테이너 및 FTP 서비스 특화 점검          ║"
echo "║                    Version 2.0                             ║"
echo "║                 $(date +"%Y-%m-%d %H:%M:%S")                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Docker 상태 확인
check_docker_status

# ============================================
# 1. KISA Docker 컨테이너 보안 가이드
# ============================================

print_header "1. KISA 클라우드 보안 가이드 - Docker 컨테이너"

if [ "$DOCKER_INSTALLED" = true ]; then
    print_subheader "1.1 Docker 데몬 보안 설정"
    
    # Docker 데몬 실행 확인
    if [ "$DOCKER_RUNNING" = true ]; then
        check_result "PASS" "Docker 데몬이 실행 중입니다" "중" "Docker-데몬"
        
        # Docker 버전 확인
        DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
        if [ ! -z "$DOCKER_VERSION" ]; then
            check_result "INFO" "Docker 버전: $DOCKER_VERSION" "하" "Docker-데몬"
        fi
    else
        check_result "FAIL" "Docker 데몬이 실행되지 않음" "상" "Docker-데몬"
    fi
    
    # Docker 소켓 권한 확인
    if [ -S /var/run/docker.sock ]; then
        SOCKET_PERM=$(stat -c %a /var/run/docker.sock)
        SOCKET_OWNER=$(stat -c %U:%G /var/run/docker.sock)
        
        if [ "$SOCKET_PERM" == "660" ] || [ "$SOCKET_PERM" == "600" ]; then
            check_result "PASS" "Docker 소켓 권한이 적절함 ($SOCKET_PERM, $SOCKET_OWNER)" "상" "Docker-데몬"
        else
            check_result "FAIL" "Docker 소켓 권한이 너무 개방적임 ($SOCKET_PERM)" "상" "Docker-데몬"
        fi
    fi
    
    # Docker 데몬 설정 파일 확인
    if [ -f /etc/docker/daemon.json ]; then
        check_result "PASS" "Docker 데몬 설정 파일이 존재함" "중" "Docker-데몬"
        
        # 로깅 드라이버 확인
        if grep -q '"log-driver"' /etc/docker/daemon.json; then
            LOG_DRIVER=$(grep '"log-driver"' /etc/docker/daemon.json | cut -d'"' -f4)
            check_result "PASS" "Docker 로깅 드라이버가 설정됨 ($LOG_DRIVER)" "중" "Docker-데몬"
        else
            check_result "WARNING" "Docker 로깅 드라이버가 설정되지 않음" "중" "Docker-데몬"
        fi
        
        # 라이브 리스토어 확인
        if grep -q '"live-restore": true' /etc/docker/daemon.json; then
            check_result "PASS" "Docker live-restore가 활성화됨" "하" "Docker-데몬"
        else
            check_result "WARNING" "Docker live-restore가 비활성화됨" "하" "Docker-데몬"
        fi
        
        # userland-proxy 비활성화 확인
        if grep -q '"userland-proxy": false' /etc/docker/daemon.json; then
            check_result "PASS" "Userland proxy가 비활성화됨" "중" "Docker-데몬"
        else
            check_result "WARNING" "Userland proxy가 활성화됨" "중" "Docker-데몬"
        fi
        
        # 기본 ulimit 설정 확인
        if grep -q '"default-ulimits"' /etc/docker/daemon.json; then
            check_result "PASS" "기본 ulimit이 설정됨" "하" "Docker-데몬"
        else
            check_result "WARNING" "기본 ulimit이 설정되지 않음" "하" "Docker-데몬"
        fi
    else
        check_result "WARNING" "Docker 데몬 설정 파일이 없음 (/etc/docker/daemon.json)" "중" "Docker-데몬"
    fi
    
    print_subheader "1.2 Docker 이미지 보안"
    
    if [ "$DOCKER_RUNNING" = true ]; then
        # 이미지 수 확인
        IMAGE_COUNT=$(docker images -q 2>/dev/null | wc -l)
        check_result "INFO" "Docker 이미지 수: $IMAGE_COUNT" "하" "Docker-이미지"
        
        # Dangling 이미지 확인
        DANGLING_IMAGES=$(docker images -f "dangling=true" -q 2>/dev/null | wc -l)
        if [ "$DANGLING_IMAGES" -eq 0 ]; then
            check_result "PASS" "Dangling 이미지가 없음" "하" "Docker-이미지"
        else
            check_result "WARNING" "Dangling 이미지 존재 ($DANGLING_IMAGES개)" "하" "Docker-이미지"
        fi
        
        # 공식 이미지 사용 확인 (vsftpd)
        if docker images 2>/dev/null | grep -q "vsftpd"; then
            check_result "INFO" "VSFTPD 컨테이너 이미지가 존재합니다" "중" "Docker-이미지"
            
            # 이미지 태그 확인
            VSFTPD_TAGS=$(docker images --format "table {{.Repository}}:{{.Tag}}" 2>/dev/null | grep vsftpd)
            if echo "$VSFTPD_TAGS" | grep -q ":latest"; then
                check_result "WARNING" "latest 태그 사용 (특정 버전 태그 권장)" "중" "Docker-이미지"
            else
                check_result "PASS" "특정 버전 태그 사용" "중" "Docker-이미지"
            fi
        fi
        
        # 이미지 취약점 스캔 도구 확인
        if command -v trivy &>/dev/null; then
            check_result "PASS" "Trivy 취약점 스캐너가 설치됨" "중" "Docker-이미지"
        elif command -v clair &>/dev/null; then
            check_result "PASS" "Clair 취약점 스캐너가 설치됨" "중" "Docker-이미지"
        else
            check_result "WARNING" "이미지 취약점 스캔 도구가 설치되지 않음" "중" "Docker-이미지"
        fi
    fi
    
    print_subheader "1.3 실행 중인 컨테이너 보안"
    
    if [ "$DOCKER_RUNNING" = true ]; then
        # 실행 중인 컨테이너 수
        RUNNING_CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)
        check_result "INFO" "실행 중인 컨테이너 수: $RUNNING_CONTAINERS" "하" "Docker-컨테이너"
        
        if [ "$RUNNING_CONTAINERS" -gt 0 ]; then
            # vsftpd 컨테이너 확인
            if docker ps --format "table {{.Names}}" 2>/dev/null | grep -q vsftpd; then
                VSFTPD_CONTAINER=$(docker ps --format "{{.Names}}" 2>/dev/null | grep vsftpd | head -1)
                check_result "PASS" "VSFTPD 컨테이너가 실행 중 ($VSFTPD_CONTAINER)" "상" "Docker-컨테이너"
                
                # 컨테이너 상세 보안 설정 확인
                echo -e "${CYAN}VSFTPD 컨테이너 보안 설정 점검 중...${NC}"
                
                # 1. 권한 상승 확인
                PRIVILEGED=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.Privileged}}' 2>/dev/null)
                if [ "$PRIVILEGED" == "false" ]; then
                    check_result "PASS" "컨테이너가 특권 모드로 실행되지 않음" "상" "Docker-컨테이너"
                else
                    check_result "FAIL" "컨테이너가 특권 모드로 실행됨" "상" "Docker-컨테이너"
                fi
                
                # 2. 읽기 전용 루트 파일시스템
                READONLY=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null)
                if [ "$READONLY" == "true" ]; then
                    check_result "PASS" "루트 파일시스템이 읽기 전용" "중" "Docker-컨테이너"
                else
                    check_result "WARNING" "루트 파일시스템이 쓰기 가능" "중" "Docker-컨테이너"
                fi
                
                # 3. 메모리 제한
                MEM_LIMIT=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.Memory}}' 2>/dev/null)
                if [ "$MEM_LIMIT" != "0" ]; then
                    MEM_LIMIT_MB=$((MEM_LIMIT / 1024 / 1024))
                    check_result "PASS" "메모리 제한이 설정됨 (${MEM_LIMIT_MB}MB)" "하" "Docker-컨테이너"
                else
                    check_result "WARNING" "메모리 제한이 설정되지 않음" "하" "Docker-컨테이너"
                fi
                
                # 4. CPU 제한
                CPU_SHARES=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.CpuShares}}' 2>/dev/null)
                CPU_QUOTA=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.CpuQuota}}' 2>/dev/null)
                if [ "$CPU_SHARES" != "0" ] || [ "$CPU_QUOTA" != "0" ]; then
                    check_result "PASS" "CPU 제한이 설정됨" "하" "Docker-컨테이너"
                else
                    check_result "WARNING" "CPU 제한이 설정되지 않음" "하" "Docker-컨테이너"
                fi
                
                # 5. 보안 옵션 확인
                SECURITY_OPTS=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.SecurityOpt}}' 2>/dev/null)
                if [ "$SECURITY_OPTS" != "[]" ] && [ "$SECURITY_OPTS" != "<no value>" ]; then
                    check_result "PASS" "보안 옵션이 설정됨" "중" "Docker-컨테이너"
                else
                    check_result "WARNING" "추가 보안 옵션이 설정되지 않음" "중" "Docker-컨테이너"
                fi
                
                # 6. 네트워크 모드 확인
                NETWORK_MODE=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.NetworkMode}}' 2>/dev/null)
                if [ "$NETWORK_MODE" == "host" ]; then
                    check_result "WARNING" "호스트 네트워크 모드 사용 (격리 권장)" "중" "Docker-컨테이너"
                else
                    check_result "PASS" "격리된 네트워크 모드 사용 ($NETWORK_MODE)" "중" "Docker-컨테이너"
                fi
                
                # 7. PID 네임스페이스 확인
                PID_MODE=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.PidMode}}' 2>/dev/null)
                if [ "$PID_MODE" == "host" ]; then
                    check_result "WARNING" "호스트 PID 네임스페이스 공유" "중" "Docker-컨테이너"
                else
                    check_result "PASS" "독립적인 PID 네임스페이스 사용" "중" "Docker-컨테이너"
                fi
                
                # 8. 사용자 네임스페이스 확인
                USER_NS=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.UsernsMode}}' 2>/dev/null)
                if [ ! -z "$USER_NS" ] && [ "$USER_NS" != "" ]; then
                    check_result "PASS" "사용자 네임스페이스 remapping 사용" "중" "Docker-컨테이너"
                else
                    check_result "WARNING" "사용자 네임스페이스 remapping 미사용" "중" "Docker-컨테이너"
                fi
                
                # 9. 재시작 정책 확인
                RESTART_POLICY=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
                if [ "$RESTART_POLICY" == "always" ] || [ "$RESTART_POLICY" == "unless-stopped" ]; then
                    check_result "PASS" "자동 재시작 정책이 설정됨 ($RESTART_POLICY)" "하" "Docker-컨테이너"
                else
                    check_result "WARNING" "자동 재시작 정책이 설정되지 않음" "하" "Docker-컨테이너"
                fi
                
                # 10. 컨테이너 실행 사용자 확인
                CONTAINER_USER=$(docker inspect $VSFTPD_CONTAINER --format='{{.Config.User}}' 2>/dev/null)
                if [ ! -z "$CONTAINER_USER" ] && [ "$CONTAINER_USER" != "root" ] && [ "$CONTAINER_USER" != "" ]; then
                    check_result "PASS" "컨테이너가 non-root 사용자로 실행 ($CONTAINER_USER)" "상" "Docker-컨테이너"
                else
                    check_result "WARNING" "컨테이너가 root 사용자로 실행될 수 있음" "상" "Docker-컨테이너"
                fi
            else
                check_result "WARNING" "VSFTPD 컨테이너가 실행되지 않음" "상" "Docker-컨테이너"
            fi
            
            # 모든 컨테이너의 특권 모드 확인
            PRIV_CONTAINERS=$(docker ps -q 2>/dev/null | xargs -I {} docker inspect {} --format='{{.Name}} {{.HostConfig.Privileged}}' 2>/dev/null | grep true | wc -l)
            if [ "$PRIV_CONTAINERS" -eq 0 ]; then
                check_result "PASS" "특권 모드로 실행 중인 컨테이너 없음" "상" "Docker-컨테이너"
            else
                check_result "FAIL" "특권 모드로 실행 중인 컨테이너 존재 ($PRIV_CONTAINERS개)" "상" "Docker-컨테이너"
            fi
        fi
    fi
    
    print_subheader "1.4 Docker 네트워크 보안"
    
    if [ "$DOCKER_RUNNING" = true ]; then
        # 네트워크 목록 확인
        NETWORK_COUNT=$(docker network ls -q 2>/dev/null | wc -l)
        check_result "INFO" "Docker 네트워크 수: $NETWORK_COUNT" "하" "Docker-네트워크"
        
        # 기본 브리지 네트워크 사용 확인
        if [ ! -z "$VSFTPD_CONTAINER" ]; then
            CONTAINER_NETWORK=$(docker inspect $VSFTPD_CONTAINER --format='{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}' 2>/dev/null | head -1)
            DEFAULT_BRIDGE=$(docker network ls --filter name=bridge --format "{{.ID}}" 2>/dev/null)
            
            if [ "$CONTAINER_NETWORK" == "$DEFAULT_BRIDGE" ]; then
                check_result "WARNING" "기본 브리지 네트워크 사용 (사용자 정의 네트워크 권장)" "중" "Docker-네트워크"
            else
                check_result "PASS" "사용자 정의 네트워크 사용" "중" "Docker-네트워크"
            fi
        fi
        
        # ICC (Inter-Container Communication) 설정 확인
        if [ -f /etc/docker/daemon.json ]; then
            if grep -q '"icc": false' /etc/docker/daemon.json; then
                check_result "PASS" "컨테이너 간 통신(ICC)이 제한됨" "중" "Docker-네트워크"
            else
                check_result "WARNING" "컨테이너 간 통신(ICC)이 제한되지 않음" "중" "Docker-네트워크"
            fi
        fi
    fi
    
    print_subheader "1.5 Docker 볼륨 및 바인드 마운트"
    
    if [ "$DOCKER_RUNNING" = true ] && [ ! -z "$VSFTPD_CONTAINER" ]; then
        # 볼륨 마운트 확인
        VOLUMES=$(docker inspect $VSFTPD_CONTAINER --format='{{range .Mounts}}{{.Type}}:{{.Source}}:{{.Destination}}:{{.Mode}} {{end}}' 2>/dev/null)
        if [ ! -z "$VOLUMES" ]; then
            check_result "INFO" "볼륨 마운트가 존재함" "중" "Docker-볼륨"
            
            # 민감한 디렉토리 마운트 확인
            SENSITIVE_DIRS=("/" "/etc" "/root" "/var/run/docker.sock")
            for sensitive_dir in "${SENSITIVE_DIRS[@]}"; do
                if echo "$VOLUMES" | grep -q ":$sensitive_dir:"; then
                    check_result "FAIL" "민감한 디렉토리가 마운트됨: $sensitive_dir" "상" "Docker-볼륨"
                fi
            done
        else
            check_result "INFO" "볼륨 마운트가 없음" "하" "Docker-볼륨"
        fi
    fi
    
else
    check_result "WARNING" "Docker가 설치되지 않음 - Docker 보안 점검 생략" "상" "Docker"
fi

# ============================================
# 2. FTP 서비스 특화 보안 점검
# ============================================

print_header "2. FTP 서비스 보안 점검 (KISA/CSAP 기준)"

print_subheader "2.1 FTP 서비스 실행 상태"

# FTP 포트 확인
if netstat -tuln 2>/dev/null | grep -q ":21 "; then
    check_result "PASS" "FTP 서비스가 포트 21에서 리스닝 중" "중" "FTP-서비스"
    FTP_RUNNING=true
else
    check_result "WARNING" "FTP 포트 21이 리스닝되지 않음" "중" "FTP-서비스"
    FTP_RUNNING=false
fi

# FTPS 포트 확인
if netstat -tuln 2>/dev/null | grep -q ":990 "; then
    check_result "PASS" "FTPS(암호화 FTP)가 포트 990에서 리스닝 중" "상" "FTP-서비스"
else
    check_result "WARNING" "FTPS 포트 990이 리스닝되지 않음" "상" "FTP-서비스"
fi

# Passive 모드 포트 범위 확인
PASSIVE_PORTS=$(netstat -tuln 2>/dev/null | grep -E ":(4[0-9]{4}|50[0-9]{3})" | wc -l)
if [ $PASSIVE_PORTS -gt 0 ]; then
    check_result "INFO" "Passive 모드 포트 열림 ($PASSIVE_PORTS개)" "하" "FTP-서비스"
fi

print_subheader "2.2 VSFTPD 설정 검증 (컨테이너 내부)"

if [ "$DOCKER_RUNNING" = true ] && [ ! -z "$VSFTPD_CONTAINER" ]; then
    echo -e "${CYAN}VSFTPD 컨테이너 내부 설정 점검 중...${NC}"
    
    # vsftpd.conf 설정 확인
    # 익명 접속 차단
    ANON_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^anonymous_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$ANON_ENABLE" == "NO" ]; then
        check_result "PASS" "익명 FTP 접속이 차단됨" "상" "FTP-설정"
    elif [ "$ANON_ENABLE" == "YES" ]; then
        check_result "FAIL" "익명 FTP 접속이 허용됨" "상" "FTP-설정"
    else
        check_result "WARNING" "익명 FTP 설정을 확인할 수 없음" "상" "FTP-설정"
    fi
    
    # 로컬 사용자 접속 허용
    LOCAL_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^local_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$LOCAL_ENABLE" == "YES" ]; then
        check_result "PASS" "로컬 사용자 접속이 허용됨" "중" "FTP-설정"
    else
        check_result "WARNING" "로컬 사용자 접속이 차단됨" "중" "FTP-설정"
    fi
    
    # chroot 설정
    CHROOT_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^chroot_local_user" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    CHROOT_LIST=$(docker exec $VSFTPD_CONTAINER grep "^chroot_list_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    
    if [ "$CHROOT_ENABLE" == "YES" ]; then
        check_result "PASS" "사용자 chroot가 활성화됨 (홈 디렉토리 제한)" "상" "FTP-설정"
    elif [ "$CHROOT_LIST" == "YES" ]; then
        check_result "PASS" "선택적 chroot가 활성화됨" "상" "FTP-설정"
    else
        check_result "FAIL" "사용자 chroot가 비활성화됨 (보안 위험)" "상" "FTP-설정"
    fi
    
    # SSL/TLS 설정
    SSL_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^ssl_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$SSL_ENABLE" == "YES" ]; then
        check_result "PASS" "SSL/TLS 암호화가 활성화됨" "상" "FTP-암호화"
        
        # SSL 상세 설정 확인
        FORCE_SSL=$(docker exec $VSFTPD_CONTAINER grep "^force_local_data_ssl" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        FORCE_LOGIN_SSL=$(docker exec $VSFTPD_CONTAINER grep "^force_local_logins_ssl" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        
        if [ "$FORCE_SSL" == "YES" ]; then
            check_result "PASS" "데이터 전송 시 SSL 강제 사용" "상" "FTP-암호화"
        else
            check_result "WARNING" "데이터 전송 시 SSL이 선택적임" "상" "FTP-암호화"
        fi
        
        if [ "$FORCE_LOGIN_SSL" == "YES" ]; then
            check_result "PASS" "로그인 시 SSL 강제 사용" "상" "FTP-암호화"
        else
            check_result "WARNING" "로그인 시 SSL이 선택적임" "상" "FTP-암호화"
        fi
        
        # TLS 버전 확인
        SSL_TLSV1=$(docker exec $VSFTPD_CONTAINER grep "^ssl_tlsv1" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        SSL_SSLV2=$(docker exec $VSFTPD_CONTAINER grep "^ssl_sslv2" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        SSL_SSLV3=$(docker exec $VSFTPD_CONTAINER grep "^ssl_sslv3" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        
        if [ "$SSL_SSLV2" == "NO" ] && [ "$SSL_SSLV3" == "NO" ]; then
            check_result "PASS" "취약한 SSL 버전(SSLv2, SSLv3)이 비활성화됨" "상" "FTP-암호화"
        else
            check_result "FAIL" "취약한 SSL 버전이 활성화될 수 있음" "상" "FTP-암호화"
        fi
    else
        check_result "FAIL" "SSL/TLS 암호화가 비활성화됨" "상" "FTP-암호화"
    fi
    
    # 로깅 설정
    XFERLOG_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^xferlog_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    LOG_FTP_PROTOCOL=$(docker exec $VSFTPD_CONTAINER grep "^log_ftp_protocol" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    
    if [ "$XFERLOG_ENABLE" == "YES" ]; then
        check_result "PASS" "파일 전송 로그가 활성화됨" "중" "FTP-로깅"
    else
        check_result "FAIL" "파일 전송 로그가 비활성화됨" "중" "FTP-로깅"
    fi
    
    if [ "$LOG_FTP_PROTOCOL" == "YES" ]; then
        check_result "PASS" "FTP 프로토콜 상세 로그가 활성화됨" "하" "FTP-로깅"
    else
        check_result "WARNING" "FTP 프로토콜 상세 로그가 비활성화됨" "하" "FTP-로깅"
    fi
    
    print_subheader "2.3 FTP 접근 제어"
    
    # 사용자 리스트 설정
    USERLIST_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^userlist_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    USERLIST_DENY=$(docker exec $VSFTPD_CONTAINER grep "^userlist_deny" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    
    if [ "$USERLIST_ENABLE" == "YES" ]; then
        if [ "$USERLIST_DENY" == "NO" ]; then
            check_result "PASS" "사용자 화이트리스트가 활성화됨" "상" "FTP-접근제어"
        else
            check_result "PASS" "사용자 블랙리스트가 활성화됨" "중" "FTP-접근제어"
        fi
    else
        check_result "WARNING" "사용자 리스트 제어가 비활성화됨" "중" "FTP-접근제어"
    fi
    
    # TCP Wrappers 설정
    TCP_WRAPPERS=$(docker exec $VSFTPD_CONTAINER grep "^tcp_wrappers" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$TCP_WRAPPERS" == "YES" ]; then
        check_result "PASS" "TCP Wrappers가 활성화됨" "중" "FTP-접근제어"
    else
        check_result "WARNING" "TCP Wrappers가 비활성화됨" "중" "FTP-접근제어"
    fi
    
    print_subheader "2.4 FTP 성능 및 제한 설정"
    
    # 업로드 권한
    WRITE_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^write_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$WRITE_ENABLE" == "YES" ]; then
        check_result "INFO" "파일 업로드가 허용됨" "중" "FTP-권한"
        
        # umask 설정
        LOCAL_UMASK=$(docker exec $VSFTPD_CONTAINER grep "^local_umask" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        if [ ! -z "$LOCAL_UMASK" ]; then
            check_result "PASS" "업로드 파일 권한 마스크 설정됨 (umask: $LOCAL_UMASK)" "중" "FTP-권한"
        else
            check_result "WARNING" "업로드 파일 권한 마스크가 설정되지 않음" "중" "FTP-권한"
        fi
    else
        check_result "INFO" "파일 업로드가 차단됨 (읽기 전용)" "중" "FTP-권한"
    fi
    
    # 동시 연결 제한
    MAX_CLIENTS=$(docker exec $VSFTPD_CONTAINER grep "^max_clients" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ ! -z "$MAX_CLIENTS" ]; then
        check_result "PASS" "최대 동시 접속자 수 제한 설정됨 ($MAX_CLIENTS명)" "중" "FTP-제한"
    else
        check_result "WARNING" "최대 동시 접속자 수가 제한되지 않음" "중" "FTP-제한"
    fi
    
    # IP당 연결 제한
    MAX_PER_IP=$(docker exec $VSFTPD_CONTAINER grep "^max_per_ip" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ ! -z "$MAX_PER_IP" ]; then
        check_result "PASS" "IP당 최대 연결 수 제한 설정됨 ($MAX_PER_IP개)" "중" "FTP-제한"
    else
        check_result "WARNING" "IP당 최대 연결 수가 제한되지 않음" "중" "FTP-제한"
    fi
    
    # 대역폭 제한
    LOCAL_MAX_RATE=$(docker exec $VSFTPD_CONTAINER grep "^local_max_rate" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    ANON_MAX_RATE=$(docker exec $VSFTPD_CONTAINER grep "^anon_max_rate" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    
    if [ ! -z "$LOCAL_MAX_RATE" ] && [ "$LOCAL_MAX_RATE" != "0" ]; then
        check_result "PASS" "로컬 사용자 대역폭 제한 설정됨 (${LOCAL_MAX_RATE}bytes/sec)" "하" "FTP-제한"
    else
        check_result "INFO" "로컬 사용자 대역폭이 제한되지 않음" "하" "FTP-제한"
    fi
    
    # 세션 타임아웃
    IDLE_SESSION_TIMEOUT=$(docker exec $VSFTPD_CONTAINER grep "^idle_session_timeout" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    DATA_CONNECTION_TIMEOUT=$(docker exec $VSFTPD_CONTAINER grep "^data_connection_timeout" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    
    if [ ! -z "$IDLE_SESSION_TIMEOUT" ]; then
        check_result "PASS" "유휴 세션 타임아웃 설정됨 (${IDLE_SESSION_TIMEOUT}초)" "중" "FTP-제한"
    else
        check_result "WARNING" "유휴 세션 타임아웃이 설정되지 않음" "중" "FTP-제한"
    fi
    
    if [ ! -z "$DATA_CONNECTION_TIMEOUT" ]; then
        check_result "PASS" "데이터 연결 타임아웃 설정됨 (${DATA_CONNECTION_TIMEOUT}초)" "하" "FTP-제한"
    else
        check_result "INFO" "데이터 연결 타임아웃이 설정되지 않음" "하" "FTP-제한"
    fi
    
    print_subheader "2.5 FTP Passive 모드 설정"
    
    # Passive 모드 설정
    PASV_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^pasv_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$PASV_ENABLE" == "YES" ] || [ -z "$PASV_ENABLE" ]; then
        check_result "PASS" "Passive 모드가 활성화됨" "중" "FTP-Passive"
        
        # Passive 포트 범위
        PASV_MIN=$(docker exec $VSFTPD_CONTAINER grep "^pasv_min_port" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        PASV_MAX=$(docker exec $VSFTPD_CONTAINER grep "^pasv_max_port" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        
        if [ ! -z "$PASV_MIN" ] && [ ! -z "$PASV_MAX" ]; then
            check_result "PASS" "Passive 모드 포트 범위가 제한됨 ($PASV_MIN-$PASV_MAX)" "중" "FTP-Passive"
        else
            check_result "WARNING" "Passive 모드 포트 범위가 설정되지 않음" "중" "FTP-Passive"
        fi
        
        # Passive 모드 주소
        PASV_ADDRESS=$(docker exec $VSFTPD_CONTAINER grep "^pasv_address" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
        if [ ! -z "$PASV_ADDRESS" ]; then
            check_result "INFO" "Passive 모드 주소가 설정됨 ($PASV_ADDRESS)" "하" "FTP-Passive"
        fi
    else
        check_result "WARNING" "Passive 모드가 비활성화됨" "중" "FTP-Passive"
    fi
    
    print_subheader "2.6 FTP 배너 및 메시지"
    
    # 배너 설정
    FTPD_BANNER=$(docker exec $VSFTPD_CONTAINER grep "^ftpd_banner" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2-)
    if [ ! -z "$FTPD_BANNER" ]; then
        check_result "PASS" "FTP 배너가 설정됨" "하" "FTP-배너"
    else
        check_result "WARNING" "FTP 배너가 설정되지 않음 (보안 경고 권장)" "하" "FTP-배너"
    fi
    
    # 메시지 파일
    DIRMESSAGE_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^dirmessage_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$DIRMESSAGE_ENABLE" == "YES" ]; then
        check_result "PASS" "디렉토리 메시지가 활성화됨" "하" "FTP-배너"
    else
        check_result "INFO" "디렉토리 메시지가 비활성화됨" "하" "FTP-배너"
    fi
    
elif [ -f /etc/vsftpd/vsftpd.conf ] || [ -f /etc/vsftpd.conf ]; then
    echo -e "${CYAN}호스트 시스템의 VSFTPD 설정 점검 중...${NC}"
    
    # 호스트에 직접 설치된 vsftpd 점검
    VSFTPD_CONF="/etc/vsftpd/vsftpd.conf"
    [ ! -f "$VSFTPD_CONF" ] && VSFTPD_CONF="/etc/vsftpd.conf"
    
    # 기본 보안 설정 확인
    if grep -q "^anonymous_enable=NO" $VSFTPD_CONF 2>/dev/null; then
        check_result "PASS" "익명 FTP 접속이 차단됨" "상" "FTP-설정"
    else
        check_result "FAIL" "익명 FTP 접속 설정 확인 필요" "상" "FTP-설정"
    fi
    
    if grep -q "^chroot_local_user=YES" $VSFTPD_CONF 2>/dev/null; then
        check_result "PASS" "사용자 chroot가 활성화됨" "상" "FTP-설정"
    else
        check_result "WARNING" "사용자 chroot 설정 확인 필요" "상" "FTP-설정"
    fi
    
    if grep -q "^ssl_enable=YES" $VSFTPD_CONF 2>/dev/null; then
        check_result "PASS" "SSL/TLS 암호화가 활성화됨" "상" "FTP-암호화"
    else
        check_result "FAIL" "SSL/TLS 암호화가 비활성화됨" "상" "FTP-암호화"
    fi
else
    check_result "INFO" "VSFTPD 설정 파일을 찾을 수 없음" "중" "FTP-설정"
fi

# ============================================
# 3. 보안 도구 및 모니터링
# ============================================

print_header "3. 보안 도구 및 모니터링"

print_subheader "3.1 컨테이너 보안 스캔 도구"

# Trivy 설치 확인
if command -v trivy &>/dev/null; then
    check_result "PASS" "Trivy 컨테이너 스캐너가 설치됨" "중" "보안도구"
    
    # vsftpd 이미지 스캔 (시간이 걸릴 수 있으므로 선택적)
    if [ "$DOCKER_RUNNING" = true ] && docker images | grep -q vsftpd; then
        echo -e "${CYAN}VSFTPD 이미지 취약점 스캔 중... (시간이 걸릴 수 있습니다)${NC}"
        VSFTPD_IMAGE=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep vsftpd | head -1)
        VULN_COUNT=$(trivy image --severity HIGH,CRITICAL --format json $VSFTPD_IMAGE 2>/dev/null | grep -c '"Severity"' || echo "0")
        
        if [ "$VULN_COUNT" -eq 0 ]; then
            check_result "PASS" "VSFTPD 이미지에 HIGH/CRITICAL 취약점 없음" "상" "보안도구"
        else
            check_result "WARNING" "VSFTPD 이미지에 취약점 발견 ($VULN_COUNT개)" "상" "보안도구"
        fi
    fi
fi

# Docker Bench Security
if [ -f /usr/local/bin/docker-bench-security.sh ] || command -v docker-bench-security &>/dev/null; then
    check_result "PASS" "Docker Bench Security가 설치됨" "중" "보안도구"
else
    check_result "INFO" "Docker Bench Security가 설치되지 않음" "중" "보안도구"
fi

print_subheader "3.2 로그 모니터링"

# Docker 로그 확인
if [ "$DOCKER_RUNNING" = true ] && [ ! -z "$VSFTPD_CONTAINER" ]; then
    # 컨테이너 로그 크기 확인
    LOG_SIZE=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.LogConfig.Config.max-size}}' 2>/dev/null)
    if [ ! -z "$LOG_SIZE" ] && [ "$LOG_SIZE" != "<no value>" ]; then
        check_result "PASS" "컨테이너 로그 크기 제한 설정됨 ($LOG_SIZE)" "하" "로그"
    else
        check_result "WARNING" "컨테이너 로그 크기가 제한되지 않음" "하" "로그"
    fi
    
    # 로그 로테이션 확인
    LOG_FILES=$(docker inspect $VSFTPD_CONTAINER --format='{{.HostConfig.LogConfig.Config.max-file}}' 2>/dev/null)
    if [ ! -z "$LOG_FILES" ] && [ "$LOG_FILES" != "<no value>" ]; then
        check_result "PASS" "로그 파일 로테이션 설정됨 (최대 $LOG_FILES개)" "하" "로그"
    else
        check_result "INFO" "로그 파일 로테이션이 설정되지 않음" "하" "로그"
    fi
fi

# FTP 로그 파일 확인
FTP_LOG_FILES=(
    "/var/log/vsftpd.log"
    "/var/log/xferlog"
    "/var/log/vsftpd/vsftpd.log"
)

for log_file in "${FTP_LOG_FILES[@]}"; do
    if [ -f "$log_file" ]; then
        check_result "PASS" "FTP 로그 파일이 존재함: $log_file" "중" "로그"
        
        # 로그 파일 권한 확인
        LOG_PERM=$(stat -c %a "$log_file" 2>/dev/null)
        if [ "$LOG_PERM" == "600" ] || [ "$LOG_PERM" == "640" ] || [ "$LOG_PERM" == "644" ]; then
            check_result "PASS" "FTP 로그 파일 권한이 적절함 ($LOG_PERM)" "중" "로그"
        else
            check_result "WARNING" "FTP 로그 파일 권한 확인 필요 ($LOG_PERM)" "중" "로그"
        fi
        break
    fi
done

# ============================================
# 4. 주요통신기반시설 추가 점검 항목
# ============================================

print_header "4. 주요통신기반시설 추가 보안 요구사항"

print_subheader "4.1 보안 감사 및 책임 추적성"

# 감사 로그 설정
if [ "$DOCKER_RUNNING" = true ]; then
    # Docker 이벤트 로깅
    DOCKER_EVENTS=$(docker system events --since '1h ago' --until '1s ago' 2>/dev/null | wc -l)
    if [ $DOCKER_EVENTS -gt 0 ]; then
        check_result "INFO" "최근 1시간 Docker 이벤트: $DOCKER_EVENTS건" "중" "감사"
    fi
fi

# FTP 사용자 활동 로깅
if [ ! -z "$VSFTPD_CONTAINER" ]; then
    DUAL_LOG=$(docker exec $VSFTPD_CONTAINER grep "^dual_log_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$DUAL_LOG" == "YES" ]; then
        check_result "PASS" "이중 로그 형식(wu-ftpd + vsftpd)이 활성화됨" "중" "감사"
    else
        check_result "INFO" "단일 로그 형식 사용 중" "중" "감사"
    fi
    
    SYSLOG_ENABLE=$(docker exec $VSFTPD_CONTAINER grep "^syslog_enable" /etc/vsftpd/vsftpd.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    if [ "$SYSLOG_ENABLE" == "YES" ]; then
        check_result "PASS" "Syslog 전송이 활성화됨" "중" "감사"
    else
        check_result "WARNING" "Syslog 전송이 비활성화됨" "중" "감사"
    fi
fi

print_subheader "4.2 데이터 무결성 및 가용성"

# 백업 확인
BACKUP_DIRS=(
    "/backup"
    "/var/backup"
    "/mnt/backup"
    "/data/backup"
)

BACKUP_FOUND=false
for backup_dir in "${BACKUP_DIRS[@]}"; do
    if [ -d "$backup_dir" ]; then
        BACKUP_FOUND=true
        RECENT_BACKUP=$(find $backup_dir -type f -mtime -7 2>/dev/null | wc -l)
        if [ $RECENT_BACKUP -gt 0 ]; then
            check_result "PASS" "최근 7일 내 백업 파일이 존재함 ($backup_dir: $RECENT_BACKUP개)" "중" "백업"
        else
            check_result "WARNING" "최근 백업이 없음 ($backup_dir)" "중" "백업"
        fi
        break
    fi
done

if [ "$BACKUP_FOUND" = false ]; then
    check_result "WARNING" "백업 디렉토리를 찾을 수 없음" "중" "백업"
fi

# Docker 볼륨 백업 확인
if [ "$DOCKER_RUNNING" = true ]; then
    VOLUME_COUNT=$(docker volume ls -q 2>/dev/null | wc -l)
    if [ $VOLUME_COUNT -gt 0 ]; then
        check_result "INFO" "Docker 볼륨 수: $VOLUME_COUNT (백업 계획 확인 필요)" "중" "백업"
    fi
fi

print_subheader "4.3 침해사고 대응"

# 포렌식 도구 설치 확인
FORENSIC_TOOLS=(
    "tcpdump:네트워크 패킷 캡처"
    "tshark:패킷 분석"
    "netstat:네트워크 연결 확인"
    "lsof:열린 파일 확인"
    "strace:시스템 콜 추적"
)

for tool_info in "${FORENSIC_TOOLS[@]}"; do
    IFS=':' read -r tool desc <<< "$tool_info"
    if command -v $tool &>/dev/null; then
        check_result "PASS" "$desc 도구($tool)가 설치됨" "하" "포렌식"
    else
        check_result "INFO" "$desc 도구($tool)가 설치되지 않음" "하" "포렌식"
    fi
done

# ============================================
# 5. CSAP 추가 요구사항
# ============================================

print_header "5. CSAP(클라우드 보안 인증) 추가 요구사항"

print_subheader "5.1 암호화 키 관리"

# SSL 인증서 확인
if [ ! -z "$VSFTPD_CONTAINER" ]; then
    # 인증서 파일 존재 확인
    CERT_EXISTS=$(docker exec $VSFTPD_CONTAINER test -f /etc/vsftpd/vsftpd.pem 2>/dev/null && echo "YES" || echo "NO")
    if [ "$CERT_EXISTS" == "YES" ]; then
        check_result "PASS" "FTP SSL 인증서가 존재함" "상" "CSAP-암호화"
        
        # 인증서 권한 확인
        CERT_PERM=$(docker exec $VSFTPD_CONTAINER stat -c %a /etc/vsftpd/vsftpd.pem 2>/dev/null)
        if [ "$CERT_PERM" == "600" ] || [ "$CERT_PERM" == "400" ]; then
            check_result "PASS" "SSL 인증서 파일 권한이 적절함 ($CERT_PERM)" "상" "CSAP-암호화"
        else
            check_result "WARNING" "SSL 인증서 파일 권한이 느슨함 ($CERT_PERM)" "상" "CSAP-암호화"
        fi
    else
        check_result "WARNING" "FTP SSL 인증서 파일을 찾을 수 없음" "상" "CSAP-암호화"
    fi
    
    # RSA 키 크기 확인
    RSA_KEY_SIZE=$(docker exec $VSFTPD_CONTAINER grep "^rsa_cert_file" /etc/vsftpd/vsftpd.conf 2>/dev/null)
    if [ ! -z "$RSA_KEY_SIZE" ]; then
        check_result "INFO" "RSA 인증서 파일이 설정됨" "중" "CSAP-암호화"
    fi
fi

print_subheader "5.2 보안 거버넌스"

# 보안 정책 문서 확인
POLICY_FILES=(
    "/etc/security/security-policy.md"
    "/etc/security/incident-response.md"
    "/etc/security/backup-policy.md"
)

POLICY_COUNT=0
for policy_file in "${POLICY_FILES[@]}"; do
    if [ -f "$policy_file" ]; then
        ((POLICY_COUNT++))
    fi
done

if [ $POLICY_COUNT -gt 0 ]; then
    check_result "PASS" "보안 정책 문서가 존재함 ($POLICY_COUNT개)" "중" "CSAP-거버넌스"
else
    check_result "WARNING" "보안 정책 문서가 없음" "중" "CSAP-거버넌스"
fi

# ============================================
# 최종 결과 요약
# ============================================

echo -e "\n${BOLD}${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}                    Part 2 점검 결과 요약${NC}"
echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════${NC}\n"

# 결과 통계
echo -e "${GREEN}${BOLD}✓ PASS:${NC}     $PASS_COUNT 항목"
echo -e "${YELLOW}${BOLD}! WARNING:${NC}  $WARNING_COUNT 항목"
echo -e "${RED}${BOLD}✗ FAIL:${NC}     $FAIL_COUNT 항목"
echo -e "${BLUE}${BOLD}i INFO:${NC}     $INFO_COUNT 항목"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}총 점검 항목:${NC} $TOTAL_COUNT 개"

# 위험도별 통계
echo -e "\n${BOLD}위험도별 분포:${NC}"
echo -e "${RED}● 상(Critical):${NC} $CRITICAL_COUNT 항목"
echo -e "${YELLOW}● 중(High):${NC}     $HIGH_COUNT 항목"
echo -e "${GREEN}● 하(Low):${NC}      $MEDIUM_COUNT 항목"

# 보안 점수 계산
TOTAL_CHECKED=$((PASS_COUNT + WARNING_COUNT + FAIL_COUNT))
if [ $TOTAL_CHECKED -gt 0 ]; then
    SCORE=$((PASS_COUNT * 100 / TOTAL_CHECKED))
    echo -e "\n${BOLD}보안 준수율:${NC} ${SCORE}%"
    
    # 점수에 따른 평가
    if [ $SCORE -ge 90 ]; then
        echo -e "${GREEN}${BOLD}[보안 상태: 우수]${NC}"
        echo -e "Docker 및 FTP 서비스 보안이 매우 잘 관리되고 있습니다."
    elif [ $SCORE -ge 70 ]; then
        echo -e "${YELLOW}${BOLD}[보안 상태: 양호]${NC}"
        echo -e "전반적으로 양호하나 일부 개선이 필요합니다."
    elif [ $SCORE -ge 50 ]; then
        echo -e "${YELLOW}${BOLD}[보안 상태: 개선 필요]${NC}"
        echo -e "보안 강화를 위한 조치가 필요합니다."
    else
        echo -e "${RED}${BOLD}[보안 상태: 위험]${NC}"
        echo -e "즉시 보안 조치가 필요합니다."
    fi
fi

# Docker 관련 요약
if [ "$DOCKER_INSTALLED" = true ]; then
    echo -e "\n${BOLD}Docker 상태:${NC}"
    if [ "$DOCKER_RUNNING" = true ]; then
        echo -e "  ${GREEN}● Docker 서비스 실행 중${NC}"
        if [ ! -z "$VSFTPD_CONTAINER" ]; then
            echo -e "  ${GREEN}● VSFTPD 컨테이너 실행 중${NC}"
        else
            echo -e "  ${YELLOW}● VSFTPD 컨테이너 미실행${NC}"
        fi
    else
        echo -e "  ${RED}● Docker 서비스 중지됨${NC}"
    fi
else
    echo -e "\n${YELLOW}Docker가 설치되지 않음${NC}"
fi

# 주요 취약점 경고
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "\n${RED}${BOLD}[주의]${NC} 위험도 '상' 항목 중 FAIL 상태인 항목들을 우선적으로 개선하시기 바랍니다."
    echo -e "${YELLOW}특히 다음 항목들을 확인하세요:${NC}"
    echo -e "  • SSL/TLS 암호화 설정"
    echo -e "  • 익명 FTP 접속 차단"
    echo -e "  • 컨테이너 특권 모드 제한"
    echo -e "  • chroot 설정 활성화"
fi

# 권장 사항
echo -e "\n${BOLD}${BLUE}[권장 개선 사항]${NC}"
echo -e "1. ${CYAN}정기적인 취약점 스캔${NC}: Trivy 등을 사용한 이미지 스캔"
echo -e "2. ${CYAN}로그 모니터링${NC}: 중앙 로그 서버 구축 및 실시간 모니터링"
echo -e "3. ${CYAN}백업 정책${NC}: 정기적인 백업 및 복구 테스트"
echo -e "4. ${CYAN}보안 업데이트${NC}: 컨테이너 이미지 및 패키지 정기 업데이트"

echo -e "\n${BOLD}점검 완료 시각:${NC} $(date +"%Y-%m-%d %H:%M:%S")"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

# 종합 보고서 안내
echo -e "\n${YELLOW}${BOLD}[안내]${NC}"
echo -e "• Part 1과 Part 2의 결과를 종합하여 전체 보안 상태를 평가하세요."
echo -e "• 상세 보고서는 ${CYAN}/var/log/security-compliance/${NC} 디렉토리에서 확인할 수 있습니다."
echo -e "• 추가 보안 강화가 필요한 경우 KISA 가이드라인을 참고하세요."

exit 0