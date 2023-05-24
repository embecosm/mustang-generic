# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Builds derivations that gather dynamic instruction counts from workloads.
{
  config,
  pkgs,
  lib,
  modulesPath,
  workloadPkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.lists) forEach;

  runsetupPkgs = config.cpu2017.runsetupPkgs;
  icountDerivations = builtins.listToAttrs (forEach config.cpu2017.normalizedRunlist (
    benchname: {
      name = benchname;
      value = pkgs.callPackage ../lib/run-benchmark.nix {
        inherit benchname workloadPkgs;
        suffix = "icount";
        icount = true;
        qemuWrapperCfg = config.qemu-wrapper;
        workloadsCfg = config.workloads;
        runsetup = runsetupPkgs."${benchname}";
      };
    }
  ));
  icountDerivation = pkgs.linkFarmFromDrvs "cpu2017-icount" (builtins.attrValues icountDerivations);
in {
  options = {
    icount = {
      pkgs = mkOption {
        type = types.attrsOf types.package;
        readOnly = true;
        description = ''
          icount packages for cpu2017 benchmarks in the runlist.
        '';
      };
    };
  };
  config = {
    build.icount = icountDerivation;
    icount.pkgs = icountDerivations;
  };
}
