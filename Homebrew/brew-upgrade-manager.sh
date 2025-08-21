#!/usr/bin/env bash
# Homebrew 智能升级脚本

# ================== 脚本环境设置 ==================

# set -e：当命令返回非零退出状态（表示失败）时，脚本会立即退出。
# 这有助于防止错误蔓延，确保脚本的稳定性。
set -e
# set -o pipefail：在管道命令（例如 command1 | command2）中，
# 如果管道中的任何一个命令失败，整个管道的退出状态码将是失败命令的退出状态码。
# 这确保了管道中的中间错误也能被捕获并导致脚本退出。
set -o pipefail

# 检查核心依赖 jq
# jq 是一个轻量级且灵活的命令行 JSON 处理器，本脚本使用它来解析 Homebrew 的 JSON 输出。
if ! command -v jq &> /dev/null; then
    # 如果 jq 命令不存在，则打印错误信息并退出。
    echo "Error: 'jq' dependency not found. Please install with: brew install jq"
    exit 1
fi

# --- 颜色定义 (自动检测终端是否支持) ---
# [ -t 1 ] 检查标准输出（文件描述符 1）是否连接到终端。
# 如果是终端，则启用彩色输出；否则，将颜色变量定义为空字符串，禁用颜色。
if [ -t 1 ]; then
    # 当标准输出是终端时，启用颜色
    GREEN='\033[1;32m'  # 定义绿色（加粗）ANSI 转义码
    YELLOW='\033[1;33m' # 定义黄色（加粗）ANSI 转义码
    BLUE='\033[1;34m'   # 定义蓝色（加粗）ANSI 转义码
    NC='\033[0m'        # 定义无颜色（重置）ANSI 转义码
else
    # 否则，定义为空，禁用颜色
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# --- 终端宽度和打印函数 ---
# 默认回退宽度，用于所有动态检测失败时。
DEFAULT_FALLBACK_WIDTH="130"
TERMINAL_WIDTH_OVERRIDE="" # 用于存储通过 --width 参数传入的宽度值
WIDTH_SOURCE=""            # 记录宽度值的来源描述

# 解析命令行参数
# 使用 while 循环配合 shift 来安全地处理命令行参数，避免 for 循环中 shift 的潜在问题。
while [[ $# -gt 0 ]]; do
    case "$1" in
        --width)
            # 处理 --width <value> 的形式
            if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                TERMINAL_WIDTH_OVERRIDE="$2"
                shift # 移除 --width
                shift # 移除宽度值
            else
                echo -e "${YELLOW}Error: '--width' parameter requires a valid numeric value.${NC}"
                exit 1
            fi
            ;;
        --width=*)
            # 处理 --width=<value> 的形式
            TERMINAL_WIDTH_OVERRIDE="${1#*=}" # 从参数中提取值（去掉 '--width=' 部分）
            if ! [[ "$TERMINAL_WIDTH_OVERRIDE" =~ ^[0-9]+$ ]]; then
                echo -e "${YELLOW}Error: '--width' parameter requires a valid numeric value.${NC}"
                exit 1
            fi
            shift # 移除整个参数（例如 --width=130）
            ;;
        *)
            # 遇到其他未知的参数时，直接移除它们以防止它们干扰后续逻辑。
            # 如果需要处理其他参数，可以在这里添加相应的 case 分支。
            shift
            ;;
    esac
done

# 确定最终的 TERMINAL_WIDTH
# 优先级：命令行参数 (--width) > 环境变量 (HB_TERMINAL_WIDTH) > stty size > tput cols > 默认回退值
if [[ -n "$TERMINAL_WIDTH_OVERRIDE" ]]; then
    TERMINAL_WIDTH="$TERMINAL_WIDTH_OVERRIDE"
    WIDTH_SOURCE="通过命令行参数"
elif [[ -n "$HB_TERMINAL_WIDTH" && "$HB_TERMINAL_WIDTH" =~ ^[0-9]+$ ]]; then
    TERMINAL_WIDTH="$HB_TERMINAL_WIDTH"
    WIDTH_SOURCE="通过环境变量 HB_TERMINAL_WIDTH"
