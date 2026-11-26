{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.yggdrasil-ng;
  tomlFormat = pkgs.formats.toml { };
in
{
  
  options.services.yggdrasil-ng = {
    enable = lib.mkEnableOption "yggdrasil-ng";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./yggdrasil-ng-drv.nix { };
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "yggdrasil";
      description = "The user on whose behalf the service will be launched.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ 
        "tcp://192.0.2.1:12345"
        "tls://peer.example.com:443?maxbackoff=30s&key=abcdef01..."
        "tls://203.0.113.5:2096?sni=peer.example.com&password=s3cr3t"
      ];
      description = ''
        List of connection strings for outbound peer connections in URI format.
        Supported schemes: tcp://, tls://
        You can find public peers at https://publicpeers.neilalexander.dev/
        Optional query parameters:
          key=HEX          - pin the remote peer's public key (connection fails if mismatch)
          password=SECRET  - shared password, must match the listener side (max 64 chars)
          priority=N       - connection priority 0-255, lower = preferred when multiple
                             connections exist to the same peer (default: 0)
          maxbackoff=DUR   - max reconnect wait if peer goes offline, e.g. 30s, 5m, 1h
                             (default: 4096s ≈ 68 min, minimum: 5s)
          sni=HOSTNAME     - override TLS SNI hostname, useful when connecting via IP
                             or through a reverse proxy (TLS only)
      '';
    };

    listen = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tcp://0.0.0.0:0" ];
      example = [
        "tcp://[::]:12345"
        "tls://[::]:443?password=s3cr3t"
      ];
      description = ''
        Listen addresses for inbound connections. You'll need to add port
        forwarding for these ports if you are behind a NAT/firewall.
        Supported schemes: tcp://, tls://
 
        Optional query parameters:
          password=SECRET  - require a shared password from connecting peers (max 64 chars)
      '';
    };

    adminListen = lib.mkOption {
      type = lib.types.str;
      default = "tcp://localhost:9001";
      description = ''
        Listen address for the admin socket.
        This is used by yggdrasil to query and control the node by default.
        Uncomment the line below and set `admin_listen = ""` to disable the admin socket.
      '';
    };

    privateKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "544d034a7dd31c582ae69ff4fe91660fedcb360e8686ff0958fdf83b93f57e936c2d08cb7e95dcda87af7fd0071349cd3390647603c0e23140a9a5e4913a613c";
      description = ''
        Your private key. DO NOT share this with anyone!
        This is a hex-encoded Ed25519 keypair (64 bytes = 128 hex characters).
        Delete this line and restart to generate a new identity.
      '';
    };

    ifName = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = ''
        Name of the TUN interface to use.
        "auto" = automatically assign a name.
        "none" = disable the TUN interface (useful for router-only nodes).
      '';
    };

    ifMtu = lib.mkOption {
      type = lib.types.int;
      default = 65535;
      description = "Maximum Transmission Unit (MTU) for the TUN interface.";
    };

    groupPassword = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Closed-network group password. When set, this node only establishes encrypted
        sessions with peers that use the EXACT same password, turning the mesh into a
        private closed network. Every member must share the same value;
        empty = open network. This is independent of the per-peer/per-multicast
        `password` above, which only authenticates direct links.
      '';
    };

    nodeInfoPrivacy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, your node_info will not be visible to other nodes.";
    };

    multicastInterfaces = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          filter = lib.mkOption {
            type = lib.types.str;
            default = "*";
          };
          beacon = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          listen = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 0;
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };
          password = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };
      });
      default = [ { } ];
      description = ''
        Multicast peer discovery — automatically finds and connects to nearby nodes
        on the local network without manual configuration.

        Each entry controls which network interfaces participate in discovery.
        Multiple entries can be added to apply different settings per interface.

        filter   - glob pattern to match interface names, e.g. "eth*", "en*", "*" (default: "*")
        beacon   - advertise this node's presence on matching interfaces (default: true)
        listen   - connect to other nodes discovered on matching interfaces (default: true)
        port     - TLS listener port for this interface, 0 = auto-assign (default: 0)
        priority - connection priority for peers found on this interface (0-255, lower = preferred),
                   used when the same peer is reachable via multiple connections
        password - shared password for discovery; only nodes with the same password
                   will discover each other on this interface (default: none)
      '';
    };

    allowedPublicKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        List of allowed public keys (hex-encoded). If non-empty, only peers with
        these public keys will be allowed to connect. Leave empty to allow all peers.
      '';
    };

    ckrEnable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Crypto-Key Routing (CKR) — tunnel arbitrary IPv4/IPv6 subnets through the Yggdrasil mesh.
        Bare IPv4/IPv6 addresses without prefix are also accepted (/32 and /128 respectively;
        applies to ~ and ! prefixed entries too)
        ‘~’ prefix means CKR tunnels without system routes. "inetv4"/"~inetv4" and
        "inetv6"/"~inetv6" expand to internet prefixes excluding internal networks.
        "!" excludes range from CKR, (e.g., "!142.250.109.0/24") for both normal
        and "~" prefixed includes. No "!inetv4" or "!inetv6" are supported.
      '';
    };
    
    ckrYggdrasilRouting = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    ckrInstallRoutes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically install system routing table entries for CKR.";
    };

    ckrIPAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
    };
   
    ckrRemoteSubnets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
    };

    firewallEnable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Built-in stateful firewall. Default policy when enabled: drop inbound
        from the mesh unless it's a reply to outbound traffic, comes from a
        whitelisted source subnet, or hits an explicitly opened port. Outbound
        is always allowed. Default off so servers reachable only via Yggdrasil
        keep working after upgrade.
      '';
    };

    firewallOpenTcp = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 22 80 443 ];
    };

    firewallOpenUdp = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ 53 ];
    };

    firewallOpenAllFor = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = [  ];
    };

    firewallAllowIcmpEcho = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    configFile = lib.mkOption {
       type = lib.types.nullOr lib.types.path;
       default = null;
       description = "Дефолтный конфиг";
    };
    settings = lib.mkOption {
      type = tomlFormat.type;
      default = {};
      description = "Произвольные настройки в TOML" ;
    };
  };

  config = lib.mkIf cfg.enable (
    let
      # итоговый конфиг: либо пользовательский файл, либо сгенерированный
      configFile =
        if cfg.configFile != null
        then cfg.configFile
        else tomlFormat.generate "config.toml" (cfg.settings // {
          private_key = cfg.privateKey;
          peers = cfg.peers;
          listen = cfg.listen;
          admin_listen = cfg.adminListen;
          if_name = cfg.ifName;
          if_mtu = cfg.ifMtu;
          group_password = cfg.groupPassword;
          # Node info
          node_info = {
            node_info_privacy = cfg.nodeInfoPrivacy;
            allowed_public_keys = cfg.allowedPublicKeys;
          };
          # Multicast peer discovery
          multicast_interfaces = cfg.multicastInterfaces;
          # CKR
          tunnel_routing = {
            enable = cfg.ckrEnable;
            yggdrasil_routing = cfg.ckrYggdrasilRouting;
            install_system_routes = cfg.ckrInstallRoutes;
            ip_addresses = cfg.ckrIPAddresses;
            remote_subnets = cfg.ckrRemoteSubnets;
          };
          # Firewall
          firewall = {
            enable = cfg.firewallEnable;
            open_tcp = cfg.firewallOpenTcp;
            open_udp = cfg.firewallOpenUdp;
            open_all_for = cfg.firewallOpenAllFor;
            allow_icmp_echo = cfg.firewallAllowIcmpEcho;
          };
        });
    in
    {
      environment.etc."yggdrasil-ng/config.toml".source = configFile;

      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.user;
        description = "yggdrasil-ng service user";
      };

      users.groups.${cfg.user} = { };
      
      systemd.services.yggdrasil-ng = {
        description = "yggdrasil-ng service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        requires = [ "network-online.target" ];
        restartTriggers = [ configFile ];
        serviceConfig = {
          ExecStart = [ "${cfg.package}/bin/yggdrasil-ng --config /etc/yggdrasil-ng/config.toml" ];
          User = cfg.user;
          Group = cfg.user;
          AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        };
      };
    }
  );
}