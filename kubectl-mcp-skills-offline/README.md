# kubectl-mcp-server 25 Agent Skills 离线安装包

把 [kubectl-mcp-server](https://github.com/rohitg00/kubectl-mcp-server) 的 Kubernetes **Agent Skills** 打成可拷到内网 / 无网环境的技能包，目标环境：**银河麒麟 V10 SP3 x86_64**。

这**不是**一个新的 MCP server，而是对已有 `kubectl-mcp-server`（200+ / 270+ 工具）的**封装形态**：把 SRE 的判断经验做成 skill，而不是把自然语言直接翻译成 `kubectl`。

| 项目 | 内容 |
| --- | --- |
| 上游仓库 | https://github.com/rohitg00/kubectl-mcp-server |
| 技能快照 | `kubernetes-skills/claude/` @ `14f9c138`（2026-04-08） |
| 产品形态 | 9 类 **25** 个 Agent Skills + `k8s-safety` 安全封装 |
| 技能规范 | [Agent Skills](https://agentskills.io/specification)（`SKILL.md`） |
| 兼容客户端 | Claude Code / Cursor / OpenCode（以及读取同一规范的其它 agent） |
| 目标 OS | 麒麟 V10 SP3 x86_64（技能本身与 CPU 架构无关；安装脚本按该环境编写） |

上游 `main` 另有第 26 个技能 `k8s-kind`（本地 kind 集群）。默认不装，可用 `--with-kind` 或 `--skills all` 打开。

## 为什么是 skill 而不是“更多 kubectl”

MCP server 已经暴露了足够多的工具。下一阶段要约束的是**判断顺序**：

| 现象 | 先做什么 | 不要先做什么 |
| --- | --- | --- |
| OOMKilled | 区分 **container limit** 还是 **node MemoryPressure** | 直接把 limits 调大 |
| CrashLoopBackOff | 按 **镜像 → 探针 → 挂载** 排查 | 先 restart / 重建镜像 |
| 滚动发布失败 | 先 **对比新旧 ReplicaSet** 的 pod template | 先 rollback 或加副本 |

这些规则写在封装层技能 `k8s-safety`（[overlay/k8s-safety](overlay/k8s-safety/SKILL.md)），并与 server 侧 safety mode 对齐：

- `--read-only`：只读，拦截一切写
- `--disable-destructive`：允许 create/update/scale，拦截 delete / Helm uninstall 等
- 技能层对危险操作再做一次拦截（即使 server 开在 `normal`）

本地预检（无集群）：

```bash
python3 overlay/k8s-safety/scripts/classify-op.py delete_namespace --mode read_only
# BLOCK  delete_namespace  class=destructive  modes_blocking=read_only,disable_destructive,confirm confirm
```

## 包内结构

```
kubectl-mcp-skills-offline/
├── README.md                 本说明
├── install.sh                离线安装到 Claude / Cursor / OpenCode
├── uninstall.sh              卸载
├── verify.sh                 无网自检
├── pack-dist.sh              维护者：生成 dist 归档
├── catalog.txt / catalog.json
├── MANIFEST.txt              版本与校验信息
├── NOTICE                    第三方许可证
├── examples/
│   ├── mcp/                  Claude / Cursor / OpenCode 的只读 MCP 示例
│   └── safety/safety.toml    safety mode 说明
├── overlay/k8s-safety/       本包封装：safety + SRE playbook
├── vendor/kubernetes-skills/ 上游 26 个 SKILL.md 快照（默认安装 25 个）
└── dist/
    ├── kubernetes-skills.tar.gz
    ├── k8s-safety-overlay.tar.gz
    ├── kubectl-mcp-skills-offline-kylin-v10-sp3-x64.tar.gz
    └── checksums.sha256
```

## 9 类 25 技能

| 类别 | Skills |
| --- | --- |
| **Core** | k8s-core, k8s-networking, k8s-storage |
| **Workload** | k8s-deploy, k8s-operations, k8s-helm |
| **Observability** | k8s-diagnostics, k8s-troubleshoot, k8s-incident |
| **Security** | k8s-security, k8s-policy, k8s-certs |
| **GitOps** | k8s-gitops, k8s-rollouts |
| **Scaling** | k8s-autoscaling, k8s-cost, k8s-backup |
| **Multi-cluster** | k8s-multicluster, k8s-capi, k8s-kubevirt, k8s-vind |
| **Networking** | k8s-service-mesh, k8s-cilium |
| **Tools** | k8s-browser, k8s-cli |
| **封装层（默认安装）** | k8s-safety |

完整清单见 `catalog.json`。

## 目标机器要求

| 依赖 | 是否必须 | 说明 |
| --- | --- | --- |
| bash 4.x、coreutils、`tar`、`sha256sum` | 必须 | 麒麟 V10 SP3 默认具备 |
| python3 ≥ 3.6 | 建议 | 仅 `classify-op.py` 与 `verify.sh`；安装脚本本身是纯 bash |
| Claude Code / Cursor / OpenCode 之一 | 必须 | 用来加载 `SKILL.md` |
| `kubectl-mcp-server` | 技能调用 MCP 工具时必须 | **本包不包含 server**，请另行安装 |

内网若还没有 MCP server，需要另外准备 `kubectl-mcp-server` 的安装包（PyPI / wheel）。没有 server 时，技能仍可作为 runbook 给 agent 阅读，只是不能真正调集群工具。

## 安装

在**有网机器**拷贝整个 `kubectl-mcp-skills-offline/` 目录（或 `dist/kubectl-mcp-skills-offline-kylin-v10-sp3-x64.tar.gz`）到 U 盘 / 内网共享，然后在**无网麒麟机器**执行：

```bash
chmod +x install.sh uninstall.sh verify.sh
./verify.sh          # 可选：校验包完整性
./install.sh         # 默认：25 技能 + k8s-safety，安装到当前用户的 agent 目录
```

默认行为：

1. 把技能放到规范目录 `~/.local/share/kubectl-mcp-skills/skills/`
2. 用符号链接挂到：
   - Claude Code：`~/.claude/skills/`
   - Cursor：`~/.cursor/skills/` 与 `~/.agents/skills/`
   - OpenCode：`~/.config/opencode/skills/`

常用选项：

```bash
# 只装 Claude + Cursor
./install.sh --target claude,cursor

# 装到某个 Git 仓库（项目级 .claude/.cursor/.opencode/.agents）
./install.sh --project /opt/apps/my-service

# 系统级目录 + 复制而非 symlink（部分加固环境禁止用户目录软链）
./install.sh --prefix /opt/kubectl-mcp-skills --mode copy

# 包含上游 k8s-kind
./install.sh --with-kind

# 只预览、不写盘
./install.sh --dry-run
```

## 把 MCP server 开成只读（建议）

技能包负责判断；server 负责硬拦截。排查故障时请用 `--read-only`：

```bash
kubectl-mcp-server serve --read-only
```

示例配置（请按本机路径合并，不要直接覆盖已有 MCP 配置）：

| 客户端 | 示例文件 |
| --- | --- |
| Claude Desktop / Claude Code | `examples/mcp/claude.json` |
| Cursor | `examples/mcp/cursor.json`（只读） / `examples/mcp/cursor-nondestrictive.json`（非破坏） |
| OpenCode | `examples/mcp/opencode.json` |

## 校验

```bash
./verify.sh
cd dist && sha256sum -c checksums.sha256
```

`classify-op.py` 可在无集群时检查某个 MCP 工具在当前 mode 下该不该放行。

## 卸载

```bash
./uninstall.sh
# 项目级
./uninstall.sh --project /opt/apps/my-service
```

## 重新打包（维护者）

在有网环境更新上游快照后：

```bash
# 刷新 vendor/kubernetes-skills 后
chmod +x pack-dist.sh
./pack-dist.sh
./verify.sh
```

## 免责声明

本离线包为上游开源技能的再分发快照 + 本仓库的 safety 封装，方便内网安装。版权仍归原作者；请遵守各项目许可证（见 `NOTICE`）。技能不能替代 Kubernetes RBAC；生产环境请使用最小权限 kubeconfig，并把 MCP server 开在只读或非破坏模式。
