# StrongSwan
![enter image description here](https://i.imgur.com/p83gWIt.png)

Simple image containing a self-builded StrongSwan 5.8.0 with images for Linux 86_64 and ARM (for Raspberry Pi 2, for example) and  XL2TPd (to enable the possibility of making L2TP/IPSec tunnels).

If you map the device `/dev/ppp` the container will run **xl2tpd** on start.

The image does not provide any helper script to make base configurations. You will need to configure StrongSwan as you want mapping configuration files.

The image uses **starter** (`ipsec start`) to launch StrongSwan, but then it will call [**swanctl**](https://wiki.strongswan.org/projects/strongswan/wiki/Swanctl) (`swanctl --load-all`) so you can use the **starter** configurations ([`/etc/ipsec.conf`](https://wiki.strongswan.org/projects/strongswan/wiki/IpsecConf) file, [`/etc/ipsec.secrets`](https://wiki.strongswan.org/projects/strongswan/wiki/IpsecSecrets) file, [`/etc/ipsec.d`](https://wiki.strongswan.org/projects/strongswan/wiki/IpsecDirectory) directory) and/or the [**swanctl**](https://wiki.strongswan.org/projects/strongswan/wiki/Swanctl) ([`/etc/swanctl.conf`](https://wiki.strongswan.org/projects/strongswan/wiki/Swanctlconf) file, [`/etc/swanctl`](https://wiki.strongswan.org/projects/strongswan/wiki/SwanctlDirectory) directory).

# iptables
iptables is called on startup (`/run.sh`) and configures the NAT table to aply MASQUERADE to the packets that match source address in the pools configured in the enviorement variable `VPN_POOLS`.

`VPN_POOLS` should contain a list of IP pools, separated by comma.  For example: `10.0.0.0/16 10.1.0.0/16`

# Example
## VPN to route all the traffic of the users through the IKEv2 VPN server
In this example we want to configure a IKEv2 VPN server that will be used to route all the traffic of the users.
### Create certificates
We will create a CA that will issue the client and server certificates using **`openssl`**.
In this example we will work inside a folder called `ca` with `certs`, `csr` and `keys` subfolders.

    mkdir -p ca/certs
    mkdir -p ca/csr
    mkdir -p ca/keys

#### Obtain openssl
`openssl` is not included in the image. You can use it from any other place, like your host or a docker container executing:

    docker run --rm -it -v${PWD}/ca:/ca alpine
    apk add openssl

#### Generate the CA certificate and key
This commands generates a self-signed certificate for the CA:

    openssl req -new -x509 -days 3650 -extensions v3_ca -keyout ca/keys/cakey.pem -out ca/certs/cacert.pem

Stores the new CA private key in `ca/keys/cakey.pem` and the certificate in `ca/certs/cacert.csr`.

You can add `-nodes` argument to avoid encrypt the private key with a password. In this example we will supose that we used `capassword` as encryption password.

#### Generate the VPN server certificate
We will create a certificate for the VPN server using our previously created CA.

##### Generate the certificate request:

    openssl req -new -keyout ca/keys/vpn_server_key.pem -out ca/csr/vpn_server.csr

Stores the new VPN server private key in `ca/keys/vpn_server_key.pem` and the certificate request in `ca/csr/vpn_server.csr`.

You can add `-nodes` argument to avoid encrypt the private key with a password. In this example we will supose that we used `serverpassword` as encryption password.

##### Generate and sign the certificate

    openssl x509 -req -CA ca/certs/cacert.pem -CAkey ca/keys/cakey.pem -CAcreateserial -in ca/csr/vpn_server.csr -out ca/certs/vpn_server_cert.pem -days 3650 -sha256

Stores the new signed certificate  in `ca/keys/vpn_server_cert.pem`.

If you CA private key is encrypted you will be asked for the password, in this example `capassword`.

### Configure StrongSwan and prepare a docker-compose.yml
At this point we have this files that we will need to use on the server:

 - Server certificate: `ca/keys/vpn_server_cert.pem`
 - Server private key: `ca/keys/vpn_server_key.pem`
 - CA certificate: `ca/certs/cacert.csr`

Now we will cover two methods to configure our VPN that will use the pool 10.100.0.0/16 as IP pool. They are equivalent, so you only need to use one.

This methods needs to put this files in different locations, but we will use Docker volume mapping to map the files in the correct location in every case.

#### With starter
##### File: ipsec.conf

    conn %default
        ikelifetime=60m
        keylife=20m
        rekeymargin=3m
        keyingtries=1

        leftcert=vpn_server_cert.pem
        leftsubnet=0.0.0.0/0
        rightsourceip=10.100.0.0/16

    conn myVPN
        keyexchange=ikev2
        auto=add

##### File: ipsec.secrets
You only need to modify this file if you set a password to the private key of the server (`vpn_server_key.pem`)


    : RSA vpn_server_key.pem serverpassword

##### File: docker-compose.yml

    version: "3"

    services:
        strongswan:
            image: dagavi/strongswan:latest
            restart: always
            volumes:
                - ./ca/certs/vpn_server_cert.pem:/etc/ipsec.d/certs/vpn_server_cert.pem:ro
                - ./ca/keys/vpn_server_key.pem:/etc/ipsec.d/private/vpn_server_key.pem:ro
                - ./ca/certs/cacert.pem:/etc/ipsec.d/cacerts/cacert.pem:ro
                - ./ipsec.conf:/etc/ipsec.conf:ro
                # Only if you have some password on ipsec.secrets
                - ./ipsec.secrets:/etc/ipsec.secrets:ro
            ports:
                - 500:500/udp
                - 4500:4500/udp
            cap_add:
                - NET_ADMIN
            environment:
                VPN_POOLS: "10.100.0.0/16"

#### With swanctl
##### File: myVpn.conf

    connections {
    
        myVPN {
    
            pools = myVpnIPv4RWPool
    
            local-serverCert {
                auth = pubkey
                certs = vpn_server_cert.pem
            }
    
            remote-rsa {
                auth = pubkey
                cacerts = cacert.pem
            }
    
            children {
                myVPN {
                    local_ts = 0.0.0.0/0
                }
            }
        }
    }
    
    secrets {
        private-myVpnServerCert {
            file = vpn_server_key.pem
            # Only if you configured a password for the private key
            secret = serverpassword
        }
    }
    
    pools {
        myVpnIPv4RWPool {
            addrs = 10.100.0.0/16
        }
    }

##### File: docker-compose.yml

    version: "3"
    
    services:
        strongswan:
            image: dagavi/strongswan:latest
            restart: always
            volumes:
                - ./ca/certs/vpn_server_cert.pem:/etc/swanctl/x509/vpn_server_cert.pem:ro
                - ./ca/keys/vpn_server_key.pem:/etc/swanctl/private/vpn_server_key.pem:ro
                - ./ca/certs/cacert.pem:/etc/swanctl/x509ca/cacert.pem:ro
                - ./myVpn.conf:/etc/swanctl/conf.d/myVpn.conf:ro
            ports:
                - 500:500/udp
                - 4500:4500/udp
            cap_add:
                - NET_ADMIN
            environment:
                VPN_POOLS: "10.100.0.0/16"

### Run the server
With the `docker-compose.yml` we only need to launch docker-compose to start the server:

    docker-compose up -d

### Generate a client certificate
We will create a certificate for a client. We will reproduce the same steps that we made to generate the server certificate in the previous step, but changing the output:

#### Generate the certificate request:

    openssl req -new -keyout ca/keys/some_client_key.pem -out ca/csr/some_client.csr

Stores the new client private key in `ca/keys/some_client_key.pem` and the certificate request in `ca/csr/some_client.csr`.

You can add `-nodes` argument to avoid encrypt the private key with a password. In this example we will supose that we used `clientpassword` as encryption password.

#### Generate and sign the client certificate

    openssl x509 -req -in ca/csr/some_client.csr -CA ca/certs/cacert.pem -CAkey ca/keys/cakey.pem -CAcreateserial -out ca/certs/some_client_cert.pem -days 3650 -sha256

Stores the new signed client certificate  in `ca/keys/some_client_cert.pem`.

If you CA private key is encrypted you will be asked for the password, in this example `capassword`.

#### Extra: Generating a client PKCS#12 file
To use the client cetficiate on some systems, like a Android device, it will be convenient to bundle the client cetificate and private key and the CA certificate in a [PKCS#12](https://en.wikipedia.org/wiki/PKCS_12) file that you can use on the other system:

    mkdir ca/pkcs12
    openssl pkcs12 -in ca/certs/some_client_cert.pem -inkey ca/keys/some_client_key.pem -certfile ca/certs/cacert.pem -export -out ca/pkcs12/some_client.p12 -name "Some Name"

If you client private key is encrypted you will be asked for the password, in this example `clientpassword`.

You will be asked for a `Export Password` that is a password that will be used to encrypt the PKCS#12 file and is different to the client password.

Now you can import `ca/pkcs12/some_client.p12` to your system.

# Links
 - [StrongSwan](https://strongswan.org/)
