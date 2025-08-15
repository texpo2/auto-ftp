#!/bin/bash

# =============================================================================
# KISA/CSAP/기술적취약점평가 통합 보안 컴플라이언스 체커
# Version: 2.0
# Author: Security Compliance Team
# Date: 2024
# =============================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 전역 변수
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0
CRITICAL_FINDINGS=()
HIGH_FINDINGS=()
MEDIUM_FINDINGS=()
LOW_FINDINGS=()
REPORT_DIR="/var/log/security-compliance"
REPORT_FILE="$REPORT_DIR/compliance-report-$(date +%Y%m%d-%H%M%S).html"
JSON_REPORT="$REPORT_DIR/compliance-report-$(date +%Y%m%d-%H%M%S).json"

# 로깅 함수
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_critical() { echo -e "${RED}${BOLD}[CRITICAL]${NC} $1"; }

# 디렉토리 생성
mkdir -p "$REPORT_DIR"

# =============================================================================
# JSON 리포트 초기화
# =============================================================================
init_json_report() {
    cat > "$JSON_REPORT" <<EOF
{
    "scan_date": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "compliance_frameworks": {
        "kisa_cloud": {},
        "technical_vulnerability": {},
        "csap": {},
        "docker_security": {}
    },
    "summary": {
        "total_checks": 0,
        "passed": 0,
        "failed": 0,
        "warnings": 0,
        "compliance_score": 0
    },
    "findings": {
        "critical": [],
        "high": [],
        "medium": [],
        "low": []
    }
}
EOF
}

# =============================================================================
# HTML 리포트 헤더
# =============================================================================
init_html_report() {
    cat > "$REPORT_FILE" <<'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>보안 컴플라이언스 리포트</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }
        .summary-card {
            background: white;
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.3s ease;
        }
        .summary-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.15);
        }
        .summary-card .value {
            font-size: 2.5em;
            font-weight: bold;
            margin: 10px 0;
        }
        .summary-card .label {
            color: #6c757d;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .warning { color: #ffc107; }
        .compliance-score {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .compliance-score .value {
            font-size: 3em;
        }
        .section {
            padding: 30px;
        }
        .section-title {
            font-size: 1.8em;
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }
        .check-item {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 10px;
            border-left: 5px solid #dee2e6;
            transition: all 0.3s ease;
        }
        .check-item:hover {
            transform: translateX(5px);
            box-shadow: 0 3px 10px rgba(0,0,0,0.1);
        }
        .check-item.passed {
            border-left-color: #28a745;
            background: #d4edda;
        }
        .check-item.failed {
            border-left-color: #dc3545;
            background: #f8d7da;
        }
        .check-item.warning {
            border-left-color: #ffc107;
            background: #fff3cd;
        }
        .severity {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 5px;
            font-size: 0.85em;
            font-weight: bold;
            text-transform: uppercase;
        }
        .severity.critical {
            background: #dc3545;
            color: white;
        }
        .severity.high {
            background: #fd7e14;
            color: white;
        }
        .severity.medium {
            background: #ffc107;
            color: #333;
        }
        .severity.low {
            background: #28a745;
            color: white;
        }
        .progress-bar {
            width: 100%;
            height: 30px;
            background: #e9ecef;
            border-radius: 15px;
            overflow: hidden;
            margin: 20px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745 0%, #20c997 100%);
            transition: width 0.5s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }
        .recommendation {
            background: #e7f3ff;
            border-left: 4px solid #007bff;
            padding: 10px 15px;
            margin-top: 10px;
            border-radius: 5px;
        }
        .timestamp {
            text-align: center;
            color: #6c757d;
            margin: 20px 0;
            font-size: 0.9em;
        }
        @media print {
            body { background: white; }
            .container { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🛡️ 보안 컴플라이언스 리포트</h1>
            <div class="subtitle">KISA • CSAP • 기술적 취약점 평가 • Docker 보안</div>
        </div>
EOF
}

# =============================================================================
# 체크 함수
# =============================================================================
perform_check() {
    local check_name="$1"
    local check_command="$2"
    local severity="${3:-MEDIUM}"
    local framework="${4:-GENERAL}"
    local recommendation="${5:-}"
    
    ((TOTAL_CHECKS++))
    
    if eval "$check_command" &>/dev/null; then
        ((PASSED_CHECKS++))
        log_success "$check_name"
        echo "<div class='check-item passed'><strong>✓ $check_name</strong> <span class='severity low'>PASSED</span></div>" >> "$REPORT_FILE"
    else
        ((FAILED_CHECKS++))
        log_error "$check_name"
        echo "<div class='check-item failed'><strong>✗ $check_name</strong> <span class='severity ${severity,,}'>$severity</span>" >> "$REPORT_FILE"
        if [[ -n "$recommendation" ]]; then
            echo "<div class='recommendation'>💡 권장사항: $recommendation</div>" >> "$REPORT_FILE"
        fi
        echo "</div>" >> "$REPORT_FILE"
        
        case $severity in
            CRITICAL) CRITICAL_FINDINGS+=("$check_name") ;;
            HIGH) HIGH_FINDINGS+=("$check_name") ;;
            MEDIUM) MEDIUM_FINDINGS+=("$check_name") ;;
            LOW) LOW_FINDINGS+=("$check_name") ;;
        esac
    fi
}

