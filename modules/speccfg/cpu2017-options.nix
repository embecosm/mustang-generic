# SPDX-FileCopyrightText: Copyright (c) 2023 by Rivos Inc.
# SPDX-License-Identifier: MIT
{
  config,
  lib,
}: let
  inherit (lib) mkOption;
in {
  options = {
    makeVars = mkOption {
      type = types.attrsOf types.str;
      description = ''
        Variables interpreted by specmake.
        https://www.spec.org/cpu2017/Docs/makevars.html
      '';
    };

    # runcpu options
    # https://www.spec.org/cpu2017/Docs/config.html#sectionII.B
    action = mkOption {
      type = types.enum [
        "build"
        "buildsetup"
        "onlyrun"
        "report"
        "runsetup"
        "validate"
      ];
      description = ''
        Action for runcpu to take.
        https://www.spec.org/cpu2017/Docs/runcpu.html#action
      '';
    };

    backup_config = mkOption {
      type = types.bool;
      default = false;
      description = ''
        When updating the hashes in the config file, make a backup copy first. Highly recommended to defend against full-file-system errors, system crashes, or other unfortunate events.
      '';
    };

    command_add_redirect = mkOption {
      type = types.bool;
      default = true;
      description = ''
        If set, the generated ''${command} will include redirection operators (stdout, stderr), which are passed along to the shell that executes the command. If this variable is not set, specinvoke does the redirection.
      '';
    };

    flagsurl = mkOption {
      type = types.str;
      default = "noflags";
      description = ''
        If set, retrieve the named URL or filename and use that as the "user" flags file. If the special value "noflags" is used, runcpu will not use any file and (if formatting previously run results) will remove any stored file.
      '';
    };

    ignore_errors = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Ignore certain errors which would otherwise cause the run to stop.
      '';
    };

    iterations = mkOption {
      type = types.ints.between 1 10;
      default = 1;
      description = ''
        Number of iterations to run. Reportable runs require either:
          3 iterations, in which case the median will be used when calculating overall metrics; or
          2 iterations, in which case the slower run will be used when calculating overall metrics.
      '';
    };

    label = mkOption {
      type = types.str;
      description = ''
        An arbitrary tag for executables, build directories, and run directories.
      '';
    };

    line_width = mkOption {
      type = types.ints.unsigned;
      default = 1020;
      description = ''
        Line wrap width for screen. If left at the default, 0, then lines will not be wrapped and may be arbitrarily long.
      '';
    };

    log_line_width = mkOption {
      type = types.ints.unsigned;
      default = 1020;
      description = ''
        Line wrap width for logfiles. If your editor complains about lines being too long when you look at logfiles, try setting this to some reasonable value, such as 80 or 32. If left at the default, 0, then lines will not be wrapped and may be arbitrarily long.
      '';
    };

    makeflags = mkOption {
      type = types.str;
      default = "--jobs=%{build_ncpus}";
      description = ''
        Line wrap width for logfiles. If your editor complains about lines being too long when you look at logfiles, try setting this to some reasonable value, such as 80 or 32. If left at the default, 0, then lines will not be wrapped and may be arbitrarily long.
      '';
    };

    mean_anyway = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Calculate mean even if invalid. DANGER: this will write a mean to all reports even if no valid mean can be computed (e.g. half the benchmarks failed). A mean from an invalid run is not "reportable" (that is, it cannot be represented in public as the SPEC metric).
      '';
    };

    output_format = mkOption {
      type = types.enum ["txt" "csv" "config" "check" "pdf" "html"];
      default = ["txt" "csv"];
      description = ''
        Format for reports.
      '';
    };

    output_root = mkOption {
      type = types.str;
      description = ''
        If set to a non-empty value, all output files will be rooted under the named directory, instead of under $SPEC
      '';
    };

    preenv = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use preENV_ lines in the config file.
      '';
    };

    reportable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Strictly follow reporting rules, to the extent that it is practical to enforce them by automated means.
      '';
    };

    nobuild = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Do not attempt to build benchmarks.
      '';
    };

    verify_binaries = mkOption {
      type = types.bool;
      default = false;
      description = ''
        runcpu uses checksums to verify that executables match the config file that invokes them, and if they do not, runcpu forces a recompile. You can turn that feature off by setting verify_binaries=no.
      '';
    };

    tune = mkOption {
      default = "base";
      type = types.enum ["base" "peak"];
      description = ''
        Tuning for benchmark builds. See SPEC CPU 2017 documentation for details.
      '';
    };
  };
}
