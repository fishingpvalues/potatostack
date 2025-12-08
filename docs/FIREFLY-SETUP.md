# Firefly III + FinTS Setup Guide for Deutsche Bank

This guide walks you through setting up Firefly III with automated Deutsche Bank transaction imports via FinTS (Financial Transaction Services).

## Overview

**Firefly III** is a self-hosted personal finance manager with:
- Advanced budgeting and forecasting
- Automated transaction imports
- Rule-based categorization
- Multi-account support
- Beautiful dashboards and reports

**FinTS Importer** automatically fetches transactions from Deutsche Bank and imports them into Firefly III daily.

## Architecture

```
Deutsche Bank (FinTS API)
         ↓
  FinTS Importer (8086)
         ↓
   Firefly III (8085)
         ↓
  MariaDB + Redis
         ↓
 Prometheus Monitoring
         ↓
  Authelia 2FA Protection
```

## Prerequisites

1. ✅ Docker Compose deployed
2. ✅ `.env` file created from `.env.example`
3. ✅ Nginx Proxy Manager configured (optional, for HTTPS)
4. ✅ Authelia configured (optional, for SSO/2FA)
5. 📋 Deutsche Bank online banking credentials
6. 📋 Deutsche Bank photoTAN app (recommended) or other TAN method

## Step 1: Generate Firefly III Application Key

Before deploying, you need to generate a secure application key:

```bash
# Generate the key
docker run --rm fireflyiii/core:latest php artisan key:generate --show

# Example output:
# base64:XYZ123ABC456... (copy everything including "base64:")
```

Add this to your `.env` file:
```bash
FIREFLY_APP_KEY=base64:XYZ123ABC456...
```

## Step 2: Set Database Passwords

In your `.env` file, set strong passwords:

```bash
FIREFLY_DB_ROOT_PASSWORD=$(openssl rand -base64 32)
FIREFLY_DB_PASSWORD=$(openssl rand -base64 32)
```

## Step 3: Create Required Directories

```bash
# Create backup directory
mkdir -p /mnt/seconddrive/backups/db

# Verify FinTS config directory exists
ls -la config/fints-importer/
```

## Step 4: Deploy Firefly III

```bash
# Deploy all services
docker compose up -d firefly-db firefly-redis-worker firefly-iii firefly-worker firefly-cron

# Check logs
docker logs -f firefly-iii

# Wait for initialization (first run takes ~60 seconds)
```

## Step 5: Initial Firefly III Setup

1. **Access Firefly III**:
   - Direct: `http://192.168.178.40:8085`
   - Via NPM: `https://firefly.lepotato.local`

2. **Create Admin Account**:
   - Email: `admin@lepotato.local` (or your email)
   - Password: Create a strong password
   - Store credentials in Vaultwarden!

3. **Complete Initial Setup**:
   - Set currency: EUR (or your preference)
   - Create your first asset account:
     - Name: "Deutsche Bank Checking"
     - Type: "Asset account"
     - Account role: "Default asset account"
     - Opening balance: Your current balance
     - Opening balance date: Today

4. **Note the Account ID**:
   - After creating, click the account
   - Look at the URL: `...firefly.../accounts/show/1`
   - The number at the end (e.g., `1`) is your account ID
   - You'll need this for FinTS configuration

## Step 6: Generate Personal Access Token

For the FinTS Importer to communicate with Firefly III:

1. In Firefly III, go to **Options** → **Profile** → **OAuth**
2. Scroll to **Personal Access Tokens**
3. Click **Create New Token**
4. Name: `FinTS Importer`
5. Click **Create**
6. **IMPORTANT**: Copy the token immediately (shown only once!)
7. Add to your `.env` file:
   ```bash
   FIREFLY_ACCESS_TOKEN=your_very_long_token_here
   ```

## Step 7: Configure Deutsche Bank FinTS Connection

### Find Your Deutsche Bank Details

1. Log into Deutsche Bank online banking
2. Find your:
   - Account number
   - IBAN
   - Available TAN methods (Settings → Security)

### Create FinTS Configuration

Create `config/fints-importer/deutsche-bank.json`:

