# Homebrew Smart Upgrade Script

A robust 和 intelligent shell script designed to streamline your Homebrew package management experience on macOS. This script goes beyond a simple `brew upgrade` by providing detailed version comparisons, pre-upgrade health checks, automatic cleanup, 和 dynamic terminal width adjustment for a perfectly formatted output.

## ✨ Features

* **Intelligent Update Flow:** Orchestrates `brew update`, `brew upgrade`, and `brew cleanup` for a comprehensive maintenance cycle.

* **Pre-Upgrade Health Check:** Integrates `brew doctor` to identify and warn about potential Homebrew environment issues before commencing upgrades.

* **Smart Output Filtering:** Suppresses common "already installed" or "up-to-date" messages during upgrades, providing a cleaner, more focused view of actual changes and errors.

* **Detailed Version Comparison Report:** Generates a colored, side-by-side comparison of package versions before and after the upgrade.

    * **`Package Name : Old Version → New Version` (New versions in green, old in yellow)**

    * **`Package Name : Version (No Change)`**

    * **`Package Name : Old Version → (Removed)` (Old version in yellow)**

* **Dynamic Terminal Width Adjustment:** Automatically attempts to detect your terminal's width using `stty size` and `tput cols`.

    * **Manual Override:** Supports explicit width setting via `--width <value>` command-line argument or `HB_TERMINAL_WIDTH` environment variable for perfect formatting in any terminal environment.

* **Automated Cleanup:** Executes `brew cleanup --prune=all` after upgrades to remove old versions and free up disk space.

* **Temporary File Management:** All temporary files generated during script execution are automatically cleaned up upon completion or exit.

## 🚀 Usage

1.  **Save the Script:**
    Save the script content to a file, for example, `brew-upgrade-manager.sh`, in a directory that's in your `PATH` (e.g., `~/bin/`).

    ```bash
    mkdir -p ~/bin
    # Copy the script content into ~/bin/brew-upgrade-manager.sh
    chmod +x ~/bin/brew-upgrade-manager.sh
    ```

2.  **Install Dependencies:**
    This script requires `jq` for JSON parsing. Install it if you haven't already:

    ```bash
    brew install jq
    ```

3.  **Run the Script:**
    Simply execute it from your terminal:

    ```bash
    brew-upgrade-manager.sh
    ```

4.  **Optional: Custom Terminal Width:**
    If the automatic width detection doesn't perfectly match your terminal, you can manually specify the width:

    * **Command-line argument (per run):**

        ```bash
        brew-upgrade-manager.sh --width 130
        ```

    * **Environment variable (persistent):**
        Add this to your shell's configuration file (e.g., `~/.bashrc`, `~/.zshrc`):

        ```bash
        export HB_TERMINAL_WIDTH=130
        ```

        Then, `source` your config file or open a new terminal.

## 💡 Why Use This Script?

* **Efficiency:** Automates multiple `brew` commands into a single, cohesive workflow.

* **Clarity:** Provides a detailed and color-coded report of what actually changed.

* **Reliability:** Proactively checks for potential issues and ensures a clean Homebrew environment.

* **Customization:** Adaptable to your terminal's visual preferences for optimal readability.

## 📝 License

This project is open