# =============================================================================
# KISA 클라우드 보안 가이드 체크
# =============================================================================
check_kisa_cloud_security() {
    echo "<div class='section'><h2 class='section-title'>📋 KISA 클라우드 보안 가이드</h2>" >> "$REPORT_FILE"
    log_info "KISA 클라우드 보안 가이드 검사 시작..."
    
    # 1. 접근통제
    perform_check "계정 관리 - root 직접 로그인 차단" \
        "grep -q '^PermitRootLogin no' /etc/ssh/sshd_config 2>/dev/null" \
        "CRITICAL" "KISA" \
        "sshd_config에서 PermitRootLogin을 no로 설정"
    
    perform_check "계정 관리 - 패스워드 복잡도 정책" \
        "grep -q 'minlen=8' /etc/security/pwquality.conf 2>/dev/null" \
        "HIGH" "KISA" \
        "pwquality.conf에서 최소 길이 8자, 복잡도 규칙 설정"
    
    perform_check "계정 관리 - 계정 잠금 정책" \
        "grep -q 'deny=5' /etc/pam.d/system-auth 2>/dev/null || grep -q 'deny=5' /etc/pam.d/common-auth 2>/dev/null" \
        "HIGH" "KISA" \
        "PAM 설정에서 5회 실패 시 계정 잠금 설정"
    
    # 2. 네트워크 보안
    perform_check "네트워크 - 방화벽 활성화" \
        "systemctl is-active firewalld &>/dev/null || systemctl is-active ufw &>/dev/null" \
        "CRITICAL" "KISA" \
        "firewalld 또는 ufw 서비스 활성화"
    
    perform_check "네트워크 - 불필요한 포트 차단" \
        "! netstat -tuln | grep -E ':(23|135|139|445|3389)' &>/dev/null" \
        "HIGH" "KISA" \
        "텔넷, SMB, RDP 등 불필요한 서비스 비활성화"
    
    # 3. 로깅 및 모니터링
    perform_check "로깅 - auditd 서비스 활성화" \
        "systemctl is-active auditd &>/dev/null" \
        "HIGH" "KISA" \
        "auditd 서비스 설치 및 활성화"
    
    perform_check "로깅 - 로그 중앙화 설정" \
        "test -f /etc/rsyslog.conf || test -f /etc/syslog-ng/syslog-ng.conf" \
        "MEDIUM" "KISA" \
        "rsyslog 또는 syslog-ng 설정"
    
    # 4. 암호화
    perform_check "암호화 - SSL/TLS 설정" \
        "test -f /etc/vsftpd/vsftpd.pem" \
        "CRITICAL" "KISA" \
        "FTP 서버 SSL 인증서 설정"
    
    perform_check "암호화 - 취약한 프로토콜 비활성화" \
        "! grep -E 'ssl_sslv2=YES|ssl_sslv3=YES|ssl_tlsv1=YES' /etc/vsftpd/vsftpd.conf 2>/dev/null" \
        "HIGH" "KISA" \
        "SSLv2, SSLv3, TLSv1.0 비활성화"
    
    echo "</div>" >> "$REPORT_FILE"
}

