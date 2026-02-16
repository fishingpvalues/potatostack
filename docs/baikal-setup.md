# Baïkal Calendar & Contacts Setup

## First-Time Setup

1. Open `https://potatostack.tale-iwato.ts.net:8085`
2. Admin wizard step 1: set admin password, click Save
3. Admin wizard step 2 (Database):
   - **Database type:** PostgreSQL
   - **Host:** `postgres`
   - **Port:** `5432`
   - **Database:** `baikal`
   - **User:** `postgres`
   - **Password:** your `POSTGRES_SUPER_PASSWORD` from `.env`
4. Click Save — Baïkal creates its tables and you're done

## Admin Panel

`https://potatostack.tale-iwato.ts.net:8085/admin/`

Create a user account here (e.g. `daniel`). Each user gets a default calendar and address book.

## Client Setup

Base URL: `https://potatostack.tale-iwato.ts.net:8085`

### DAVx5 (Android)

1. Install DAVx5 → Add account → "Login with URL and user name"
2. **Base URL:** `https://potatostack.tale-iwato.ts.net:8085/dav.php/`
3. **User:** your Baïkal username
4. **Password:** your Baïkal password
5. DAVx5 auto-discovers calendars and contacts — select which to sync

### iOS / macOS

Settings → Calendar → Accounts → Add Account → Other → CalDAV

- **Server:** `potatostack.tale-iwato.ts.net:8085/dav.php`
- **User / Password:** Baïkal credentials

### Thunderbird

File → New → Calendar → Network → CalDAV

- **URL:** `https://potatostack.tale-iwato.ts.net:8085/dav.php/calendars/<username>/default/`

### InfCloud (Web)

`https://potatostack.tale-iwato.ts.net:8082` — log in with Baïkal credentials.

## Import Google Calendar

1. Google Calendar → Settings → Import & Export → Export (downloads `.ical` zip)
2. In DAVx5/Thunderbird: import each `.ics` file into the synced Baïkal calendar
