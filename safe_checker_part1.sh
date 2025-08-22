#!/bin/bash

# ============================================
# KISA/CSAP/주요통신기반시설 보안 점검 스크립트 Part 1
# 기본 시스템 보안 및 KISA 클라우드 가이드
# Version: 3.0
# Date: 2025-08-18
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

# 진행률 표시
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percent * bar_length / 100))
    
    printf "\r${CYAN}진행률: ["
    printf "%${filled_length}s" | tr ' ' '='
    printf "%$((bar_length - filled_length))s" | tr ' ' '-'
    printf "] %d%%${NC}" $percent
}

# ============================================
# 메인 점검 시작
# ============================================

clear
echo -e "${BOLD}${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   KISA/CSAP/주요통신기반시설 보안 점검 스크립트 Part 1    ║"
echo "║           기본 시스템 보안 및 KISA 클라우드 가이드         ║"
echo "║                    Version 2.0                             ║"
echo "║                 $(date +"%Y-%m-%d %H:%M:%S")                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# ============================================
# 1. KISA 클라우드 보안 가이드 - 계정 관리
# ============================================

print_header "1. KISA 클라우드 보안 가이드 - 계정 관리"

print_subheader "1.1 계정 인증 및 권한 관리"

# root 계정 직접 로그인 제한
if [ -f /etc/ssh/sshd_config ]; then
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config* 2>/dev/null || \
       grep -q "^PermitRootLogin prohibit-password" /etc/ssh/sshd_config* 2>/dev/null; then
        check_result "PASS" "Root 계정 SSH 직접 로그인이 차단됨" "상" "KISA-계정"
    else
        check_result "FAIL" "Root 계정 SSH 직접 로그인이 허용됨" "상" "KISA-계정"
    fi
else
    check_result "WARNING" "SSH 설정 파일을 찾을 수 없음" "상" "KISA-계정"
fi

