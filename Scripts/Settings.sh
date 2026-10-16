#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# Athena 属于 qualcommax/ipq60xx：优先只搜索当前目标平台，避免 find 返回多行路径
WIFI_DIR="./target/linux/qualcommax/base-files/etc/uci-defaults"
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
WIFI_FOUND=0

if [ -d "$WIFI_DIR" ]; then
	while IFS= read -r -d '' WIFI_FILE; do
		if grep -q '^BASE_SSID=' "$WIFI_FILE" && grep -q '^BASE_WORD=' "$WIFI_FILE"; then
			sed -i \
				-e "s|^BASE_SSID='.*'|BASE_SSID='$WRT_SSID'|" \
				-e "s|^BASE_WORD='.*'|BASE_WORD='$WRT_WORD'|" \
				"$WIFI_FILE"

			if ! grep -Fxq "BASE_SSID='$WRT_SSID'" "$WIFI_FILE" ||
			   ! grep -Fxq "BASE_WORD='$WRT_WORD'" "$WIFI_FILE"; then
				echo "::error::Wi-Fi defaults verification failed: $WIFI_FILE"
				exit 1
			fi
			WIFI_FOUND=1
			echo "Wi-Fi defaults updated: $WIFI_FILE"
		fi
	done < <(find "$WIFI_DIR" -type f -name '*set-wireless.sh' -print0)
fi

if [ "$WIFI_FOUND" -eq 0 ] && [ -f "$WIFI_UC" ]; then
	if grep -q "^ssid=" "$WIFI_UC" && grep -q "^key=" "$WIFI_UC"; then
		sed -i \
			-e "s|^ssid='.*'|ssid='$WRT_SSID'|" \
			-e "s|^key='.*'|key='$WRT_WORD'|" \
			"$WIFI_UC"

		if ! grep -Fxq "ssid='$WRT_SSID'" "$WIFI_UC" ||
		   ! grep -Fxq "key='$WRT_WORD'" "$WIFI_UC"; then
			echo "::error::Wi-Fi config verification failed: $WIFI_UC"
			exit 1
		fi
		WIFI_FOUND=1
	fi
fi

if [ "$WIFI_FOUND" -eq 0 ]; then
	echo "::error::No supported Wi-Fi defaults found for qualcommax target"
	exit 1
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
if [ ! -f "$CFG_FILE" ]; then
	echo "::error::Missing config_generate: $CFG_FILE"
	exit 1
fi

# 仅替换 LAN 默认地址表达式，不再全文件替换所有 192.168.x.x 字符串
if ! grep -Fq 'lan) ipad=${ipaddr:-"192.168.1.1"}' "$CFG_FILE"; then
	echo "::error::Expected LAN default IP expression not found in $CFG_FILE"
	exit 1
fi
sed -i "s|lan) ipad=\${ipaddr:-\"192.168.1.1\"}|lan) ipad=\${ipaddr:-\"$WRT_IP\"}|" "$CFG_FILE"

if ! grep -Fq 'lan) ipad=${ipaddr:-"'"$WRT_IP"'"}' "$CFG_FILE"; then
	echo "::error::LAN default IP verification failed in $CFG_FILE"
	exit 1
fi

# 修改默认主机名前先确认目标文件中存在预期配置
if ! grep -q "^\s*option hostname" "$CFG_FILE" && ! grep -q "hostname='" "$CFG_FILE"; then
	echo "::error::Expected hostname setting not found in $CFG_FILE"
	exit 1
fi
sed -i "s|hostname='.*'|hostname='$WRT_NAME'|g" "$CFG_FILE"
if ! grep -Fq "hostname='$WRT_NAME'" "$CFG_FILE"; then
	echo "::error::Hostname verification failed in $CFG_FILE"
	exit 1
fi

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
