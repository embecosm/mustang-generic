# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Module for configuring a qemu wrapper for a workload.
{
  config,
  pkgs,
  lib,
  modulesPath,
  workloadPkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.qemu-wrapper;

  qemuArches = ["aarch64" "riscv64" "x86_64"];
in {
  options = {
    qemu-wrapper = {
      enable = mkEnableOption "QEMU workload wrapper";

      pkg = mkOption {
        default = pkgs.qemu;
        type = types.package;
        description = ''
          qemu package to use for user mode emulation.
        '';
      };

      arch = mkOption {
        readOnly = true;
        type = types.enum qemuArches;
        description = ''
          qemu architecture for emulation. Determined by the workload system.
        '';
      };

      cpu = mkOption {
        default = "";
        type = types.str;
        description = ''
          CPU to use for emulation. See `qemu-$ARCH -cpu help` for a list.
        '';
      };

      bbv = mkOption {
        default = null;
        type = types.nullOr (types.attrsOf types.str);
        description = ''
          BBV plugin configuration
        '';
      };

      cache = mkOption {
        default = null;
        type = types.nullOr (types.attrsOf types.str);
        description = ''
          Cache plugin configuration
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    qemu-wrapper.arch = workloadPkgs.hostPlatform.qemuArch;
  };
}
