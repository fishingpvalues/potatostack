# How to fix Vaultwarden HTTPS issue

The issue with accessing Vaultwarden via HTTPS is likely due to your browser not trusting the self-signed certificate used by Traefik.

To fix this, you need to import the local Certificate Authority (CA) certificate into your browser's or your operating system's trust store.

The CA certificate is located at `config/traefik/certs/ca.crt`.

The script `scripts/setup/generate-local-certs.sh` provides instructions on how to do this for different operating systems:

**Linux:**
```bash
sudo cp config/traefik/certs/ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain config/traefik/certs/ca.crt
```

**Windows:**
```powershell
certutil -addstore -f "ROOT" config\traefik\certs\ca.crt
```

After importing the certificate, you may need to restart your browser.

If you are using Tailscale's MagicDNS, you should ensure that it is configured correctly to resolve `*.danielhomelab.local` to the IP address of your server.