```json
{
  "version": 2,
  "name": "Deutsche Bank Import",
  "url": "https://fints.deutsche-bank.de/fints",
  "bank_code": "50010517",
  "username": "YOUR_DB_USERNAME",
  "pin": "YOUR_DB_PIN",
  "accounts": [
    {
      "account_number": "YOUR_ACCOUNT_NUMBER",
      "iban": "DE89370400440532013000",
      "firefly_account_id": 1,
      "name": "Deutsche Bank Checking"
    }
  ],
  "tan_mechanism": "photoTAN",
  "import_settings": {
    "days_back": 7,
    "skip_duplicates": true,
    "map_payees": true,
    "create_rules": true
  }
}
```

**Important Configuration Notes**:
- `url`: Use `https://fints.deutsche-bank.de/fints` (official Deutsche Bank FinTS endpoint)
- `bank_code`: `50010517` for Deutsche Bank AG (standard BLZ)
- `username`: Your Deutsche Bank online banking username
- `pin`: Your online banking PIN (NOT TAN!)
- `firefly_account_id`: The account ID from Step 5.4
- `tan_mechanism`:
  - `photoTAN` (recommended - use Deutsche Bank photoTAN app)
  - `mobileTAN` (SMS-based)
  - `chipTAN` (card reader)
- `days_back`: How many days of historical transactions to fetch on first import

### Security Warning

⚠️ **CRITICAL**: This file contains your banking credentials!

- **NEVER** commit to git (already excluded in `.gitignore`)
- Store the file with restrictive permissions:
  ```bash
  chmod 600 config/fints-importer/deutsche-bank.json
  ```
- Consider encrypting with `age` or similar:
  ```bash
  age -e -R ~/.ssh/id_ed25519.pub \
    config/fints-importer/deutsche-bank.json > \
    config/fints-importer/deutsche-bank.json.age
  ```

## Step 8: Deploy FinTS Importer

```bash
# Update the stack with importer
docker compose up -d fints-importer fints-cron

# Check logs
docker logs -f fints-importer
```

## Step 9: Test FinTS Connection

### Manual Test via GUI

1. Access FinTS Importer: `http://192.168.178.40:8086`
2. Click **"Configure"** or **"Add Configuration"**
3. Upload your `deutsche-bank.json` OR enter details manually
4. Click **"Test Connection"**
5. If prompted, enter TAN from your photoTAN app
6. Verify connection success

### Manual Import Test

1. In FinTS Importer GUI, click **"Import"**
2. Select date range (e.g., last 7 days)
3. Click **"Start Import"**
4. Complete TAN challenge if prompted
5. Wait for import to complete
6. Check Firefly III → **Transactions** to verify imports

### Troubleshooting Connection Issues

**Error: "Invalid credentials"**
- Verify username and PIN are correct
- Check if account is locked (too many failed attempts)
- Try logging into Deutsche Bank web interface first

**Error: "TAN required"**
- Install Deutsche Bank photoTAN app on your phone
- Scan QR code when prompted
- Enter TAN in importer

**Error: "Connection timeout"**
- Deutsche Bank FinTS servers may be down (rare)
- Check https://www.hbci-zka.de/ for known issues
- Try again in a few minutes

**Error: "Invalid bank code"**
- Verify BLZ is `50010517`
- Some Deutsche Bank branches use different codes
- Check your account statement for exact BLZ

## Step 10: Enable Automated Daily Imports

The `fints-cron` container runs daily imports automatically. To verify:

```bash
# Check cron container logs
docker logs fints-cron

# Should show:
# "Running FinTS import at [timestamp]..."
# "Next import in 24 hours..."
```

### Customize Import Schedule

Edit `docker-compose.yml`, find `fints-cron` service:

```yaml
# For twice-daily imports (every 12 hours)
sleep 43200

# For hourly imports (not recommended - may trigger rate limits)
sleep 3600
```

Then restart:
```bash
docker compose restart fints-cron
```

## Step 11: Configure Firefly III Rules (Auto-Categorization)

Make transaction management easier with automatic rules:

1. In Firefly III, go to **Automation** → **Rules**
2. Click **Create New Rule**
3. Example rules:

   **Grocery Store Auto-Category**:
   - Trigger: Description contains "REWE" OR "EDEKA" OR "ALDI"
   - Action: Set category to "Groceries"

   **Salary Recognition**:
   - Trigger: Description contains "GEHALT" AND Amount > 1000
   - Action: Set category to "Income: Salary"

   **Rent Payment**:
   - Trigger: Description contains "MIETE" AND Amount is about -800
   - Action: Set category to "Housing: Rent"