# =============================================================================
# Docker 보안 체크 (KISA 가이드)
# =============================================================================
check_docker_security() {
    echo "<div class='section'><h2 class='section-title'>🐳 Docker 보안 체크</h2>" >> "$REPORT_FILE"
    log_info "Docker 보안 검사 시작..."
    
    # Docker 설치 여부 확인
    if command -v docker &>/dev/null; then
        perform_check "Docker - 데몬 보안 설정" \
            "test -f /etc/docker/daemon.json" \
            "HIGH" "DOCKER" \
            "daemon.json 파일 생성 및 보안 옵션 설정"
        
        perform_check "Docker - 루트리스 모드" \
            "docker info 2>/dev/null | grep -q 'rootless'" \
            "MEDIUM" "DOCKER" \
            "Docker rootless 모드 활성화 권장"
        
        perform_check "Docker - 컨테이너 격리" \
            "! docker ps --quiet 2>/dev/null | xargs -I {} docker inspect {} | grep -q '\"Privileged\": true'" \
            "CRITICAL" "DOCKER" \
            "privileged 컨테이너 사용 금지"
        
        perform_check "Docker - 이미지 서명 검증" \
            "grep -q 'content-trust' /etc/docker/daemon.json 2>/dev/null" \
            "MEDIUM" "DOCKER" \
            "Docker Content Trust 활성화"
        
        perform_check "Docker - 로깅 드라이버 설정" \
            "docker info 2>/dev/null | grep -q 'Logging Driver'" \
            "MEDIUM" "DOCKER" \
            "적절한 로깅 드라이버 설정"
        
        perform_check "Docker - 네트워크 격리" \
            "docker network ls | grep -q bridge" \
            "HIGH" "DOCKER" \
            "사용자 정의 브리지 네트워크 사용"
        
        perform_check "Docker - 리소스 제한" \
            "test -f /etc/docker/daemon.json && grep -q 'default-ulimits' /etc/docker/daemon.json" \
            "MEDIUM" "DOCKER" \
            "컨테이너 리소스 제한 설정"
    else
        log_warning "Docker가 설치되지 않음 - Docker 보안 체크 건너뜀"
    fi
    
    echo "</div>" >> "$REPORT_FILE"
}

