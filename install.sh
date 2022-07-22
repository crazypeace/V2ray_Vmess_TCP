# 等待1秒, 避免curl下载脚本的打印与脚本本身的显示冲突, 吃掉了提示用户按回车继续的信息
sleep 1

echo -e "                     _ ___                   \n ___ ___ __ __ ___ _| |  _|___ __ __   _ ___ \n|-_ |_  |  |  |-_ | _ |   |- _|  |  |_| |_  |\n|___|___|  _  |___|___|_|_|___|  _  |___|___|\n        |_____|               |_____|        "
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
echo -e "有问题加群 ${cyan}https://t.me/+D8aqonnCR3s1NTRl${none}"
echo "----------------------------------------------------------------"

# 执行脚本带参数
if [ $# -ge 1 ]; then
    v2ray_id=${1}
    v2ray_port=${2}
    if [[ -z $v2ray_port ]]; then
        v2ray_port=$(shuf -i20001-65535 -n1)
    fi

    echo -e "v2ray_id: ${v2ray_id}"
    echo -e "v2ray_port: ${v2ray_port}"
fi

pause

# 准备工作
apt update
apt install -y curl sudo jq qrencode

# 设置时间
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true

# 输出当前时间
echo 
echo -e "${yellow}当前系统时间-UTC${none}"
date -u

# 换算为上海时区
echo -e "${yellow}当前系统时间-上海时区${none}"
TZ=Asia/Shanghai date -d @`date +%s` "+%Y-%m-%d %H:%M:%S";

# 安装V2ray最新版本
echo
echo -e "$yellow安装V2ray最新版本$none"
echo "----------------------------------------------------------------"
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

systemctl enable v2ray

# 打开BBR
echo
echo -e "$yellow打开BBR$none"
echo "----------------------------------------------------------------"
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
sysctl -p >/dev/null 2>&1
echo

# 配置 Vmess_TCP 模式, 需要:V2ray端口, UUID
echo
echo -e "$yellow配置 Vmess_TCP 模式$none"
echo "----------------------------------------------------------------"

# UUID
if [[ -z $v2ray_id ]]; then
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
fi

# V2ray端口
if [[ -z $v2ray_port ]]; then
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
fi

# 配置 /usr/local/etc/v2ray/config.json
echo
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
        }
    ],
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
                "protocol": [
                    "bittorrent"
                ],
                "outboundTag": "blocked"
            }
        ]
    }
}
EOF

# 重启 V2Ray
echo
echo -e "$yellow重启 V2Ray$none"
echo "----------------------------------------------------------------"
service v2ray restart

# IPv4
ipv4=$(curl -4 -s https://api.myip.la)
if [[ -n $ipv4 ]]; then
    echo
    echo
    echo "---------- V2Ray 配置信息 -------------"
    echo
    echo -e "$yellow 地址 (Address) = $cyan${ipv4}$none"
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
    v2ray_vmess_url_v4="vmess://$(echo -n "\
{\
\"v\": \"2\",\
\"ps\": \"Vmess_TCP_${ipv4}\",\
\"add\": \"${ipv4}\",\
\"port\": \"${v2ray_port}\",\
\"id\": \"${v2ray_id}\",\
\"aid\": \"0\",\
\"net\": \"tcp\",\
\"type\": \"none\",\
\"host\": \"\",\
\"path\": \"\",\
\"tls\": \"\"\
}"\
    | base64 -w 0)"

    echo -e "${cyan}${v2ray_vmess_url_v4}${none}"
    echo "以下两个二维码完全一样的内容"
    qrencode -t ANSI $v2ray_vmess_url_v4
    qrencode -t UTF8 $v2ray_vmess_url_v4
    echo
    echo $v2ray_vmess_url_v4 > ~/_v2ray_vmess_url_v4_
    echo "以下两个二维码完全一样的内容" >> ~/_v2ray_vmess_url_v4_
    qrencode -t ANSI $v2ray_vmess_url_v4 >> ~/_v2ray_vmess_url_v4_
    qrencode -t UTF8 $v2ray_vmess_url_v4 >> ~/_v2ray_vmess_url_v4_
fi

# IPv6
ipv6=$(curl -6 -s https://api.myip.la)
if [[ -n $ipv6 ]]; then
    echo
    echo
    echo "---------- V2Ray 配置信息 -------------"
    echo
    echo -e "$yellow 地址 (Address) = $cyan${ipv6}$none"
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
    v2ray_vmess_url_v6="vmess://$(echo -n "\
{\
\"v\": \"2\",\
\"ps\": \"Vmess_TCP_${ipv6}\",\
\"add\": \"${ipv6}\",\
\"port\": \"${v2ray_port}\",\
\"id\": \"${v2ray_id}\",\
\"aid\": \"0\",\
\"net\": \"tcp\",\
\"type\": \"none\",\
\"host\": \"\",\
\"path\": \"\",\
\"tls\": \"\"\
}"\
    | base64 -w 0)"

    echo -e "${cyan}${v2ray_vmess_url_v6}${none}"
    echo "以下两个二维码完全一样的内容"
    qrencode -t ANSI $v2ray_vmess_url_v6
    qrencode -t UTF8 $v2ray_vmess_url_v6
    echo
    echo $v2ray_vmess_url_v6 > ~/_v2ray_vmess_url_v6_
    echo "以下两个二维码完全一样的内容" >> ~/_v2ray_vmess_url_v6_
    qrencode -t ANSI $v2ray_vmess_url_v6 >> ~/_v2ray_vmess_url_v6_
    qrencode -t UTF8 $v2ray_vmess_url_v6 >> ~/_v2ray_vmess_url_v6_
fi

echo
echo "---------- END -------------"
echo
