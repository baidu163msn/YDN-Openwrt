#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#本脚本由 workflow 在 wrt/package 目录下调用，feeds 位于 ../feeds
#（修复：原 $FEEDS_PACKAGES 从未定义，find 在空路径上运行，下面的补丁从未生效）
FEEDS_PACKAGES="../feeds/packages"

#修复Rust编译失败
RUST_FILE="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	echo " "

	if sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"; then
		echo "rust has been fixed!"
	else
		echo "rust fix failed; continuing!"
	fi
fi

#修复 miniupnpd 编译失败
#miniupnpd 2.3.11 源码已内建 upnppermissions 解析器重写等改动，openwrt 官方对 2.3.11 已不再携带任何补丁。
#但上游 feeds 仍残留旧补丁（020-descr-filter-fix 等），会对已修复的源码重复打补丁，
#导致 prepare 阶段 "Hunk FAILED / Patch failed" 而终止编译。这里移除过时补丁，按上游原生 2.3.11 编译。
MINIUPNPD_PATCHES="$FEEDS_PACKAGES/net/miniupnpd/patches"
if [ -d "$MINIUPNPD_PATCHES" ]; then
	echo " "

	if rm -rf "$MINIUPNPD_PATCHES"; then
		echo "miniupnpd obsolete patches removed!"
	else
		echo "miniupnpd patch cleanup failed; continuing!"
	fi
fi
