#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# SPDX-License-Identifier: MIT
"""Converts a speccmds-format file into a JSON workload description"""

import argparse
from dataclasses import dataclass, asdict
import json
import pathlib
import sys


@dataclass
class SpecWorkloadCommand:
    env: "dict[str, str]"
    args: "list[str]"
    stdin_file: str
    stdout_file: str
    stderr_file: str
    cwd: str


def parse_workload(speccmds):
    cwd = ""
    env = {}
    workload = []

    for line in speccmds:
        # Split the full command line by whitespace first.
        args = line.split()

        # Environment variable?
        if args[0] == "-E":
            env[args[1]] = args[2]
            continue

        # cwd?
        if args[0] == "-C":
            cwd = args[1]
            continue

        # other ignored parameters
        if args[0] == "-r" or args[0] == "-N":
            continue

        if args[0] == "-k":
            args = args[1:]

        stdin_file = None
        stdout_file = None
        stderr_file = None
        if args[0] == "-i":
            stdin_file = args[1]
            args = args[2:]

        if args[0] == "-o":
            stdout_file = args[1]
            args = args[2:]

        if args[0] == "-e":
            stderr_file = args[1]
            args = args[2:]

        # The last args are stdout/stderr redirection. > foo.out 2>> bar.err
        if len(args) >= 3 and args[-2] == "2>>":
            args = args[:-2]
        if len(args) >= 3 and args[-2] == ">":
            args = args[:-2]
        if len(args) >= 3 and args[-2] == "<":
            args = args[:-2]

        # Remove the qemu wrapper, if any.
        # The flags removal is hacky. Oh well. Use QEMU_* env variables instead.
        QEMU_FLAGS = set(["-cpu", "-plugin"])
        if "qemu" in args[0]:
            args = args[1:]
            while args[0] in QEMU_FLAGS:
                args = args[2:]

        workload_cmd = SpecWorkloadCommand(
            **{
                "stdin_file": stdin_file,
                "stdout_file": stdout_file,
                "stderr_file": stderr_file,
                "args": args,
                "env": env,
                "cwd": cwd,
            }
        )

        workload.append(workload_cmd)

    return workload


# Note that nix does _not_ allow importing strings that contain paths to the nix store.
# This means SHELL and PATH are no good.
ENV_ALLOWLIST = set(
    [
        "HOME",
        "LC_ALL",
        "LC_LANG",
        "OMP_NUM_THREADS",
        "OMP_STACKSIZE",
        "OMP_THREAD_LIMIT",
        "USER",
    ]
)


def filter_env(workload_cmds):
    for cmd in workload_cmds:
        cmd.env = {k: v for k, v in cmd.env.items() if k in ENV_ALLOWLIST}

    return workload_cmds


def normalize_paths(workload_cmds):
    # SPEC seems to always try to go to the parent of the rundir. Get rid of that.
    # We can't use pathlib resolve() since that wants to make the path absolute.
    for cmd in workload_cmds:
        arg0_path = pathlib.PurePath(cmd.args[0])
        if not arg0_path.is_absolute():
            # The binary is in this rundir anyway. Just get the name of it.
            cmd.args[0] = f"./{arg0_path.name}"

        # The cmds file is in the rundir.
        cmd.cwd = "."

    return workload_cmds


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--no-normalize",
        help="don't perform normalization of paths in the speccmds file",
        action="store_true",
    )
    parser.add_argument(
        "--no-env-filter",
        help="don't filter extraneous environment variables",
        action="store_true",
    )
    parser.add_argument(
        "speccmds_file", help="path to a speccmds-format file", type=pathlib.Path
    )
    args = parser.parse_args()

    with open(args.speccmds_file, "r") as f:
        workload_cmds = parse_workload(f.readlines())
        if not args.no_normalize:
            workload_cmds = normalize_paths(workload_cmds)
        if not args.no_env_filter:
            workload_cmds = filter_env(workload_cmds)

        # Convert the dataclass into a raw dict, since the json package can't
        # serialize dataclasses automatically.
        workload_cmds = list(map(asdict, workload_cmds))
        workload_json = json.dumps(workload_cmds, sort_keys=True, indent=4)
        print(f"{workload_json}")

    sys.exit(0)


if __name__ == "__main__":
    main()
