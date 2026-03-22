!macro customHeader
  BrandingText "$(wordzInstallerBranding)"
  !define MUI_ABORTWARNING
  !define MUI_UNABORTWARNING
  !define MUI_WELCOMEPAGE_TITLE "$(wordzWelcomeTitle)"
  !define MUI_WELCOMEPAGE_TEXT "$(wordzWelcomeText)"
  !define MUI_DIRECTORYPAGE_TEXT_TOP "$(wordzDirectoryText)"
  !define MUI_FINISHPAGE_TITLE "$(wordzFinishTitle)"
  !define MUI_FINISHPAGE_TEXT "$(wordzFinishText)"
  !define MUI_FINISHPAGE_RUN_TEXT "$(wordzFinishRunText)"
  !define MUI_UNWELCOMEPAGE_TITLE "$(wordzUninstallTitle)"
  !define MUI_UNWELCOMEPAGE_TEXT "$(wordzUninstallText)"
  !define MUI_UNFINISHPAGE_TITLE "$(wordzUninstallFinishTitle)"
  !define MUI_UNFINISHPAGE_TEXT "$(wordzUninstallFinishText)"
!macroend

LangString wordzInstallerBranding 1033 "WordZ Stable Installer"
LangString wordzInstallerBranding 2052 "WordZ 稳定版安装器"

LangString wordzWelcomeTitle 1033 "Welcome to the WordZ Setup Wizard"
LangString wordzWelcomeTitle 2052 "欢迎使用 WordZ 安装向导"

LangString wordzWelcomeText 1033 "WordZ is a local corpus analysis workbench for quick opening, library management, statistics, KWIC, collocate analysis, text lookup, and export.$\r$\n$\r$\nThis setup will install the stable desktop edition for the current user or for all users on this computer."
LangString wordzWelcomeText 2052 "WordZ 是一款本地语料分析工作台，支持快速打开、语料库管理、统计、KWIC、Collocate、原文定位与导出。$\r$\n$\r$\n该安装器将把稳定版安装到当前用户或这台电脑的所有用户环境中。"

LangString wordzDirectoryText 1033 "Choose where WordZ should be installed. Keeping the default location is recommended for most users."
LangString wordzDirectoryText 2052 "请选择 WordZ 的安装位置。对大多数用户来说，保持默认路径即可。"

LangString wordzFinishTitle 1033 "WordZ is ready"
LangString wordzFinishTitle 2052 "WordZ 已准备就绪"

LangString wordzFinishText 1033 "The stable desktop edition of WordZ has been installed successfully. You can now open local corpora, manage libraries, run statistics, KWIC, and collocate analysis."
LangString wordzFinishText 2052 "WordZ 稳定版已安装完成。你现在可以打开本地语料、管理语料库，并进行统计、KWIC 与 Collocate 分析。"

LangString wordzFinishRunText 1033 "Launch WordZ now"
LangString wordzFinishRunText 2052 "立即启动 WordZ"

LangString wordzUninstallTitle 1033 "Uninstall WordZ"
LangString wordzUninstallTitle 2052 "卸载 WordZ"

LangString wordzUninstallText 1033 "This wizard will remove WordZ from your computer. Your corpus backups are not deleted automatically."
LangString wordzUninstallText 2052 "该向导将从你的电脑中移除 WordZ。你手动保存的语料库备份不会被自动删除。"

LangString wordzUninstallFinishTitle 1033 "WordZ has been removed"
LangString wordzUninstallFinishTitle 2052 "WordZ 已被移除"

LangString wordzUninstallFinishText 1033 "WordZ was removed from this computer. If you plan to reinstall later, keeping an external corpus backup is recommended."
LangString wordzUninstallFinishText 2052 "WordZ 已从这台电脑移除。如果你后续还会重新安装，建议保留一份外部语料库备份。"
