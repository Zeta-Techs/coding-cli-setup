# ZetaTechs Coding CLI Setup

一个用于快速配置三类 Coding CLI 的交互式脚本（MIT License）：
- Factory Droid CLI（~/.factory/config.json）
- OpenAI Codex CLI（~/.codex/config.toml 与 ~/.codex/auth.json）
- Anthropic Claude Code CLI（写入环境变量到 ~/.bashrc / ~/.zshrc）

脚本会引导你选择 API 站点并输入 API Key，写入各工具的配置位置；如再次运行且不做选择/输入，将保留原配置不变。

## 特性
- 内置 4 种站点选择
  1. ZetaTechs API 主站: https://api.zetatechs.com/v1
  2. ZetaTechs API 企业站: https://ent.zetatechs.com/v1
  3. ZetaTechs API Codex 站: https://codex.zetatechs.com/v1
  4. 自定义: 手动输入 base_url（会提示示例，格式同 1 号站点），随后输入 Key
- 自动备份原配置（创建 .bak 或带时间戳的备份）
- 尽量保证写入合法 JSON（如安装了 jq 会做严格校验）
- 避免把 Key 写入到仓库，所有密钥仅落盘到用户目录（权限 600）

## 安装与使用
- 下载脚本并执行：
  ```
  curl -fsSL https://raw.githubusercontent.com/Zeta-Techs/coding-cli-setup/main/coding-cli-setup.sh | bash
  ```
- 按提示选择要配置的应用（1/2/3）。
- 选择站点时提供 4 个选项：
  - 1/2/3 为预设站点。
  - 4 自定义时，脚本会展示示例：例如 https://api.zetatechs.com/v1（要求以 http(s):// 开头），随后会提示你输入 API Key。
- 运行结束后：
  - Factory Droid CLI: 配置保存在 ~/.factory/config.json
  - OpenAI Codex CLI: 配置在 ~/.codex/config.toml，密钥在 ~/.codex/auth.json
  - Anthropic CLI: 环境变量写入 ~/.bashrc 与 ~/.zshrc（需要 source 生效）

## 常见问题
- JSON 解析错误
  - 用 jq 验证：jq . ~/.factory/config.json
  - 清理 UTF-8 BOM：sed -i '1s/^\xEF\xBB\xBF//' ~/.factory/config.json
- Key 中有换行导致解析失败
  - 粘贴时确保是单行；脚本会移除回车换行，但若手工编辑请保持同一行。
- 权限
  - 配置文件权限会设为 600，如需多人共享请按需调整。

## 安全
- 脚本不会上传你的 Key；仅在本地写入用户目录，并设置为 600 权限。
- 建议把包含密钥的文件（如 ~/.codex/auth.json、~/.factory/config.json）加入你的全局 .gitignore 避免误提交。

## 许可

MIT License

Copyright (c) 2025 ZetaTechs (Zeta Frontier Technology (Hangzhou) Co., Ltd.)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
