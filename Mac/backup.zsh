# ========== Backup V1.5 by Zhonghui ==========
#
# 更新日期：2026/06/28
# 运行平台：Only on MacOS
#
# ！！！注意！！！
# 恢复/备份前一定要彻底退出Chrome、codex等
#
# 功能描述：
# 将需要备份的文件内容压缩打包
# 包内包含备份的数据和一个解压并恢复数据到原始位置的脚本
# 执行此恢复脚本即可读取备份数据并进行恢复
# 恢复的时候对文件夹必须使用替换模式（而非合并模式）
# 无论恢复脚本从哪个路径开始执行都应该可以恢复成功
# 备份时：路径不存在则直接跳过
# 恢复时：路径不存在则需要自动完成创建
#
# 重点备份列表：
# "$HOME/Library/Keychains/"
# "$HOME/Library/Application Support/Google/Chrome/Local State"
# "$HOME/Library/Application Support/Google/Chrome/Default/Cookies"
# "$HOME/Library/Application Support/Google/Chrome/Default/Local Storage/"
# "$HOME/.ssh/"
# "$HOME/.claude.json"
# "$HOME/.config/rclone/rclone.conf"
# "$HOME/.codex/auth.json"
# 其他备份列表：
# ...
#
# 输出格式：
# ~/Desktop/<username>_<date>_<time>.zip
#
# 包内内容：
# /unzip_<version>.zsh
# /Data.zip
#
# 执行方式：
# zsh <script_name>.zsh
#
# 代码作者：Claude Opus 4.8
#
# =============================================

#!/usr/bin/env zsh

set -u
set -o pipefail

# ---------- 版本号（用于标识备份包由哪个版本生成）----------
VERSION="1.5"

# ---------- 备份列表（相对 $HOME 的路径；以 / 结尾表示文件夹）----------
BACKUP_ITEMS=(
    "Library/Keychains/"
    "Library/Application Support/Google/Chrome/Local State"
    "Library/Application Support/Google/Chrome/Default/Cookies"
    "Library/Application Support/Google/Chrome/Default/Local Storage/"
    ".ssh/"
    ".claude.json"
    ".config/rclone/rclone.conf"
    ".codex/auth.json"
)

# ---------- 基本信息 ----------
USERNAME="$(whoami)"
DATE_STR="$(date +%Y%m%d)"
TIME_STR="$(date +%H%M%S)"
OUT="$HOME/Desktop/${USERNAME}_${DATE_STR}_${TIME_STR}.zip"

# 恢复脚本文件名（带版本号，方便判断是哪个版本生成的）
UNZIP_NAME="unzip_v${VERSION}.zsh"

# 临时工作目录
WORK="$(mktemp -d)" || { echo "无法创建临时目录" >&2; exit 1 }
STAGE="$WORK/stage"      # 收集备份数据
PKG="$WORK/pkg"          # 最终打包内容（unzip.zsh + Data.zip）
mkdir -p "$STAGE" "$PKG"

# 退出时清理临时目录
trap 'rm -rf "$WORK"' EXIT

# ---------- 收集数据 ----------
echo "==> 正在收集备份数据 ..."
for item in "${BACKUP_ITEMS[@]}"; do
    rel="${item%/}"            # 去掉末尾的 /
    src="$HOME/$rel"

    # 路径不存在则直接跳过
    if [[ ! -e "$src" ]]; then
        echo "    [跳过] 路径不存在：$rel"
        continue
    fi

    # ditto 会自动创建中间目录，并完整保留权限/ACL/扩展属性
    ditto "$src" "$STAGE/$rel"
    echo "    [备份] $rel"
done

# ---------- 压缩数据为 Data.zip ----------
# 用 ditto 打包：标准 zip 格式，且通过 AppleDouble 保留 ACL/扩展属性
echo "==> 正在压缩数据 ..."
ditto -c -k --sequesterRsrc "$STAGE" "$PKG/Data.zip"

# ---------- 生成恢复脚本 unzip.zsh ----------
echo "==> 正在生成恢复脚本 ..."
{
    echo '#!/usr/bin/env zsh'
    echo
    echo "# 本脚本由 Backup V${VERSION} 自动生成，用于恢复备份数据"
    echo '# 代码作者：Claude Opus 4.8'
    echo
    echo 'set -u'
    echo 'set -o pipefail'
    echo
    # 写入备份列表（与备份时保持一致）
    echo 'BACKUP_ITEMS=('
    for item in "${BACKUP_ITEMS[@]}"; do
        printf '    "%s"\n' "$item"
    done
    echo ')'
    echo
    # 恢复逻辑（使用单引号 heredoc，保证变量在恢复时才展开）
    cat <<'RESTORE_EOF'
# 脚本所在目录（绝对路径）
SCRIPT_DIR="${0:A:h}"

if [[ ! -f "$SCRIPT_DIR/Data.zip" ]]; then
    echo "找不到 Data.zip，恢复中止" >&2
    exit 1
fi

# 解压到临时目录
TMP="$(mktemp -d)" || { echo "无法创建临时目录" >&2; exit 1 }
trap 'rm -rf "$TMP"' EXIT

echo "==> 正在解压备份数据 ..."
ditto -x -k "$SCRIPT_DIR/Data.zip" "$TMP"

echo "==> 正在恢复数据到原始位置 ..."
for item in "${BACKUP_ITEMS[@]}"; do
    rel="${item%/}"
    extracted="$TMP/$rel"
    target="$HOME/$rel"

    # 备份中不包含该项（备份时被跳过），恢复时也跳过
    if [[ ! -e "$extracted" ]]; then
        echo "    [跳过] 备份中无此项：$rel"
        continue
    fi

    # 替换模式：先删除已存在的目标（文件夹/文件都适用），
    # 再由 ditto 在干净位置重建，确保权限/ACL/扩展属性与原始完全一致
    # （若不先删除，ditto 覆盖已存在文件时不会重置其权限位）
    rm -rf "$target"
    # ditto 会自动创建中间目录（路径不存在则自动创建），
    # 并完整保留权限/ACL/扩展属性
    ditto "$extracted" "$target"
    echo "    [恢复] $rel"
done

echo "==> 恢复完成"
RESTORE_EOF
} > "$PKG/$UNZIP_NAME"

chmod +x "$PKG/$UNZIP_NAME"

# ---------- 打包为最终输出 ----------
# 外层只是把恢复脚本和 Data.zip 打成一个包，用 ditto 保持工具统一
echo "==> 正在生成备份包 ..."
rm -f "$OUT"
ditto -c -k "$PKG" "$OUT"

OUT_SIZE="$(du -h "$OUT" | cut -f1)"
echo "==> 备份完成：$OUT"
echo "==> 文件大小：$OUT_SIZE"