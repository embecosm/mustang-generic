# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Perform the runsetup stage for a single benchmark, yielding only the run directory.
{
  stdenv,
  lib,
  gfortran,
  cpu2017,
  buildPackages,
  specConfig,
  benchname,
}: let
  SPEC_MARCH =
    if stdenv.hostPlatform.gcc ? arch
    then "-march=${stdenv.hostPlatform.gcc.arch}"
    else "";
  SPEC_MTUNE =
    if stdenv.hostPlatform.gcc ? tune
    then "-mtune=${stdenv.hostPlatform.gcc.tune}"
    else "";

  speccmds-to-json =
    buildPackages.writers.writePython3Bin "speccmds-to-json" {
      flakeIgnore = ["E265" "E501"];
    }
    ../scripts/speccmds_to_json.py;
in
  assert (import ./cpu2017/benchsets.nix).cpu2017.inCpu benchname;
    stdenv.mkDerivation rec {
      name = "cpu2017-${benchname}-runsetup";

      nativeBuildInputs = [
        gfortran
        cpu2017
        speccmds-to-json
      ];

      # We want compiler wrapper output to ensure we're passing the right flags.
      NIX_DEBUG = 1;

      dontStrip = true;

      inherit SPEC_MARCH SPEC_MTUNE;

      unpackPhase = ''
        local spec_symlinks=(MANIFEST TOOLS.sha512 Docs bin shrc version.txt)
        for f in ''${spec_symlinks[@]}; do
          ln -s "${buildPackages.cpu2017}"/"$f" "$f"
        done
        cp -r --reflink=auto --no-preserve=mode "${buildPackages.cpu2017}"/benchspec benchspec

        mkdir -p config
        cp ${specConfig} config/default.cfg
        # It's harmless but annoying when runcpu complains about this, so just let the config be writable.
        chmod u+w config/default.cfg
      '';

      # Patches are applied in the build directory for the benchmark.
      prePatch = ''
        local benchdir="benchspec/CPU/${benchname}"
        if [ -d "$benchdir/src" ]; then
          pushd benchspec/CPU/${benchname}/src
        elif [ -f "$benchdir/Spec/origin" ]; then
          mapfile -t lines < "$benchdir/Spec/origin"
          local srcName="''${lines[0]}"
          pushd benchspec/CPU/"$srcName"/src
        else
          echo "couldn't find source to patch for ${benchname}"
          exit 1
        fi
      '';

      postPatch = ''
        popd
      '';

      buildPhase = ''
        export SPEC_OUTPUT_ROOT=$(pwd)/build
        export SPEC_NOCHECK=1
        # Sourcing shrc changes the umask among other things. Run this in
        # a subshell to be tidier.
        (
          source shrc
          runcpu --action=build ${benchname}
          runcpu --action=runsetup --fake ${benchname}
        )
        cat build/result/CPU2017.*.log
      '';

      installPhase = ''
        mkdir -p $out/run
        # TODO: {run,build}_*.0000 => {run,build}_$tune*.0000 to seperate base/peak in future
        cp -r "$SPEC_OUTPUT_ROOT"/benchspec/CPU/${benchname}/run/run_*.0000/* $out/run/
        cp -r "$SPEC_OUTPUT_ROOT"/benchspec/CPU/${benchname}/exe/* $out/run/
        cp -r "$SPEC_OUTPUT_ROOT"/benchspec/CPU/${benchname}/build/build_*.0000/make*.out $out/run/
        # record git sha of the source of gcc/llvm src
        #   gcc: "gcc version 12.1.0 (Rivos-sdk gd5602ce0278e)"
        #  llvm: "Rivos clang version 15.0.0 ... git 504b7db7a72e93eff46b758a052e79d80e11ac2a"
        $CC -v >$out/run/compiler-ver 2>&1
      '';

      preFixup = ''
        local INPUTGEN_PATH=$out/run/inputgen.cmd
        local SPECCMDS_PATH=$out/run/speccmds.cmd

        if [ -e "$INPUTGEN_PATH" ]; then
          substituteInPlace "$INPUTGEN_PATH" --replace "$TMPDIR/bin" '${buildPackages.cpu2017}'/bin
          speccmds-to-json "$INPUTGEN_PATH" > $out/run/inputgen.json
        fi

        substituteInPlace "$SPECCMDS_PATH" --replace "$TMPDIR/bin" '${buildPackages.cpu2017}'/bin
        speccmds-to-json "$SPECCMDS_PATH" > $out/run/speccmds.json
      '';
    }
