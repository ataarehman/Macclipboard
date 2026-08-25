# MacClipboard website

Public product site for **https://macclipboard.mernify.co**

Light Apple-style landing (same layout language as mac-stats.com): sticky header, large headline, black download button, MacBook hero, feature tabs.

## Deploy on the existing VPS

DNS already points `macclipboard.mernify.co` at `209.126.9.159`. Upload this folder to the server and add an nginx vhost:

```bash
sudo mkdir -p /var/www/macclipboard
# copy website/ contents into /var/www/macclipboard
```

```nginx
server {
    listen 80;
    server_name macclipboard.mernify.co;
    root /var/www/macclipboard;
    index index.html;
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

Then enable HTTPS:

```bash
sudo certbot --nginx -d macclipboard.mernify.co
```

Put the latest app zip at `website/downloads/MacClipboard.zip` so the Download button works.

```bash
mkdir -p website/downloads
cp dist/MacClipboard.zip website/downloads/MacClipboard.zip
```

This site has no analytics.
