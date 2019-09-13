#!/bin/sh

enableNetwork() {
    VPN_NETWORK="${1}"
    INTERFACE="$(ip route | grep default | cut -d' ' -f5)"

    echo "Configure iptables NAT MASQUERADE for ${VPN_NETWORK} on ${INTERFACE}"


    # Only forwrd packets from / to our VPN
    iptables -A FORWARD -s "${VPN_NETWORK}" -o "${INTERFACE}" -j ACCEPT || return $?
    iptables -A FORWARD -d "${VPN_NETWORK}" -i "${INTERFACE}" -j ACCEPT

    iptables -t nat -A POSTROUTING -s "${VPN_NETWORK}" -o "${INTERFACE}" -j MASQUERADE
}

systemConfiguration() {
    if [ -z "${VPN_POOLS}" ];
    then
        echo "WARNING: No pools configured on VPN_POOLS to be openen on iptables"
    else
        iptables -P FORWARD DROP

        for POOL in ${VPN_POOLS}
        do
            enableNetwork "${POOL}" || return $?
        done

        iptables -nL
        iptables -t nat -nL
    fi
}

main() {
    echo "System configuration"
    if ! systemConfiguration;
    then
        echo "System configuration returned and error."
        echo "Check the VPN_POOLS variable. Current value: ${VPN_POOLS}"
        echo "This variable should have one or more pools separated by spaces."
        echo "Example:"
        echo "    VPN_POOL=\"10.1.0.0/16 10.2.0.0/16\""
        exit 1
    fi

    echo "Executing OpenVPN"
    openvpn /server.ovpn
}

main
