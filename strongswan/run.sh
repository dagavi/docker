#!/bin/sh

enableNetwork() {
    VPN_NETWORK="${1}"
    INTERFACE="$(ip route | grep default | cut -d' ' -f5)"

    echo "Configure iptables NAT MASQUERADE for ${VPN_NETWORK} on ${INTERFACE}"


    # Only forwrd packets from / to our VPN
    iptables -A FORWARD -s "${VPN_NETWORK}" -o "${INTERFACE}" -j ACCEPT || return $?
    iptables -A FORWARD -d "${VPN_NETWORK}" -i "${INTERFACE}" -j ACCEPT

    # Rules from: https://wiki.strongswan.org/projects/strongswan/wiki/ForwardingAndSplitTunneling
    iptables -t nat -A POSTROUTING -s "${VPN_NETWORK}" -o "${INTERFACE}" -m policy --dir out --pol ipsec -j ACCEPT
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

        # Rules from: https://wiki.strongswan.org/projects/strongswan/wiki/ForwardingAndSplitTunneling
        iptables -t nat -I POSTROUTING -m policy --pol ipsec --dir out -j ACCEPT

        iptables -nL
        iptables -t nat -nL
    fi
}

delayedExecution() {
    ITERATIONS=60
    if [ ! -z "${SWANCTL_CHARON_WAIT_SECONDS}" ];
    then
        ITERATIONS="${SWANCTL_CHARON_WAIT_SECONDS}"
    fi

    if [ "${ITERATIONS}" -gt 0 ];
    then
        ITERATION=1
        while [ "${ITERATION}" -lt "${ITERATIONS}" ] && ! ps | grep "ipsec/charon" | grep -vq grep;
        do
            ITERATION=$((ITERATION + 1))
            sleep 1
        done

        if ps | grep "ipsec/charon" | grep -vq grep;
        then
            # Give one second more to ensure that charon.vici listens incoming connections
            sleep 1
            echo "Charon working"
            swanctl --load-all
            swanctl --list-conns
        else
            echo "Error: swanctl not executed because charon was not detected running"
        fi
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

    if [ -e /dev/ppp ];
    then
        echo "Launching xl2tpd"
        xl2tpd
    else
        echo "Don't launch xl2tpd because /dev/ppp doesn't exists"
        echo "To enable xl2tpd support pass /dev/ppp device to the container"
    fi

    echo "Executing StrongSwan"
    delayedExecution &

    ipsec start --nofork
}

main
