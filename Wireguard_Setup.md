# Exposing private cluster over public internet

This guide assumes that you're using a VM in OCI - this is not required and you can use any other cloud provider with slight changes to follow this guide.
This guide also assumes that the wireguard client and server are using ubuntu - you can change the installation commands for your distro and follow this guide.


## Create the VM in OCI with a .pem file for ssh access

Make sure you're able to ssh into the VM. Then run the following commands:

```
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo apt-get install docker-compose wireguard -y
sudo reboot
```

## Setting up DuckDNS

This step is only needed if you don't own a domain already.
Create an account on [DuckDNS](https://www.duckdns.org/). After logging in, you'll see your token and your list of subdomains.
Create a new subdomain and keep it's value handy for the following command.

```
mkdir duckdns
cd duckdns
# Using DuckDNS for a subdomain - update subdomains list and token value
sudo docker run -d \
  --name=duckdns \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Kolkata \
  -e SUBDOMAINS=example.duckdns.org \
  -e TOKEN=token_value \
  -e LOG_FILE=true \
  -v `pwd`:/config `#optional` \
  --restart unless-stopped \
  lscr.io/linuxserver/duckdns:latest

# Go back to the home dir
cd ..
```
  
## Setting up Nginx Proxy Manager

Open only port 80 and 443 on the VM subnet settings.

Port 8080 is for managing your proxy manager (with the port mapping in this config) - by default it will have very weak creds - we'll port forward the port over SSH to configure this securely later.
```
mkdir nginx-proxy-manager
vim docker-compose.yml
```

Paste the following into the file. Update username and passwords as needed.
```
version: "3"
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      # These ports are in format <host-port>:<container-port>
      - '80:80' # Public HTTP Port
      - '443:443' # Public HTTPS Port
      - '8080:81' # Admin Web Port
      # Add any other Stream port you want to expose
      # - '21:21' # FTP
    environment:
      DB_MYSQL_HOST: "db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "username"
      DB_MYSQL_PASSWORD: "password"
      DB_MYSQL_NAME: "username"
      # Uncomment this if IPv6 is not enabled on your host
      DISABLE_IPV6: 'true'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - db

  db:
    image: 'jc21/mariadb-aria:latest'
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: 'password'
      MYSQL_DATABASE: 'username'
      MYSQL_USER: 'username'
      MYSQL_PASSWORD: 'password'
    volumes:
      - ./data/mysql:/var/lib/mysql
```

Deploy nginx proxy manager.
```
sudo docker-compose up -d
```
In case you need to restart this compose after the wireguard connection - make sure to delete the data and letsencypt dirs.


SSH using -L flag to port forward 8080
```
ssh -L 8080:127.0.0.1:8080 ubuntu@IP
```
In your local go to http://localhost:8080/login
Update the username and password from admin@example.com/changeme to something more secure



## Setting up Wireguard

Many cloud providers use something called CGNAT to stop wireguard traffic. 
Follow the steps mentioned in this [repo](https://github.com/mochman/Bypass_CGNAT.git) to get around this.

In the following instructions:

Client = Raspberry Pi/VM running HAProxy

Server = VPS in the cloud

Assuming that you're using OCI as your cloud provider, you may have to follow the instructions below to fix some issues with the script.

- Modify the Endpoint on the client side to use the duckdns subdomain
- Fix the public key on the client side - this will requre regenerating the wg keys for both client and server as the script seems to mess up the public key on the client side

```
# On both client and server
wg genkey | tee privatekey | wg pubkey > publickey
```

- Copy the private key from file 'privatekey' and update in this file

```
sudo vim /etc/wireguard/wg0.conf
```
- Copy the publickey of client and move to the config of server and also the other way around

On clinet run this and select this option --> 2) Reload Wireguard Service
Just press enter from that point onwards

```
# Only on the client
./Oracle_Installer.sh
sudo systemctl restart wg-quick@wg0.service
```

- Make sure the server and client are able to ping each other
- One way to check this is to use wg show

```
sudo wg show
```
- If you see anything in the 'transfer' section - then this means the VPN is working!


## Notes

Make sure that your IP is not being leaked by checking your subdomain in https://ipleak.net/
