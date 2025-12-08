-- Initialize databases and users for shared MariaDB instance
-- This script runs automatically when the container is first created

-- Create Nextcloud database and user
CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'nextcloud'@'%' IDENTIFIED BY '${NEXTCLOUD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';

-- Create Firefly III database and user
CREATE DATABASE IF NOT EXISTS firefly CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'firefly'@'%' IDENTIFIED BY '${FIREFLY_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON firefly.* TO 'firefly'@'%';

-- Flush privileges to ensure changes take effect
FLUSH PRIVILEGES;
