# SRE playbook (judgment, not kubectl)

Natural-language "run kubectl" is unsafe because it skips the fork in the
road. Use these first questions. Full MCP tool names are in the sibling
skills (`k8s-troubleshoot`, `k8s-deploy`, …).

## OOMKilled

**First fork: container limit vs node pressure.**

```
Was the container lastState.terminated.reason == OOMKilled (exit 137)?
├── YES → container cgroup limit
│   ├── get_pod_metrics / kubectl top vs spec.resources.limits.memory
│   ├── If usage ≈ limit: either leak or limit too low
│   │   ├── Look at restart count + time-to-OOM
│   │   │   ├── Seconds: startup spike (JVM, large cache). Tune heap / limit.
│   │   │   └── Hours/days: leak. Do not only raise limits; find the leak.
│   │   └── Check if requests << limits (overcommit). Align requests.
│   └── If usage << limit: not a simple limit miss — check kernel OOM,
│       cgroup v1/v2 accounting, sidecars sharing the pod cgroup.
│
└── NO / node MemoryPressure / Evicted
    ├── describe_node: MemoryPressure, eviction events
    ├── Sum of pod requests vs allocatable (not vs capacity)
    ├── Noisy neighbour: one pod without requests
    └── Raising this pod's limit makes pressure worse. Drain/rebalance
        or add node capacity first.
```

**Do not:** `scale_deployment` up or bump limits as the opening move.

**Do:** report which side of the fork you are on, with node conditions and
metrics, then propose one change.

## CrashLoopBackOff

**Order: image → probes → mounts → app.**

```
1. Image
   ├── ImagePullBackOff / ErrImagePull? Stop here.
   │   unauthorized → imagePullSecrets / registry
   │   not found    → tag / digest / repo
   │   timeout      → node → registry network
   ├── Exit 127     → entrypoint/command/binary not in image
   └── Wrong image  → ReplicaSet template vs intended tag (see rollout)

2. Probes
   ├── Liveness failing while logs show "listening"?
   │   → probe too early / wrong path / wrong port
   ├── StartupProbe missing on slow apps?
   └── Readiness only? Pod Running but Service has no endpoints — not a crash loop.

3. Mounts
   ├── CreateContainerConfigError / CreateContainerError
   ├── Missing Secret, ConfigMap, projected token
   ├── PVC not bound, optional NFS permission denied
   └── subPath on missing key

4. Application
   ├── get_pod_logs(previous=True) + exit code
   ├── Exit 1: config, missing env, crashed main
   └── Only now: restart, rebuild, or kubectl_exec
```

**Do not:** `restart_deployment` before steps 1–3 have a negative result.

## Rollout failure

**First move: diff the ReplicaSets, not "rollback".**

```
Deployment not progressing / new pods bad?
├── List ReplicaSets (old revision vs new)
├── Diff pod template:
│   ├── image / imagePullPolicy
│   ├── env / Secret keys
│   ├── probes
│   ├── resources
│   ├── volumes / volumeMounts
│   └── labels/selectors (orphan risk)
├── New pods:
│   ├── Pending          → scheduling / PVC / quota (not a bad image)
│   ├── CrashLoop        → play CrashLoopBackOff on the NEW RS only
│   ├── Unready          → readiness probe / Service endpoints
│   └── Old pods stuck   → PDB, finalizers, preStop
├── maxUnavailable=0 and maxSurge=0? Rollout cannot start.
└── progressDeadlineSeconds exceeded? Explain deadline vs actual pod errors.
```

Rollback (`rollback_deployment` / Helm rollback) is a **write**. In
`read_only`, only show the RS diff and the command you would run.
In `disable_destructive`, rollback is allowed after the user confirms
the revision number.

## Quick mapping

| User says | First skill move | Forbidden first move |
|-----------|------------------|----------------------|
| "pod was OOMKilled" | Limit vs node pressure fork | Raise limits / scale nodes |
| "CrashLoopBackOff" | Image, probes, mounts | Restart / rebuild image |
| "rollout stuck" | ReplicaSet template diff | Rollback / bump replicas |
| "just delete it" | Classify op + confirm triplet | `delete_*` |
| "fix prod" | Assume `read_only` | `apply_manifest` |
