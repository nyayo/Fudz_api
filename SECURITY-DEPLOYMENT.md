# Deploying the API and dashboard security fixes

Deploy the API before the updated dashboard. No database migration is needed.

## Dashboard browser sessions

The dashboard exchanges login refresh tokens for HttpOnly, Secure, SameSite=None
cookies and keeps access tokens only in memory. Reloading restores a session
through the cookie endpoint; legacy local-storage credentials are discarded.
Existing dashboard users will need to sign in again.

Configure the API with exact HTTPS origins (no paths or trailing slashes):

```
DEBUG=False
ALLOWED_HOSTS=api.example.com
FRONTEND_URL=https://dashboard.example.com
CORS_ALLOW_ALL_ORIGINS=False
CORS_ALLOWED_ORIGINS=https://dashboard.example.com
BROWSER_SESSION_ORIGINS=https://dashboard.example.com
```

Add other legitimate web clients to CORS_ALLOWED_ORIGINS as needed. Browser
session establishment, refresh, and logout reject missing or untrusted Origin
headers. Keep browser session endpoints HTTPS-only and preserve Origin and
Set-Cookie through the reverse proxy. The dashboard sends credentials only to
these endpoints. Existing mobile bearer-token refresh endpoints are unchanged.

Host the dashboard and API under the same registrable domain, for example
`dashboard.example.com` and `api.example.com`. Browsers may block the refresh
cookie when these are unrelated sites. In that case use a same-site API reverse
proxy and update the dashboard API_BASE_URL; do not fall back to storing refresh
tokens in JavaScript storage.

## Registration

New-account OTP verification now returns `registration_token`. Registration must
send it alongside the same email or phone. It expires in 30 minutes and is
consumed transactionally. A database verified flag by itself no longer authorizes
registration. The dashboard and bundled Flutter registration routes pass this
credential; update other clients before deployment.

## WebSockets

Tracking requires an authenticated active session and a relationship to the
requested delivery. Customer location writes are restricted to the customer's
own user ID. The ASGI stack uses Django session authentication and validates the
WebSocket Origin against BROWSER_SESSION_ORIGINS. JWT-only clients must first establish an
authorized session or use a separately designed short-lived WebSocket ticket;
never put long-lived refresh tokens in a WebSocket URL.

## Infrastructure and credentials

Production Compose no longer publishes Redis on a host port. Development tools
that need Redis should run on the Compose network or use a private tunnel.

An old database credential was removed from settings.py. Rotate/revoke that
credential with the database provider if it was ever valid. Removing source text
does not revoke it or remove it from Git history. Coordinate any history rewrite
with repository owners; these changes do not rewrite shared history.
