# Safety modes

Skill-layer policy aligned with `kubectl-mcp-server` `kubectl_mcp_tool/safety.py`.

The MCP server flags are a backstop. This skill still classifies tools and
refuses blocked work if the server was started in `normal`.

## Modes

### `read_only`

Start the server with:

```bash
kubectl-mcp-server serve --read-only
```

Use for: production inspection, incident timeline, cost reports, security
audits that only read RBAC.

Blocked: every write in `WRITE_OPERATIONS` (create, update, scale, apply,
patch, delete, Helm install/upgrade/uninstall, context switch, VM lifecycle).

### `disable_destructive` (non-destructive)

```bash
kubectl-mcp-server serve --disable-destructive
```

Use for: guided deploys, scaling, image bumps, GitOps sync that does not
delete.

Blocked: deletes, Helm uninstall, rollout abort, KubeVirt VM stop.

Allowed: create / apply / patch / scale / restart / Helm install & upgrade
(still confirm production context).

### `confirm`

Server elicitation for destructive tools. If the client cannot elicit, treat
as blocked — do not "helpfully" call delete.

Skill-layer: require the user to repeat **cluster context**, **namespace**,
and **resource name**.

### `normal`

Server allows all tools. Skill-layer still intercepts [DANGEROUS-OPS.md](DANGEROUS-OPS.md).

## Precedence (server)

1. CLI `--read-only`
2. CLI `--disable-destructive`
3. Config file (if present)
4. Default `normal`

`--read-only` wins if both flags are set.

## Recommended MCP client snippets

See `examples/mcp/` in this offline package:

| Client | File |
|--------|------|
| Claude Desktop / Claude Code | `examples/mcp/claude.json` |
| Cursor | `examples/mcp/cursor.json` |
| OpenCode | `examples/mcp/opencode.json` |

Pair investigation sessions with `--read-only`. Do not rely on the model
alone to stay read-only.

## What this skill does not do

- It does not replace Kubernetes RBAC. Use a least-privilege kubeconfig.
- It does not start `kubectl-mcp-server`. Install that binary separately.
- It does not add new kubectl verbs. It constrains the 200+ existing MCP tools.
