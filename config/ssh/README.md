Place your SSH public keys in `authorized_keys` to enable key-based SFTP/SSH access for the `sftp` service.

Example:

  config/ssh/authorized_keys

If you prefer password access, set `PASSWORD_ACCESS=true` and `USER_PASSWORD` in `.env`,
otherwise the container defaults to key-only access.