elif command -v stty &>/dev/null && stty size &>/dev/null; then
    # 尝试使用 stty size 获取宽度
    TERMINAL_WIDTH=$(stty size 2>/dev/null | awk '{print $2}')
    if [[ -n "$TERMINAL_WIDTH" && "$TERMINAL_WIDTH" =~ ^[0-9]+$ && "$TERMINAL_WIDTH" -gt 0 ]]; then
        WIDTH_SOURCE="通过 stty size"
    else
        # stty size 获取失败，回退到 tput cols
        TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo "$DEFAULT_FALLBACK_WIDTH")
        if (( TERMINAL_WIDTH == DEFAULT_FALLBACK_WIDTH )) && ! tput cols &>/dev/null; then
            WIDTH_SOURCE="通过 tput cols (回退到默认值 130)"
        else
            WIDTH_SOURCE="通过 tput cols"
        fi
    fi
else
    # stty size 不可用或失败，直接尝试 tput cols
    TERMINAL_WIDTH=$(tput cols 2>/dev/null || echo "$DEFAULT_FALLBACK_WIDTH")
    if (( TERMINAL_WIDTH == DEFAULT_FALLBACK_WIDTH )) && ! tput cols &>/dev/null; then
        WIDTH_SOURCE="通过 tput cols (回退到默认值 130)"
    else
        WIDTH_SOURCE="通过 tput cols"
    fi
fi

# 移除了显示终端宽度的 echo 语句，避免冗余输出。
# echo -e "${BLUE}脚本检测到的终端宽度为: ${TERMINAL_WIDTH} 列 (${WIDTH_SOURCE})${NC}\n"

# separator 函数：打印一个与终端宽度等长的分隔线。
separator() { printf '=%.0s' $(seq 1 "$TERMINAL_WIDTH"); printf "\n"; }
# print_header 函数：使用蓝色打印步骤标题，并添加换行。
print_header() { echo -e "${BLUE}$1${NC}"; }
# print_version 函数：以“名称 : 版本”的格式打印包的版本信息，左对齐。
print_version() { printf "%-35s : %s\n" "$1" "$2"; }
# print_version_diff 函数：打印版本对比信息，并使用颜色区分变化。
print_version_diff() {
    if [[ "$2" == "$3" ]]; then
        # 如果升级前后的版本相同，显示“无变化”。
        printf "%-35s : %s (无变化)\n" "$1" "$2"
    elif [[ "$3" == "(已移除)" ]]; then
        # 如果升级后包被移除，显示黄色“已移除”提示。
        printf "%-35s : ${YELLOW}%s${NC} → (已移除)\n" "$1" "$2"
    else
        # 如果有版本升级，使用颜色对比。
        printf "%-35s : ${YELLOW}%-25s${NC} → ${GREEN}%s${NC}\n" "$1" "$2" "$3"
    fi
}

# --- 临时文件与清理 ---
# mktemp 命令：创建唯一的临时文件。这些文件用于存储 Homebrew 命令的 JSON 输出和升级日志。
TMP_JSON_BEFORE=$(mktemp) # 存储升级前 Homebrew 包信息的临时 JSON 文件
TMP_JSON_AFTER=$(mktemp)  # 存储升级后 Homebrew 包信息的临时 JSON 文件
TMP_UPGRADE_LOG=$(mktemp) # 存储升级日志的临时文件
# cleanup 函数：删除所有创建的临时文件。
cleanup() { rm -f "$TMP_JSON_BEFORE" "$TMP_JSON_AFTER" "$TMP_UPGRADE_LOG"; }
# trap cleanup EXIT：设置一个陷阱，确保在脚本退出（无论是正常退出还是因错误退出）时，
# 都会调用 cleanup 函数来删除临时文件。这保证了临时文件不会残留在系统中。
trap cleanup EXIT

# ================== 流程开始 ==================
printf "\n"
separator # 打印分隔线
print_header "第 1 步：更新 Homebrew 仓库"
# brew update：更新 Homebrew 及其所有 tap（第三方仓库）。
# 这会获取最新的包定义和版本信息，是升级前的必要步骤。
brew update
separator
printf "\n"

# ================== 第 2 步：健康检查 (brew doctor) ==================
separator
print_header "第 2 步：健康检查 (brew doctor)"
# brew doctor 命令会诊断 Homebrew 环境中可能存在的问题。
# 2>&1 将标准错误重定向到标准输出，以便错误信息也能被捕获。
# if ! ...; then 检查 brew doctor 的退出状态，如果是非零（表示有警告或错误）则进入。
if ! brew doctor; then
    echo -e "${YELLOW}Warning: 'brew doctor' detected issues. Manual review and resolution are recommended.${NC}"
    # 您可以选择在此处添加用户确认，例如：
    # read -p "是否继续升级？(y/N) " -n 1 -r REPLY
    # echo # 换行
    # if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    #     echo "已取消升级。"
    #     exit 1
    # fi
