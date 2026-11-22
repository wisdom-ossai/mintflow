# Mintflow legal / marketing pages

Static pages for App Store required URLs:

- `/privacy` → [privacy.html](privacy.html)
- `/terms` → [terms.html](terms.html)
- `/support` → [support.html](support.html)

## Deploy (Firebase Hosting or any static host)

Point `mintflow.app` at this folder (or copy these three files into your existing site root). Example with Firebase:

```bash
# firebase.json public dir should include these files as privacy.html, terms.html, support.html
# and rewrites:
#   /privacy → /privacy.html
#   /terms → /terms.html
#   /support → /support.html
firebase deploy --only hosting
```

Until DNS is live, App Store Connect will reject submissions that link to failing URLs — verify HTTP 200 before submit.
