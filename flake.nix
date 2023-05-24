# SPDX-FileCopyrightText: Copyright (c) 2022 by Rivos Inc.
# SPDX-License-Identifier: MIT
{
  description = "rivos nix workloads framework";

  inputs = {
    crosspkgs.url = "github:rivosinc/crosspkgs";
    nixpkgs.follows = "crosspkgs/nixpkgs";

    flake-parts.follows = "crosspkgs/flake-parts";
    nix-filter.follows = "crosspkgs/nix-filter";

    qemu.url = "git+https://github.com/rivosinc/qemu.git?ref=rivos/main&submodules=1";
    qemu.inputs.nixpkgs.follows = "nixpkgs";
    qemu.inputs.flake-parts.follows = "flake-parts";
    qemu.inputs.nix-filter.follows = "nix-filter";

    rvv-gcc = {
      url = "github:embecosm/rvv-gcc";
      flake = false;
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        ./eval-config.nix
      ];
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
    };
}
