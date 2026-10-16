#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 先克隆并验证上游仓库；失败时不删除现有软件包
	if ! git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"; then
		echo "::error::Failed to clone $PKG_REPO branch $PKG_BRANCH"
		return 1
	fi
	if ! git -C "$REPO_NAME" rev-parse --verify HEAD >/dev/null 2>&1; then
		echo "::error::Cloned repository is invalid: $REPO_NAME"
		return 1
	fi

	# pkg 模式先确认上游存在可提取的包目录，避免验证失败后删除旧包
	local PKG_DIRS=()
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		mapfile -d '' PKG_DIRS < <(
			find "./$REPO_NAME" -mindepth 1 -maxdepth 5 -type d \
				\( -iname "$PKG_NAME" -o -iname "*-$PKG_NAME" \) \
				-exec test -f "{}/Makefile" \; -print0
		)
		if [ "${#PKG_DIRS[@]}" -eq 0 ]; then
			echo "::error::No package directory with Makefile found for $PKG_NAME in $PKG_REPO"
			return 1
		fi
	fi

	# 只删除目录名与包名/显式别名完全匹配的目录，避免模糊匹配误删
	for NAME in "${PKG_LIST[@]}"; do
		[ -n "$NAME" ] || continue
		echo "Search exact package directory: $NAME"
		while IFS= read -r -d '' DIR; do
			echo "Delete directory: $DIR"
			rm -rf -- "$DIR" || {
				echo "::error::Failed to remove package directory: $DIR"
				return 1
			}
		done < <(
			find ../feeds/luci/ ../feeds/packages/ -mindepth 1 -maxdepth 3 \
				-type d \( -iname "$NAME" -o -iname "*-$NAME" \) -print0 2>/dev/null
		)
	done
	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		for DIR in "${PKG_DIRS[@]}"; do
			cp -rf -- "$DIR" ./ || {
				echo "::error::Failed to copy package directory: $DIR"
				return 1
			}
		done
		rm -rf -- "./$REPO_NAME"
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		if ! mv -f -- "$REPO_NAME" "$PKG_NAME"; then
			echo "::error::Failed to rename $REPO_NAME to $PKG_NAME"
			return 1
		fi
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
# 只保留 Config/GENERAL.txt 实际用到的包源；其余（aurora/kucat/noobwrt/shadcn/fluent 等主题，
# momo/nikki/passwall/passwall2/ddns-go/diskman/easytier/mosdns/qbittorrent/vnt 等插件，
# 以及其它机型的 fancontrol/netmode 系列）已移除以缩短构建，
# 历史完整列表见本文件的 git 记录；临时增补请写到 Scripts/PRIVATE.sh，无需改本文件。
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12" || exit $?
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg" || exit $?
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "axonhub gecoosac sing-box luci-app-homeproxy luci-app-timewol luci-app-wolplus luci-app-wolultra" || exit $?

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