# =============================================================================
# 기술적 취약점 평가 체크
# =============================================================================
check_technical_vulnerability() {
    echo "<div class='section'><h2 class='section-title'>🔍 기술적 취약점 평가</h2>" >> "$REPORT_FILE"
    log_info "기술적 취약점 평가 시작..."
    
    # 1. 운영체제 보안
    perform_check "OS - 최신 보안 패치 적용" \
        "! dnf check-update --security 2>/dev/null | grep -q 'updates'" \
        "CRITICAL" "VULN" \
        "dnf update --security 실행"
    
    perform_check "OS - 커널 보안 모듈 (SELinux)" \
        "sestatus 2>/dev/null | grep -q 'enforcing'" \
        "HIGH" "VULN" \
        "SELinux enforcing 모드 설정"
    
    perform_check "OS - 불필요한 서비스 비활성화" \
        "! systemctl list-unit-files | grep enabled | grep -E 'bluetooth|cups|avahi'" \
        "MEDIUM" "VULN" \
        "불필요한 서비스 비활성화"
    
    # 2. 파일시스템 보안
    perform_check "파일시스템 - SUID/SGID 파일 최소화" \
        "test $(find / -perm /6000 -type f 2>/dev/null | wc -l) -lt 50" \
        "MEDIUM" "VULN" \
        "불필요한 SUID/SGID 비트 제거"
    
    perform_check "파일시스템 - 중요 파일 권한" \
        "test $(stat -c %a /etc/passwd) = '644'" \
        "HIGH" "VULN" \
        "/etc/passwd 파일 권한 644 설정"
    
    perform_check "파일시스템 - /tmp 파티션 보안" \
        "mount | grep '/tmp' | grep -q 'noexec'" \
        "MEDIUM" "VULN" \
        "/tmp 파티션에 noexec 옵션 설정"
    
    # 3. 네트워크 보안
    perform_check "네트워크 - TCP SYN Flood 방어" \
        "sysctl net.ipv4.tcp_syncookies | grep -q '= 1'" \
        "HIGH" "VULN" \
        "tcp_syncookies 활성화"
    
    perform_check "네트워크 - IP 스푸핑 방지" \
        "sysctl net.ipv4.conf.all.rp_filter | grep -q '= 1'" \
        "HIGH" "VULN" \
        "rp_filter 활성화"
    
    perform_check "네트워크 - ICMP 리다이렉트 차단" \
        "sysctl net.ipv4.conf.all.accept_redirects | grep -q '= 0'" \
        "MEDIUM" "VULN" \
        "ICMP 리다이렉트 비활성화"
    
    # 4. 애플리케이션 보안
    perform_check "FTP - Anonymous 로그인 차단" \
        "grep -q 'anonymous_enable=NO' /etc/vsftpd/vsftpd.conf 2>/dev/null" \
        "CRITICAL" "VULN" \
        "vsftpd.conf에서 anonymous_enable=NO 설정"
    
    perform_check "FTP - chroot jail 설정" \
        "grep -q 'chroot_local_user=YES' /etc/vsftpd/vsftpd.conf 2>/dev/null" \
        "HIGH" "VULN" \
        "사용자를 홈 디렉토리에 제한"
    
    perform_check "FTP - 전송 암호화" \
        "grep -q 'ssl_enable=YES' /etc/vsftpd/vsftpd.conf 2>/dev/null" \
        "CRITICAL" "VULN" \
        "FTPS 활성화"
    
    echo "</div>" >> "$REPORT_FILE"
}

