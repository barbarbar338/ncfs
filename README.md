# 🚀 NGROK to Cloudflare Tunnel Script

- This script will help you to create a tunnel to your local minecraft server using ngrok and cloudflare.
- The best solution for people behind NAT or firewall.
- Creates a ngrok tcp tunnel and sets required dns record on cloudflare.
- Opens your local minecraft server to world without any hassle.
- Port forwarding, firewall settings or any other configuration is not required, everything is handled by ngrok and cloudflare.

# 🏃 How to use

1. Clone this repository
2. Fill `config.json` file with your credentials
3. Create a CNAME record on your cloudflare DNS dashboard pointing to domain you set in `config.json`
4. Create a SRV record on your cloudflare DNS dashboard pointing to domain you set in `config.json`
5. Run `ncfs.sh` and wait
6. You (and everyone in the world!) can now connect to your minecraft server using your domain name.

# 🐋 Use with docker
- To start using this script with docker, you need to install docker and docker-compose.
- After installing docker and docker-compose, you have to create a configuration file. Please follow step 2, 3 and 4 from [How to use](#-how-to-use) section.
- After creating the configuration file, download `docker-compose.yml` file.
    ```bash
    wget "https://raw.githubusercontent.com/barbarbar338/ncfs/main/docker/docker-compose.yml"
    ```
- Edit `docker-compose.yml` file as you wish.
- Run `docker-compose up -d` and wait
- You (and everyone in the world!) can now connect to your minecraft server using your domain name.

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
