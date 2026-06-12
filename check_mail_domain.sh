#!/bin/bash
#
# Nagios Plugin: 监控 mail.didihu.com.cn 可用性
# 用法：./check_mail_domain.sh
#
# 返回值：
#   0 - OK      域名正常
#   2 - CRITICAL 不可访问
#   3 - UNKNOWN  命令错误
#

set -o pipefail

# ==================== 参数校验 ====================
if [ -z "$1" ]; then
    echo "UNKNOWN: 缺少参数 - 用法: $0 <domain>"
    exit 3
fi

# ==================== 配置 ====================
DOMAIN="$1"
URL="https://${DOMAIN}"
TIMEOUT=10

# ==================== 依赖检查 ====================
if ! command -v curl &>/dev/null; then
    echo "UNKNOWN: curl 命令不可用"
    exit 3
fi

# ==================== 请求 ====================
OUTPUT=$(curl -s -o /dev/null -w "http_code=%{http_code}\ntime_total=%{time_total}\ntime_namelookup=%{time_namelookup}\ntime_connect=%{time_connect}\ntime_starttransfer=%{time_starttransfer}" \
    --max-time "${TIMEOUT}" \
    "${URL}" 2>&1)
CURL_EXIT=$?

# ==================== curl 连接层错误 ====================
if [ ${CURL_EXIT} -ne 0 ]; then
    case ${CURL_EXIT} in
        6)  echo "CRITICAL: DNS 解析失败 - ${DOMAIN} | status=2"; exit 2;;
        7)  echo "CRITICAL: 连接被拒绝 - ${DOMAIN} | status=2"; exit 2;;
        28) echo "CRITICAL: 请求超时 (${TIMEOUT}s) - ${DOMAIN} | status=2"; exit 2;;
        35) echo "CRITICAL: SSL/TLS 握手失败 - ${DOMAIN} | status=2"; exit 2;;
        60) echo "CRITICAL: SSL 证书无效 - ${DOMAIN} | status=2"; exit 2;;
        *)  echo "CRITICAL: curl 错误 (code=${CURL_EXIT}) - ${DOMAIN} | status=2"; exit 2;;
    esac
fi

# ==================== HTTP 状态码检查 ====================
eval "${OUTPUT}"

case "${http_code}" in
    200|301|302)
        echo "OK: ${DOMAIN} 访问正常 (HTTP ${http_code}) | http_code=${http_code}; time_total=${time_total}s; time_namelookup=${time_namelookup}s; time_connect=${time_connect}s; time_starttransfer=${time_starttransfer}s"
        exit 0
        ;;
    502)
        echo "CRITICAL: ${DOMAIN} 返回 502 Bad Gateway | http_code=${http_code}; time_total=${time_total}s"
        exit 2
        ;;
    503)
        echo "CRITICAL: ${DOMAIN} 返回 503 Service Unavailable | http_code=${http_code}; time_total=${time_total}s"
        exit 2
        ;;
    504)
        echo "CRITICAL: ${DOMAIN} 返回 504 Gateway Timeout | http_code=${http_code}; time_total=${time_total}s"
        exit 2
        ;;
    000)
        echo "CRITICAL: ${DOMAIN} 无法连接 (HTTP 000) | http_code=0; time_total=${time_total}s"
        exit 2
        ;;
    4*)
        echo "CRITICAL: ${DOMAIN} 客户端错误 (HTTP ${http_code}) | http_code=${http_code}; time_total=${time_total}s"
        exit 2
        ;;
    5*)
        echo "CRITICAL: ${DOMAIN} 服务端错误 (HTTP ${http_code}) | http_code=${http_code}; time_total=${time_total}s"
        exit 2
        ;;
    *)
        echo "CRITICAL: ${DOMAIN} 状态码异常 (HTTP ${http_code}) | http_code=${http_code}; time_total=${time_total}s"
        exit 2
        ;;
esac