# =============================================================================
# CSAP 체크리스트
# =============================================================================
check_csap_compliance() {
    echo "<div class='section'><h2 class='section-title'>☁️ CSAP 컴플라이언스</h2>" >> "$REPORT_FILE"
    log_info "CSAP 컴플라이언스 검사 시작..."
    
    # 1. 데이터 보호
    perform_check "CSAP - 데이터 암호화 (전송 중)" \
        "grep -q 'force_local_data_ssl=YES' /etc/vsftpd/vsftpd.conf 2>/dev/null" \
        "CRITICAL" "CSAP" \
        "데이터 전송 시 SSL 강제"
    
    perform_check "CSAP - 데이터 암호화 (저장)" \
        "command -v cryptsetup &>/dev/null" \
        "HIGH" "CSAP" \
        "LUKS 또는 dm-crypt 설정"
    
    perform_check "CSAP - 백업 정책" \
        "test -f /etc/cron.d/backup || crontab -l 2>/dev/null | grep -q backup" \
        "HIGH" "CSAP" \
        "정기적인 백업 스케줄 설정"
    
    # 2. 접근 제어
    perform_check "CSAP - 다단계 인증" \
        "test -f /etc/pam.d/sshd && grep -q 'pam_google_authenticator' /etc/pam.d/sshd" \
        "MEDIUM" "CSAP" \
        "Google Authenticator 또는 유사 MFA 설정"
    
    perform_check "CSAP - 역할 기반 접근 제어" \
        "test -f /etc/sudoers.d/security-roles" \
        "HIGH" "CSAP" \
        "세분화된 sudo 권한 설정"
    
    perform_check "CSAP - 세션 타임아웃" \
        "grep -q 'TMOUT=' /etc/profile 2>/dev/null" \
        "MEDIUM" "CSAP" \
        "쉘 세션 타임아웃 설정"
    
    # 3. 보안 모니터링
    perform_check "CSAP - 침입 탐지 시스템" \
        "systemctl is-active fail2ban &>/dev/null || systemctl is-active aide &>/dev/null" \
        "HIGH" "CSAP" \
        "Fail2ban 또는 AIDE 활성화"
    
    perform_check "CSAP - 로그 무결성" \
        "test -f /etc/rsyslog.d/remote.conf || test -f /etc/audit/auditd.conf" \
        "HIGH" "CSAP" \
        "중앙 로그 서버 또는 로그 무결성 도구 설정"
    
    perform_check "CSAP - 보안 이벤트 알림" \
        "test -f /etc/aide.conf || test -f /etc/tripwire/twpol.txt" \
        "MEDIUM" "CSAP" \
        "파일 무결성 모니터링 설정"
    
    # 4. 사고 대응
    perform_check "CSAP - 사고 대응 계획" \
        "test -f /etc/security/incident-response.md" \
        "MEDIUM" "CSAP" \
        "문서화된 사고 대응 절차 작성"
    
    perform_check "CSAP - 포렌식 준비" \
        "command -v tcpdump &>/dev/null && command -v tshark &>/dev/null" \
        "LOW" "CSAP" \
        "포렌식 도구 사전 설치"
    
    echo "</div>" >> "$REPORT_FILE"
}

# =============================================================================
# FTP 서버 특화 보안 체크
# =============================================================================
check_ftp_specific() {
    echo "<div class='section'><h2 class='section-title'>📁 FTP 서버 보안 체크</h2>" >> "$REPORT_FILE"
    log_info "FTP 서버 특화 보안 검사 시작..."
    
    # vsftpd 설정 체크
    if [[ -f /etc/vsftpd/vsftpd.conf ]]; then
        perform_check "FTP - 로컬 사용자 제한" \
            "grep -q 'userlist_enable=YES' /etc/vsftpd/vsftpd.conf" \
            "HIGH" "FTP" \
            "사용자 화이트리스트 활성화"
        
        perform_check "FTP - 업로드 파일 권한" \
            "grep -q 'local_umask=022' /etc/vsftpd/vsftpd.conf" \
            "MEDIUM" "FTP" \
            "업로드 파일 권한 제한"
        
        perform_check "FTP - 대역폭 제한" \
            "grep -q 'local_max_rate=' /etc/vsftpd/vsftpd.conf" \
            "LOW" "FTP" \
            "사용자별 대역폭 제한 설정"
        
        perform_check "FTP - 동시 연결 제한" \
            "grep -q 'max_clients=' /etc/vsftpd/vsftpd.conf" \
            "MEDIUM" "FTP" \
            "최대 동시 접속자 수 제한"
        
        perform_check "FTP - IP별 연결 제한" \
            "grep -q 'max_per_ip=' /etc/vsftpd/vsftpd.conf" \
            "MEDIUM" "FTP" \
            "IP당 최대 연결 수 제한"
        
        perform_check "FTP - 세션 타임아웃" \
            "grep -q 'idle_session_timeout=' /etc/vsftpd/vsftpd.conf" \
            "MEDIUM" "FTP" \
            "유휴 세션 타임아웃 설정"
        
        perform_check "FTP - 로그 활성화" \
            "grep -q 'xferlog_enable=YES' /etc/vsftpd/vsftpd.conf" \
            "HIGH" "FTP" \
            "전송 로그 활성화"
        
        perform_check "FTP - 디버그 로그" \
            "grep -q 'log_ftp_protocol=YES' /etc/vsftpd/vsftpd.conf" \
            "LOW" "FTP" \
            "상세 프로토콜 로깅 활성화"
        
        perform_check "FTP - Passive 모드 포트 제한" \
            "grep -q 'pasv_min_port=' /etc/vsftpd/vsftpd.conf" \
            "MEDIUM" "FTP" \
            "Passive 모드 포트 범위 제한"
        
        perform_check "FTP - 배너 설정" \
            "grep -q 'ftpd_banner=' /etc/vsftpd/vsftpd.conf" \
            "LOW" "FTP" \
            "보안 경고 배너 설정"
    else
        log_warning "vsftpd 설정 파일을 찾을 수 없음"
    fi
    
    echo "</div>" >> "$REPORT_FILE"
}

