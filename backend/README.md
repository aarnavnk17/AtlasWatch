Backend email configuration
===========================

This backend can send OTP emails via two methods:

- SendGrid API (recommended for production) — set SENDGRID_API_KEY.
- SMTP provider (e.g., SendGrid SMTP, Mailgun, or local dev SMTP like MailHog/Maildev) — set SMTP_HOST, SMTP_PORT, and optionally SMTP_USER/SMTP_PASS.

Environment variables
---------------------

- SENDGRID_API_KEY — If set, the backend tries to use the SendGrid API (via @sendgrid/mail) to send emails. If the package is not installed or the API call fails, it falls back to SMTP/console.
- SMTP_HOST — SMTP server hostname (default: localhost for local dev).
- SMTP_PORT — SMTP server port (default: 1025 used by Maildev/MailHog).
- SMTP_USER / SMTP_PASS — SMTP auth credentials (optional).
- OTP_FROM — Optional From address for OTP emails (default: no-reply@atlaswatch.local).

SendGrid SMTP example (no extra package required)
------------------------------------------------
Use SendGrid's SMTP relay by setting these env vars:

SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=<YOUR_SENDGRID_API_KEY>
OTP_FROM=no-reply@yourdomain.com

SendGrid API example (requires installing @sendgrid/mail):
------------------------------------------------------
SENDGRID_API_KEY=<YOUR_SENDGRID_API_KEY>
OTP_FROM=no-reply@yourdomain.com

Local dev (Maildev / MailHog)
----------------------------
Run a local SMTP dev server on port 1025 and the backend will pick it up by default.
Example using Maildev:

1) npm install -g maildev
2) maildev
3) Visit http://localhost:1080 to see captured emails

Notes
-----
- The backend logs OTP codes to the console when sending fails or when using a dev SMTP — useful during development.
- For production, use environment variables and secure storage for API keys/credentials.
