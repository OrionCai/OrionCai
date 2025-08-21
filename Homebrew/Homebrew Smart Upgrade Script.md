# Homebrew 智能升级脚本

[English Version](Homebrew Smart Upgrade Script.md "Click to view English version")

这是一个强大且智能的 Shell 脚本，旨在简化您在 macOS 上的 Homebrew 包管理体验。它不仅仅是一个简单的 `brew upgrade`，通过提供详细的版本对比、升级前健康检查、自动清理和动态终端宽度调整，确保输出格式完美且专业。

## ✨ 主要功能

* **智能更新流程**：整合 `brew update`、`brew upgrade` 和 `brew cleanup`，提供一个全面的维护周期。

* **升级前健康检查**：集成 `brew doctor`，在开始升级前检测并警告潜在的 Homebrew 环境问题。

* **智能输出过滤**：在升级过程中抑制常见的“已安装”或“已是最新”消息，提供更清晰、更专注于实际变更和错误的视图。

* **详细版本对比报告**：生成彩色、并排的包版本对比报告，展示升级前后的变化。

    * **`包名称 : 旧版本 → 新版本` (新版本绿色显示，旧版本黄色显示)**

    * **`包名称 : 版本 (无变化)`**

    * **`包名称 : 旧版本 → (已移除)` (旧版本黄色显示)**

* **动态终端宽度调整**：自动尝试使用 `stty size` 和 `tput cols` 检测终端宽度。

    * **手动覆盖**：支持通过 `--width <值>` 命令行参数或 `HB_TERMINAL_WIDTH` 环境变量明确设置宽度，确保在任何终端环境下都能完美格式化输出。

* **自动化清理**：升级后执行 `brew cleanup --prune=all`，移除旧版本并释放磁盘空间。

* **临时文件管理**：脚本执行过程中生成的所有临时文件，在脚本完成或退出时都会被自动清理。

## 🚀 使用方法

1.  **保存脚本**：
    将脚本内容保存到文件，例如 `brew-upgrade-manager.sh`，并放置在您的 `PATH` 环境变量中的某个目录（例如 `~/bin/`）。

    ```bash
    mkdir -p ~/bin
    # 将脚本内容复制到 ~/bin/brew-upgrade-manager.sh
    chmod +x ~/bin/brew-upgrade-manager.sh
    ```

2.  **安装依赖**：
    本脚本需要 `jq` 进行 JSON 解析。如果尚未安装，请通过以下命令安装：

    ```bash
    brew install jq
    ```

3.  **运行脚本**：
    直接在您的终端中执行脚本：

    ```bash
    brew-upgrade-manager.sh
    ```

4.  **可选：自定义终端宽度**：
    如果自动宽度检测未能完美匹配您的终端，您可以手动指定宽度：

    * **命令行参数（单次运行）**：

        ```bash
        brew-upgrade-manager.sh --width 130
        ```

    * **环境变量（持久设置）**：
        将此行添加到您的 Shell 配置文件（例如 `~/.bashrc`、`~/.zshrc`）：

        ```bash
        export HB_TERMINAL_WIDTH=130
        ```

        然后，`source` 您的配置文件或打开一个新的终端。

## 💡 为什么使用这个脚本？

* **高效**：将多个 `brew` 命令自动化为一个连贯的工作流。

* **清晰**：提供详细且颜色编码的报告，清晰展示了实际的变更。

* **可靠**：主动检查潜在问题，并确保 Homebrew 环境的清洁。

* **可定制**：可根据您的终端视觉偏好进行调整，以获得最佳可读性。

## 📝 许可证

本项目依据 MIT 许可证发布。
