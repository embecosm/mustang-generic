# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Creates a script to run the workload.
{
  pkgs,
  workloadPkgs,
  lib,
  spectacles,
  runsetup,
  benchname,
  qemuWrapperCfg,
  workloadsCfg,
}: let
  inherit (lib) concatStringsSep mapAttrsToList generators optional optionalAttrs;

  qemuLinuxUser = "${qemuWrapperCfg.pkg}/bin/qemu-${qemuWrapperCfg.arch}";

  # From nixos/modules/virtualisation/qemu-vm.nix
  mkKeyValue = generators.mkKeyValueDefault {} "=";
  mkOpts = opts: concatStringsSep "," (mapAttrsToList mkKeyValue opts);

  qemuPlugin = let
    bbvCfg = qemuWrapperCfg.bbv;
    cacheCfg = qemuWrapperCfg.cache;
    # Order matters! file must come first.
    bbvOpts =
      if bbvCfg != null
      then concatStringsSep "," ["file=${qemuWrapperCfg.pkg.plugins}/lib/libbbvgen.so" (mkOpts bbvCfg)]
      else "";
    cacheOpts =
      if cacheCfg != null
      then concatStringsSep "," ["file=${qemuWrapperCfg.pkg.plugins}/lib/libcache.so" (mkOpts cacheCfg)]
      else "";
    activePlugins =
      []
      ++ optional (bbvOpts != "") bbvOpts
      ++ optional (cacheOpts != "") cacheOpts;
  in "${concatStringsSep "," activePlugins}";

  haveQemuCpu = qemuWrapperCfg.cpu != "";
  haveQemuPlugins = qemuPlugin != "";

  runscriptVars =
    rec {
      QEMU_BIN = qemuLinuxUser;
      BENCHNAME = benchname;
      RUNSETUP_PKG = "${runsetup}";
      RUN_BENCHMARK = "${spectacles}/bin/run-speccpu-benchmark";
      RESULT_ROOT = "${builtins.toString workloadsCfg.resultRoot}";
      LABEL = "${workloadsCfg.label}";
      RESULT_RUNDIR = "${RESULT_ROOT}/${LABEL}/${BENCHNAME}";
    }
    // optionalAttrs haveQemuPlugins {
      QEMU_PLUGIN = qemuPlugin;
    }
    // optionalAttrs haveQemuCpu {
      QEMU_CPU = qemuWrapperCfg.cpu;
    };
in
  assert (import ./cpu2017/benchsets.nix).cpu2017.inCpu benchname;
    pkgs.writers.writeBash "cpu2017-${benchname}-runscript" ''
      ${lib.toShellVars runscriptVars}

      set -euo pipefail

      main() {
        mkdir -p "$RESULT_RUNDIR"

        cp -r "$RUNSETUP_PKG"/run/* "$RESULT_RUNDIR"

        # Files in the nix store are read-only, so open up write permissions.
        chmod ug+w -R "$RESULT_RUNDIR"

        export BENCHNAME QEMU_BIN QEMU_CPU QEMU_PLUGIN
        exec "$RUN_BENCHMARK" "$RESULT_RUNDIR"
      }

      main "$@"
    ''
