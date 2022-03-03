red='\e[91m'
green='\e[92m'
yellow='\e[93m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e ${red}$*${none}; }
_green() { echo -e ${green}$*${none}; }
_yellow() { echo -e ${yellow}$*${none}; }
_magenta() { echo -e ${magenta}$*${none}; }
_cyan() { echo -e ${cyan}$*${none}; }

error() {
    echo -e "\n$red 输入错误！$none\n"
}

pause() {
	read -rsp "$(echo -e "按 $green Enter 回车键 $none 继续....或按 $red Ctrl + C $none 取消.")" -d $'\n'
	echo
}

# 说明
echo -e "$yellow此脚本仅兼容于Debian 10+系统. 如果你的系统不符合,请Ctrl+C退出脚本$none"
echo -e "可以去 ${cyan}https://github.com/crazypeace/V2ray_Vmess_TCP${none} 查看脚本整体思路和关键命令, 以便针对你自己的系统做出调整."
echo "----------------------------------------------------------------"
pause

# 准备工作
apt update
apt install -y bash curl sudo jq

# 设置时间
echo
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
echo "已将你的主机设置为Asia/Shanghai时区并通过systemd-timesyncd自动同步时间。"
echo

echo -e "\n主机时间：${yellow}"
timedatectl status | sed -n '1p;4p'
echo -e "${none}"

# 安装V2ray最新版本
echo -e "$yellow安装V2ray最新版本$none"
echo "----------------------------------------------------------------"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# 打开BBR
echo -e "$yellow打开BBR$none"
echo "----------------------------------------------------------------"
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
sysctl -p >/dev/null 2>&1
echo

# 是否纯IPv6小鸡, 到底
while :; do
    read -p "$(echo -e "(是否纯IPv6小鸡: [${magenta}Y$none]):") " record
    if [[ -z "$record" ]]; then
        error
    else
        if [[ "$record" == [Yy] ]]; then
            net_stack="ipv6"
            echo
            echo
            echo -e "$yellow 以下流程按纯IPv6的环境执行$none"
            echo "----------------------------------------------------------------"
            echo
            break
        else
            net_stack="ipv4"
            echo
            echo
            echo -e "$yellow 以下流程按IPv4的环境执行$none"
            echo "----------------------------------------------------------------"
            echo
            break
        fi
    fi
done

# 配置 Vmess_TCP 模式, 需要:V2ray端口, UUID
echo -e "$yellow配置 Vmess_TCP 模式$none"
echo "----------------------------------------------------------------"

# UUID
uuid=$(cat /proc/sys/kernel/random/uuid)
while :; do
    echo -e "请输入 "$yellow"V2RayID"$none" "
    read -p "$(echo -e "(默认ID: ${cyan}${uuid}$none):")" v2ray_id
    [ -z "$v2ray_id" ] && v2ray_id=$uuid
    case $(echo $v2ray_id | sed 's/[a-z0-9]\{8\}-[a-z0-9]\{4\}-[a-z0-9]\{4\}-[a-z0-9]\{4\}-[a-z0-9]\{12\}//g') in
    "")
        echo
        echo
        echo -e "$yellow V2RayID = $cyan$v2ray_id$none"
        echo "----------------------------------------------------------------"
        echo
        break
        ;;
    *)
        error
        ;;
    esac
done

# V2ray端口
random=$(shuf -i20001-65535 -n1)
while :; do
    echo -e "请输入 "$yellow"V2Ray"$none" 端口 ["$magenta"1-65535"$none"]"
    read -p "$(echo -e "(默认端口: ${cyan}${random}$none):")" v2ray_port
    [ -z "$v2ray_port" ] && v2ray_port=$random
    case $v2ray_port in
    [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-9][0-9][0-9][0-9] | [1-5][0-9][0-9][0-9][0-9] | 6[0-4][0-9][0-9][0-9] | 65[0-4][0-9][0-9] | 655[0-3][0-5])
        echo
        echo
        echo -e "$yellow V2Ray 端口 = $cyan$v2ray_port$none"
        echo "----------------------------------------------------------------"
        echo
        break
        ;;
    *)
        error
        ;;
    esac
done

# 配置 /usr/local/etc/v2ray/config.json
echo -e "$yellow配置 /usr/local/etc/v2ray/config.json$none"
echo "----------------------------------------------------------------"
cat >/usr/local/etc/v2ray/config.json <<-EOF
{    // Vmess_TCP
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $v2ray_port,             // ***
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "$v2ray_id",             // ***
                        "level": 1,
                        "alterId": 0                   // AEAD
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp"
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls"
                ]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIP"
            },
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        },
        {
            "protocol": "mtproto",
            "settings": {},
            "tag": "tg-out"
        }
    ],
    "dns": {
        "servers": [
            "https+local://8.8.8.8/dns-query",
            "8.8.8.8",
            "1.1.1.1",
            "localhost"
        ]
    },
    "routing": {
        "domainStrategy": "IPOnDemand",
        "rules": [
            {
                "type": "field",
                "ip": [
                    "0.0.0.0/8",
                    "10.0.0.0/8",
                    "100.64.0.0/10",
                    "127.0.0.0/8",
                    "169.254.0.0/16",
                    "172.16.0.0/12",
                    "192.0.0.0/24",
                    "192.0.2.0/24",
                    "192.168.0.0/16",
                    "198.18.0.0/15",
                    "198.51.100.0/24",
                    "203.0.113.0/24",
                    "::1/128",
                    "fc00::/7",
                    "fe80::/10"
                ],
                "outboundTag": "blocked"
            },
            {
                "type": "field",
                "inboundTag": ["tg-in"],
                "outboundTag": "tg-out"
            }           ,
                {
                    "type": "field",
                    "protocol": [
                        "bittorrent"
                    ],
                    "outboundTag": "blocked"
                }
        ]
    },
    "transport": {
        "kcpSettings": {
            "uplinkCapacity": 100,
            "downlinkCapacity": 100,
            "congestion": true
        }
    }
}
EOF

# 重启 V2Ray
echo -e "$yellow重启 V2Ray$none"
echo "----------------------------------------------------------------"
service v2ray restart

ip=$(curl -s https://api.myip.la)

echo
echo
echo "---------- V2Ray 配置信息 -------------"
echo
echo -e "$yellow 地址 (Address) = $cyan${ip}$none"
echo
echo -e "$yellow 端口 (Port) = $cyan$v2ray_port$none"
echo
echo -e "$yellow 用户ID (User ID / UUID) = $cyan${v2ray_id}$none"
echo
echo -e "$yellow 额外ID (Alter Id) = ${cyan}0${none}"
echo
echo -e "$yellow 传输协议 (Network) = ${cyan}tcp$none"
echo
echo -e "$yellow 伪装类型 (header type) = ${cyan}none$none"
echo

echo "---------- V2Ray Vmess URL ----------"
echo
echo -e "$cyan vmess://$(echo -n "\
{\
\"v\": \"2\",\
\"ps\": \"Vmess_TCP_${ip}\",\
\"add\": \"${ip}\",\
\"port\": \"${v2ray_port}\",\
\"id\": \"${v2ray_id}\",\
\"aid\": \"0\",\
\"net\": \"tcp\",\
\"type\": \"none\",\
\"host\": \"\",\
\"path\": \"\",\
\"tls\": \"\"\
}"\
| base64 -w 0)$none"
echo
echo "---------- END -------------"
echo
