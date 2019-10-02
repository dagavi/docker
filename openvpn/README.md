# OpenVPN
![enter image description here](https://i.imgur.com/7yw81Uu.png)

Simple image containing a self-builded OpenVPN 2.4.7 with images for Linux 86_64 and ARM (for Raspberry Pi 2, for example).

The image does not provide any helper script to make base configurations. You will need to configure OpenVPN as you want mapping configuration files.

# iptables
iptables is called on startup (`/run.sh`) and configures the NAT table to aply MASQUERADE to the packets that match source address in the pools configured in the enviorement variable `VPN_POOLS`.

`VPN_POOLS` should contain a list of IP pools, separated by comma.  For example: `10.0.0.0/16 10.1.0.0/16`

# Usage

You should map your configuration as "/server.ovpn".

# Links
 - [OpenVPN](https://openvpn.net/)

