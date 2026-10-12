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
