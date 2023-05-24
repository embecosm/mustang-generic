#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# SPDX-License-Identifier: MIT
"""Runs a SPEC benchmark from the preprocessed cmd JSON files"""

import argparse
import json
import os
import pathlib
import subprocess
import sys

"""
Resolve a path from the cmd json.
If the command path is absolute, use it.
Otherwise, append to the rundir.
"""


def resolve_path(rundir_path, cmd_path):
    if cmd_path.is_absolute():
        return cmd_path
    else:
        return rundir_path / cmd_path


"""
Resolve the file path and open if redirection is used.
Otherwise, return /dev/null.
"""


def prepare_stdio(rundir_path, stdio_path, flags):
    if stdio_path is None:
        return subprocess.DEVNULL

    stdio_path = pathlib.Path(stdio_path)

    return open(resolve_path(rundir_path, stdio_path), flags)


def load_cmd_json(path):
    assert path.is_file()

    cmd_json = {}
    with open(path, "r") as f:
        cmd_json = json.load(f)

    assert cmd_json

    return cmd_json


def run_cmd(rundir, cmd):
    stdin = prepare_stdio(rundir, cmd["stdin_file"], "r")
    stdout = prepare_stdio(rundir, cmd["stdout_file"], "w")
    stderr = prepare_stdio(rundir, cmd["stderr_file"], "w")
    if stderr == subprocess.DEVNULL:
        stderr = subprocess.STDOUT
    cwd = resolve_path(rundir, pathlib.Path(cmd["cwd"]))
    proc = subprocess.Popen(
        cmd["args"],
        cwd=cwd,
        env=cmd["env"],
        stdin=stdin,
        stdout=stdout,
        stderr=stderr,
        close_fds=True,
    )
    proc.wait()
    if proc.returncode != 0:
        print(f'cmd {cmd["args"]} exited with status {proc.returncode}')
        stdout_txt = ""
        if cmd["stdout_file"] is not None:
            stdout_txt = prepare_stdio(rundir, cmd["stdout_file"], "r").read()
        stderr_txt = ""
        if cmd["stderr_file"] in cmd:
            stderr_txt = prepare_stdio(rundir, cmd["stderr_file"], "r").read()
        print(f"stdout: {stdout_txt}")
        print(f"stderr: {stderr_txt}")

        sys.exit(1)


def apply_wrapper(wrapper_args, cmd, i, benchname):
    # Perform substitution in the qemu args to allow workload numbers
    # in the output filenames.
    format_args = {
        "workload": i,
        "benchname": benchname,
    }
    formatted_args = list(map(lambda x: x.format_map(format_args), wrapper_args))
    cmd["args"] = formatted_args + cmd["args"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--qemu",
        default=os.environ.get("QEMU_BIN"),
        help="path to qemu linux user binary",
        type=str,
    )
    parser.add_argument(
        "--qemu_cpu",
        default=os.environ.get("QEMU_CPU"),
        help="cpu for qemu to use",
        type=str,
    )
    parser.add_argument(
        "--qemu_plugin",
        default=os.environ.get("QEMU_PLUGIN"),
        help="plugin argument for qemu",
        type=str,
    )
    parser.add_argument(
        "--benchname",
        default=os.environ.get("BENCHNAME"),
        help="benchmark name",
        type=str,
    )
    parser.add_argument(
        "bench_rundir", help="path to a prepared rundir", type=pathlib.Path
    )
    args = parser.parse_args()

    rundir = args.bench_rundir
    assert rundir.is_dir()

    benchname = args.benchname
    if benchname is None:
        benchname = "NO_NAME"

    inputgen_path = rundir / "inputgen.json"
    inputgen_cmds = []
    if inputgen_path.exists():
        inputgen_cmds = load_cmd_json(inputgen_path)

    compare_path = rundir / "compare.json"
    compare_cmds = []
    if compare_path.exists():
        compare_cmds = load_cmd_json(compare_path)

    workload_path = rundir / "speccmds.json"
    workload_cmds = []
    if not workload_path.exists():
        print(f"not a spec rundir, or missing preprocessed speccmds: {rundir}")

    workload_cmds = load_cmd_json(workload_path)

    qemu_args = []
    qemu_args_base = []

    if args.qemu is not None:
        qemu_args.append(args.qemu)

        if args.qemu_cpu is not None:
            qemu_args.extend(["-cpu", args.qemu_cpu])

        qemu_args_base = qemu_args

        if args.qemu_plugin is not None:
            qemu_args = qemu_args + ["-plugin", args.qemu_plugin]

    # inputgen
    for i, cmd in enumerate(inputgen_cmds):
        # inputgen can refer to the native-built spec tools.
        arg0_is_native = pathlib.PurePath(cmd["args"][0]).is_absolute()
        if not arg0_is_native:
            # Don't use the plugins or checkpoints for input generation. We don't
            # care about instrumenting those.
            apply_wrapper(qemu_args_base, cmd, i, benchname)
        print(f'running input generation cmd {i}: {" ".join(cmd["args"])}')
        run_cmd(rundir, cmd)

    # run
    for i, cmd in enumerate(workload_cmds):
        workload_qemu_args = qemu_args.copy()

        apply_wrapper(workload_qemu_args, cmd, i, benchname)
        print(f'running workload cmd {i}: {" ".join(cmd["args"])}')
        run_cmd(rundir, cmd)

    # compare
    for i, cmd in enumerate(compare_cmds):
        # compare can refer to the native-built spec tools.
        arg0_is_native = pathlib.PurePath(cmd["args"][0]).is_absolute()
        if not arg0_is_native:
            # Don't use the plugins or checkpoints for input generation. We don't
            # care about instrumenting those.
            apply_wrapper(qemu_args_base, cmd, i, benchname)
        print(f'running compare cmd {i}: {" ".join(cmd["args"])}')
        run_cmd(rundir, cmd)


if __name__ == "__main__":
    main()
