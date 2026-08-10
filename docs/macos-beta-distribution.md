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
