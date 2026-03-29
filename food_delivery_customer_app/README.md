# food_delivery_customer_app

A new Flutter project.

## Google Maps API keys

This app uses Google Maps on Android and iOS. Add your API key in both places:

- Android: update the value in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
	under `com.google.android.geo.API_KEY`.
- iOS: update the key in [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift)
	inside `GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")`.

Make sure the key has the Maps SDK for Android and Maps SDK for iOS enabled.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
