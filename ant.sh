#!/system/bin/sh

# --- 1. 自动提权 ---
if [ "$(id -u)" != "0" ]; then
    echo "正在请求 Root 权限..."
    exec su -c "sh \"$0\""
    exit $?
fi

# --- 2. 变量定义 ---
URL="https://download-cdn.niulinkcloud.com/init/android_up"
BIN_NAME="android_up"
TARGET_DIR="/data/.ant"
TARGET_PATH="$TARGET_DIR/$BIN_NAME"
DOWNLOAD_DIR="/storage/emulated/0/Download/Browser"

echo "=== 状态: Root 已确认 ==="

# --- 3. 文件存在性判断与部署 ---
if [ -f "$TARGET_PATH" ]; then
    echo "[!] 发现现有二进制文件，跳过下载步骤。"
    # 重新赋予执行权限，防止权限丢失
    chmod 777 "$TARGET_PATH"
else
    echo "[1/2] 目标文件不存在，准备下载..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR" || exit 1
    
    # 清理旧残留并下载
    rm -f "./$BIN_NAME"
    if ! curl -Lk -o "./$BIN_NAME" "$URL"; then
        wget --no-check-certificate -O "./$BIN_NAME" "$URL"
    fi

    if [ ! -f "./$BIN_NAME" ]; then
        echo "错误: 下载失败，请检查网络。"
        exit 1
    fi

    echo "[2/2] 正在迁移至系统目录 $TARGET_DIR ..."
    mkdir -p "$TARGET_DIR"
    # 尝试重新挂载以确保写入权限
    mount -o remount,rw /data >/dev/null 2>&1
    
    # 写入文件并授权
    cat "./$BIN_NAME" > "$TARGET_PATH"
    chmod 777 "$TARGET_PATH"
    
    # 清理下载目录中的临时文件
    rm -f "./$BIN_NAME"
    echo "[*] 部署成功。"
fi

# --- 4. 进程刷新 ---
echo "[*] 正在刷新旧进程..."
pkill -f "$BIN_NAME" >/dev/null 2>&1
sleep 1

# --- 5. 启动后台保活逻辑 (60秒间隔) ---
echo "[*] 开启后台守护进程，检查间隔: 60s"

(
    while true
    do
        # 检查进程是否在运行
        if ! pidof "$BIN_NAME" >/dev/null; then
            # 启动进程并使用 disown 脱离 shell 关联
            nohup "$TARGET_PATH" --channel ant --uid 89154 >/dev/null 2>&1 &
            if command -v disown >/dev/null; then
                disown
            fi
        fi
        sleep 60
    done
) &

echo "=== 全部操作已完成 ==="