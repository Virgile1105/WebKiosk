# DeviceGate

A Flutter application that functions as a web kiosk builder, allowing users to browse websites in full-screen mode with a swipe-accessible menu.

## Features

- **URL Input**: Enter any website URL when the app starts
- **Full-Screen Browsing**: Websites are displayed in immersive full-screen mode
- **Swipe Menu**: Swipe from the left to access a menu showing:
  - Website icon (favicon)
  - Website name
  - Current URL
  - Navigation controls (back, forward, reload, home)
  - Option to change website

## Getting Started

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

## Usage

1. Launch the app
2. Enter a website URL (e.g., "google.com" or "https://example.com")
3. Click "Open Website" to load the page in full-screen
4. Swipe from the left edge to open the menu
5. Use menu options to navigate or change websites

## Dependencies

- `webview_flutter`: ^4.4.2 - For displaying web content
- `url_launcher`: ^6.2.1 - For URL handling
- `http`: ^1.1.0 - For HTTP requests

## Platform Support

- Android
- iOS
- Web (with limitations)
