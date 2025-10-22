# OpenAlbum

An iOS app + Home Screen widget that displays a random image from an Amazon Photos shared album (or from a single image URL) at a configurable refresh interval.

> Unofficial project. Not affiliated with Amazon. Uses publicly accessible Amazon Photos share endpoints (no private API keys, no login flow). Use at your own risk.

## Features

- Add Amazon Photos share URLs (e.g. `https://www.amazon.com/photos/share/XXXXXXXXXXXX`) to the app
- (Optional) Add a direct image URL instead of an album; supports common image extensions (`jpg`, `png`, `gif`, `webp`, `heic`, etc.)
- Home Screen widget shows a randomly selected image from all registered albums/images
- Configurable widget refresh interval (5 minutes to 1 day)

## Requirements

- Xcode 16+ (or the latest stable supporting Swift 5.9 / iOS 18 SDK)
- iOS 17+ target recommended (adjust if you need earlier; SwiftData requires iOS 17)
- An Amazon Photos shared album link (public share) if using album functionality

## Getting Started

1. Clone the repository:
	```bash
	git clone https://github.com/ssssota/OpenAlbum.git
	cd OpenAlbum
	```
2. Open `OpenAlbum.xcodeproj` in Xcode.
3. Select the `OpenAlbum` scheme and run on a simulator or device.
4. In the app, tap “Add Item” and paste an Amazon Photos share URL or an image URL.
5. After adding at least one item, long-press your Home Screen, tap “+”, and add the OpenAlbum widget.
6. (Optional) Edit the widget and set the refresh interval.

## Amazon Photos Share URL Format

Valid examples (replace the ID with your share ID):

```
https://www.amazon.com/photos/share/XXXXXXXXXXXXXXXXXXXXXXXX
https://www.amazon.co.jp/photos/share/XXXXXXXXXXXXXXXXXXXXXXXX
```

Only public share links are supported. Private/non-shared albums won’t work.

## License

GPL-3.0. See [LICENSE](LICENSE) for details.

## Disclaimer

Amazon may change share endpoint behavior at any time; this project might break without notice. Avoid excessive refresh intervals that could look like abusive traffic.