# 패스워드 복잡도 설정
if [ -f /etc/security/pwquality.conf ]; then
    MINLEN=$(grep "^minlen" /etc/security/pwquality.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    DCREDIT=$(grep "^dcredit" /etc/security/pwquality.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    UCREDIT=$(grep "^ucredit" /etc/security/pwquality.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    LCREDIT=$(grep "^lcredit" /etc/security/pwquality.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    OCREDIT=$(grep "^ocredit" /etc/security/pwquality.conf 2>/dev/null | cut -d= -f2 | tr -d ' ')
    
    if [ ! -z "$MINLEN" ] && [ "$MINLEN" -ge 8 ]; then
        check_result "PASS" "패스워드 최소 길이 정책이 설정됨 (${MINLEN}자)" "중" "KISA-계정"
    else
        check_result "FAIL" "패스워드 최소 길이가 부족함 (권장: 8자 이상)" "중" "KISA-계정"
    fi
    
    if [ ! -z "$DCREDIT" ] && [ ! -z "$UCREDIT" ] && [ ! -z "$LCREDIT" ] && [ ! -z "$OCREDIT" ]; then
        check_result "PASS" "패스워드 복잡도 규칙이 설정됨" "중" "KISA-계정"
    else
        check_result "WARNING" "패스워드 복잡도 규칙이 미흡함" "중" "KISA-계정"
    fi
else
    check_result "FAIL" "패스워드 복잡도 설정 파일이 없음" "중" "KISA-계정"
fi

# 계정 잠금 임계값 설정
if [ -f /etc/pam.d/system-auth ] || [ -f /etc/pam.d/common-auth ]; then
    if grep -q "pam_faillock.so" /etc/pam.d/system-auth 2>/dev/null || \
       grep -q "pam_faillock.so" /etc/pam.d/common-auth 2>/dev/null; then
        check_result "PASS" "계정 잠금 정책이 설정됨 (faillock)" "중" "KISA-계정"
    elif grep -q "pam_tally2.so" /etc/pam.d/system-auth 2>/dev/null || \
         grep -q "pam_tally2.so" /etc/pam.d/common-auth 2>/dev/null; then
        check_result "PASS" "계정 잠금 정책이 설정됨 (tally2)" "중" "KISA-계정"
    else
        check_result "FAIL" "계정 잠금 정책이 설정되지 않음" "중" "KISA-계정"
    fi
fi

# 패스워드 최대 사용기간
if [ -f /etc/login.defs ]; then
    PASS_MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}')
    if [ ! -z "$PASS_MAX_DAYS" ] && [ "$PASS_MAX_DAYS" -le 90 ] && [ "$PASS_MAX_DAYS" -gt 0 ]; then
        check_result "PASS" "패스워드 최대 사용기간이 설정됨 (${PASS_MAX_DAYS}일)" "중" "KISA-계정"
    else
        check_result "WARNING" "패스워드 최대 사용기간이 부적절함" "중" "KISA-계정"
    fi
fi

# 불필요한 계정 확인
SYSTEM_ACCOUNTS=$(awk -F: '$3 >= 1000 && $7 !~ /nologin|false/ {print $1}' /etc/passwd)
ACCOUNT_COUNT=$(echo "$SYSTEM_ACCOUNTS" | wc -l)
check_result "INFO" "활성 사용자 계정 수: $ACCOUNT_COUNT" "하" "KISA-계정"

# UID 0 계정 확인
UID_ZERO_ACCOUNTS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | grep -v "^root$")
if [ -z "$UID_ZERO_ACCOUNTS" ]; then
    check_result "PASS" "root 외 UID 0 계정이 없음" "상" "KISA-계정"
else
    check_result "FAIL" "root 외 UID 0 계정 존재: $UID_ZERO_ACCOUNTS" "상" "KISA-계정"
fi

print_subheader "1.2 계정 권한 분리"

# sudo 설정 확인
if [ -f /etc/sudoers ]; then
    if grep -q "^Defaults.*requiretty" /etc/sudoers 2>/dev/null; then
        check_result "PASS" "sudo 사용 시 TTY 요구 설정됨" "중" "KISA-계정"
    else
        check_result "WARNING" "sudo 사용 시 TTY 요구 설정 안됨" "중" "KISA-계정"
    fi
    
    if grep -q "^Defaults.*use_pty" /etc/sudoers 2>/dev/null; then
        check_result "PASS" "sudo 사용 시 PTY 사용 설정됨" "중" "KISA-계정"
    else
        check_result "WARNING" "sudo 사용 시 PTY 사용 설정 안됨" "중" "KISA-계정"
    fi
fi

# ============================================
# 2. 주요통신기반시설 기술적 취약점 평가 - 파일 및 디렉토리
# ============================================

print_header "2. 주요통신기반시설 기술적 취약점 평가 - 파일 시스템"

print_subheader "2.1 중요 파일 권한 관리"

# 중요 시스템 파일 권한 확인
important_files=(
    "/etc/passwd:644:상"
    "/etc/shadow:000:상"
    "/etc/group:644:중"
    "/etc/gshadow:000:중"
    "/etc/hosts:644:중"
    "/etc/hosts.allow:644:중"
    "/etc/hosts.deny:644:중"
    "/etc/ssh/sshd_config:600:상"
    "/etc/sudoers:440:상"
    "/etc/crontab:600:중"
    "/etc/securetty:600:중"
)

for file_info in "${important_files[@]}"; do
    IFS=':' read -r file expected_perm risk <<< "$file_info"
    if [ -f "$file" ]; then
        actual_perm=$(stat -c %a "$file" 2>/dev/null)
        if [ "$actual_perm" == "$expected_perm" ] || \
           ([ "$expected_perm" == "000" ] && ([ "$actual_perm" == "000" ] || [ "$actual_perm" == "400" ] || [ "$actual_perm" == "600" ])) || \
           ([ "$expected_perm" == "644" ] && ([ "$actual_perm" == "644" ] || [ "$actual_perm" == "640" ])) || \
           ([ "$expected_perm" == "600" ] && ([ "$actual_perm" == "600" ] || [ "$actual_perm" == "640" ])) || \
           ([ "$expected_perm" == "440" ] && [ "$actual_perm" == "440" ]); then
            check_result "PASS" "$file 권한이 적절함 ($actual_perm)" "$risk" "취약점-파일"
        else
            check_result "FAIL" "$file 권한이 부적절함 (현재: $actual_perm, 권장: $expected_perm)" "$risk" "취약점-파일"
        fi
    else
        check_result "INFO" "$file 파일이 존재하지 않음" "$risk" "취약점-파일"
    fi
done

print_subheader "2.2 SUID/SGID 파일 점검"

# SUID 파일 확인
echo -e "${CYAN}SUID 설정 파일 검색 중...${NC}"
SUID_FILES=$(find / -type f -perm -4000 2>/dev/null | head -20)
SUID_COUNT=$(find / -type f -perm -4000 2>/dev/null | wc -l)

if [ $SUID_COUNT -gt 0 ]; then
    check_result "INFO" "SUID 설정 파일 수: $SUID_COUNT" "중" "취약점-파일"
    
    # 불필요한 SUID 파일 확인
    UNNECESSARY_SUID=(
        "/usr/bin/at"
        "/usr/bin/lppasswd"
        "/usr/bin/newgrp"
    )
    
    for suid_file in "${UNNECESSARY_SUID[@]}"; do
        if [ -f "$suid_file" ] && [ -u "$suid_file" ]; then
            check_result "WARNING" "불필요한 SUID 파일: $suid_file" "중" "취약점-파일"
        fi
    done
fi

# SGID 파일 확인
SGID_COUNT=$(find / -type f -perm -2000 2>/dev/null | wc -l)
check_result "INFO" "SGID 설정 파일 수: $SGID_COUNT" "하" "취약점-파일"

print_subheader "2.3 홈 디렉토리 권한"

# 사용자 홈 디렉토리 권한 확인
for user_home in $(awk -F: '$3>=1000 && $3!=65534 {print $6}' /etc/passwd); do
    if [ -d "$user_home" ]; then
        home_perm=$(stat -c %a "$user_home" 2>/dev/null)
        if [ "$home_perm" == "700" ] || [ "$home_perm" == "750" ]; then
            check_result "PASS" "$user_home 디렉토리 권한이 적절함 ($home_perm)" "중" "취약점-파일"
        else
            check_result "WARNING" "$user_home 디렉토리 권한이 느슨함 ($home_perm)" "중" "취약점-파일"
        fi
    fi
done

# ============================================
# 3. 네트워크 서비스 보안
# ============================================

print_header "3. 네트워크 서비스 보안"

print_subheader "3.1 불필요한 서비스 점검"

# 위험한 서비스 확인
dangerous_services=(
    "telnet:상:23/tcp"
    "rsh:상:514/tcp"
    "rlogin:상:513/tcp"
    "rexec:상:512/tcp"
    "finger:중:79/tcp"
    "talk:하:517/udp"
    "ntalk:하:518/udp"
    "tftp:중:69/udp"
)

for service_info in "${dangerous_services[@]}"; do
    IFS=':' read -r service risk port <<< "$service_info"
    
    # systemctl로 서비스 확인
    if systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
        if systemctl is-active "$service" &>/dev/null; then
            check_result "FAIL" "$service 서비스가 실행 중" "$risk" "네트워크"
        else
            check_result "PASS" "$service 서비스가 비활성화됨" "$risk" "네트워크"
        fi
    # 포트 리스닝 확인
    elif netstat -tuln 2>/dev/null | grep -q ":${port%/*} "; then
        check_result "FAIL" "$service 포트($port)가 열려있음" "$risk" "네트워크"
    else
        check_result "PASS" "$service 서비스가 실행되지 않음" "$risk" "네트워크"
    fi
done

print_subheader "3.2 SSH 보안 설정"

if [ -f /etc/ssh/sshd_config ]; then
    # Protocol 2 사용
    if grep -q "^Protocol 2" /etc/ssh/sshd_config 2>/dev/null || ! grep -q "^Protocol" /etc/ssh/sshd_config 2>/dev/null; then
        check_result "PASS" "SSH Protocol 2를 사용" "상" "네트워크-SSH"
    else
        check_result "FAIL" "SSH Protocol 1이 허용될 수 있음" "상" "네트워크-SSH"
    fi
    
    # 빈 패스워드 로그인 차단
    if grep -q "^PermitEmptyPasswords no" /etc/ssh/sshd_config 2>/dev/null || ! grep -q "^PermitEmptyPasswords" /etc/ssh/sshd_config 2>/dev/null; then
        check_result "PASS" "빈 패스워드 로그인이 차단됨" "상" "네트워크-SSH"
    else
        check_result "FAIL" "빈 패스워드 로그인이 허용될 수 있음" "상" "네트워크-SSH"
    fi
    
    # MaxAuthTries 설정
    MAX_AUTH=$(grep "^MaxAuthTries" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    if [ ! -z "$MAX_AUTH" ] && [ "$MAX_AUTH" -le 4 ]; then
        check_result "PASS" "SSH 최대 인증 시도 횟수 제한 ($MAX_AUTH회)" "중" "네트워크-SSH"
    else
        check_result "WARNING" "SSH 최대 인증 시도 횟수가 설정되지 않음" "중" "네트워크-SSH"
    fi
    
    # ClientAliveInterval 설정
    CLIENT_ALIVE=$(grep "^ClientAliveInterval" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    if [ ! -z "$CLIENT_ALIVE" ] && [ "$CLIENT_ALIVE" -gt 0 ]; then
        check_result "PASS" "SSH 세션 타임아웃이 설정됨 (${CLIENT_ALIVE}초)" "하" "네트워크-SSH"
    else
        check_result "WARNING" "SSH 세션 타임아웃이 설정되지 않음" "하" "네트워크-SSH"
    fi
    
    # X11Forwarding 차단
    if grep -q "^X11Forwarding no" /etc/ssh/sshd_config 2>/dev/null; then
        check_result "PASS" "X11 포워딩이 차단됨" "중" "네트워크-SSH"
    else
        check_result "WARNING" "X11 포워딩이 허용될 수 있음" "중" "네트워크-SSH"
    fi
fi

print_subheader "3.3 방화벽 상태"

# firewalld 확인
if systemctl is-active firewalld &>/dev/null; then
    check_result "PASS" "방화벽(firewalld)이 활성화됨" "상" "네트워크"
    
    # 기본 zone 확인
    DEFAULT_ZONE=$(firewall-cmd --get-default-zone 2>/dev/null)
    if [ ! -z "$DEFAULT_ZONE" ]; then
        check_result "INFO" "기본 방화벽 존: $DEFAULT_ZONE" "하" "네트워크"
    fi
    
    # 활성 서비스 확인
    ACTIVE_SERVICES=$(firewall-cmd --list-services 2>/dev/null | wc -w)
    check_result "INFO" "방화벽에서 허용된 서비스 수: $ACTIVE_SERVICES" "중" "네트워크"
    
# iptables 확인
elif systemctl is-active iptables &>/dev/null; then
    check_result "PASS" "방화벽(iptables)이 활성화됨" "상" "네트워크"
    
    # iptables 규칙 수 확인
    IPTABLES_RULES=$(iptables -L -n 2>/dev/null | grep -c "^ACCEPT\|^DROP\|^REJECT" || echo "0")
    check_result "INFO" "iptables 규칙 수: $IPTABLES_RULES" "중" "네트워크"
    
# ufw 확인 (Ubuntu)
elif command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
    check_result "PASS" "방화벽(ufw)이 활성화됨" "상" "네트워크"
else
    check_result "FAIL" "방화벽이 비활성화됨" "상" "네트워크"
fi

# ============================================
# 4. 커널 보안 파라미터
# ============================================

print_header "4. 커널 보안 파라미터"

print_subheader "4.1 네트워크 보안 파라미터"

kernel_network_params=(
    "net.ipv4.tcp_syncookies:1:SYN Flooding 공격 방어:상"
    "net.ipv4.conf.all.rp_filter:1:IP Spoofing 방어:상"
    "net.ipv4.conf.default.rp_filter:1:IP Spoofing 방어(기본값):상"
    "net.ipv4.conf.all.accept_source_route:0:Source Routing 차단:중"
    "net.ipv4.conf.default.accept_source_route:0:Source Routing 차단(기본값):중"
    "net.ipv4.icmp_echo_ignore_broadcasts:1:Smurf 공격 방어:중"
    "net.ipv4.icmp_ignore_bogus_error_responses:1:잘못된 ICMP 응답 무시:하"
    "net.ipv4.conf.all.accept_redirects:0:ICMP 리다이렉트 차단:중"
    "net.ipv4.conf.default.accept_redirects:0:ICMP 리다이렉트 차단(기본값):중"
    "net.ipv4.conf.all.secure_redirects:0:보안 ICMP 리다이렉트 차단:중"
    "net.ipv4.conf.all.send_redirects:0:ICMP 리다이렉트 전송 차단:중"
    "net.ipv4.conf.default.send_redirects:0:ICMP 리다이렉트 전송 차단(기본값):중"
    "net.ipv4.tcp_timestamps:0:TCP 타임스탬프 비활성화:하"
    "net.ipv4.conf.all.log_martians:1:스푸핑 패킷 로깅:중"
    "net.ipv4.conf.default.log_martians:1:스푸핑 패킷 로깅(기본값):중"
)

for param_info in "${kernel_network_params[@]}"; do
    IFS=':' read -r param expected desc risk <<< "$param_info"
    current=$(sysctl -n $param 2>/dev/null)
    if [ "$current" == "$expected" ]; then
        check_result "PASS" "$desc ($param = $current)" "$risk" "커널"
    else
        check_result "FAIL" "$desc (현재: $param = $current, 권장: $expected)" "$risk" "커널"
    fi
done

print_subheader "4.2 시스템 보안 파라미터"

kernel_system_params=(
    "kernel.randomize_va_space:2:ASLR 활성화:상"
    "fs.protected_symlinks:1:심볼릭 링크 보호:중"
    "fs.protected_hardlinks:1:하드 링크 보호:중"
    "kernel.exec-shield:1:버퍼 오버플로우 방지:상"
    "kernel.dmesg_restrict:1:dmesg 접근 제한:중"
    "kernel.kptr_restrict:1:커널 포인터 노출 제한:중"
    "kernel.yama.ptrace_scope:1:ptrace 제한:중"
)

for param_info in "${kernel_system_params[@]}"; do
    IFS=':' read -r param expected desc risk <<< "$param_info"
    current=$(sysctl -n $param 2>/dev/null)
    if [ ! -z "$current" ]; then
        if [ "$current" == "$expected" ] || ([ "$param" == "kernel.randomize_va_space" ] && [ "$current" -ge "$expected" ]); then
            check_result "PASS" "$desc ($param = $current)" "$risk" "커널"
        else
            check_result "FAIL" "$desc (현재: $param = $current, 권장: $expected)" "$risk" "커널"
        fi
    else
        check_result "INFO" "$desc - 파라미터가 설정되지 않음" "$risk" "커널"
    fi
done

# ============================================
# 5. 로깅 및 감사
# ============================================

print_header "5. 로깅 및 감사 설정"

print_subheader "5.1 시스템 로깅"

# rsyslog 또는 syslog-ng 확인
if systemctl is-active rsyslog &>/dev/null; then
    check_result "PASS" "시스템 로깅 서비스(rsyslog)가 활성화됨" "중" "로깅"
    
    # 원격 로깅 설정 확인
    if grep -q "^*.*[[:space:]]*@" /etc/rsyslog.conf 2>/dev/null || \
       grep -q "^*.*[[:space:]]*@@" /etc/rsyslog.conf 2>/dev/null || \
       grep -q "^*.*[[:space:]]*@" /etc/rsyslog.d/*.conf 2>/dev/null; then
        check_result "PASS" "원격 로그 서버 설정이 있음" "중" "로깅"
    else
        check_result "WARNING" "원격 로그 서버가 설정되지 않음" "중" "로깅"
    fi
elif systemctl is-active syslog-ng &>/dev/null; then
    check_result "PASS" "시스템 로깅 서비스(syslog-ng)가 활성화됨" "중" "로깅"
elif systemctl is-active systemd-journald &>/dev/null; then
    check_result "PASS" "시스템 로깅 서비스(journald)가 활성화됨" "중" "로깅"
else
    check_result "FAIL" "시스템 로깅 서비스가 비활성화됨" "중" "로깅"
fi

print_subheader "5.2 감사 로그 (auditd)"

if systemctl is-active auditd &>/dev/null; then
    check_result "PASS" "감사 데몬(auditd)이 실행 중" "상" "로깅"
    
    # 감사 규칙 확인
    AUDIT_RULES=$(auditctl -l 2>/dev/null | wc -l)
    if [ $AUDIT_RULES -gt 0 ]; then
        check_result "PASS" "감사 규칙이 설정됨 ($AUDIT_RULES개)" "중" "로깅"
        
        # 주요 감사 규칙 확인
        if auditctl -l 2>/dev/null | grep -q "/etc/passwd"; then
            check_result "PASS" "패스워드 파일 변경 감사 설정됨" "상" "로깅"
        else
            check_result "WARNING" "패스워드 파일 변경 감사가 설정되지 않음" "상" "로깅"
        fi
        
        if auditctl -l 2>/dev/null | grep -q "/etc/shadow"; then
            check_result "PASS" "Shadow 파일 변경 감사 설정됨" "상" "로깅"
        else
            check_result "WARNING" "Shadow 파일 변경 감사가 설정되지 않음" "상" "로깅"
        fi
    else
        check_result "WARNING" "감사 규칙이 설정되지 않음" "중" "로깅"
    fi
    
    # 감사 로그 크기 확인
    if [ -f /etc/audit/auditd.conf ]; then
        MAX_LOG_FILE=$(grep "^max_log_file " /etc/audit/auditd.conf 2>/dev/null | awk '{print $3}')
        if [ ! -z "$MAX_LOG_FILE" ] && [ "$MAX_LOG_FILE" -ge 8 ]; then
            check_result "PASS" "감사 로그 파일 크기 제한 설정됨 (${MAX_LOG_FILE}MB)" "하" "로깅"
        else
            check_result "WARNING" "감사 로그 파일 크기가 작음" "하" "로깅"
        fi
    fi
else
    check_result "FAIL" "감사 데몬(auditd)이 실행되지 않음" "상" "로깅"
fi

print_subheader "5.3 로그 파일 권한"

log_files=(
    "/var/log/messages:600:중"
    "/var/log/secure:600:상"
    "/var/log/audit/audit.log:600:상"
    "/var/log/cron:600:중"
    "/var/log/maillog:600:하"
    "/var/log/boot.log:600:하"
)

for log_info in "${log_files[@]}"; do
    IFS=':' read -r logfile expected_perm risk <<< "$log_info"
    if [ -f "$logfile" ]; then
        actual_perm=$(stat -c %a "$logfile" 2>/dev/null)
        if [ "$actual_perm" == "$expected_perm" ] || [ "$actual_perm" == "640" ] || [ "$actual_perm" == "644" ]; then
            check_result "PASS" "$logfile 권한이 적절함 ($actual_perm)" "$risk" "로깅"
        else
            check_result "WARNING" "$logfile 권한 확인 필요 (현재: $actual_perm, 권장: $expected_perm)" "$risk" "로깅"
        fi
    else
        check_result "INFO" "$logfile 파일이 존재하지 않음" "$risk" "로깅"
    fi
done

# ============================================
# 6. SELinux/AppArmor 상태
# ============================================

print_header "6. 강제 접근 제어 (MAC)"

# SELinux 확인
if command -v getenforce &>/dev/null; then
    SELINUX_STATUS=$(getenforce 2>/dev/null)
    case $SELINUX_STATUS in
        "Enforcing")
            check_result "PASS" "SELinux가 Enforcing 모드로 실행 중" "상" "MAC"
            
            # SELinux 정책 확인
            SELINUX_POLICY=$(sestatus 2>/dev/null | grep "Loaded policy name" | awk '{print $4}')
            if [ ! -z "$SELINUX_POLICY" ]; then
                check_result "INFO" "SELinux 정책: $SELINUX_POLICY" "중" "MAC"
            fi
            ;;
        "Permissive")
            check_result "WARNING" "SELinux가 Permissive 모드로 실행 중" "상" "MAC"
            ;;
        "Disabled")
            check_result "FAIL" "SELinux가 비활성화됨" "상" "MAC"
            ;;
    esac
# AppArmor 확인 (Ubuntu/Debian)
elif command -v aa-status &>/dev/null; then
    if systemctl is-active apparmor &>/dev/null; then
        check_result "PASS" "AppArmor가 활성화됨" "상" "MAC"
        
        # AppArmor 프로파일 수 확인
        APPARMOR_PROFILES=$(aa-status 2>/dev/null | grep "profiles are loaded" | awk '{print $1}')
        if [ ! -z "$APPARMOR_PROFILES" ] && [ "$APPARMOR_PROFILES" -gt 0 ]; then
            check_result "INFO" "AppArmor 프로파일 수: $APPARMOR_PROFILES" "중" "MAC"
        fi
    else
        check_result "FAIL" "AppArmor가 비활성화됨" "상" "MAC"
    fi
else
    check_result "WARNING" "강제 접근 제어(SELinux/AppArmor)가 설치되지 않음" "상" "MAC"
fi

# ============================================
# 7. 업데이트 및 패치 관리
# ============================================

print_header "7. 업데이트 및 패치 관리"

print_subheader "7.1 보안 업데이트 확인"

# CentOS/RHEL/Rocky Linux
if command -v dnf &>/dev/null; then
    echo -e "${CYAN}보안 업데이트 확인 중... (시간이 걸릴 수 있습니다)${NC}"
    SECURITY_UPDATES=$(dnf check-update --security 2>/dev/null | grep -c "security" || echo "0")
    if [ "$SECURITY_UPDATES" == "0" ]; then
        check_result "PASS" "모든 보안 업데이트가 적용됨" "상" "업데이트"
    else
        check_result "WARNING" "적용 가능한 보안 업데이트: $SECURITY_UPDATES개" "상" "업데이트"
    fi
# Ubuntu/Debian
elif command -v apt &>/dev/null; then
    echo -e "${CYAN}보안 업데이트 확인 중... (시간이 걸릴 수 있습니다)${NC}"
    apt update &>/dev/null 2>&1
    SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c "security" || echo "0")
    if [ "$SECURITY_UPDATES" == "0" ]; then
        check_result "PASS" "모든 보안 업데이트가 적용됨" "상" "업데이트"
    else
        check_result "WARNING" "적용 가능한 보안 업데이트: $SECURITY_UPDATES개" "상" "업데이트"
    fi
fi

# 자동 업데이트 설정 확인
if [ -f /etc/dnf/automatic.conf ]; then
    if grep -q "apply_updates = yes" /etc/dnf/automatic.conf 2>/dev/null; then
        check_result "PASS" "자동 업데이트가 설정됨" "중" "업데이트"
    else
        check_result "WARNING" "자동 업데이트가 설정되지 않음" "중" "업데이트"
    fi
elif [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    if grep -q "Unattended-Upgrade::Allowed-Origins" /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null; then
        check_result "PASS" "자동 업데이트가 설정됨" "중" "업데이트"
    else
        check_result "WARNING" "자동 업데이트가 설정되지 않음" "중" "업데이트"
    fi
fi

# ============================================
# 8. CSAP 기본 요구사항
# ============================================

print_header "8. CSAP(클라우드 보안 인증) 기본 요구사항"

print_subheader "8.1 데이터 보호"

# 디스크 암호화 확인
if lsblk -o NAME,FSTYPE 2>/dev/null | grep -q "crypto_LUKS"; then
    check_result "PASS" "디스크 암호화(LUKS)가 적용됨" "상" "CSAP-데이터"
else
    # dm-crypt 확인
    if lsmod | grep -q "dm_crypt"; then
        check_result "WARNING" "dm-crypt 모듈이 로드됨 (암호화 부분 적용)" "상" "CSAP-데이터"
    else
        check_result "FAIL" "디스크 암호화가 적용되지 않음" "상" "CSAP-데이터"
    fi
fi

# 백업 정책 확인
if [ -d /backup ] || [ -d /var/backup ] || [ -d /mnt/backup ]; then
    check_result "PASS" "백업 디렉토리가 존재함" "중" "CSAP-데이터"
    
    # cron 백업 작업 확인
    if crontab -l 2>/dev/null | grep -q "backup" || \
       grep -q "backup" /etc/cron.d/* 2>/dev/null || \
       grep -q "backup" /etc/crontab 2>/dev/null; then
        check_result "PASS" "정기 백업 스케줄이 설정됨" "중" "CSAP-데이터"
    else
        check_result "WARNING" "정기 백업 스케줄이 설정되지 않음" "중" "CSAP-데이터"
    fi
else
    check_result "WARNING" "백업 디렉토리가 없음" "중" "CSAP-데이터"
fi

print_subheader "8.2 접근 제어"

# Multi-Factor Authentication 확인
if [ -f /etc/pam.d/sshd ]; then
    if grep -q "pam_google_authenticator.so" /etc/pam.d/sshd 2>/dev/null || \
       grep -q "pam_oath.so" /etc/pam.d/sshd 2>/dev/null || \
       grep -q "pam_duo.so" /etc/pam.d/sshd 2>/dev/null; then
        check_result "PASS" "MFA(Multi-Factor Authentication)가 설정됨" "상" "CSAP-접근"
    else
        check_result "WARNING" "MFA가 설정되지 않음" "상" "CSAP-접근"
    fi
fi

# 세션 타임아웃 설정
if grep -q "^TMOUT=" /etc/profile 2>/dev/null || \
   grep -q "^export TMOUT=" /etc/profile 2>/dev/null || \
   grep -q "^TMOUT=" /etc/bash.bashrc 2>/dev/null; then
    TMOUT_VALUE=$(grep "^TMOUT=" /etc/profile 2>/dev/null | cut -d= -f2)
    if [ ! -z "$TMOUT_VALUE" ]; then
        check_result "PASS" "쉘 세션 타임아웃이 설정됨 (${TMOUT_VALUE}초)" "중" "CSAP-접근"
    fi
else
    check_result "WARNING" "쉘 세션 타임아웃이 설정되지 않음" "중" "CSAP-접근"
fi

print_subheader "8.3 보안 모니터링"

# 침입 탐지 시스템 확인
if systemctl is-active fail2ban &>/dev/null; then
    check_result "PASS" "침입 차단 시스템(Fail2ban)이 활성화됨" "상" "CSAP-모니터링"
    
    # Fail2ban jail 확인
    if [ -f /etc/fail2ban/jail.local ] || [ -f /etc/fail2ban/jail.conf ]; then
        ENABLED_JAILS=$(fail2ban-client status 2>/dev/null | grep "Number of jail" | awk '{print $5}')
        if [ ! -z "$ENABLED_JAILS" ] && [ "$ENABLED_JAILS" -gt 0 ]; then
            check_result "INFO" "활성화된 Fail2ban jail 수: $ENABLED_JAILS" "중" "CSAP-모니터링"
        fi
    fi
elif command -v aide &>/dev/null; then
    check_result "PASS" "파일 무결성 모니터링(AIDE)이 설치됨" "상" "CSAP-모니터링"
    
    # AIDE 데이터베이스 확인
    if [ -f /var/lib/aide/aide.db ] || [ -f /var/lib/aide/aide.db.gz ]; then
        check_result "PASS" "AIDE 데이터베이스가 초기화됨" "중" "CSAP-모니터링"
    else
        check_result "WARNING" "AIDE 데이터베이스가 초기화되지 않음" "중" "CSAP-모니터링"
    fi
elif command -v tripwire &>/dev/null; then
    check_result "PASS" "파일 무결성 모니터링(Tripwire)이 설치됨" "상" "CSAP-모니터링"
else
    check_result "WARNING" "침입 탐지/파일 무결성 모니터링 도구가 설치되지 않음" "상" "CSAP-모니터링"
fi

# ============================================
# 최종 결과 요약
# ============================================

echo -e "\n${BOLD}${CYAN}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}                    Part 1 점검 결과 요약${NC}"
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
        echo -e "시스템 보안이 매우 잘 관리되고 있습니다."
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

# 주요 취약점 경고
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "\n${RED}${BOLD}[주의]${NC} 위험도 '상' 항목 중 FAIL 상태인 항목들을 우선적으로 개선하시기 바랍니다."
fi

echo -e "\n${BOLD}점검 완료 시각:${NC} $(date +"%Y-%m-%d %H:%M:%S")"
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}${BOLD}[안내]${NC} Docker 및 FTP 서비스 점검은 Part 2 스크립트(safe_checker_part2.sh)를 실행하세요."

exit 0