# =============================================================================
# 추가 보안 체크
# =============================================================================
check_additional_security() {
    echo "<div class='section'><h2 class='section-title'>🔒 추가 보안 체크</h2>" >> "$REPORT_FILE"
    log_info "추가 보안 검사 시작..."
    
    # 1. SSH 보안
    if [[ -f /etc/ssh/sshd_config ]]; then
        perform_check "SSH - 프로토콜 버전 2" \
            "! grep -q 'Protocol 1' /etc/ssh/sshd_config" \
            "CRITICAL" "SSH" \
            "SSH 프로토콜 버전 2만 사용"
        
        perform_check "SSH - 키 기반 인증" \
            "grep -q 'PubkeyAuthentication yes' /etc/ssh/sshd_config" \
            "HIGH" "SSH" \
            "공개키 인증 활성화"
        
        perform_check "SSH - 빈 패스워드 차단" \
            "grep -q 'PermitEmptyPasswords no' /etc/ssh/sshd_config" \
            "CRITICAL" "SSH" \
            "빈 패스워드 로그인 차단"
    fi
    
    # 2. 시스템 무결성
    perform_check "시스템 - AIDE 데이터베이스" \
        "test -f /var/lib/aide/aide.db.gz" \
        "HIGH" "SYSTEM" \
        "AIDE 데이터베이스 초기화"
    
    perform_check "시스템 - 로그 로테이션" \
        "test -f /etc/logrotate.d/vsftpd" \
        "MEDIUM" "SYSTEM" \
        "로그 로테이션 설정"
    
    # 3. 성능 및 가용성
    perform_check "성능 - 스왑 파일 존재" \
        "test -f /swapfile || swapon -s | grep -q partition" \
        "LOW" "SYSTEM" \
        "스왑 공간 설정"
    
    perform_check "가용성 - NTP 동기화" \
        "systemctl is-active chronyd &>/dev/null || systemctl is-active ntp &>/dev/null" \
        "MEDIUM" "SYSTEM" \
        "시간 동기화 서비스 활성화"
    
    echo "</div>" >> "$REPORT_FILE"
}

