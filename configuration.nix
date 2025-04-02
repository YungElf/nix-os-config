# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

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
    code-cursor
  ];

  java = with pkgs; [
    openjdk17
    jdt-language-server
  ];

terminalStuff = with pkgs; [
  tmux
  (pkgs.writeShellScriptBin "kitty" ''
    exec ${pkgs.kitty}/bin/kitty --config /etc/nixos/assets/kitty/kitty.conf \
      tmux attach || tmux
  '')
];

  basicStuff = with pkgs; [
    xclip
    jetbrains-mono
  ];

  gamingStuff = with pkgs; [
    steam
    discord-ptb
  ];

  customScripts = with pkgs; [
    (pkgs.writeShellScriptBin "nixsave" (builtins.readFile /etc/nixos/scripts/nixsave))
   (pkgs.writeShellScriptBin "firefox" ''
      exec ${pkgs.firefox}/bin/firefox \
        --no-remote \
        --profile /etc/nixos/assets/firefox-hardmode
    '')
  ];
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Phoenix";

  # Select internationalisation properties.
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


  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };

     # Mount 2TB ext4 drive labeled 'Ultra' at /mnt/games
  fileSystems."/mnt/Ultra" = {
    device = "/dev/disk/by-label/Ultra";
    fsType = "ext4";
  };

  # Mount 500GB ext4 drive labeled 'Sparkle' at /mnt/sparkle
  fileSystems."/mnt/sparkle" = {
    device = "/dev/disk/by-label/Sparkle";
    fsType = "ext4";
  };


  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.elf = {
    isNormalUser = true;
    description = "elf";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "elf";

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Install all required packages
  environment.systemPackages =
    devStuff ++ java ++ terminalStuff ++ basicStuff ++ gamingStuff ++ customScripts;

    environment.etc."tmux.conf".source = /etc/nixos/assets/tmux.conf;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken.
  system.stateVersion = "24.11";
}
