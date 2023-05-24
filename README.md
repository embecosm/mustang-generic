# workload runs with nix

Configure, build, and run benchmarks reproducibly.

## Getting started with nix

I like the Determinate Systems installer, as well as their
[Zero to Nix](https://zero-to-nix.com/start/install) guide.

## Usage

Each configuration for a run should have its own config file. For example,
`specrate_gcc.nix` contains a basic configuration that runs all
of the `specrate` suite with Rivos's GCC.

For a SPEC config, there are a number of buildable attributes.

* `runsetup`: Results of `runcpu --action=runsetup`, which builds and creates run dirs.
* `icount`: Runs the benchmark under qemu and collects instruction counts

### Local builds

*NOTE*: All examples below be run from this directory.

To get icounts for all of specrate:

```sh
# for GCC
nix build '.#specrate_gcc.icount' --max-jobs 32
```

If you're interested in just a single benchmark, there's no need to edit the config file.
Just build the benchmark attributes directly!

```sh
nix build '.#gcc.config.icount.pkgs."525.x264_r"' # The quotes are necessary!
```

#### Using a compiler at a custom revision

If you'd like to override the compiler, provide the `--override-input` flag to `nix build`.
This uses [flake reference](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html#flake-references) syntax; see examples below.

Example:

```sh
# Use a local git checkout
nix build --override-input rvv-gcc /path/to/gcc \
          '.#specrate_rvv_gcc.config.icount.pkgs."525.x264_r"'
```

