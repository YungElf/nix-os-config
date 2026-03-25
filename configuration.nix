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
    direnv
    nix-direnv
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
    jetbrains-mono
    vlc
    google-chrome
    qbittorrent-enhanced
  ];

  gamingStuff = with pkgs; [
    steam
    bolt-launcher
    lutris
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
        --profile /etc/nixos/assets/firefox-hardmode
    '')
  ];
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  ## Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ## Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  ## Time / Locale
  time.timeZone = "America/Phoenix";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  ## Graphics (renamed from hardware.opengl)
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  ## Filesystems
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

  ## Desktop
  services.xserver.enable = true;
  services.xserver.xkb.layout = "us";

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.theme = "breeze";
  services.desktopManager.plasma6.enable = true;

  ## Auto-login (renamed namespace)
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "elf";

  ## Printing
  services.printing.enable = true;

  ## Audio (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  ## Virtualization
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  ## User
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
    ];
  };

  ## Browsers
  programs.firefox.enable = true;

  ## Nix settings
  nixpkgs.config.allowUnfree = true;

  programs.nix-ld.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  ## zram swap (responsiveness)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  
  ##CAC Reader
  services.pcscd.enable = true;

  ## Packages
  environment.systemPackages =
    devStuff
    ++ java
    ++ terminalStuff
    ++ basicStuff
    ++ gamingStuff
    ++ customScripts
    ++ (with pkgs; [
      opensc
      ccid
      pcsctools
    ]);  

  environment.etc."tmux.conf".source =
    /etc/nixos/assets/tmux.conf;

  system.stateVersion = "24.11";
}
