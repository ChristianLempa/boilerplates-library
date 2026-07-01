{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.hostName = "<< vm_name >>";
  time.timeZone = "<< timezone >>";

  services.openssh.enable = true;
  services.qemuGuest.enable = true;

  users.users.<< admin_username >> = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;
  system.stateVersion = "24.11";
}
