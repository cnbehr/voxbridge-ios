# VoxBridge

Real-time interpreter earpiece for iOS. VoxBridge continuously listens to ambient foreign-language speech via the device microphone and translates it into your language through your headphones, powered by OpenAI's GPT-4o Realtime API.

## Use Case

Two people speaking different languages, each with their own phone + headphones running VoxBridge. The app picks up what the OTHER person says and translates it. You just hear the translation whispered in your ear.

## Requirements

- iOS 17.0+
- Xcode 16.0+
- OpenAI API key with Realtime API access
- Headphones (wired or Bluetooth)

## Setup

1. Clone the repository
2. Generate the Xcode project (requires [XcodeGen](https://github.com/yonaskolb/XcodeGen)):
   ```bash
   xcodegen generate
   ```
3. Open `VoxBridge.xcodeproj` in Xcode
4. Set your development team in Signing & Capabilities
5. Build and run on a physical device (microphone required)

If you don't have XcodeGen, create a new Xcode project manually and drag the `VoxBridge/` folder into it.

## Architecture

- **SwiftUI** app lifecycle with `@main`
- **AVAudioEngine** for capture and playback with real-time sample rate conversion (hardware rate to/from 24kHz PCM16 mono)
- **URLSessionWebSocketTask** for the OpenAI Realtime API connection
- **Server-side VAD** for always-on ambient listening (no push-to-talk)
- **Keychain** for secure API key storage

## Supported Languages

English, Spanish, French, German, Italian, Portuguese, Japanese, Mandarin Chinese, Korean, Arabic, Russian, Hindi, Dutch, Swedish, Turkish

## Cost

Approximately $0.30/min while active (GPT-4o Realtime pricing: ~$0.06/min audio input + ~$0.24/min audio output).

## Privacy

VoxBridge only uses the microphone to listen for speech to translate. Audio is streamed to OpenAI's API for processing and is not stored locally. Your API key is stored in the iOS Keychain and never leaves your device except to authenticate with OpenAI.
