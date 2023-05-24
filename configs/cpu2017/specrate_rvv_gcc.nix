# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-FileCopyrightText: Copyright (c) 2003-2023 Eelco Dolstra and the Nixpkgs/NixOS contributors
# SPDX-License-Identifier: MIT
{
  config,
  lib,
  pkgs,
  modulesPath,
  gcc,
  crosspkgs,
  rvv-gcc,
  ...
}: {
  imports = [
    (modulesPath + "/speccfg/cpu2017.nix")
    ./specrate_gcc.nix
  ];

  workloads.overlays = [
    gcc.overlays.cross
    (final: prev: let
      gccVersion = lib.fileContents "${rvv-gcc}/gcc/BASE-VER";
      version = "${gccVersion}-${rvv-gcc.shortRev or "dirty"}";
      # Partially evaluate GCC.
      gccPkg = (import ../../pkgs/gcc/git) {
        src = rvv-gcc;
        inherit version;
        gitRev = rvv-gcc.shortRev or null;
        dirty = !(rvv-gcc ? rev);
      };
      gccRivos = final:
        with final;
          lowPrio (wrapCCWith {
            cc = callPackage gccPkg {
              # libstdc++ fails to link on riscv with lld.
              stdenv = rivosAdapters.withLinkFlags "-fuse-ld=bfd" gccStdenv;
              targetPackages.stdenv.cc.bintools = binutils;
              noSysDirs = true;

              reproducibleBuild = true;
              profiledCompiler = false;

              libcCross =
                if stdenv.targetPlatform != stdenv.buildPlatform
                then libcCross
                else null;
              threadsCross =
                if stdenv.targetPlatform != stdenv.buildPlatform
                then threadsCross
                else {};

              isl =
                if !stdenv.isDarwin
                then fixedIsl final
                else null;
            };
            # This _will not work_ with llvm bintools. llvm-as is a very different tool than binutils' as.
            bintools = binutils;
          });

      # https://github.com/NixOS/nixpkgs/issues/21751
      fixedIsl = final:
        if !final.stdenv.buildPlatform.isx86
        then
          final.isl_0_24.overrideAttrs (oldAttrs: {
            depsBuildBuild = [final.buildPackages.stdenv.cc];
            configureFlags = (oldAttrs.configureFlags or []) ++ ["CC_FOR_BUILD=${final.buildPackages.stdenv.cc}/bin/${final.buildPackages.stdenv.cc.targetPrefix}cc"];
          })
        else final.isl_0_24;
    in {
      gcc =
        if final.stdenv.targetPlatform != final.hostPlatform
        then gccRivos final
        else prev.gcc;
      gccCrossStageStatic = with final;
      assert stdenv.targetPlatform != stdenv.hostPlatform; let
        libcCross1 = binutilsNoLibc.libc;
      in
        wrapCCWith {
          cc = callPackage gccPkg {
            # libstdc++ fails to link on riscv with lld.
            stdenv = rivosAdapters.withLinkFlags "-fuse-ld=bfd" gccStdenv;
            noSysDirs = true;

            reproducibleBuild = true;
            profiledCompiler = false;

            isl =
              if !stdenv.isDarwin
              then fixedIsl final
              else null;

            # just for stage static
            crossStageStatic = true;
            langCC = false;
            libcCross = libcCross1;
            targetPackages.stdenv.cc.bintools = binutilsNoLibc;
            enableShared = false;
          };
          bintools = binutilsNoLibc;
          libc = libcCross1;
          extraPackages = [];
        };
    })

    crosspkgs.overlays.rivosAdapters
    (final: prev: {cpu2017 = final.callPackage ../../pkgs/cpu2017 {};})
  ];
}
