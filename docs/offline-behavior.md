# Offline reading and freshness

KABLAY opens saved content immediately. Network refreshes run in the background on launch, when the app becomes active, and when a user pulls to refresh. A failed refresh never replaces a successful snapshot with an empty list. The app shows the last confirmed update time and warns when a saved list may be outdated.

| Content | Revalidate after | Retention |
| --- | ---: | --- |
| Specialist directory | 30 minutes | Keep last complete response until the next successful response |
| Articles and editorial HTML | 12 hours | Keep last complete response until the next successful response |
| Service catalog | 24 hours | Keep last response; bundled categories remain available |
| Client requests, professional work, conversations and statistics | 5 minutes | Keep per account until refreshed or sign-out |
| Available jobs | 2 minutes | Keep per account until the next successful response; label stale data |
| Downloaded images | 7 days | Refresh in the background; remove an unreferenced image only after 90 days |

Category covers and repair guides ship with the app. Remote images are stored in Application Support, not only URLCache. The app prefetches list covers, specialist avatars, and article images; other media is saved when viewed. Images remain visible while an old file is refreshed. Large lists load in small pages. The newest page appears first; additional pages load on demand, and article pages are preloaded in the background for offline reading. A failed page never clears the saved snapshot. Cached older rows remain available until a complete successful listing can establish what is no longer current.

Personal snapshots are separated by account ID and protected by iOS file protection. Signing out removes that account's snapshots and known request images. The cached lists and conversations are read-only offline: creating requests, responding to jobs, sending messages, purchases, and changing account settings still require a connection and server confirmation. A fresh install with no prior successful sync can show only bundled content until it connects once.
