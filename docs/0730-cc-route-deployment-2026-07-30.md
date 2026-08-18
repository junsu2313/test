# Opal `/cc` route deployment · 2026-07-30

## Result

The Opal user entry now redirects both `/cc` and `/cc/` to:

`/remote-ui/0716-1.1.html`

The active nginx fragment is:

`/etc/nginx/gl-conf.d/cc.conf`

The repository source for that fragment is:

`deploy/scripts/cc-nginx.conf`

## Deployment

- Device: GL.iNet Opal at `192.168.8.1`
- Web server: nginx with `/etc/nginx/gl-conf.d/*.conf` included
- Validation: `nginx -t` passed
- Reload: nginx master received `HUP`
- HTTP verification: `/cc` → `302 /remote-ui/0716-1.1.html`
- HTTP verification: `/cc/` → `302 /remote-ui/0716-1.1.html`

The previous legacy `/www/cc` directory was moved, not deleted, to:

`/root/d810-deploy-backups/20260730-cc-route-v2/legacy-cc`

The previous nginx route file was preserved at:

`/root/d810-deploy-backups/20260730-cc-route-v2/cc.conf`
