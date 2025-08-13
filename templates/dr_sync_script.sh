#!/bin/bash
# DR 데이터 동기화 스크립트
# 메인 스토리지에서 DR 스토리지로 데이터 동기화

set -e

# 설정
MAIN_STORAGE="${main_storage_account}"
DR_STORAGE="${dr_storage_account}"
SYNC_FREQUENCY="${sync_frequency}"
RETENTION_DAYS="${retention_days}"
LOG_FILE="/var/log/dr-sync.log"

# 로그 함수
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "DR 데이터 동기화 시작"

# Azure CLI 로그인 확인
if ! az account show >/dev/null 2>&1; then
    log "Azure CLI 인증 필요"
    # Managed Identity로 로그인 시도
    az login --identity
fi

# azcopy를 사용한 데이터 동기화
log "메인 스토리지에서 DR 스토리지로 동기화 중..."

# FTP 데이터 동기화
azcopy sync \
    "https://$MAIN_STORAGE.blob.core.windows.net/ftp-data" \
    "https://$DR_STORAGE.blob.core.windows.net/ftp-data" \
    --recursive \
    --delete-destination=true \
    --log-level=INFO

# 로그 동기화
azcopy sync \
    "https://$MAIN_STORAGE.blob.core.windows.net/logs" \
    "https://$DR_STORAGE.blob.core.windows.net/dr-logs" \
    --recursive \
    --delete-destination=true \
    --log-level=INFO

log "DR 데이터 동기화 완료"

# 동기화 상태를 로그에 기록
echo "SYNC_STATUS=SUCCESS" >> "$LOG_FILE"
echo "SYNC_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$LOG_FILE"