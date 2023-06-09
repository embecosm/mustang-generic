# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# SPDX-FileCopyrightText: Copyright (c) 2003-2022 Eelco Dolstra and the Nixpkgs/NixOS contributors
# Licensed under the MIT License; see LICENSE for details.
# SPDX-License-Identifier: MIT
{
  lib,
  targetPlatform,
}: let
  p =
    targetPlatform.gcc
    or {}
    // targetPlatform.parsed.abi;
in
  lib.concatLists [
    (lib.optional (!targetPlatform.isx86_64 && p ? arch) "--with-arch=${p.arch}") # --with-arch= is unknown flag on x86_64
    (lib.optional (!targetPlatform.isRiscV && p ? cpu) "--with-cpu=${p.cpu}") # --with-arch= is unknown flag on riscv
    (lib.optional (p ? abi) "--with-abi=${p.abi}")
    (lib.optional (p ? fpu) "--with-fpu=${p.fpu}")
    (lib.optional (p ? float) "--with-float=${p.float}")
    (lib.optional (p ? mode) "--with-mode=${p.mode}")
    (lib.optional
      (let tp = targetPlatform; in tp.isPower && tp.libc == "glibc" && tp.is64bit)
      "--with-long-double-128")
  ]