4. Click **Test Rule** on existing transactions to verify
5. Enable **"Active"** to apply to future imports

## Step 12: Set Up Budgets

1. Go to **Budgets** → **Create Budget**
2. Create monthly budgets:
   - Groceries: €400
   - Dining Out: €150
   - Transportation: €100
   - Entertainment: €80
   - Utilities: €200

3. Firefly will track spending against budgets automatically

## Step 13: Configure Monitoring

Prometheus is already configured to monitor:
- Firefly III uptime (`blackbox-http` job)
- Database connectivity (`blackbox-tcp` job)
- External accessibility

### Create Grafana Dashboard

1. Access Grafana: `http://192.168.178.40:3000`
2. Create **New Dashboard** → **Add Panel**
3. Query examples:

   **Firefly III Uptime**:
   ```promql
   probe_success{instance="http://firefly-iii:8080"}
   ```

   **Database Response Time**:
   ```promql
   probe_duration_seconds{instance="firefly-db:3306"}
   ```

   **Import Success Rate**:
   ```promql
   rate(firefly_importer_success_total[1h])
   ```

## Step 14: Configure Backup Verification

Daily database backups run automatically. Verify:

```bash
# Check backup container logs
docker logs firefly_db_backup

# List backups
ls -lh /mnt/seconddrive/backups/db/firefly-db-*.sql.gz

# Test restore (dry-run)
docker exec -it firefly-db bash
zcat /backups/firefly-db-YYYY-MM-DD-HHMM.sql.gz | mysql -u firefly -p firefly --dry-run
```

## Step 15: Enable HTTPS via Nginx Proxy Manager (Optional)

1. Access NPM: `http://192.168.178.40:81`
2. Add **Proxy Host**:
   - Domain: `firefly.lepotato.local`
   - Scheme: `http`
   - Forward Hostname: `firefly-iii`
   - Forward Port: `8080`
   - Websockets: ✅ Enabled (for real-time updates)
   - SSL: Request Let's Encrypt certificate OR use self-signed

3. Repeat for FinTS Importer:
   - Domain: `fints.lepotato.local`
   - Forward to: `fints-importer:8080`

4. Update `/etc/hosts` on your client:
   ```
   192.168.178.40  firefly.lepotato.local
   192.168.178.40  fints.lepotato.local
   ```

## Step 16: Enable Authelia 2FA Protection (Optional)

Already configured! Access control requires two-factor auth for:
- `firefly.lepotato.local`
- `fints.lepotato.local`

Users in `users` or `admins` groups can access after 2FA.

## Alternative: CSV Import (Fallback)

If FinTS doesn't work or you prefer manual control:

### Download from Deutsche Bank

1. Log into Deutsche Bank online banking
2. Go to **Account** → **Transactions** → **Export**
3. Select date range
4. Format: **CSV** (not PDF!)
5. Download file (e.g., `transactions_2025-01.csv`)

### Import to Firefly III

1. In Firefly III, go to **Data** → **Import Data**
2. Click **Upload File**
3. Select CSV file
4. Map columns:
   - Date → Booking Date
   - Description → Description
   - Amount → Amount
   - (Deutsche Bank format varies - adjust mapping)
5. Click **Import**
6. Review and confirm

### CSV Format Notes

Deutsche Bank CSV typically includes:
- Buchungstag (Booking Date)
- Wertstellung (Value Date)
- Vorgang (Transaction Type)
- Buchungstext (Description)
- Betrag (Amount)
- Währung (Currency)

Firefly III can auto-detect most formats.

## Common Issues & Solutions

### Issue: "APP_KEY is not set" Error

**Solution**:
```bash
# Regenerate key
docker run --rm fireflyiii/core:latest php artisan key:generate --show

# Update .env
FIREFLY_APP_KEY=base64:...

# Restart
docker compose restart firefly-iii
```

### Issue: Duplicate Transactions

**Solution**:
- Enable `skip_duplicates: true` in FinTS config
- Firefly detects duplicates by: date + amount + description
- Delete duplicates: Transactions → Select duplicates → Delete

