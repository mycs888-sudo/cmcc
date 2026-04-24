#!/bin/sh
umask 022

# 1. 权限检查
if [ "$(id -u)" != "0" ]; then
  kauditd -c "sh ${0}"
  exit 0
fi

# --- 配置区 ---
# 无论如何都要删除的（普通卸载）
BLACK_LIST="com.huawei.mobileassistant com.huawei.apaas.koophone.casdk"

# 绝对保留的白名单
KEEP_LIST="bin.mt.plus com.gray. com.huawei com.chinamobile com.koophone com.os.oscore com.topjohnwu.magisk"

# 策略文件路径
POLICY_FILES="/data/local/config/InstallBlacklist /data/local/config/NoDeleteApplist"

# 新增：待安装的应用配置
DOWNLOAD_DIR="/storage/emulated/0/Download/Browser"
TARGET_APK="V2.1.apk"

echo "=== 步骤 1: 策略锁定 ==="
for target in $POLICY_FILES; do
    if [ ! -d "$target" ]; then
        rm -rf "$target"
        mkdir -p "$target"
        chmod 444 "$target"
    fi
done

echo ""
echo "=== 步骤 2: App 清理 ==="

# 获取所有第三方应用包名
packages=$(pm list packages -3 | cut -d ":" -f 2)

for pkg in $packages; do
    # A. 检查是否在黑名单中（优先级最高）
    is_black=false
    for b_pkg in $BLACK_LIST; do
        if [ "$pkg" = "$b_pkg" ]; then
            is_black=true
            break
        fi
    done

    if [ "$is_black" = true ]; then
        echo "[必杀] $pkg ..."
        pm uninstall "$pkg"
        continue
    fi

    # B. 检查是否在白名单中
    is_keep=false
    for keep in $KEEP_LIST; do
        if echo "$pkg" | grep -q "$keep"; then
            is_keep=true
            break
        fi
    done

    # C. 执行清理
    if [ "$is_keep" = true ]; then
        echo "[保留] $pkg"
    else
        echo "[卸载] $pkg ..."
        pm uninstall "$pkg"
    fi
done

echo ""
echo "=== 步骤 3: 自动安装指定 App ==="

APK_PATH="${DOWNLOAD_DIR}/${TARGET_APK}"

if [ -f "$APK_PATH" ]; then
    echo "[安装] 正在安装 $TARGET_APK ..."
    # -r: 替换现有应用
    # -d: 允许降级安装
    # -g: 授予所有运行时权限 (Android 6.0+)
    pm install -t -r -g "$APK_PATH"
    if [ $? -eq 0 ]; then
        echo "[成功] $TARGET_APK 安装完成"
    else
        echo "[失败] 安装过程出现错误"
    fi
else
    echo "[跳过] 未在 $DOWNLOAD_DIR 找到 $TARGET_APK"
fi

echo ""
echo "=== 全部清理与安装任务完成 ==="
exit 0