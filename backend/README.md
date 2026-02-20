Backend - MongoDB migration & run

You can place your connection string in `backend/.env` (this repo now includes a local `.env` file for convenience). Be sure to rotate credentials after testing.

1) Install dependencies

```bash
cd backend
npm install
```

2) Set `MONGODB_URI` (example using your provided cluster)

```bash
export MONGODB_URI="mongodb+srv://aarnavnk17:Atlas123@atlaswatch.ykagnef.mongodb.net/atlaswatch?retryWrites=true&w=majority"
# (macOS / Linux)
```

3) Run migration (reads `./atlaswatch.db` and writes to MongoDB)

```bash
npm run migrate-to-mongo
```

4) Start backend (uses `PORT` env var if provided)

```bash
npm start
```

5) Verify migrated data (using `mongosh` or Compass)

```js
use atlaswatch
db.users.count()
db.profiles.count()
db.contacts.find().limit(5)
```

Security notes
- You provided a connection string directly; for production rotate credentials and store secrets in the provider's secret manager (Render/Heroku/Cloud Run secrets, or environment variables in CI).
- For Atlas, configure a restricted DB user and limit IP access appropriately.

If you want, I can:
- Update endpoints in `index.js` to use Mongoose models so the backend no longer depends on `sqlite3`.
- Add a Dockerfile or Render/Fly/Cloud Run deployment configs.
Backend email configuration
===========================

This backend sends OTP emails using an SMTP relay via `nodemailer`.
Configure an SMTP provider (SendGrid SMTP, Mailgun, Amazon SES SMTP, or a local dev SMTP like MailHog/Maildev).

Environment variables
---------------------

Environment variables
---------------------

- `SMTP_HOST` — SMTP server hostname (default: `localhost` for local dev).
- `SMTP_PORT` — SMTP server port (default: `1025` used by Maildev/MailHog).
- `SMTP_USER` / `SMTP_PASS` — SMTP auth credentials (optional).
- `OTP_FROM` — Optional From address for OTP emails (default: `no-reply@atlaswatch.local`).

SendGrid SMTP example
----------------------
Use SendGrid's SMTP relay by setting these env vars (no extra package required):

```
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=<YOUR_SENDGRID_API_KEY>
OTP_FROM=no-reply@yourdomain.com
```

Local dev (Maildev / MailHog)
----------------------------
Run a local SMTP dev server on port `1025` and the backend will pick it up by default.
Example using Maildev:

1) npm install -g maildev
2) maildev
3) Visit http://localhost:1080 to see captured emails

Notes
-----
- The backend logs OTP codes to the console when sending fails or when using a dev SMTP — useful during development.
- For production, use environment variables and secure storage for API keys/credentials.
