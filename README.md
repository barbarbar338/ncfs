# 🚀 NGROK to Cloudflare Tunnel Script

- This script will help you to create a tunnel to your local game server using ngrok and cloudflare.
- The best solution for people behind NAT or firewall.
- Creates a ngrok tcp tunnel and sets required dns record on cloudflare.
- Opens your local game server to world without any hassle.
- Port forwarding, firewall settings or any other configuration is not required, everything is handled by ngrok and cloudflare.

# 🐋 Use with docker
- To start using this script, you need to install docker and docker-compose.
- Download [`docker-compose.yml`](https://raw.githubusercontent.com/barbarbar338/ncfs/main/docker/docker-compose.yml) file
```yml
version: "3.8"

name: ncfs

networks:
    ncfs-net:

services:
    ncfs:
        image: barbarbar338/ncfs:buildx-latest 
        container_name: ncfs
        restart: unless-stopped
        ports:
            - 4040:4040
        networks:
            - ncfs-net
        environment:
            NGROK_TCP_PORT: <game server port here>
            NGROK_AUTH_TOKEN: <Your NGROK auth token here>
            CLOUDFLARE_AUTH_EMAIL: <Your Cloudflare email here>
            CLOUDFLARE_API_KEY: <Your Cloudflare Global API key here>
            CLOUDFLARE_ZONE_ID: <Your domain's Cloudflare Zone ID here>
            CLOUDFLARE_CNAME_RECORD_NAME: server.example.com
            # If the game supports SRV records, put the prefix here, otherwise leave blank
            CLOUDFLARE_SRV_RECORD_NAME: <SRV record name>
            CLOUDFLARE_SRV_RECORD_PREFIX: <SRV record prefix>
```
- Edit `docker-compose.yml` file as you wish.
- Run `docker-compose up -d` and wait
- You (and everyone in the world!) can now connect to your game server using your domain name.

# 📦 Templates
- You can use ready to use templates for your game server.
- To use a template, simply download the template file and run `docker-compose up -d -f <template file>`
- Currently these templates are supported:
    - Minecraft: https://raw.githubusercontent.com/barbarbar338/ncfs/main/templates/minecraft.yml
    - Terraria (TShock): https://raw.githubusercontent.com/barbarbar338/ncfs/main/templates/terraria.yml

# 🧦 Contributing

Feel free to use GitHub's features.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/my-feature`)
3. Commit your Changes (`git commit -m 'my awesome feature my-feature'`)
4. Push to the Branch (`git push origin feature/my-feature`)
5. Open a Pull Request

# 🔥 Show your support

Give a ⭐️ if this project helped you!

# 📞 Contact

- Mail: hi@338.rocks
- Discord: https://discord.gg/BjEJFwh