# =============================================================================
# 보고서 요약 생성
# =============================================================================
generate_summary() {
    local compliance_score=$(echo "scale=2; ($PASSED_CHECKS * 100) / $TOTAL_CHECKS" | bc)
    
    # HTML 요약
    cat >> "$REPORT_FILE" <<EOF
        <div class="summary-grid">
            <div class="summary-card">
                <div class="label">전체 검사 항목</div>
                <div class="value">$TOTAL_CHECKS</div>
            </div>
            <div class="summary-card">
                <div class="label">통과</div>
                <div class="value passed">$PASSED_CHECKS</div>
            </div>
            <div class="summary-card">
                <div class="label">실패</div>
                <div class="value failed">$FAILED_CHECKS</div>
            </div>
            <div class="summary-card">
                <div class="label">경고</div>
                <div class="value warning">$WARNING_CHECKS</div>
            </div>
            <div class="summary-card compliance-score">
                <div class="label">컴플라이언스 점수</div>
                <div class="value">${compliance_score}%</div>
            </div>
        </div>
        
        <div class="progress-bar">
            <div class="progress-fill" style="width: ${compliance_score}%">
                ${compliance_score}% 준수
            </div>
        </div>
EOF
    
    # 심각도별 findings 출력
    if [[ ${#CRITICAL_FINDINGS[@]} -gt 0 ]]; then
        echo "<div class='section'><h3>🚨 Critical Findings (${#CRITICAL_FINDINGS[@]})</h3><ul>" >> "$REPORT_FILE"
        for finding in "${CRITICAL_FINDINGS[@]}"; do
            echo "<li>$finding</li>" >> "$REPORT_FILE"
        done
        echo "</ul></div>" >> "$REPORT_FILE"
    fi
    
    if [[ ${#HIGH_FINDINGS[@]} -gt 0 ]]; then
        echo "<div class='section'><h3>⚠️ High Risk Findings (${#HIGH_FINDINGS[@]})</h3><ul>" >> "$REPORT_FILE"
        for finding in "${HIGH_FINDINGS[@]}"; do
            echo "<li>$finding</li>" >> "$REPORT_FILE"
        done
        echo "</ul></div>" >> "$REPORT_FILE"
    fi
    
    # JSON 요약 업데이트
    python3 -c "
import json
with open('$JSON_REPORT', 'r+') as f:
    data = json.load(f)
    data['summary'] = {
        'total_checks': $TOTAL_CHECKS,
        'passed': $PASSED_CHECKS,
        'failed': $FAILED_CHECKS,
        'warnings': $WARNING_CHECKS,
        'compliance_score': $compliance_score
    }
    f.seek(0)
    json.dump(data, f, indent=2)
    f.truncate()
"
}

# =============================================================================
# 메인 실행
# =============================================================================
main() {
    echo -e "${BOLD}${CYAN}"
    echo "============================================================"
    echo "   보안 컴플라이언스 통합 검사 도구 v2.0"
    echo "   KISA | CSAP | 기술적 취약점 평가 | Docker 보안"
    echo "============================================================"
    echo -e "${NC}"
    
    # 루트 권한 확인
    if [[ $EUID -ne 0 ]]; then
        log_error "이 스크립트는 루트 권한으로 실행해야 합니다."
        exit 1
    fi
    
    # 리포트 초기화
    init_json_report
    init_html_report
    
    # 검사 실행
    check_kisa_cloud_security
    check_docker_security
    check_technical_vulnerability
    check_csap_compliance
    check_ftp_specific
    check_additional_security
    
    # 요약 생성
    generate_summary
    
    # HTML 리포트 마무리
    cat >> "$REPORT_FILE" <<EOF
        <div class="timestamp">
            보고서 생성: $(date '+%Y년 %m월 %d일 %H:%M:%S')
        </div>
    </div>
</body>
</html>
EOF
    
    # 결과 출력
    echo
    echo -e "${BOLD}${CYAN}========== 검사 완료 ==========${NC}"
    echo -e "${GREEN}통과: $PASSED_CHECKS${NC} | ${RED}실패: $FAILED_CHECKS${NC} | ${YELLOW}경고: $WARNING_CHECKS${NC}"
    echo -e "${BOLD}컴플라이언스 점수: ${compliance_score}%${NC}"
    echo
    echo -e "${CYAN}상세 리포트:${NC}"
    echo "  HTML: $REPORT_FILE"
    echo "  JSON: $JSON_REPORT"
    
    # 심각한 문제 경고
    if [[ ${#CRITICAL_FINDINGS[@]} -gt 0 ]]; then
        echo
        log_critical "즉시 조치가 필요한 Critical 항목이 ${#CRITICAL_FINDINGS[@]}개 발견되었습니다!"
    fi
    
    # 브라우저에서 리포트 열기 (GUI 환경인 경우)
    if [[ -n "$DISPLAY" ]] && command -v xdg-open &>/dev/null; then
        xdg-open "$REPORT_FILE" &>/dev/null &
    fi
}

# 스크립트 실행
main "$@"