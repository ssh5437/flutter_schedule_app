# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter schedule app - a new Flutter application project currently in its initial setup phase with the default counter app template.

## Essential Commands

### Development
- `flutter run` - Run the app in debug mode with hot reload enabled
- `flutter run -d <device_id>` - Run on specific device (chrome, windows, android, ios, etc.)
- `flutter devices` - List available devices

### Testing
- `flutter test` - Run all tests
- `flutter test test/widget_test.dart` - Run specific test file

### Code Quality
- `flutter analyze` - Run static analysis using linter rules from `analysis_options.yaml`
- Lints configured via `package:flutter_lints/flutter.yaml` (version 5.0.0)

### Build & Dependencies
- `flutter pub get` - Install dependencies from pubspec.yaml
- `flutter pub upgrade` - Upgrade dependencies
- `flutter pub outdated` - Check for outdated packages
- `flutter clean` - Clean build artifacts
- `flutter build <platform>` - Build for specific platform (apk, appbundle, ios, web, windows, etc.)

## Project Configuration

- **SDK Version**: Dart ^3.9.2
- **Main Dependencies**:
  - flutter (sdk)
  - cupertino_icons ^1.0.8
- **Dev Dependencies**:
  - flutter_test (sdk)
  - flutter_lints ^5.0.0

## Platform Support

Multi-platform Flutter project with support for:
- Android (android/)
- iOS (ios/)
- Web (web/)
- Windows (windows/)
- macOS (macos/)
- Linux (linux/)

## Current Architecture

Standard Flutter project structure:
- `lib/main.dart` - Application entry point with MyApp (root widget) and MyHomePage (stateful demo counter widget)
- `test/` - Widget and unit tests
- Platform-specific code in respective platform directories
