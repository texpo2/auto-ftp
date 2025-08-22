#!/bin/bash
# KISA/CSAP 보안 가이드라인 준수 FTP 서버 설정 스크립트
# 작성일: 2024
# VM 생성 후 실행용 스크립트

set -e  # 오류 발생시 중단
LOG_FILE="/var/log/ftp-setup.log"

# 로깅 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "FTP 서버 설정 시작"

# ============================================
# 1. 시스템 업데이트 및 보안 설정
# ============================================
log "시스템 패키지 업데이트 중..."
dnf update -y

# SELinux 설정
log "SELinux 설정 중..."
setenforce 1
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# 보안 커널 파라미터 설정
log "커널 보안 파라미터 설정 중..."
cat >> /etc/sysctl.d/99-security.conf <<EOF
# Network security
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sysctl -p /etc/sysctl.d/99-security.conf

# ============================================
# 2. 필수 패키지 설치
# ============================================
log "필수 패키지 설치 중..."
# EPEL 설치 (실패 시 계속 진행)
dnf install -y epel-release || {
    log "EPEL 설치 실패 - 수동으로 추가 시도"
    rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm || log "EPEL 설치 실패"
}

# 필수 패키지 설치 (각 패키지 실패 시에도 계속 진행)
dnf install -y vsftpd || log "vsftpd 설치 실패"
dnf install -y firewalld || log "firewalld 설치 실패"
dnf install -y fail2ban || log "fail2ban 설치 실패"
dnf install -y aide || log "aide 설치 실패"
dnf install -y audit || log "audit 설치 실패"
dnf install -y openssl || log "openssl 설치 실패"
dnf install -y policycoreutils-python-utils || log "policycoreutils 설치 실패"

# ============================================
# 3. vsftpd 설정 (KISA 보안 가이드 준수)
# ============================================
log "vsftpd 보안 설정 구성 중..."

# 백업
cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak

# vsftpd 설정 파일 생성
cat > /etc/vsftpd/vsftpd.conf <<'EOF'
# KISA 보안 가이드라인 준수 설정

# 기본 설정
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
listen=YES
listen_ipv6=NO
pam_service_name=vsftpd
userlist_enable=YES
userlist_deny=NO
tcp_wrappers=YES

# 보안 강화 설정
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
user_sub_token=$USER
local_root=/home/$USER/ftp

# SSL/TLS 설정 (FTPS)
ssl_enable=YES
rsa_cert_file=/etc/vsftpd/vsftpd.pem
rsa_private_key_file=/etc/vsftpd/vsftpd.pem
ssl_tlsv1_2=YES
ssl_tlsv1_3=YES
ssl_sslv2=NO
ssl_sslv3=NO
ssl_tlsv1=NO
ssl_tlsv1_1=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
force_local_data_ssl=YES
force_local_logins_ssl=YES

# 연결 제한
max_clients=50
max_per_ip=3
idle_session_timeout=600
data_connection_timeout=120

# 로깅 설정
log_ftp_protocol=YES
debug_ssl=YES
vsftpd_log_file=/var/log/vsftpd.log
dual_log_enable=YES

# 대역폭 제한
local_max_rate=1048576

# 배너 설정
ftpd_banner=Authorized Access Only. All activities are monitored and logged.

# 명령 제한
cmds_allowed=ABOR,CWD,LIST,MDTM,MKD,NLST,PASS,PASV,PORT,PWD,QUIT,RETR,RMD,RNFR,RNTO,SITE,SIZE,STOR,TYPE,USER,ACCT,APPE,CDUP,HELP,MODE,NOOP,REIN,STAT,STOU,STRU,SYST

# Passive 모드 설정
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
pasv_address=10.0.1.10
EOF

# ============================================
# 4. SSL 인증서 생성
# ============================================
log "SSL 인증서 생성 중..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/vsftpd/vsftpd.pem \
    -out /etc/vsftpd/vsftpd.pem \
    -subj "/C=KR/ST=Seoul/L=Seoul/O=Organization/CN=ftp.example.com"

