# YDN-Openwrt

基于 [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt) 的京东云雅典娜（JDCloud RE-CS-02 / IPQ60xx）定制固件自动构建。

## 目录简要说明

- `.github/workflows` — CI 配置
  - `QCA-ALL.yml`：触发入口（定时 / 手动），定义机型矩阵参数
  - `WRT-CORE.yml`：可复用构建流程（编译、打包、发布、缓存维护）
  - `LINT.yml`：静态检查（actionlint 校验 workflow、shellcheck 校验脚本）
- `Config` — 配置
  - `GENERAL.txt`：所有机型共用的通用配置
  - `<机型>.txt`：机型专属配置（如 `IPQ60XX-WIFI-YES.txt`）
  - `PRIVATE.txt`（可选，已在 .gitignore，不提交）：私有扩展配置，追加到 `.config`
- `Scripts` — 构建脚本
  - `Packages.sh`：插件源替换与版本更新
  - `Settings.sh`：固件默认值修改（SSID / Wi-Fi 密码 / 登录 IP / 主机名等）
  - `Handles.sh`：编译兼容修复（rust、miniupnpd 等）
  - `PRIVATE.sh`（可选，已在 .gitignore，不提交）：私有扩展脚本，被 `Packages.sh` 引入

## 构建方式

Actions 页面选择 `QCA-ALL`：

- 定时构建：每周一 03:00 UTC（北京时间 11:00）
- 手动构建（workflow_dispatch）：
  - `PACKAGE`：临时调整插件配置（直接追加进 `.config` 的 kconfig 片段，多个用换行分隔）
  - `TEST`：仅生成并发布配置文件（含 `make defconfig` 归一化差异），不编译固件

## 配置命名约定

- 机型配置文件名须包含 `WIFI-YES` 或 `WIFI-NO`：
  - `WIFI-NO`：DTS 切换到 `*-nowifi.dtsi`（Q6 内存重新分配），固件文件名标记为 `wifi-no`
- 文件名含 `test` 的配置：只使用该文件，不追加以 `GENERAL.txt`
- `make defconfig` 后会对关键目标/插件做回归检查（见 `WRT-CORE.yml` 中 `REQUIRED_OPTIONS`），插件被静默丢弃或改名的配置漂移会直接让构建失败，而不是悄悄少装插件

## 构建缓存

- 缓存键：`wrt-<源码>-<分支>-<目标平台>-<源码提交>`，恢复时按前缀取最新一代，覆盖
  `dl`、`feeds`、`.ccache`、`staging_dir/host*`、`staging_dir/tool*`
- 每次构建成功后，`housekeeping` 任务滚动删除旧一代缓存，并只保留最近 3 个 Release
