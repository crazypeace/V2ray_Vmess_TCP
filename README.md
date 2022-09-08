# 2022-9-8
临时地，本脚本指定安装V2ray v4.45.2 (v5之前的最后一个v4)

相关信息 
v2fly/fhs-install-v2ray#243

# 说明
V2ray最新版本，Vmess_TCP模式

# 一键执行
```
apt update
apt install -y curl
```
```
bash <(curl -L https://github.com/crazypeace/V2ray_Vmess_TCP/raw/main/install.sh)
```

脚本中很大部分都是在校验用户的输入。其实照着下面的内容自己配置就行了。

# 设置时间
```
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
```

# 打开BBR
```
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.conf
echo "net.core.default_qdisc = fq" >>/etc/sysctl.conf
sysctl -p >/dev/null 2>&1
```

# 安装V2ray最新版本
```
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
```

# 配置 /usr/local/etc/v2ray/config.json
```
{    // Vmess_TCP
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 你的v2ray端口,             // ***改这里
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "你的v2rayID",             // ***改这里
                        "level": 1,
                        "alterId": 0                     // AEAD
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
```

# 如果是 IPv6 only 的小鸡，用 WARP 添加 IPv4 能力
```
bash <(curl -fsSL git.io/warp.sh) 4
```

# Uninstall
```
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh) --remove
```

# 后记
对于喜欢V2rayN PAC模式的朋友，实测客户端可以用 V2rayN v3.29 + V2ray-core V4.44.0

# 带参数执行
如果你已经很熟悉了, 安装过程中的参数都确认没问题. 可以带参数使用本脚本, 跳过脚本中的各种校验.
```
bash <(curl -L https://github.com/crazypeace/V2ray_Vmess_TCP/raw/main/install.sh) <uuid> [port]
```
其中

`uuid`      你的UUID

`port`      v2ray监听的端口, 如果为空会随机生成


例如
```
bash <(curl -L https://github.com/crazypeace/V2ray_Vmess_TCP/raw/main/install.sh) 6be678e3-8dc7-4ac1-a4de-c8bf9e3a6854
bash <(curl -L https://github.com/crazypeace/V2ray_Vmess_TCP/raw/main/install.sh) 6be678e3-8dc7-4ac1-a4de-c8bf9e3a6854 9527
```
你如果两个参数都想随机生成，你可以
```
bash <(curl -L https://github.com/crazypeace/V2ray_Vmess_TCP/raw/main/install.sh) $(cat /proc/sys/kernel/random/uuid)
```

## 用你的STAR告诉我这个Repo对你有用 Welcome STARs! :)

[![Stargazers over time](https://starchart.cc/crazypeace/V2ray_Vmess_TCP.svg)](https://starchart.cc/crazypeace/V2ray_Vmess_TCP)