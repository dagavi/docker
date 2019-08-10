#!/bin/sh

function systemConfiguration {
    VPN_NETWORK="10.0.0.0/8"
    INTERFACE="$(ip route | grep default | cut -d' ' -f5)"

    sysctl net.ipv4.ip_forward=1
    sysctl net.ipv4.conf.all.accept_redirects=0
    sysctl net.ipv4.conf.all.send_redirects=0

    iptables -F

    # Only forwrd packets from / to our VPN
    iptables -P FORWARD DROP
    iptables -A FORWARD -s ${VPN_NETWORK} -o "${INTERFACE}" -j ACCEPT
    iptables -A FORWARD -d ${VPN_NETWORK} -i "${INTERFACE}" -j ACCEPT

    # Reglas extraidas de: https://wiki.strongswan.org/projects/strongswan/wiki/ForwardingAndSplitTunneling
    iptables -t nat -A POSTROUTING -s ${VPN_NETWORK} -o "${INTERFACE}" -m policy --dir out --pol ipsec -j ACCEPT
    iptables -t nat -A POSTROUTING -s ${VPN_NETWORK} -o "${INTERFACE}" -j MASQUERADE
    iptables -t nat -I POSTROUTING -m policy --pol ipsec --dir out -j ACCEPT

    iptables --list
    iptables -t nat --list
}

function delayedExecution {
    sleep 2
    swanctl --load-all
    swanctl --list-conns
}

echo "System configuration"
systemConfiguration

echo "Executing StrongSwan"
delayedExecution &

ipsec start --nofork