chmod 600 /etc/vsftpd/vsftpd.pem

# ============================================
# 5. FTP 사용자 설정
# ============================================
log "FTP 사용자 설정 중..."

# ftpuser 생성
useradd -m -s /bin/bash ftpuser
echo "ftpuser:SecureP@ssw0rd2024!" | chpasswd

# FTP 디렉토리 구조 생성
mkdir -p /home/ftpuser/ftp/{upload,download}
chown -R ftpuser:ftpuser /home/ftpuser/ftp
chmod 755 /home/ftpuser/ftp
chmod 775 /home/ftpuser/ftp/upload
chmod 755 /home/ftpuser/ftp/download

# 사용자 리스트 설정
echo "ftpuser" > /etc/vsftpd/user_list
echo "ftpuser" > /etc/vsftpd/chroot_list

# ============================================
# 6. 방화벽 설정
# ============================================
log "방화벽 설정 중..."
systemctl start firewalld
systemctl enable firewalld

# FTP 포트 개방
firewall-cmd --permanent --add-service=ftp
firewall-cmd --permanent --add-port=40000-40100/tcp
firewall-cmd --permanent --add-port=990/tcp
firewall-cmd --reload

# ============================================
# 7. Fail2ban 설정
# ============================================
log "Fail2ban 설정 중..."

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[vsftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
filter = vsftpd
logpath = /var/log/vsftpd.log
maxretry = 3
bantime = 7200
EOF

# ============================================
# 8. 감사 로깅 설정
# ============================================
log "감사 로깅 설정 중..."

# auditd 규칙 추가
cat >> /etc/audit/rules.d/ftp.rules <<'EOF'
# FTP 관련 감사 규칙
-w /etc/vsftpd/ -p wa -k ftp_config
-w /var/log/vsftpd.log -p wa -k ftp_log
-w /home/ftpuser/ftp/ -p rwxa -k ftp_data
EOF

# auditd 재시작
systemctl restart auditd
systemctl enable auditd

# ============================================
# 9. 파일 무결성 모니터링 (AIDE)
# ============================================
log "AIDE 초기화 중..."
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

# ============================================
# 10. 서비스 시작 및 활성화
# ============================================
log "서비스 시작 중..."

# SELinux 컨텍스트 설정
setsebool -P ftpd_full_access on
setsebool -P allow_ftpd_use_cifs on
setsebool -P allow_ftpd_use_nfs on

# 서비스 시작
systemctl restart vsftpd
systemctl enable vsftpd
systemctl restart fail2ban
systemctl enable fail2ban

# ============================================
# 11. 로그 로테이션 설정
# ============================================
cat > /etc/logrotate.d/vsftpd <<'EOF'
/var/log/vsftpd.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
    postrotate
        /bin/kill -USR1 `cat /var/run/vsftpd.pid 2>/dev/null` 2>/dev/null || true
    endscript
}
EOF

# ============================================
# 12. 설정 확인
# ============================================
log "설정 검증 중..."

# vsftpd 상태 확인
if systemctl is-active --quiet vsftpd; then
    log "✓ vsftpd 서비스 정상 실행 중"
else
    log "✗ vsftpd 서비스 실행 실패"
fi

# 방화벽 규칙 확인
if firewall-cmd --list-services | grep -q ftp; then
    log "✓ 방화벽 FTP 규칙 설정됨"
else
    log "✗ 방화벽 FTP 규칙 설정 실패"
fi

# Fail2ban 상태 확인
if systemctl is-active --quiet fail2ban; then
    log "✓ Fail2ban 서비스 정상 실행 중"
else
    log "✗ Fail2ban 서비스 실행 실패"
fi

log "=========================================="
log "FTP 서버 설정 완료!"
log "FTP 사용자: ftpuser"
log "FTP 포트: 21 (FTP), 990 (FTPS)"
log "Passive 포트: 40000-40100"
log "로그 파일: /var/log/vsftpd.log"
log "=========================================="