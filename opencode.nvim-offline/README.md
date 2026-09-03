# opencode.nvim 离线安装包

将 [nickjvandyke/opencode.nvim](https://github.com/nickjvandyke/opencode.nvim) **v1.0.0** 打成可拷贝到内网/无网环境的安装包。插件本身是纯 Lua，不依赖 npm / luarocks；本包还附带可选的 [snacks.nvim](https://github.com/folke/snacks.nvim)（增强 Ask / Select 界面）。

| 项目 | 内容 |
| --- | --- |
| 上游仓库 | https://github.com/nickjvandyke/opencode.nvim |
| 打包版本 | **v1.0.0**（2026-08-20） |
| 对应提交 | `4576b372034495b8868e6cbe878e85c717998867` |
| 许可证 | MIT（插件） / Apache-2.0（可选 snacks.nvim 2.31.0） |

## 包内结构

```
opencode.nvim-offline/
├── README.md                 本说明
├── install.sh                离线安装到 Neovim packpath
├── uninstall.sh              卸载
├── MANIFEST.txt              版本与校验信息
├── NOTICE                    第三方许可证声明
├── examples/
│   ├── init.lua              推荐 keymap（packpath / 原生配置）
│   ├── lazy.lua              lazy.nvim 的 dir = 离线写法
│   └── vim-pack.lua          Neovim vim.pack 的 file:// 示例
├── vendor/
│   └── opencode.nvim/        插件源码（v1.0.0）
└── dist/
    ├── opencode.nvim-v1.0.0.tar.gz
    ├── opencode.nvim-v1.0.0.gitbundle   完整 git bundle（含全部 tag）
    ├── snacks.nvim-optional.tar.gz
    └── checksums.sha256
```

## 目标机器要求

**本包只包含 Neovim 插件，不包含 `opencode` 命令行。** 插件启动后会调用本机的 `opencode`。

| 依赖 | 是否必须 | 说明 |
| --- | --- | --- |
| Neovim | 必须 | 建议 0.10+；上游 README 推荐 `vim.pack`（0.12+） |
| `opencode` CLI | 必须 | `>= 1.17`，且在 `$PATH` 中。请单独安装：https://opencode.ai/ |
| `curl` | 必须 | 与 OpenCode server 通信 |
| `pgrep` + `lsof` | Unix 下默认需要 | 用于发现本机 `--port` 进程；若设置了 `server.url` 则可省略 |
| snacks.nvim | 可选 | 增强 `ask()` / `select()`；可用 `--with-snacks` 一并安装 |

内网若还没有 `opencode` CLI，需要另外准备其安装包（与本 Neovim 插件无关）。

## 安装（推荐：原生 packpath）

在**有网机器**拷贝整个 `opencode.nvim-offline/` 目录（或把它打成一个 tar）到 U 盘 / 内网共享，然后在**无网机器**执行：

```bash
# 可选：打成单文件再拷贝
# tar -czf opencode.nvim-offline-v1.0.0.tar.gz opencode.nvim-offline

chmod +x install.sh uninstall.sh
./install.sh
```

默认安装位置：

```
~/.local/share/nvim/site/pack/offline/start/opencode.nvim
```

Neovim 会自动加载 `pack/*/start/*`，**不需要** lazy.nvim / packer。

常用选项：

```bash
# 同时安装 snacks.nvim，并写入示例快捷键
./install.sh --with-snacks --with-keymaps

# 安装到自定义 packpath 前缀
./install.sh --prefix /opt/nvim/site

# 从 git bundle 克隆（保留 .git，:checkhealth 能显示 commit）
./install.sh --bundle

# 只预览、不写盘
./install.sh --dry-run
```

`--with-keymaps` 会把 `examples/init.lua` 复制为：

```
~/.config/nvim/plugin/opencode-keymaps.lua
```

若该路径已有同名文件，请先自行备份。

## 安装后配置

在 `init.lua`（或 `--with-keymaps` 生成的文件）中至少需要：

```lua
---@type opencode.Opts
vim.g.opencode_opts = {}

vim.keymap.set({ "n", "x" }, "<C-a>", function()
  require("opencode").ask("@this: ")
end, { desc = "Ask OpenCode…" })

vim.keymap.set({ "n", "x" }, "<C-x>", function()
  require("opencode").select()
end, { desc = "Select OpenCode…" })
```

若安装了 snacks.nvim：

```lua
require("snacks").setup({
  input = { enabled = true },  -- 增强 Ask
  picker = { enabled = true }, -- 增强 Select
})
```

完整选项见 `vendor/opencode.nvim/lua/opencode/config.lua` 与上游 README。

启动 Neovim 后执行：

```
:checkhealth opencode
```

应能加载插件模块；若提示找不到 `opencode` 可执行文件，请先在该机器安装 CLI。

## 其他插件管理器（仍完全离线）

### lazy.nvim

先执行 `./install.sh`，再把 `examples/lazy.lua` 里的 spec 加入 lazy 配置，核心是用 `dir =` 指向本地目录，避免访问 GitHub：

```lua
{
  "nickjvandyke/opencode.nvim",
  dir = vim.fn.stdpath("data") .. "/site/pack/offline/start/opencode.nvim",
  version = false,
}
```

也可以把 `vendor/opencode.nvim` 拷到任意路径，把 `dir` 改成该路径。

### 仅解压 tar.gz

```bash
mkdir -p ~/.local/share/nvim/site/pack/offline/start
tar -xzf dist/opencode.nvim-v1.0.0.tar.gz \
  -C ~/.local/share/nvim/site/pack/offline/start
```

### 从 git bundle 安装

适合希望保留完整 git 历史 / tag 的环境：

```bash
git clone --branch v1.0.0 \
  dist/opencode.nvim-v1.0.0.gitbundle \
  ~/.local/share/nvim/site/pack/offline/start/opencode.nvim
```

校验 bundle：

```bash
git bundle verify dist/opencode.nvim-v1.0.0.gitbundle
```

## 校验文件完整性

```bash
cd dist
sha256sum -c checksums.sha256
```

## 卸载

```bash
./uninstall.sh
```

会删除 packpath 下的 `opencode.nvim`、`snacks.nvim`，以及 `--with-keymaps` 写入的 keymap 文件。

## 运行时注意

- 必须用 `opencode --port` 启动 CLI，插件才能发现 HTTP API。
- 未找到已运行的 server 时，插件默认会执行：`vsplit term://opencode --port`。
- OpenCode 从磁盘读文件，提示前请先保存 buffer。

## 重新打包（维护者）

本目录已包含 v1.0.0 快照。若要更新版本，在有网环境：

```bash
git clone --branch v1.0.0 https://github.com/nickjvandyke/opencode.nvim.git vendor/opencode.nvim
# 刷新 dist/*.tar.gz 与 git bundle 后更新 checksums.sha256 与 MANIFEST.txt
```

## 免责声明

本离线包仅为上游开源插件的再分发快照，方便内网安装。版权仍归原作者；请遵守各项目许可证（见 `NOTICE`）。
