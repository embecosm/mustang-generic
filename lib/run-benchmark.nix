# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Common derivation for running a benchmark, potentially under a simulator.
{
  stdenvNoCC,
  lib,
  runsetup,
  benchname,
  qemuWrapperCfg,
  workloadsCfg,
  suffix ? null,
  buildPackages,
  icount ? false,
  ...
}: let
  inherit (builtins) toString;
  inherit (lib) concatStringsSep mapAttrsToList generators optional optionals optionalAttrs optionalString;

  qemuLinuxUser = "${qemuWrapperCfg.pkg}/bin/qemu-${qemuWrapperCfg.arch}";

  # From nixos/modules/virtualisation/qemu-vm.nix
  mkKeyValue = generators.mkKeyValueDefault {} "=";
  mkOpts = opts: concatStringsSep "," (mapAttrsToList mkKeyValue opts);

  qemuPlugin = let
    # Order matters! file must come first.
    icountOpts =
      optionalString icount "file=${qemuWrapperCfg.pkg.plugins}/lib/libinsn.so,inline=true";
    activePlugins =
      []
      ++ optional (icountOpts != "") icountOpts;
  in "${concatStringsSep "," activePlugins}";

  haveQemuCpu = qemuWrapperCfg.cpu != "";
  haveQemuPlugins = qemuPlugin != "";

  runscriptFlags = [];

  envVars =
    rec {
      QEMU_BIN = qemuLinuxUser;
      BENCHNAME = benchname;
    }
    // optionalAttrs haveQemuPlugins {
      QEMU_PLUGIN = qemuPlugin;
    }
    // optionalAttrs haveQemuCpu {
      QEMU_CPU = qemuWrapperCfg.cpu;
    };

  run-speccpu =
    buildPackages.writers.writePython3Bin "run-speccpu-benchmark" {
      flakeIgnore = ["E265" "E501"];
    }
    ../scripts/run_speccpu_benchmark.py;
in
  assert (import ./cpu2017/benchsets.nix).cpu2017.inCpu benchname;
    stdenvNoCC.mkDerivation (
      {
        name = "cpu2017-${benchname}" + optionalString (suffix != null) "-${suffix}";
        src = null;

        dontUnpack = true;

        nativeBuildInputs = [run-speccpu];

        buildPhase = ''
          ${lib.toShellVar "runscriptFlags" runscriptFlags}
          mkdir -p $out

          cp -r "${runsetup}"/run/* "$out"

          # Files in the nix store are read-only, so open up write permissions.
          chmod u+w -R "$out"
          run-speccpu-benchmark "''${runscriptFlags[@]}" "$out"
        '';

        dontInstall = true;

        passthru = {
          inherit benchname;
        };
      }
      // envVars
    )