else
    echo "Homebrew environment is in good health."
fi
separator
printf "\n"

# ================== 第 3 步：获取升级前所有包的状态 ==================
separator # 添加分隔线，确保与前一步骤一致
print_header "第 3 步：扫描所有已安装的 Formulae 和 Casks..."
# brew info --json=v2 --installed：获取所有已安装的 Homebrew formula (命令行工具)
# 和 cask (macOS 应用程序) 的详细信息，并以 JSON 格式输出。
# --json=v2 指定输出 JSON 格式的版本 2。
# --installed 限制只显示已安装的包。
# 将输出重定向到 TMP_JSON_BEFORE 临时文件。
brew info --json=v2 --installed > "$TMP_JSON_BEFORE"

# declare -A VERSIONS_BEFORE：声明一个名为 VERSIONS_BEFORE 的关联数组（hash map）。
# 这个数组将用于存储升级前所有包的名称及其对应的版本号。
declare -A VERSIONS_BEFORE
# declare -a PINNED_FORMULAS：声明一个名为 PINNED_FORMULAS 的普通数组。
# 存储所有已 pin (锁定版本，不自动升级) 的 formula 名称。
declare -a PINNED_FORMULAS
# declare -a UNPINNED_FORMULAS：声明一个名为 UNPINNED_FORMULAS 的普通数组。
# 存储所有未 pin 的 formula 名称。
declare -a UNPINNED_FORMULAS
# declare -a ALL_CASKS：声明一个名为 ALL_CASKS 的普通数组。
# 存储所有已安装的 cask 名称。
declare -a ALL_CASKS

# jq -r '.formulae[] | select(.pinned == true) | .name' "$TMP_JSON_BEFORE"：
# 从 JSON 文件中筛选出所有 pinned 为 true 的 formula 的名称。
# .formulae[] 遍历所有 formula。
# select(.pinned == true) 过滤出已 pin 的 formula。
# .name 提取其名称。
PINNED_FORMULAS=($(jq -r '.formulae[] | select(.pinned == true) | .name' "$TMP_JSON_BEFORE"))
# jq -r '.formulae[] | select(.pinned == false) | .name' "$TMP_JSON_BEFORE"：
# 从 JSON 文件中筛选出所有 pinned 为 false 的 formula 的名称。
UNPINNED_FORMULAS=($(jq -r '.formulae[] | select(.pinned == false) | .name' "$TMP_JSON_BEFORE"))
# jq -r '.casks[] | .token' "$TMP_JSON_BEFORE"：
# 从 JSON 文件中提取所有 cask 的 token (即 cask 的名称)。
ALL_CASKS=($(jq -r '.casks[] | .token' "$TMP_JSON_BEFORE"))

# 填充 VERSIONS_BEFORE 关联数组：
# jq -r '.formulae[] | "\(.name)=\(.versions.stable)"' "$TMP_JSON_BEFORE"：
# 从 JSON 文件中提取每个 formula 的名称和稳定版本号，格式为 "name=version"。
# while IFS="=" read -r name version; do ... done < <(...)：
# 这是一个 bash 技巧，通过进程替换 <(...) 将 jq 的输出作为 while 循环的输入。
# IFS="=" 将输入行按 '=' 分割，分别赋值给 name 和 version 变量。
# VERSIONS_BEFORE["$name"]="$version"：将包名作为键，版本号作为值存储到关联数组中。
while IFS="=" read -r name version; do VERSIONS_BEFORE["$name"]="$version"; done < <(jq -r '.formulae[] | "\(.name)=\(.versions.stable)"' "$TMP_JSON_BEFORE")
while IFS="=" read -r name version; do VERSIONS_BEFORE["$name"]="$version"; done < <(jq -r '.casks[] | "\(.token)=\(.version)"' "$TMP_JSON_BEFORE")
echo "Scanning complete!" # 扫描完成提示
separator # 添加分隔线，确保与下一部分分隔
printf "\n"

