# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
{
  config,
  lib,
  pkgs,
  modulesPath,
  gcc,
  crosspkgs,
  ...
}: {
  imports = [
    (modulesPath + "/speccfg/cpu2017.nix")
  ];

  cpu2017 = {
    runlist = ["specrate"];
    tune = "base";
    baseOptimizeFlags = [
      "-Ofast" # -Ofast implies -ffast-math.
      "-flto=auto"
    ];
  };

  qemu-wrapper = {
    enable = true;
    # Picked arbitrarily; adjust as needed.
    cpu = "rv64,g=true,c=true,v=true,vext_spec=v1.0,vlen=256,elen=64";
  };

  workloads = {
    overlays = [
      gcc.overlays.cross
      crosspkgs.overlays.rivosAdapters
      (final: prev: {cpu2017 = final.callPackage ../../pkgs/cpu2017 {};})
    ];
    system = {
      config = "riscv64-unknown-linux-gnu";
      gcc.arch = "rv64gcv";
      system = "riscv64-linux";
    };
  };
}
