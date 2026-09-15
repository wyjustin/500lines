---
name: k8s-safety
description: Mandatory Kubernetes safety and SRE judgment for kubectl-mcp-server. Load before any cluster write. Enforces read-only, non-destructive, and dangerous-op interception. Use for OOMKilled, CrashLoopBackOff, failed rollouts, deletes, Helm uninstalls, namespace changes, and any mutation. Safer than translating natural language into kubectl.
license: Apache-2.0
compatibility: Claude Code, Cursor, OpenCode, and any Agent Skills client plus kubectl-mcp-server MCP tools
metadata:
  author: kubectl-mcp-skills-offline
  version: "1.0.0"
  category: safety
  wrapping: kubectl-mcp-server kubernetes-skills
  not_a_new_server: "true"
---

# Kubernetes Safety + SRE Judgment

This is **not** another MCP server and **not** "run kubectl from chat".
It is a skill wrapper around `kubectl-mcp-server` that encodes SRE judgment
and intercepts dangerous operations.

Always load this skill when the user mentions Kubernetes, kubectl, pods,
deployments, Helm, GitOps, incidents, or cluster changes.

## Hard rules

1. **Investigate before mutate.** Prefer `get_*` / `describe_*` / logs / events.
2. **Do not translate natural language into a write.** Map the symptom to a
   decision tree first (see [references/SRE-PLAYBOOK.md](references/SRE-PLAYBOOK.md)).
3. **Respect the active safety mode.** If unknown, assume `read_only` until
   the user explicitly asks to change the cluster.
4. **Intercept dangerous ops.** Classify the tool with
   `scripts/classify-op.py` (or the tables below). If the class is blocked
   in the current mode, refuse and explain what evidence is still missing.
5. **Never dump Secret data in chat.** Point at names, keys, and rotation
   steps — not values.

## Safety modes

These match `kubectl-mcp-server` (`--read-only`, `--disable-destructive`,
`--confirm` / `SafetyMode.CONFIRM`). Skill-layer enforcement must still
happen even if the server is in `normal` mode — agents can call tools
the user did not intend.

| Mode | CLI | Allowed | Blocked |
|------|-----|---------|---------|
| `read_only` | `--read-only` | List / get / describe / logs / metrics / diff | All create / update / delete / scale / apply / exec-that-writes |
| `disable_destructive` | `--disable-destructive` | Create / update / scale / rollout (non-abort) | Deletes, Helm uninstall, rollout abort, VM stop |
| `confirm` | server confirm/elicitation | Same as disable_destructive until the user confirms | Destructive ops without an explicit "yes, delete X in namespace Y" |
| `normal` | (default server) | Server allows all | **Skill still intercepts** the dangerous list and asks for confirmation |

Recommended production pairing:

- Incident investigation: MCP `--read-only` + this skill
- Guided deploy: MCP `--disable-destructive` + this skill
- Break-glass delete: MCP `normal` + spoken confirmation of resource, namespace, and cluster context

See [references/SAFETY-MODES.md](references/SAFETY-MODES.md).

## Dangerous operations (always intercept)

Refuse or require explicit confirmation (resource **name**, **namespace**,
**context/cluster**) before calling:

- `delete_namespace`, `delete_resource` on Namespace / CRD / PV / StorageClass
- `uninstall_helm_chart`, `kubectl_delete` with force/gracePeriod=0
- `rollout_abort_tool`, `kubevirt_vm_stop`
- Any delete of `kube-system` / `kube-public` / `cert-manager` / ingress controller
- `switch_context` to production without repeating the context name back to the user

Full lists live in [references/DANGEROUS-OPS.md](references/DANGEROUS-OPS.md)
and `scripts/classify-op.py`.

```text
python3 scripts/classify-op.py delete_namespace
# destructive  modes_blocking=read_only,disable_destructive,confirm
```

## SRE judgment (do this instead of "just kubectl")

### OOMKilled — limits vs node pressure first

Do **not** immediately raise memory limits.

1. Confirm the signal: container `OOMKilled` / exit 137 vs node `MemoryPressure` eviction.
2. If **node pressure**: check `describe_node`, allocatable vs requests, eviction
   events, and noisy neighbours. Raising one pod's limit can make node pressure worse.
3. If **container limit**: compare working-set (`get_pod_metrics`) to the limit.
   Look for leaks, unbounded caches, and missing `resources.requests`.
4. Only then recommend a limit change, and say whether requests should move with it.

Details: [references/SRE-PLAYBOOK.md](references/SRE-PLAYBOOK.md#oomkilled).

### CrashLoopBackOff — image / probes / mounts first

Do **not** restart or rebuild as the first move.

1. **Image**: `ImagePullBackOff`, wrong tag, digest, `imagePullSecrets`, exit 127 (binary missing).
2. **Probes**: liveness too aggressive; app still starting. Compare probe timing to startup logs.
3. **Mounts**: missing Secret / ConfigMap / PVC, bad `subPath`, permission on volume.
4. Then application config, command, and previous logs (`get_pod_logs(previous=True)`).

Details: [references/SRE-PLAYBOOK.md](references/SRE-PLAYBOOK.md#crashloopbackoff).

### Rolling update failed — compare ReplicaSets first

Do **not** rollback or bump replicas blindly.

1. List ReplicaSets for the Deployment; identify stable vs new.
2. Diff pod templates: image, env, probes, resources, volumes, labels.
3. Check `maxUnavailable` / `maxSurge`, PDB, and whether new pods are unready vs crashlooping.
4. Rollback only after the diff is explained to the user.

Details: [references/SRE-PLAYBOOK.md](references/SRE-PLAYBOOK.md#rollout-failure).

## Workflow when the user asks to "fix the cluster"

```
1. State the safety mode you will assume (default: read_only).
2. Gather: pods, events, ReplicaSet/Deployment diff, node conditions.
3. Name the hypothesis using the playbook (OOM vs pressure, probe vs image, RS diff).
4. Propose the smallest write, in disable_destructive if possible.
5. Stop if the next tool is in the intercept list and confirmation is missing.
```

## Relationship to the other 25 skills

| Need | Skill to load after this one |
|------|------------------------------|
| Resource inventory | `k8s-core`, `k8s-networking`, `k8s-storage` |
| Deploy / Helm | `k8s-deploy`, `k8s-operations`, `k8s-helm` |
| Debug / incident | `k8s-troubleshoot`, `k8s-diagnostics`, `k8s-incident` |
| RBAC / policy / certs | `k8s-security`, `k8s-policy`, `k8s-certs` |
| Flux / Argo / rollouts | `k8s-gitops`, `k8s-rollouts` |
| HPA / cost / Velero | `k8s-autoscaling`, `k8s-cost`, `k8s-backup` |
| Many clusters / CAPI / VMs | `k8s-multicluster`, `k8s-capi`, `k8s-kubevirt`, `k8s-vind` |
| Istio / Cilium | `k8s-service-mesh`, `k8s-cilium` |
| Dashboards / CLI | `k8s-browser`, `k8s-cli` |

Those skills teach **how** to use MCP tools. This skill teaches **whether**
and **in what order**.
