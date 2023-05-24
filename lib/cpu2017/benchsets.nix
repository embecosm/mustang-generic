# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
# Benchmark sets available in each version of SPEC CPU.
let
  inherit (builtins) elem;
in {
  cpu2017 = rec {
    intrate = [
      "500.perlbench_r"
      "502.gcc_r"
      "505.mcf_r"
      "520.omnetpp_r"
      "523.xalancbmk_r"
      "525.x264_r"
      "531.deepsjeng_r"
      "541.leela_r"
      "548.exchange2_r"
      "557.xz_r"
      "999.specrand_ir"
    ];

    fprate = [
      "503.bwaves_r"
      "507.cactuBSSN_r"
      "508.namd_r"
      "510.parest_r"
      "511.povray_r"
      "519.lbm_r"
      "521.wrf_r"
      "526.blender_r"
      "527.cam4_r"
      "538.imagick_r"
      "544.nab_r"
      "549.fotonik3d_r"
      "554.roms_r"
      "997.specrand_fr"
    ];

    intspeed = [
      "600.perlbench_s"
      "602.gcc_s"
      "605.mcf_s"
      "620.omnetpp_s"
      "623.xalancbmk_s"
      "625.x264_s"
      "631.deepsjeng_s"
      "641.leela_s"
      "648.exchange2_s"
      "657.xz_s"
      "998.specrand_is"
    ];

    fpspeed = [
      "603.bwaves_s"
      "607.cactuBSSN_s"
      "619.lbm_s"
      "621.wrf_s"
      "627.cam4_s"
      "628.pop2_s"
      "638.imagick_s"
      "644.nab_s"
      "649.fotonik3d_s"
      "654.roms_s"
      "996.specrand_fs"
    ];

    intrate_no_fortran = [
      "500.perlbench_r"
      "502.gcc_r"
      "505.mcf_r"
      "520.omnetpp_r"
      "523.xalancbmk_r"
      "525.x264_r"
      "531.deepsjeng_r"
      "541.leela_r"
      "557.xz_r"
      "999.specrand_ir"
    ];

    fprate_no_fortran = [
      "508.namd_r"
      "510.parest_r"
      "511.povray_r"
      "519.lbm_r"
      "526.blender_r"
      "538.imagick_r"
      "544.nab_r"
      "997.specrand_fr"
    ];

    specrate = intrate ++ fprate;
    specspeed = intspeed ++ fpspeed;
    specrate_no_fortran = intrate_no_fortran ++ fprate_no_fortran;
    cpu = specrate ++ specspeed;

    # Check if a given benchmark name is in one of the benchsets.
    inIntRate = benchname: elem benchname intrate;
    inFpRate = benchname: elem benchname fprate;
    inSpecRate = benchname: elem benchname specrate;

    inIntSpeed = benchname: elem benchname intspeed;
    inFpSpeed = benchname: elem benchname fpspeed;
    inSpecSpeed = benchname: elem benchname specspeed;

    inCpu = benchname: (elem benchname cpu);
  };
}