### Issue: FinTS Import Fails with "Strong Authentication Required"

**Cause**: PSD2 regulation requires SCA (Strong Customer Authentication)

**Solution**:
- Use photoTAN (most reliable)
- Ensure Deutsche Bank app is installed and activated
- Complete TAN challenge within 90 seconds

### Issue: Transactions Not Categorizing

**Solution**:
- Create more specific rules
- Use "OR" conditions for multiple merchant names
- Test rules on existing transactions first
- Enable "Stop processing after this rule" for exclusive categories

### Issue: High Memory Usage

**Solution**:
```bash
# Check current usage
docker stats firefly-iii

# If > 256MB, increase limit in docker-compose.yml:
mem_limit: 384m

# Restart
docker compose up -d firefly-iii
```

### Issue: Cannot Access After 2FA Setup

**Solution**:
- Temporarily disable Authelia protection in `config/authelia/configuration.yml`
- Change policy from `two_factor` to `one_factor`
- Restart Authelia: `docker compose restart authelia`

## Daily Workflow

1. **Morning**: Check Firefly III dashboard for yesterday's transactions
2. **Review**: Verify auto-categorized transactions are correct
3. **Budget**: Check budget progress (Budgets tab)
4. **Categorize**: Manually categorize any unrecognized transactions
5. **Reports**: Weekly/monthly, run reports (Reports → Net Worth, etc.)

## Advanced Configuration

### Multi-Account Support

If you have multiple Deutsche Bank accounts:

1. Add to FinTS config:
   ```json
   "accounts": [
     {
       "iban": "DE89370400440532013000",
       "firefly_account_id": 1,
       "name": "Checking"
     },
     {
       "iban": "DE89370400440532013001",
       "firefly_account_id": 2,
       "name": "Savings"
     }
   ]
   ```

2. Create corresponding accounts in Firefly III first
3. Note each account ID
4. Update config with correct IDs

### Recurring Transactions

Set up recurring bills for auto-tracking:

1. **Piggy Banks** → **Create Recurring Transaction**
2. Example: Netflix subscription
   - Amount: -12.99
   - Frequency: Monthly
   - Start date: 2025-01-01
   - Category: Entertainment

Firefly will expect these transactions and alert if missing.

### API Access

Firefly III has a full REST API for automation:

```bash
# Get account balance
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://firefly-iii:8080/api/v1/accounts/1

# Create transaction
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "transactions": [{
      "type": "withdrawal",
      "date": "2025-01-15",
      "amount": "42.99",
      "description": "Grocery store",
      "source_id": 1,
      "destination_name": "REWE"
    }]
  }' \
  http://firefly-iii:8080/api/v1/transactions
```

Docs: https://docs.firefly-iii.org/api/

## Resources

- **Firefly III Docs**: https://docs.firefly-iii.org/
- **FinTS Importer GitHub**: https://github.com/benkl/firefly-iii-fints-importer
- **Deutsche Bank Developer**: https://developer.db.com/
- **German FinTS Spec**: https://www.hbci-zka.de/
- **Community Support**: r/FireflyIII on Reddit

## Security Checklist

- [ ] Firefly III admin password is strong and stored in Vaultwarden
- [ ] Personal Access Token is stored securely in `.env` (not committed)
- [ ] FinTS config file permissions are `600` (read/write owner only)
- [ ] Database passwords are randomly generated (32+ characters)
- [ ] Authelia 2FA is enabled for Firefly access
- [ ] SSL/HTTPS is enabled via Nginx Proxy Manager
- [ ] Backups are tested and verified monthly
- [ ] photoTAN app is protected with device PIN/biometric

## Maintenance

### Weekly
- Review imported transactions
- Categorize uncategorized items
- Check budget progress

### Monthly
- Run net worth report
- Review spending by category
- Test database backup restore
- Update Firefly III: `docker compose pull firefly-iii && docker compose up -d`

### Quarterly
- Review and optimize rules
- Audit old transactions for accuracy
- Check for Firefly III updates/features

---

**Congratulations!** 🎉 You now have a fully automated household finance system with Deutsche Bank integration!

For support, consult the FinTS Importer README at `config/fints-importer/README.md` or open an issue on GitHub.
