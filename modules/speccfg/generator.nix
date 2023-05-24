# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Generate a SPEC CPU config file.
{
  config,
  lib,
  workloadPkgs,
}:
assert workloadPkgs.stdenv.is64bit;
assert workloadPkgs.stdenv.isLinux; let
  inherit (lib.strings) concatStrings concatStringsSep optionalString;
  cfg = config.cpu2017;

  runlist = concatStringsSep "," cfg.normalizedRunlist;
  workloadStdenv = workloadPkgs.stdenv;
  workloadPlatform = workloadStdenv.hostPlatform;

  baseOptimizeFlags = concatStringsSep " " cfg.baseOptimizeFlags;
  marchFlag = optionalString (workloadPlatform.gcc ? arch) "-march=${workloadPlatform.gcc.arch}";
  mtuneFlag = optionalString (workloadPlatform.gcc ? tune) "-mtune=${workloadPlatform.gcc.tune}";

  isClang = workloadStdenv.cc.isClang;

  # TODO: don't hardcode this.
  label = "rivos";

  # Common portability flags.
  commonPortabilityFlags = ''
    default:
      EXTRA_PORTABILITY = -DSPEC_LP64

    500.perlbench_r,600.perlbench_s:  #lang='C'
       PORTABILITY   = -DSPEC_LINUX_AARCH64

    521.wrf_r,621.wrf_s:  #lang='F,C'
       CPORTABILITY  = -DSPEC_CASE_FLAG
       # -Mbyteswapio for flang
       FPORTABILITY  = -fconvert=big-endian

    523.xalancbmk_r,623.xalancbmk_s:  #lang='CXX'
       PORTABILITY   = -DSPEC_LINUX

    526.blender_r:  #lang='CXX,C'
       PORTABILITY   = -funsigned-char -DSPEC_LINUX
       # for clang
       CXXPORTABILITY = -D__BOOL_DEFINED

    527.cam4_r,627.cam4_s:  #lang='F,C'
       PORTABILITY   = -DSPEC_CASE_FLAG

    628.pop2_s:  #lang='F,C'
       CPORTABILITY  = -DSPEC_CASE_FLAG
       # -Mbyteswapio for flang
       FPORTABILITY  = -fconvert=big-endian
  '';

  # Flags for workarounds only.
  workaroundFlags = ''
    #   500.perlbench_r,600.perlbench_s=peak:    # https://www.spec.org/cpu2017/Docs/benchmarks/500.perlbench_r.html
    #      EXTRA_CFLAGS = -fno-strict-aliasing -fno-unsafe-math-optimizations -fno-finite-math-only
    #   502.gcc_r,602.gcc_s=peak:                # https://www.spec.org/cpu2017/Docs/benchmarks/502.gcc_r.html
    #      EXTRA_CFLAGS = -fno-strict-aliasing -fgnu89-inline
    #   505.mcf_r,605.mcf_s=peak:                # https://www.spec.org/cpu2017/Docs/benchmarks/505.mcf_r.html
    #      EXTRA_CFLAGS = -fno-strict-aliasing
    #   525.x264_r,625.x264_s=peak:              # https://www.spec.org/cpu2017/Docs/benchmarks/525.x264_r.html
    #      EXTRA_CFLAGS = -fcommon
    #
    # Integer workarounds - base - combine the above - https://www.spec.org/cpu2017/Docs/runrules.html#BaseFlags
    #
       intrate,intspeed=base:
    #      EXTRA_CFLAGS = -fno-strict-aliasing -fno-unsafe-math-optimizations -fno-finite-math-only -fgnu89-inline -fcommon
          EXTRA_CFLAGS = -fno-strict-aliasing -fgnu89-inline -fcommon
    #
    # Floating Point workarounds - peak
    #
    #   511.povray_r=peak:                       # https://www.spec.org/cpu2017/Docs/benchmarks/511.povray_r.html
    #      EXTRA_CFLAGS = -fno-strict-aliasing
    #   521.wrf_r,621.wrf_s=peak:                # https://www.spec.org/cpu2017/Docs/benchmarks/521.wrf_r.html
    #      EXTRA_FFLAGS = -fallow-argument-mismatch
    #   527.cam4_r,627.cam4_s=peak:              # https://www.spec.org/cpu2017/Docs/benchmarks/527.cam4_r.html
    #      EXTRA_CFLAGS = -fno-strict-aliasing
    #      EXTRA_FFLAGS = -fallow-argument-mismatch
       # See also topic "628.pop2_s basepeak" below
    #   628.pop2_s=peak:                         # https://www.spec.org/cpu2017/Docs/benchmarks/628.pop2_s.html
    #      EXTRA_FFLAGS = -fallow-argument-mismatch
    #
    # FP workarounds - base - combine the above - https://www.spec.org/cpu2017/Docs/runrules.html#BaseFlags
    #
       fprate,fpspeed=base:
    #     EXTRA_CFLAGS = -fno-strict-aliasing
    #     EXTRA_FFLAGS = -fallow-argument-mismatch -fno-unsafe-math-optimizations
          EXTRA_FFLAGS = -fallow-argument-mismatch -fmax-stack-var-size=65536
  '';

  # Options only relevant for report generation.
  reportingOpts = ''
    default:
       sw_base_ptrsize = 64-bit
       sw_peak_ptrsize = 64-bit
  '';

  # Default global opts. These runs are not reportable.
  defaultGlobalOpts = ''
    default:
      command_add_redirect = 1
      ignore_errors        = 0
      iterations           = 1
      label                = ${label}
      line_width           = 1020
      log_line_width       = 1020
      # TODO: don't hardcode.
      makeflags            = --jobs=%{ENV_NIX_BUILD_CORES}
      mean_anyway          = 1
      output_format        = txt,csv
      output_root          = %{ENV_SPEC_OUTPUT_ROOT}
      preenv               = 1
      reportable           = 0
      runlist = ${runlist}
      tune = ${cfg.tune}

    intrate,fprate:
       copies           = 1

    intspeed,fpspeed:
       threads          = 1
  '';

  # Compiler paths and version options.
  compilerOpts = ''
    default:
       CC  = %{ENV_CC}  -std=c99
       CXX = %{ENV_CXX} -std=c++03
       FC  = %{ENV_FC}

       # Works for gcc and clang.
       CC_VERSION_OPTION       = --version
       CXX_VERSION_OPTION      = --version
       FC_VERSION_OPTION       = --version
  '';

  # Optimization settings.
  optimizeOpts = ''
    default=base:
      OPTIMIZE = ${baseOptimizeFlags} ${mtuneFlag} ${marchFlag}

    intspeed,fpspeed:
      EXTRA_OPTIMIZE = -fopenmp -DSPEC_OPENMP

    fpspeed:
      #
      # 627.cam4 needs a big stack; the preENV will apply it to all
      # benchmarks in the set, as required by the rules.
      #
      preENV_OMP_STACKSIZE = 120M
  '';
  inherit (lib.generators) mkValueStringDefault mkKeyValueDefault;
in
  # Convert a CPU 2017 config into a config file.
  concatStrings [
    defaultGlobalOpts
    reportingOpts
    compilerOpts
    optimizeOpts
    commonPortabilityFlags
    workaroundFlags
  ]
