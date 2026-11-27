# QazaqType macOS 安装与发布说明

## 支持范围

- macOS 12 或更高版本
- Intel 与 Apple 芯片 Mac
- 安装到当前用户的 `~/Library/Input Methods`
- 不需要管理员密码

## 安装

1. 打开 `QazaqType-0.4.0-macOS-universal.dmg`。
2. 双击“QazaqType 安装器”。正式包已通过 Apple 公证，不需要绕过 Gatekeeper。
3. 在安装向导中点击“安装并继续”。
4. macOS 询问是否启用输入法时，点击“允许”。
5. 如果向导提示刷新登录会话，请注销并重新登录，再次打开安装器。

如果检测到早期测试版安装在 `/Library/Input Methods`，安装器会请求一次管理员授权，将旧副本备份到 `/Users/Shared` 后完成升级。

## 正式发布

正式包使用 `Developer ID Application: Estay Kargabai (5YX83877Q3)`。

1. 首次发布前，在 Apple 账号生成“App 专用密码”。
2. 运行 `./scripts/configure-macos-notarization.sh`，凭据只保存到登录钥匙串。
3. 运行 `./scripts/build-macos-installer.sh` 生成带时间戳的 Universal 2 DMG。
4. 运行 `./scripts/notarize-macos-installer.sh` 提交 Apple 公证并装订票据。
5. 在干净的 Intel 与 Apple 芯片 Mac 上分别验证。

## 版本号

唯一的版本来源是 `platforms/macos/InputMethod/Info.plist`
（`CFBundleShortVersionString` 与 `CFBundleVersion`）。构建脚本会把同一版本写入
设置应用和安装器。

## 更新

- 已安装旧版本的用户打开新版 DMG 时，安装器会显示“Жаңа нұсқа қолжетімді”
  和“Жаңарту”按钮。更新会替换文件、结束旧的输入法进程，设置保持不变，无需注销。
- 设置助手每天最多检查一次
  `https://api.github.com/repos/qadyrjan/qazaq-type-app/releases/latest`。
  发现新版本时提示用户，下载 DMG、验证安装器的 Developer ID 签名
  （团队 `5YX83877Q3`）后打开安装器。
- 发布新版本：创建标签为 `vX.Y.Z` 的 GitHub Release，并上传公证后的
  `QazaqType-X.Y.Z-macOS-universal.dmg`。仓库必须是公开的，否则检查会返回 404。
- 1.1.0 之前的版本没有更新检查，这些用户需要手动下载一次新版 DMG。
