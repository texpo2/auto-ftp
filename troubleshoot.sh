#!/bin/bash
troubleshoot() {
    local issue="${1:-general}"
    
    log_info "=== 문제 해결 도구 ==="
    
    case "$issue" in
        "connection")
            log_info "FTP 연결 문제 진단 중..."
            
            echo ""
            log_info "1. 포트 상태 확인:"
            for port in 21 990 30000-30010; do
                if [[ "$port" == "30000-30010" ]]; then
                    for p in {30000..30010}; do
                        echo -n "  포트 $p: "
                        if netstat -tlnp | grep -q ":$p "; then
                            echo -e "${GREEN}열림${NC}"
                            break
                        fi
                    done
                    echo -e "${YELLOW}패시브 포트 범위 확인됨${NC}"
                else
                    echo -n "  포트 $port: "
                    if netstat -tlnp | grep -q ":$port "; then
                        echo -e "${GREEN}열림${NC}"
                    else
                        echo -e "${RED}닫힘${NC}"
                    fi
                fi
            done
            
            echo ""
            log_info "2. 방화벽 상태 확인:"
            systemctl is-active firewalld && {
                echo "Firewall 규칙:"
                firewall-cmd --list-all
            } || echo "Firewall이 비활성화되어 있습니다."
            
            echo ""
            log_info "3. Docker 네트워크 확인:"
            docker network ls
            docker port ftp-server 2>/dev/null || log_warning "FTP 컨테이너 포트 정보를 가져올 수 없습니다."
            ;;
            
        "service")
            log_info "FTP 서비스 상태 진단 중..."
            
            echo ""
            log_info "1. Docker 컨테이너 상태:"
            docker ps -a --filter name=ftp-server --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Command}}"
            
            echo ""
            log_info "2. 컨테이너 헬스체크:"
            if docker ps --filter name=ftp-server --filter health=healthy | grep -q ftp-server; then
                log_success "컨테이너가 정상 상태입니다."
            else
                log_warning "컨테이너 상태를 확인하세요."
                docker inspect ftp-server --format='{{.State.Health.Status}}' 2>/dev/null || echo "헬스체크 정보 없음"
            fi
            
            echo ""
            log_info "3. 최근 컨테이너 로그:"
            docker logs --tail 50 ftp-server 2>/dev/null || log_error "로그를 가져올 수 없습니다."
            
            echo ""
            log_info "4. vsftpd 프로세스 확인:"
            docker exec ftp-server ps aux | grep vsftpd 2>/dev/null || log_warning "vsftpd 프로세스 정보를 가져올 수 없습니다."
            ;;
            
        "restart")
            log_info "FTP 서비스 재시작 중..."
            
            log_info "Docker 컨테이너 재시작 중..."
            docker restart ftp-server && log_success "컨테이너가 재시작되었습니다." || log_error "컨테이너 재시작에 실패했습니다."
            
            log_info "서비스 초기화 대기 중 (30초)..."
            sleep 30
            
            if docker ps --filter name=ftp-server | grep -q ftp-server; then
                log_success "FTP 서비스가 정상적으로 재시작되었습니다."
                
                for port in 21 990; do
                    if netstat -tlnp | grep -q ":$port "; then
                        log_success "포트 $port가 정상적으로 열렸습니다."
                    else
                        log_warning "포트 $port 연결에 문제가 있습니다."
                    fi
                done
            else
                log_error "서비스 재시작에 문제가 있습니다."
                docker logs --tail 20 ftp-server
            fi
            ;;
        
        "rebuild")
            log_info "FTP 컨테이너 재빌드 중..."
            
            docker stop ftp-server 2>/dev/null || true
            docker rm ftp-server 2>/dev/null || true
            
            if [[ -d /opt/secure-ftp ]]; then
                cd /opt/secure-ftp
                docker build -t secure-ftp-server .
                
                docker run -d \
                    --name ftp-server \
                    --restart always \
                    --read-only \
                    --tmpfs /tmp \
                    --tmpfs /var/run \
                    --tmpfs /var/log \
                    --cap-drop ALL \
                    --cap-add CHOWN \
                    --cap-add DAC_OVERRIDE \
                    --cap-add NET_BIND_SERVICE \
                    --security-opt no-new-privileges:true \
                    --security-opt seccomp=unconfined \
                    -p 21:21 \
                    -p 990:990 \
                    -p 30000-30010:30000-30010 \
                    -v /opt/secure-ftp/data:/home/ftpuser:rw \
                    -v /opt/secure-ftp/logs:/var/log/vsftpd:rw \
                    secure-ftp-server
                
                log_success "컨테이너가 재빌드되고 실행되었습니다."
            else
                log_error "/opt/secure-ftp 디렉터리를 찾을 수 없습니다."
            fi
            ;;
            
        *)
            echo "사용법: $0 troubleshoot [옵션]"
            echo ""
            echo "옵션:"
            echo "  connection  - 연결 문제 진단"
            echo "  service     - 서비스 상태 진단"
            echo "  restart     - 서비스 재시작"
            echo "  rebuild     - 컨테이너 재빌드"
            echo ""
            echo "예: $0 troubleshoot connection"
            ;;
    esac
}