# ================== 第 4 步：显示当前状态 ==================
separator
print_header "第 4.1 步：检查已 pin 的 Formula (将跳过升级)"
# 检查 PINNED_FORMULAS 数组的长度。
if [ ${#PINNED_FORMULAS[@]} -gt 0 ]; then
    # 如果有已 pin 的 formula，则遍历并打印它们的名称和版本。
    for f in "${PINNED_FORMULAS[@]}"; do print_version "$f" "${VERSIONS_BEFORE[$f]}"; done
else
    # 如果没有，则显示相应信息。
    echo "No pinned formulae found." # 没有已 pin 的 formula 提示
fi
separator
printf "\n"

separator
print_header "第 4.2 步：检查待升级的 Formula"
# 检查 UNPINNED_FORMULAS 数组的长度。
if [ ${#UNPINNED_FORMULAS[@]} -gt 0 ]; then
    # 如果有未 pin 的 formula，则遍历并打印它们的名称和版本。这些是可能被升级的。
    for f in "${UNPINNED_FORMULAS[@]}"; do print_version "$f" "${VERSIONS_BEFORE[$f]}"; done
else
    # 如果没有，则显示相应信息。
    echo "All formulae are pinned or up-to-date." # 所有 formula 均已 pin 或无需升级提示
fi
separator
printf "\n"

separator
print_header "第 4.3 步：检查待升级的 Cask"
# 检查 ALL_CASKS 数组的长度。
if [ ${#ALL_CASKS[@]} -gt 0 ]; then
    # 如果有已安装的 cask，则遍历并打印它们的名称和版本。这些是可能被升级的。
    for c in "${ALL_CASKS[@]}"; do print_version "$c" "${VERSIONS_BEFORE[$c]}"; done
else
    # 如果没有，则显示相应信息。
    echo "No casks installed." # 没有已安装的 cask 提示
fi
separator
printf "\n"

# ================== 第 5 步：执行升级操作 ==================
separator
print_header "第 5 步：执行升级（仅显示实际更新和错误信息）"

# 定义一个 flag 来跟踪是否有任何升级操作被执行
UPGRADE_ATTEMPTED=0 # 初始值为 0，表示尚未尝试任何升级。

# 【关键优化】使用 grep -v 过滤掉不需要的警告信息
# 这是一个优化点，通过管道将 brew upgrade 的输出传递给 grep -v，
# 过滤掉常见的“已安装”或“已是最新”的非关键信息，使输出更简洁。
# -e 'already installed'      -> 过滤 formula 的 '已安装' 警告
# -e 'is already up-to-date'  -> 过滤 cask 的 '已是最新' 警告
if [ ${#UNPINNED_FORMULAS[@]} -gt 0 ]; then
    UPGRADE_ATTEMPTED=1 # 如果有 formula 待升级，设置 flag 为 1。
    echo "--- Upgrading Formulae ---" # 正在升级 Formulae 提示
    # brew upgrade "${UNPINNED_FORMULAS[@]}"：升级所有未 pin 的 formula。
    # 2>&1：将标准错误（stderr）重定向到标准输出（stdout），以便 grep 可以处理所有输出。
    # | grep -v ...：通过管道过滤掉指定的警告信息。
    # | tee "$TMP_UPGRADE_LOG"：将过滤后的输出同时显示在终端并写入到 TMP_UPGRADE_LOG 临时文件。
    # || true：即使 grep 没有任何匹配（这意味着所有输出都被过滤掉了，或者没有需要升级的包），
    # 导致 grep 返回非零退出码，|| true 也会强制整个 command 的退出状态为 0，
    # 从而避免触发 set -e 导致脚本提前退出。
    brew upgrade "${UNPINNED_FORMULAS[@]}" 2>&1 | grep -v -e 'already installed' -e 'is already up-to-date' | tee "$TMP_UPGRADE_LOG" || true
    echo ""
fi

if [ ${#ALL_CASKS[@]} -gt 0 ]; then
    UPGRADE_ATTEMPTED=1 # 如果有 cask 待升级，设置 flag 为 1。
    echo "--- Upgrading Casks ---" # 正在升级 Casks 提示
    # brew upgrade --cask "${ALL_CASKS[@]}"：升级所有 cask。
    # tee -a "$TMP_UPGRADE_LOG"：使用 -a 参数将输出追加到日志文件，
    # 以便 formula 和 cask 的升级日志都在同一个文件中。
    brew upgrade --cask "${ALL_CASKS[@]}" 2>&1 | grep -v -e 'already installed' -e 'is already up-to-date' | tee -a "$TMP_UPGRADE_LOG" || true
fi

# 根据 UPGRADE_ATTEMPTED flag 判断是否执行了升级操作，并给出提示。
if [ ${UPGRADE_ATTEMPTED} -eq 0 ]; then
    echo "All packages are up-to-date. No upgrade needed." # 所有包都已是最新版，无需升级提示
fi
separator
printf "\n"


# ================== 第 6 步：生成彩色版本对比报告 ==================
separator
print_header "第 6 步：版本升级对比报告"
# brew info --json=v2 --installed：再次获取所有已安装包的 JSON 信息，但这次是升级后的状态，存储到 TMP_JSON_AFTER。
brew info --json=v2 --installed > "$TMP_JSON_AFTER"

declare -A VERSIONS_AFTER # 声明一个关联数组，用于存储升级后包的版本信息。
# 填充 VERSIONS_AFTER 关联数组，方法与升级前相同。
while IFS="=" read -r name version; do VERSIONS_AFTER["$name"]="$version"; done < <(jq -r '.formulae[] | "\(.name)=\(.versions.stable)"' "$TMP_JSON_AFTER")
while IFS="=" read -r name version; do VERSIONS_AFTER["$name"]="$version"; done < <(jq -r '.casks[] | "\(.token)=\(.version)"' "$TMP_JSON_AFTER")

echo "--- Formulae Comparison ---" # Formulae 对比提示
if [ ${#UNPINNED_FORMULAS[@]} -gt 0 ]; then
    # 遍历所有之前未 pin 的 formula，进行版本对比。
    for f in "${UNPINNED_FORMULAS[@]}"; do
        before=${VERSIONS_BEFORE[$f]} # 获取升级前的版本。
        # 获取升级后的版本。如果包在升级后被移除，jq可能找不到其信息，
        # 此时 ${VERSIONS_AFTER[$f]:-"(已移除)"} 会将 after 设置为 "(已移除)"。
        after=${VERSIONS_AFTER[$f]:-"(已移除)"}
        print_version_diff "$f" "$before" "$after" # 打印带颜色的版本差异。
    done
else
    echo "No formulae were upgraded." # 没有 formula 被升级提示
fi

echo ""
echo "--- Casks Comparison ---" # Casks 对比提示
if [ ${#ALL_CASKS[@]} -gt 0 ]; then
    # 遍历所有 cask，进行版本对比。
    for c in "${ALL_CASKS[@]}"; do
        before=${VERSIONS_BEFORE[$c]} # 获取升级前的版本。
        after=${VERSIONS_AFTER[$c]:-"(已移除)"} # 获取升级后的版本，处理移除情况。
        print_version_diff "$c" "$before" "$after" # 打印带颜色的版本差异。
    done
else
    echo "No casks were upgraded." # 没有 Cask 被升级提示
fi
separator
printf "\n"

# ================== 第 7 步：最终总结 ==================
separator
print_header "第 7 步：最终状态确认"
echo "--- Pinned Formulae Status ---" # 保持版本的 Formula 提示
if [ ${#PINNED_FORMULAS[@]} -gt 0 ]; then
    # 遍历所有已 pin 的 formula，确认它们保持了原始版本。
    for f in "${PINNED_FORMULAS[@]}"; do
        # ${VERSIONS_AFTER[$f]:-${VERSIONS_BEFORE[$f]}}：
        # 尝试获取升级后的版本，如果不存在（例如在极少数情况下被移除），则使用升级前的版本。
        print_version "$f" "${VERSIONS_AFTER[$f]:-${VERSIONS_BEFORE[$f]}}"
    done
else
    echo "No pinned formulae found." # 没有已 pin 的 formula 提示
fi
separator
printf "\n"

# ================== 第 8 步：清理旧文件和缓存 (brew cleanup) ==================
separator
print_header "第 8 步：清理旧文件和缓存 (brew cleanup)"
# brew cleanup 命令会移除旧版本的 Formulae 和 Casks，以及旧的下载文件，从而释放磁盘空间。
brew cleanup --prune=all
separator
printf "\n"

# 打印最终完成信息，使用绿色高亮显示。
echo -e "${GREEN}All operations completed!${NC}" # 所有操作已完成提示
printf "\n"
