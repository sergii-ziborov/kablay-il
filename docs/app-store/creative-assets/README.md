# App Store product-page creative assets

These opaque PNGs are prepared for **Product Page Information → Header and Search Results** in App Store Connect. Each locale uses screenshots of the corresponding running app language. Dimensions follow [Apple's creative-asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications).

| Locale | Header (3840 × 1646) | Search results (1920 × 1280) |
| --- | --- | --- |
| English (U.S.) | [header-en.png](header-en.png) | [search-en.png](search-en.png) |
| Russian | [header-ru.png](header-ru.png) | [search-ru.png](search-ru.png) |
| Hebrew | [header-he.png](header-he.png) | [search-he.png](search-he.png) |

Regenerate from the repository root with `swift docs/app-store/creative-assets/generate.swift`. The generator uses checked-in app screenshots and writes opaque RGB PNGs. Inspect each generated image at original resolution before uploading. App Store Connect acceptance and App Review approval must be checked there; the presence of these files does not mean they are published.
