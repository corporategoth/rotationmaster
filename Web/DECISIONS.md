# Before the website goes public

The site runs locally and is built to be hosted, but these choices belong to the project owner. Nothing below has been chosen; each item says what the code already supports and what would change.

## 1. Hosting

- **Where it runs.** Any host that can run one long-lived Node process (Node 22.13+, no npm packages) with a writable directory for the SQLite file: a small VPS, a container, or a home server behind a reverse proxy.
- **TLS and proxy.** Put HTTPS in front (Caddy, nginx, Cloudflare and so on). Then set `RM_COOKIE_SECURE=1`, `RM_TRUST_PROXY=1` (so rate limits see the real client address) and bind the proxy-facing address.
- **One instance or several.** Rate limiting is in memory, per process. Several instances would need a shared limiter (or the proxy's own) and a shared database.
- **Static-only option.** The viewer and the help pages could be published as static files with no server at all; sharing needs the service.

## 2. Domain

Pick a domain or subdomain. Then update the addon's TOC `X-Website` (currently the GitHub wiki), the links back from the wiki, and any Discord announcements. Session cookies are host-only, so no cookie domain setting is needed.

## 3. Sign-in provider

Only a **development** sign-in exists: anyone can type any name, and the server refuses to expose it on a non-loopback address. Choose a real provider before publishing:

- **Discord OAuth2** (natural fit: the community already lives there). Needs a Discord application, a client ID and secret, and the redirect URL on the chosen domain. Scope `identify` only. User ids would be `discord:<snowflake>`.
- **Battle.net OAuth** (ties shares to a WoW account). Needs a Blizzard developer client; region handling to decide.
- **Both**, or GitHub as a fallback.

The interface is in `Web/server/identity/provider.mjs`, with a description of the Discord flow; no other server code changes. Also decide: are display names the provider's name, or chosen on the site? Can a user rename? Is a user id shown publicly (it is today, next to the name)?

Set `RM_SESSION_SECRET` (32+ random characters) so sign-ins survive restarts.

## 4. Moderation policy

What exists: anyone signed in can report a share (one report per user per share, with a reason); reports are stored; `node Web/server/moderate.mjs` lists reports, hides, unhides or deletes a share, resolves reports and bans a user (a ban also ends existing sessions). `RM_REPORT_HIDE_THRESHOLD=N` can hide a share automatically after N open reports; it is off by default.

To decide:

- Who moderates, and whether they need a web interface rather than the command line.
- Whether reports auto-hide, and at what threshold.
- Rules for shares containing Lua (allowed, flagged, reviewed first, or refused), and for chatty announcements.
- How a hidden share's uploader is told, and whether they can appeal.
- Whether to require a minimum account age (for example a Discord account) before publishing.

## 5. Retention and deletion

- Uploaders can delete their own shares; deletion is immediate and permanent (no soft delete, no history).
- Decide whether deleted shares should be kept for a while for abuse investigation, how long reports and server logs (which record share ids and user ids) are kept, and what happens to a user's shares when they ask to be forgotten.
- Backups of the SQLite file are not set up; decide where and how often.

## 6. Abuse handling and limits

Defaults: exports up to 256 KiB, descriptions up to 20,000 characters, 10 uploads per user and 30 per address per hour, 20 reports per user per hour, 30 sign-ins per address per hour. Decide whether these suit a public site, whether to add a global daily cap, and who is alerted when limits are hit. Consider whether the proxy should add its own request-rate limits.

## 7. Licence for shared content

The addon is MIT licensed; shared exports are written by players. Decide what uploaders agree to when publishing (for example CC0 or CC BY 4.0 for exports and descriptions, or "you keep your rights and grant the site a licence to display"), and add that text to the upload form and footer. Also decide how to handle exports that copy a Built In rotation or a published guide.

## 8. Privacy notice and terms

A public site with accounts needs a short privacy notice (what is stored: user id, display name, shares, reports, IP addresses in memory for rate limits and in logs) and terms of use. Neither has been written.

## 9. Things deliberately not built yet

- Editing a share after publishing (today: delete and re-upload).
- Comments, ratings or favourites.
- Item and spell names (shares show game IDs; names would need a game-data source and licence).
- Translations of the help (English only).
