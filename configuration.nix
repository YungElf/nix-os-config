{ config, pkgs, ... }:

let
  devStuff = with pkgs; [
    gcc
    cmake
    gnumake
    pkg-config
    ripgrep
    fd
    unzip
    curl
    git
    neovim
    code-cursor-fhs
    jetbrains.idea-ultimate
    wineWowPackages.stable
    python3
    teams-for-linux
  ];

  java = with pkgs; [
    openjdk17
    openjdk11
    jdt-language-server
  ];

  terminalStuff = with pkgs; [
    # tmux
  ];

  basicStuff = with pkgs; [
    xclip
    nerd-fonts.jetbrains-mono  # kitty.conf specifies the Nerd Font variant
    vlc
    google-chrome
    qbittorrent-enhanced
  ];

  gamingStuff = with pkgs; [
    # steam is managed via programs.steam module below
    lutris
    bolt-launcher
    discord-ptb
    mumble
    obs-studio
    path-of-building
    prismlauncher
  ];

  customScripts = with pkgs; [
    (writeShellScriptBin "nixsave"
      (builtins.readFile /etc/nixos/scripts/nixsave)
    )
    (writeShellScriptBin "firefox" ''
      exec ${pkgs.firefox}/bin/firefox \
        --no-remote \
        --profile /home/elf/.mozilla/firefox/hardmode
    '')
  ];
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Bootloader ────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Networking ────────────────────────────────────────────────────────────
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # ── Locale & Time ─────────────────────────────────────────────────────────
  time.timeZone = "America/Phoenix";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Hardware ──────────────────────────────────────────────────────────────
  # Enables AMD firmware + microcode updates (hardware-configuration.nix gates
  # hardware.cpu.amd.updateMicrocode on this flag, so it was previously off).
  hardware.enableRedistributableFirmware = true;

  # RX 5700 XT (RDNA1): RADV is the recommended Vulkan driver — it outperforms
  # amdvlk on this GPU generation and is included automatically with Mesa.
  # enable32Bit covers 32-bit Vulkan for Steam/Wine via the same Mesa stack.
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # ── Filesystems ───────────────────────────────────────────────────────────
  fileSystems."/mnt/Ultra" = {
    device = "/dev/disk/by-label/Ultra";
    fsType = "ext4";
  };

  fileSystems."/mnt/sparkle" = {
    device = "/dev/disk/by-label/Sparkle";
    fsType = "ext4";
    neededForBoot = true;
  };

  fileSystems."/home" = {
    device = "/mnt/sparkle/home";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  # ── Desktop ───────────────────────────────────────────────────────────────
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.theme = "breeze";
  services.desktopManager.plasma6.enable = true;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "elf";

  # Required for KWin screenshot authorization and other portal-backed features
  # (file picker, screen sharing, etc.). KDE portal handles screenshots; GTK
  # portal gives Chrome/Firefox a native-looking file dialog instead of routing
  # them through the Qt one (which renders text as tofu for GTK clients).
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [
    pkgs.kdePackages.xdg-desktop-portal-kde
    pkgs.xdg-desktop-portal-gtk
  ];
  xdg.portal.xdgOpenUsePortal = true;

  # ── Audio ─────────────────────────────────────────────────────────────────
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Printing ──────────────────────────────────────────────────────────────
  services.printing.enable = true;

  # ── Virtualization ────────────────────────────────────────────────────────
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.elf = {
    isNormalUser = true;
    description = "elf";
    extraGroups = [
      "wheel"
      "networkmanager"
      "libvirtd"
    ];
    packages = with pkgs; [
      kdePackages.kate
      kdePackages.spectacle
    ];
  };

  # ── Programs ──────────────────────────────────────────────────────────────
  programs.firefox.enable = true;
  programs.nix-ld.enable = true;

  # Replaces bare direnv/nix-direnv packages — the module adds shell hooks
  # so `use nix` and `use flake` work automatically in project dirs.
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Steam module handles udev rules, 32-bit libs, and steam-hardware in one shot.
  programs.steam.enable = true;

  # Switches CPU governor to performance and raises game process priority on launch.
  # Works automatically with Steam and Lutris — no per-game config needed.
  programs.gamemode.enable = true;

  # GnuPG agent for git signing and key management across sessions.
  programs.gnupg.agent.enable = true;

  # ── Packages ──────────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages =
    devStuff
    ++ java
    ++ terminalStuff
    ++ basicStuff
    ++ gamingStuff
    ++ customScripts
    ++ (with pkgs; [
      gnupg
    ]);

  environment.etc."tmux.conf".source = /etc/nixos/assets/tmux.conf;

  environment.sessionVariables = {
    MOZ_USE_XINPUT2 = "1";  # fixes Firefox scroll precision on X11
  };

  # ── Nix / Store ───────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;   # deduplicates store on every build
  };

  # 14 days gives two full weeks of rollback headroom before GC.
  # nix.optimise (scheduled) removed — auto-optimise-store covers this.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ── System Services ───────────────────────────────────────────────────────
  services.journald.extraConfig = "SystemMaxUse=500M";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  system.stateVersion = "24.11";
}
