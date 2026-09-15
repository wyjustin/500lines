#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Classify kubectl-mcp-server tool names for k8s-safety.

Python 3.6+ (Kylin V10 SP3 ships Python 3). Stdlib only. Offline.
"""
from __future__ import print_function

import argparse
import json
import sys

DESTRUCTIVE = {
    "delete_pod",
    "delete_deployment",
    "delete_statefulset",
    "delete_daemonset",
    "delete_service",
    "delete_configmap",
    "delete_secret",
    "delete_namespace",
    "delete_resource",
    "uninstall_helm_chart",
    "rollout_abort_tool",
    "kubevirt_vm_stop",
    "kubectl_delete",
}

WRITE = DESTRUCTIVE | {
    "run_pod",
    "scale_deployment",
    "restart_deployment",
    "rollback_deployment",
    "create_deployment",
    "update_deployment",
    "scale_statefulset",
    "restart_statefulset",
    "restart_daemonset",
    "create_service",
    "update_service",
    "create_configmap",
    "update_configmap",
    "create_secret",
    "update_secret",
    "create_namespace",
    "install_helm_chart",
    "upgrade_helm_chart",
    "rollback_helm_release",
    "apply_manifest",
    "patch_resource",
    "create_resource",
    "replace_resource",
    "switch_context",
    "set_namespace_for_context",
    "rollout_promote_tool",
    "rollout_retry_tool",
    "rollout_restart_tool",
    "kubevirt_vm_start",
    "kubevirt_vm_restart",
    "kubevirt_vm_pause",
    "kubevirt_vm_unpause",
    "kubevirt_vm_migrate",
    "capi_machinedeployment_scale_tool",
    "kubectl_apply",
    "kubectl_patch",
    "kubectl_exec",
}

# kubectl_exec is context-dependent; default class is write so read_only
# sessions must justify a downgrade to read.
EXEC_READ_HINTS = (
    "ls",
    "cat",
    "head",
    "tail",
    "env",
    "printenv",
    "nslookup",
    "dig",
    "hostname",
    "id",
    "ps",
    "date",
    "uname",
)

ALWAYS_CONFIRM = {
    "delete_namespace",
    "uninstall_helm_chart",
    "switch_context",
    "kubevirt_vm_stop",
    "rollout_abort_tool",
}


def classify(name, exec_command=None):
    name = (name or "").strip()
    cls = "read"
    if name in DESTRUCTIVE:
        cls = "destructive"
    elif name in WRITE:
        cls = "write"

    if name == "kubectl_exec" and exec_command:
        first = exec_command.strip().split()[0] if exec_command.strip() else ""
        if first in EXEC_READ_HINTS:
            cls = "read"

    blocked_in = []
    if cls in ("write", "destructive"):
        blocked_in.append("read_only")
    if cls == "destructive":
        blocked_in.extend(["disable_destructive", "confirm"])

    return {
        "tool": name,
        "class": cls,
        "blocked_in": blocked_in,
        "always_confirm": name in ALWAYS_CONFIRM or cls == "destructive",
    }


def allowed(result, mode):
    mode = (mode or "confirm").strip()
    if mode == "normal":
        return not result["always_confirm"] or result["class"] == "read"
    if mode in result["blocked_in"]:
        return False
    if mode == "confirm" and result["always_confirm"]:
        return False
    return True


def main(argv):
    parser = argparse.ArgumentParser(
        description="Classify a kubectl-mcp-server tool for k8s-safety."
    )
    parser.add_argument("tool", help="Tool name, e.g. delete_namespace")
    parser.add_argument(
        "--mode",
        default="read_only",
        choices=["normal", "confirm", "read_only", "disable_destructive"],
        help="Active safety mode (default: read_only)",
    )
    parser.add_argument(
        "--exec-command",
        default="",
        help="For kubectl_exec: the command string inside the pod",
    )
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument(
        "--list",
        action="store_true",
        help="Ignore tool argument semantics; list all known tools as JSON",
    )
    args = parser.parse_args(argv)

    if args.list:
        rows = [classify(t) for t in sorted(WRITE)]
        json.dump(rows, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0

    result = classify(args.tool, args.exec_command or None)
    result["mode"] = args.mode
    result["allowed"] = allowed(result, args.mode)

    if args.json:
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        blocked = ",".join(result["blocked_in"]) or "-"
        flag = "ALLOW" if result["allowed"] else "BLOCK"
        confirm = " confirm" if result["always_confirm"] else ""
        sys.stdout.write(
            "{flag}  {tool}  class={cls}  modes_blocking={blocked}{confirm}\n".format(
                flag=flag,
                tool=result["tool"],
                cls=result["class"],
                blocked=blocked,
                confirm=confirm,
            )
        )
    return 0 if result["allowed"] else 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
