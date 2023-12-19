## Docker

### Use docker compose

- Create config.json

Download config.json

```bash
wget "https://raw.githubusercontent.com/barbarbar338/ncfs/main/config.json"
```

Open with text editor.
In reference to the [`config.scheme.json`](https://github.com/barbarbar338/ncfs/blob/main/config.schema.json), please create the `config.json`.

```bash
vim config.json
```

- Start with docker

```bash
sudo docer compose build
sudo docker compose up -d
```
