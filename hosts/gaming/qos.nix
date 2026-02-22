{ pkgs, ... }:

let
  ip = "${pkgs.iproute2}/bin/ip";
  tc = "${pkgs.iproute2}/bin/tc";
in
{
  # Load ifb at boot with the module option applied on first load
  boot.kernelModules = [ "ifb" ];
  boot.extraModprobeConfig = "options ifb numifbs=1";

  systemd.services.cake-qos = {
    description = "CAKE QoS (egress + ingress via IFB) on enp7s0";
    after   = [ "network-online.target" "sys-subsystem-net-devices-enp7s0.device" ];
    wants   = [ "network-online.target" ];
    bindsTo = [ "sys-subsystem-net-devices-enp7s0.device" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Tune these. Start here for 1G service.
      Environment = [
        "DEV=enp7s0"
        "IFB=ifb0"
        "DOWN=950Mbit"
        "UP=950Mbit"
      ];
    };

    script = ''
      set -euo pipefail

      # Clean up old state if present
      ${tc} qdisc del dev "$DEV" root 2>/dev/null || true
      ${tc} qdisc del dev "$DEV" ingress 2>/dev/null || true
      ${tc} qdisc del dev "$IFB" root 2>/dev/null || true
      ${ip} link del "$IFB" 2>/dev/null || true

      # Create IFB for ingress shaping
      ${ip} link add "$IFB" type ifb
      ${ip} link set "$IFB" up

      # Egress CAKE (uploads) — diffserv4 prioritises DSCP-marked gaming/VoIP over bulk
      ${tc} qdisc replace dev "$DEV" root cake bandwidth "$UP" diffserv4 ack-filter

      # Ingress redirect to IFB
      ${tc} qdisc add dev "$DEV" handle ffff: ingress
      ${tc} filter add dev "$DEV" parent ffff: protocol all u32 match u32 0 0 action mirred egress redirect dev "$IFB"

      # Ingress CAKE (downloads)
      ${tc} qdisc replace dev "$IFB" root cake bandwidth "$DOWN" diffserv4
    '';

    postStop = ''
      ${tc} qdisc del dev "$DEV" root 2>/dev/null || true
      ${tc} qdisc del dev "$DEV" ingress 2>/dev/null || true
      ${tc} qdisc del dev "$IFB" root 2>/dev/null || true
      ${ip} link del "$IFB" 2>/dev/null || true
    '';
  };
}
