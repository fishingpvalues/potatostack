# FinTS Importer Configuration for Deutsche Bank

This directory contains configuration files for the FinTS (Financial Transaction Services) importer, which automatically fetches transactions from Deutsche Bank and imports them into Firefly III.

## Initial Setup

### 1. Generate Firefly III Access Token

After deploying Firefly III, you need to create a Personal Access Token:

1. Log into Firefly III at `http://192.168.178.40:8085` (or your configured domain)
2. Go to **Options** → **Profile** → **OAuth** → **Personal Access Tokens**
3. Click **Create New Token**
4. Name it "FinTS Importer"
5. Copy the generated token and add it to your `.env` file as `FIREFLY_ACCESS_TOKEN`

### 2. Configure Deutsche Bank Connection

The FinTS importer uses a JSON configuration file. Create a file named `deutsche-bank.json` in this directory with the following structure:

```json
{
  "version": 2,
  "url": "https://fints.deutsche-bank.de/fints",
  "bank_code": "50010517",
  "username": "YOUR_DEUTSCHE_BANK_USERNAME",
  "password": "YOUR_DEUTSCHE_BANK_PIN",
  "accounts": [
    {
      "account_number": "YOUR_ACCOUNT_NUMBER",
      "iban": "YOUR_IBAN",
      "firefly_account_id": null,
      "firefly_account_name": "Deutsche Bank Checking"
    }
  ],
  "tan_mechanism": "iTAN",
  "connection": {
    "name": "Deutsche Bank",
    "type": "FinTS"
  },
  "import_settings": {
    "days_back": 7,
    "skip_duplicates": true,
    "auto_categorize": true
  }
}
```

### 3. Deutsche Bank FinTS Details

- **FinTS URL**: `https://fints.deutsche-bank.de/fints`
- **Bank Code (BLZ)**: `50010517` (Deutsche Bank AG)
- **TAN Methods**: Deutsche Bank supports:
  - **photoTAN** (recommended) - Use Deutsche Bank photoTAN app
  - **mobileTAN** - SMS-based TAN
  - **chipTAN** - Card reader with chip

### 4. Account Configuration

1. Log into your Deutsche Bank account to find:
   - Your account number
   - Your IBAN
   - Available TAN methods

2. After creating the account in Firefly III:
   - Note the account ID (visible in the URL when viewing the account)
   - Update `firefly_account_id` in the JSON config

### 5. Security Considerations

⚠️ **IMPORTANT SECURITY NOTES**:

- **Never commit** configuration files with real credentials to git
- The `config/fints-importer/` directory is excluded in `.gitignore`
- Store your Deutsche Bank PIN in Vaultwarden for secure access
- Consider using environment variables for sensitive data
- Enable 2FA in Firefly III (Options → Security)

### 6. Alternative: CSV Import

If FinTS doesn't work or you prefer manual control:

1. Download CSV exports from Deutsche Bank online banking
2. Place them in `/mnt/seconddrive/firefly-csv/` (you can create this directory)
3. Use Firefly III's built-in CSV import tool (Data → Import Data)
4. Create import configuration for Deutsche Bank CSV format

Deutsche Bank CSV format typically includes:
- Booking date
- Value date
- Transaction type
- Description
- Amount
- Currency

### 7. Testing the Connection

Once configured:

1. Restart the FinTS importer: `docker compose restart fints-importer`
2. Check logs: `docker logs fints-importer`
3. Access the importer GUI at `http://192.168.178.40:8086`
4. Click "Test Connection" to verify Deutsche Bank access
5. Run a manual import to test transaction fetching
6. Verify transactions appear in Firefly III

### 8. Automated Daily Imports

The `fints-cron` container automatically runs imports every 24 hours. To customize:

- Edit the `sleep 86400` value in docker-compose.yml (seconds)
- For hourly imports: `sleep 3600`
- For twice daily: `sleep 43200`

### 9. Troubleshooting

**Connection Failed**:
- Verify FinTS URL and bank code
- Check Deutsche Bank online banking is accessible
- Ensure your IP isn't blocked (too many failed attempts)

**TAN Challenges**:
- Some operations require TAN confirmation
- Use photoTAN app for best experience
- The importer will prompt for TAN when needed

**Duplicate Transactions**:
- Enable `skip_duplicates: true` in config
- Firefly III detects duplicates by date, amount, and description
- Adjust `days_back` to avoid re-importing old data

**No Transactions Imported**:
- Check account mapping in Firefly III
- Verify `firefly_account_id` matches your account
- Review importer logs for errors

### 10. Resources

- **FinTS Importer GitHub**: https://github.com/benkl/firefly-iii-fints-importer
- **Firefly III Docs**: https://docs.firefly-iii.org/
- **Deutsche Bank Developer**: https://developer.db.com/
- **German FinTS Specification**: https://www.hbci-zka.de/

### 11. Example Workflow

1. Deploy Firefly III and create your first account
2. Generate access token in Firefly III
3. Create `deutsche-bank.json` with your credentials
4. Test connection via importer GUI
5. Run manual import to verify
6. Let cron handle daily automatic imports
7. Review and categorize transactions in Firefly III
8. Set up budgets and rules for auto-categorization

---

**Note**: If you encounter issues with the FinTS importer, you can always fall back to CSV imports as a reliable alternative. Deutsche Bank provides excellent CSV export functionality in their online banking portal.
