{
  description = "FIDO2 credential manager using GTK4 and Rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "credentialsd";
            version = "0.1.0";
            src = ./.;
            enableParallelBuilding = true;

            cargoDeps = pkgs.rustPlatform.importCargoLock {
              lockFile = ./Cargo.lock;
              outputHashes = {
                "libwebauthn-0.2.2" = "sha256-h0uQMGfkELmR1sWOB9WnUKCwFq2jN09OvtxxwuLz8TE=";
              };
            };

            nativeBuildInputs = with pkgs; [
              meson
              ninja
              pkg-config
              blueprint-compiler
              desktop-file-utils
              wrapGAppsHook4
              rustPlatform.cargoSetupHook
              cargo
              rustc
              rustPlatform.bindgenHook
            ];

            buildInputs = with pkgs; [
              gtk4
              openssl
              dbus
              pcsclite
              libnfc
              systemd
              zip
            ];

            mesonFlags = [
              "-Dcargo_offline=true"
              "-Dprofile=default"
            ];

            meta = with pkgs.lib; {
              description = "FIDO2 credential manager";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
              mainProgram = "credentialsd";
            };
          };

          # https://phabricator.services.mozilla.com/D261536
          firefox-patched =
            let
              patchedUnwrapped = pkgs.firefox-unwrapped.overrideAttrs (old: {
                pname = "firefox-central-patched";
                version = "136.0a1-central-279b57e-patched";
                src = pkgs.fetchhg {
                  url = "https://hg.mozilla.org/mozilla-central";
                  rev = "279b57ef4bf0";
                  sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                };
                cargoHash = "sha256-BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
                patches = (old.patches or [ ]) ++ [
                  (pkgs.fetchurl {
                    url = "https://mozphab-phabhost-cdn.devsvcprod.mozaws.net/file/data/2clddjc2rfaolvrjsvcl/PHID-FILE-v3attguu44dellpfb6h5/D261536.1770504402.diff";
                    sha256 = "sha256-xzRH2afUrvLqJRKZX3rZNdl05BYnjyRBJ8I+rYlp7Fo=";
                  })
                ];
              });
            in
            pkgs.wrapFirefox patchedUnwrapped {
              applicationName = "firefox";
              extraPolicies = {
                DisableAppUpdate = true;
              };
            };
        }
      );

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.credentialsd;
          defaultPackage = self.packages.${pkgs.system}.default;
        in
        {
          options.services.credentialsd = {
            enable = lib.mkEnableOption "credentialsd daemon infrastructure";

            ui = {
              enable = lib.mkEnableOption "credentialsd GTK4 User Interface";
            };

            package = lib.mkOption {
              type = lib.types.package;
              default = defaultPackage;
              description = "The credentialsd package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            services.udev.packages = [ cfg.package ];
            services.dbus.packages = [ cfg.package ];
            environment.systemPackages = lib.mkIf cfg.ui.enable [ cfg.package ];
          };
        };

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [
              rust-analyzer
              clippy
              rustfmt
            ];
          };
        }
      );
    };
}
