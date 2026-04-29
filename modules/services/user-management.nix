{ config, lib, ... }:

let
  cfg = config.personalInfra.services.userManagement;

  policyType = lib.types.submodule {
    options = {
      policy = lib.mkOption {
        type = lib.types.enum [
          "one_factor"
          "two_factor"
        ];
        default = "one_factor";
        description = "Authelia policy required for this route.";
      };

      groups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "LLDAP groups allowed to access the route.";
      };
    };
  };

  defaultAccessPolicies = {
    ${cfg.lldap.domain} = {
      policy = "two_factor";
      groups = [ "admins" ];
    };
    ${cfg.services.coolifyDomain} = {
      policy = "two_factor";
      groups = [
        "paas-admins"
        "admins"
      ];
    };
    ${cfg.services.wgDashboardDomain} = {
      policy = "two_factor";
      groups = [ "wg-admin" ];
    };
    ${cfg.services.gitDomain} = {
      groups = [
        "git-users"
        "git-admins"
        "admins"
      ];
    };
    ${cfg.services.prowlarrDomain} = {
      policy = "two_factor";
      groups = [
        "media-admins"
        "admins"
      ];
    };
    ${cfg.services.jellyseerrDomain} = {
      groups = [
        "media-users"
        "media-admins"
        "admins"
      ];
    };
    ${cfg.services.wikiDomain} = {
      groups = [
        "wiki-users"
        "admins"
      ];
    };
    ${cfg.services.monitoringDomain} = {
      groups = [
        "monitoring-users"
        "infra-admins"
        "admins"
      ];
    };
  };
in
{
  options.personalInfra.services.userManagement = {
    enable = lib.mkEnableOption "LLDAP-backed user management through Authelia";

    baseDn = lib.mkOption {
      type = lib.types.str;
      default = "dc=theau,dc=net";
      description = "LLDAP base DN used by Authelia.";
    };

    groups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "admins"
        "infra-admins"
        "media-users"
        "media-admins"
        "git-users"
        "git-admins"
        "paas-users"
        "paas-admins"
        "wiki-users"
        "monitoring-users"
        "service-accounts"
        "wg-admin"
      ];
      description = "Standard LLDAP groups used by Authelia access policies.";
    };

    lldap = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "users.theau.net";
        description = "Public LLDAP management UI domain, protected by Authelia.";
      };

      httpAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "LLDAP HTTP listen address.";
      };

      httpPort = lib.mkOption {
        type = lib.types.port;
        default = 17170;
        description = "LLDAP HTTP listen port.";
      };

      ldapAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "LLDAP LDAP listen address.";
      };

      ldapPort = lib.mkOption {
        type = lib.types.port;
        default = 3890;
        description = "LLDAP LDAP listen port.";
      };

      adminUser = lib.mkOption {
        type = lib.types.str;
        default = "theau";
        description = "Initial LLDAP admin username.";
      };

      adminEmail = lib.mkOption {
        type = lib.types.str;
        default = "theau@example.invalid";
        description = "Initial LLDAP admin email placeholder.";
      };

      adminPasswordFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/lldap-admin-password";
        description = "Runtime path to the LLDAP bootstrap admin password.";
      };
    };

    authelia = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "authelia.theau.net";
        description = "Public Authelia portal domain.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "tcp://127.0.0.1:9091";
        description = "Authelia listen address.";
      };

      jwtSecretFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/authelia-jwt-secret";
        description = "Runtime path for the Authelia JWT secret.";
      };

      storageEncryptionKeyFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/authelia-storage-encryption-key";
        description = "Runtime path for the Authelia storage encryption key.";
      };

      ldapPasswordFile = lib.mkOption {
        type = lib.types.path;
        default = "/run/secrets/authelia-ldap-password";
        description = "Runtime path for the LLDAP bind password used by Authelia.";
      };
    };

    services = {
      coolifyDomain = lib.mkOption {
        type = lib.types.str;
        default = "coolify.theau.net";
        description = "Coolify admin UI domain.";
      };

      wgDashboardDomain = lib.mkOption {
        type = lib.types.str;
        default = "wg.theau.net";
        description = "WGDashboard domain.";
      };

      gitDomain = lib.mkOption {
        type = lib.types.str;
        default = "git.theau.net";
        description = "Forgejo domain.";
      };

      prowlarrDomain = lib.mkOption {
        type = lib.types.str;
        default = "prowlarr.theau.net";
        description = "Prowlarr admin UI domain.";
      };

      jellyseerrDomain = lib.mkOption {
        type = lib.types.str;
        default = "jellyseerr.theau.net";
        description = "Jellyseerr domain.";
      };

      wikiDomain = lib.mkOption {
        type = lib.types.str;
        default = "wiki.theau.net";
        description = "Offline wiki domain.";
      };

      monitoringDomain = lib.mkOption {
        type = lib.types.str;
        default = "monitoring.theau.net";
        description = "Monitoring dashboard domain.";
      };
    };

    accessPolicies = lib.mkOption {
      type = lib.types.attrsOf policyType;
      default = { };
      description = "Extra or overriding Authelia policies keyed by web hostname.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.elem "wg-admin" cfg.groups;
        message = "personalInfra.services.userManagement.groups must include wg-admin for WGDashboard access control.";
      }
      {
        assertion = builtins.elem "admins" cfg.groups;
        message = "personalInfra.services.userManagement.groups must include admins for LLDAP administration.";
      }
    ];

    personalInfra.services.identityProvider = {
      enable = lib.mkDefault true;
      baseDn = cfg.baseDn;
      publicUrl = "https://${cfg.lldap.domain}";
      lldapAdminUser = cfg.lldap.adminUser;
      lldapAdminEmail = cfg.lldap.adminEmail;
      lldapAdminPasswordFile = cfg.lldap.adminPasswordFile;
    };

    personalInfra.services.authelia = {
      enable = lib.mkDefault true;
      listenAddress = cfg.authelia.listenAddress;
      baseDn = cfg.baseDn;
      ldapUrl = "ldap://${cfg.lldap.ldapAddress}:${toString cfg.lldap.ldapPort}";
      ldapUser = "uid=${cfg.lldap.adminUser},ou=people,${cfg.baseDn}";
      secrets = {
        jwtSecretFile = cfg.authelia.jwtSecretFile;
        storageEncryptionKeyFile = cfg.authelia.storageEncryptionKeyFile;
        ldapPasswordFile = cfg.authelia.ldapPasswordFile;
      };
      services = defaultAccessPolicies // cfg.accessPolicies;
    };

    personalInfra.services.caddy.virtualHosts = {
      ${cfg.authelia.domain} = {
        upstream = "http://127.0.0.1:9091";
        authPolicy = "public";
      };
      ${cfg.lldap.domain} = {
        upstream = "http://${cfg.lldap.httpAddress}:${toString cfg.lldap.httpPort}";
        authPolicy = "super-admin";
      };
    };
  };
}
