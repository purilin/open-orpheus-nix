{
  description = "Open Orpheus — an open-source implementation of Netease Cloud Music's Orpheus browser host";

  inputs = {
    # Keep in sync with flake.lock. Pinned to nixos-unstable for recent Electron/GTK libs.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      version = "0.19.2";

      # Only the two Linux architectures with upstream release artifacts.
      systems = [ "x86_64-linux" "aarch64-linux" ];

      # Prebuilt AppImage artifacts from GitHub Releases.
      # Hashes are the upstream asset SHA-256 (as published by GitHub).
      appImages = {
        x86_64-linux = {
          url = "https://github.com/YUCLing/open-orpheus/releases/download/v${version}/open-orpheus-${version}-x86_64.AppImage";
          hash = "sha256-3nyS+iFmKFU9/WvzmYm0fW2/3hayQHADwqJXU7BZSuY=";
        };
        aarch64-linux = {
          url = "https://github.com/YUCLing/open-orpheus/releases/download/v${version}/open-orpheus-${version}-aarch64.AppImage";
          hash = "sha256-5iSB6O+lewPAFSpjNylWXaHRv3J1EM6lqf+o56fXOjY=";
        };
      };

      forAllSystems = f: lib.genAttrs systems (system: f system);

      # Builds a runnable package for one system.
      # - `appimageTools.wrapType2` extracts the AppImage and wraps it in an FHS
      #   environment, which is the most reliable way to run bundled Electron
      #   binaries on Nix (GTK/NSS/PulseAudio/Wayland etc. are provided by the FHS).
      # - A .desktop file and hicolor icons are layered on top so the app also
      #   shows up in launchers when the package is added to `home.packages`.
      mkOpenOrpheus = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          app = pkgs.appimageTools.wrapType2 {
            pname = "open-orpheus";
            inherit version;
            src = pkgs.fetchurl {
              url = appImages.${system}.url;
              hash = appImages.${system}.hash;
            };
          };

          desktopItem = pkgs.runCommand "open-orpheus-desktop" { } ''
            mkdir -p "$out/share/applications"
            cat > "$out/share/applications/open-orpheus.desktop" <<'EOF'
            [Desktop Entry]
            Type=Application
            Name=Open Orpheus
            GenericName=Music Player
            Comment=An open-source Netease Cloud Music client
            Comment[zh_CN]=一个开源的网易云音乐客户端
            Icon=open-orpheus
            Exec=open-orpheus %U
            Terminal=false
            StartupNotify=true
            Categories=AudioVideo;Audio;Player;Network;
            MimeType=audio/mpeg;audio/wav;audio/x-wav;audio/flac;audio/ogg;audio/x-m4a;
            Keywords=Netease Cloud Music;Music;Player;Online Music;
            Keywords[zh_CN]=网易云音乐;音乐;播放器;在线音乐;
            EOF
          '';

          icons = pkgs.runCommand "open-orpheus-icons" { } ''
            mkdir -p \
              "$out/share/icons/hicolor/256x256/apps" \
              "$out/share/icons/hicolor/512x512/apps" \
              "$out/share/icons/hicolor/scalable/apps"
            cp "${self}/assets/icon_256.png" "$out/share/icons/hicolor/256x256/apps/open-orpheus.png"
            cp "${self}/assets/icon_512.png" "$out/share/icons/hicolor/512x512/apps/open-orpheus.png"
            cp "${self}/assets/icon.svg" "$out/share/icons/hicolor/scalable/apps/open-orpheus.svg"
          '';
        in
        pkgs.symlinkJoin {
          name = "open-orpheus-${version}";
          paths = [ app desktopItem icons ];
          meta = with lib; {
            description = "An open-source Netease Cloud Music client";
            homepage = "https://github.com/YUCLing/open-orpheus";
            license = licenses.mit;
            mainProgram = "open-orpheus";
            platforms = systems;
            sourceProvenance = with sourceTypes; [ binaryNativeCode ];
          };
        };
    in
    {
      packages = forAllSystems (system: {
        default = mkOpenOrpheus system;
        open-orpheus = mkOpenOrpheus system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${mkOpenOrpheus system}/bin/open-orpheus";
        };
      });

      # Home-manager module. Usage (in your home-manager flake):
      #
      #   inputs.open-orpheus.url = "github:YUCLing/open-orpheus";
      #
      #   home-manager.lib.homeManagerConfiguration {
      #     modules = [
      #       open-orpheus.homeManagerModules.default
      #       { programs.open-orpheus.enable = true; }
      #     ];
      #   };
      homeManagerModules = {
        default = self.homeManagerModules.open-orpheus;
        open-orpheus = { config, lib, pkgs, ... }:
          let
            pkg = self.packages.${pkgs.stdenv.hostPlatform.system}.open-orpheus;
          in
          {
            options.programs.open-orpheus = {
              enable = lib.mkEnableOption "Open Orpheus (an open-source Netease Cloud Music client)";
            };

            config = lib.mkIf config.programs.open-orpheus.enable {
              home.packages = [ pkg ];

              xdg.desktopEntries.open-orpheus = {
                name = "Open Orpheus";
                genericName = "Music Player";
                comment = "An open-source Netease Cloud Music client";
                exec = "open-orpheus %U";
                icon = "open-orpheus";
                terminal = false;
                categories = [ "AudioVideo" "Audio" "Player" "Network" ];
                mimeType = [
                  "audio/mpeg"
                  "audio/wav"
                  "audio/x-wav"
                  "audio/flac"
                  "audio/ogg"
                  "audio/x-m4a"
                ];
              };

              home.file.".local/share/icons/hicolor/256x256/apps/open-orpheus.png".source = "${self}/assets/icon_256.png";
              home.file.".local/share/icons/hicolor/512x512/apps/open-orpheus.png".source = "${self}/assets/icon_512.png";
              home.file.".local/share/icons/hicolor/scalable/apps/open-orpheus.svg".source = "${self}/assets/icon.svg";
            };
          };
      };
    };
}
