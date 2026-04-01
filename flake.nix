{
  description = "efwmc-helix: A post-modern text editor with Steel plugin support.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs lib.systems.flakeExposed;
      pkgsFor = eachSystem (
        system:
        import nixpkgs {
          localSystem.system = system;
          overlays = [
            (import rust-overlay)
            self.overlays.efwmc-helix
          ];
        }
      );
      gitRev = self.rev or self.dirtyRev or null;
    in
    {
      packages = eachSystem (system: {
        efwmc-helix = pkgsFor.${system}.efwmc-helix;
        default = self.packages.${system}.efwmc-helix;
      });
      checks = lib.mapAttrs (
        system: pkgs:
        let
          msrvToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          msrvPlatform = pkgs.makeRustPlatform {
            cargo = msrvToolchain;
            rustc = msrvToolchain;
          };
        in
        {
          efwmc-helix = self.packages.${system}.efwmc-helix.override {
            rustPlatform = msrvPlatform;
          };
        }
      ) pkgsFor;

      # Devshell behavior is preserved.
      devShells = lib.mapAttrs (system: pkgs: {
        default =
          let
            commonRustFlagsEnv = "-C link-arg=-fuse-ld=lld -C target-cpu=native --cfg tokio_unstable";
            platformRustFlagsEnv = lib.optionalString pkgs.stdenv.isLinux "-Clink-arg=-Wl,--no-rosegment";
          in
          pkgs.mkShell {
            inputsFrom = [ self.checks.${system}.efwmc-helix ];
            nativeBuildInputs =
              with pkgs;
              [
                lld
                cargo-flamegraph
                rust-bin.nightly.latest.rust-analyzer
              ]
              ++ (lib.optional (stdenv.isx86_64 && stdenv.isLinux) cargo-tarpaulin)
              ++ (lib.optional stdenv.isLinux lldb);
            shellHook = ''
              export RUST_BACKTRACE="1"
              export RUSTFLAGS="''${RUSTFLAGS:-""} ${commonRustFlagsEnv} ${platformRustFlagsEnv}"
            '';
          };
      }) pkgsFor;

      overlays = {
        efwmc-helix = final: prev: {
          efwmc-helix = final.callPackage ./default.nix { inherit gitRev; };
        };

        default = self.overlays.efwmc-helix;
      };
    };
  nixConfig = {
    extra-substituters = [
      "https://helix.cachix.org"
      "https://helix-steel-system.cachix.org"
    ];
    extra-trusted-public-keys = [
      "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      "helix-steel-system.cachix.org-1:l6e6SidE31VDBciOGFuOEM7h4v7Ll85DvDNODQLDl+Y="
    ];
  };
}
