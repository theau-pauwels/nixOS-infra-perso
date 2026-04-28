{ config, lib, ... }:

let
  cfg = config.personalInfra.services.identityProvider;
in
{
  options.personalInfra.services.identityProvider = {
    enable = lib.mkEnableOption "central LLDAP identity provider";

    baseDn = lib.mkOption {
      type = lib.types.str;
      default = "dc=infra,dc=theau,dc=local";
      description = "LDAP base DN for personal infrastructure users.";
    };

    publicUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://auth.theau-vps.duckdns.org";
      description = "Public SSO URL exposed through IONOS-VPS2.";
    };

    lldapAdminUser = lib.mkOption {
      type = lib.types.str;
      default = "theau";
      description = "Initial LLDAP super-admin username.";
    };

    lldapAdminEmail = lib.mkOption {
      type = lib.types.str;
      default = "theau@example.invalid";
      description = "Initial LLDAP super-admin email placeholder.";
    };

    lldapAdminPasswordFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/lldap-admin-password";
      description = "Path to the initial LLDAP admin password file.";
    };

  };

  config = lib.mkIf cfg.enable {
    services.lldap = {
      enable = lib.mkDefault true;
      settings = {
        http_host = "127.0.0.1";
        http_port = 17170;
        ldap_host = "127.0.0.1";
        ldap_port = 3890;
        http_url = cfg.publicUrl;
        ldap_base_dn = cfg.baseDn;
        ldap_user_dn = cfg.lldapAdminUser;
        ldap_user_email = cfg.lldapAdminEmail;
        ldap_user_pass_file = cfg.lldapAdminPasswordFile;
      };
      silenceForceUserPassResetWarning = lib.mkDefault true;
    };

    # LLDAP only manages identities. Service access is owned centrally by
    # modules/services/authelia.nix and enforced at the reverse proxy.
  };
}
