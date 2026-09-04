#!/bin/bash

# 全局命令自动注册（判断如果系统里还没有快捷命令，就自动下载保存一份）
if [ ! -f "/usr/local/bin/komari-box" ]; then
    curl -sL "https://raw.githubusercontent.com/chandee1069/komari-tools/main/komari.sh" -o /usr/local/bin/komari-box 2>/dev/null
    chmod +x /usr/local/bin/komari-box 2>/dev/null
fi


RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; PLAIN='\033[0m'
    IP=$(curl -s4 --max-time 3 https://api.ipify.org || curl -s4 --max-time 3 https://ipv4.icanhazip.com)
    IP=${IP:-"你的VPS_IP"}
}

show_menu() {
    echo -e "\n${GREEN}=====================================${PLAIN}"
    echo -e "${GREEN}      Komari 探针纯净管理工具箱      ${PLAIN}"
    echo -e "${GREEN}=====================================${PLAIN}"
    echo -e " 1. 安装 / 重新安装 Komari 面板"
    echo -e " 2. 更新 Komari 探针面板"
    echo -e " 3. 卸载 Komari (清除环境)"
    echo -e " 4. 放行端口 (防火墙设置)"
    echo -e " 5. 添加 / 修改域名访问 (Cloudflare反代)"
    echo -e " 0. 退出脚本"
    echo -e "${GREEN}=====================================${PLAIN}"
    read -p "请输入选项 [0-5]: " num < /dev/tty

    case "$num" in
        1)
            read -p "请输入面板映射端口 [默认 8090]: " PORT < /dev/tty; PORT=${PORT:-8090}
            command -v docker &>/dev/null || curl -fsSL https://get.docker.com | sh
            docker rm -f komari 2>/dev/null
            docker run -d --name komari --restart always -p ${PORT}:25774 -v /var/lib/komari:/app/data ghcr.io/komari-monitor/komari:latest
            ufw allow ${PORT}/tcp 2>/dev/null || iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT 2>/dev/null
            get_ip
            echo -e "\n${GREEN}Komari 已成功安装！${PLAIN}"
            echo -e "IP 直连访问地址: ${YELLOW}http://${IP}:${PORT}${PLAIN}"
            ;;
        2)
            echo -e "${YELLOW}\n正在更新 Komari...${PLAIN}"
            OLD_PORT=$(docker inspect --format='{{(index (index .HostConfig.PortBindings "25774/tcp") 0).HostPort}}' komari 2>/dev/null); OLD_PORT=${OLD_PORT:-8090}
            docker pull ghcr.io/komari-monitor/komari:latest
            docker rm -f komari 2>/dev/null
            docker run -d --name komari --restart always -p ${OLD_PORT}:25774 -v /var/lib/komari:/app/data ghcr.io/komari-monitor/komari:latest
            get_ip
            echo -e "\n${GREEN}Komari 更新完成！${PLAIN}"
            echo -e "访问地址: ${YELLOW}http://${IP}:${OLD_PORT}${PLAIN}"
            ;;
        3)
            docker rm -f komari komari-caddy 2>/dev/null; rm -rf /var/lib/komari /etc/caddy 2>/dev/null
            echo -e "${GREEN}\n环境已彻底清理！${PLAIN}"
            ;;
        4)
            read -p "请输入要放行的端口: " PORT < /dev/tty
            ufw allow ${PORT}/tcp 2>/dev/null || iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT 2>/dev/null
            echo -e "${GREEN}\n端口 ${PORT} 已放行。${PLAIN}"
            ;;
        5)
            read -p "请输入你的绑定域名: " DOMAIN < /dev/tty; [ -z "$DOMAIN" ] && return
            read -p "请输入 Komari 当前面板端口 [默认 8090]: " PORT < /dev/tty; PORT=${PORT:-8090}
            DOCKER_GATEWAY=$(docker network inspect bridge --format='{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null); DOCKER_GATEWAY=${DOCKER_GATEWAY:-172.17.0.1}
            mkdir -p /etc/caddy
            cat << CADDY_EOF > /etc/caddy/Caddyfile
http://$DOMAIN {
    reverse_proxy $DOCKER_GATEWAY:$PORT
}
CADDY_EOF
            docker rm -f komari-caddy 2>/dev/null
            docker run -d --name komari-caddy --restart always --network host -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile caddy:alpine
            ufw allow 80/tcp 2>/dev/null || iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
            echo -e "\n${GREEN}域名反代配置成功！${PLAIN}"
            echo -e "域名访问地址: ${YELLOW}http://${DOMAIN}${PLAIN}"
            ;;
        0) exit 0 ;;
        *) exit 0 ;;
    esac
}

show_menu
