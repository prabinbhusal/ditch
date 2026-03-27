# Contributing to Ditch

Thanks for wanting to contribute!

## Getting Started

1. **Fork** the repository
2. **Clone** your fork:
   ```bash
   git clone https://github.com/prabinbhusal/ditch.git
   ```
3. **Open** `Ditch.xcodeproj` in Xcode
4. **Build & Run** with `⌘R`

## Requirements

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- Swift 5.0+

## How to Contribute

### Reporting Bugs

- Open an [Issue](https://github.com/prabinbhusal/ditch/issues) with a clear title
- Describe the bug and steps to reproduce
- Include your macOS version and Mac model

### Suggesting Features

- Open an [Issue](https://github.com/prabinbhusal/ditch/issues) with the `feature` label
- Describe the feature and why it would be useful

### Submitting Code

1. Create a new branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make your changes
3. Test thoroughly on your Mac
4. Commit with a clear message
5. Push and open a Pull Request

## Code Style

- Follow existing patterns
- Keep functions focused and small
- Use descriptive variable names
- Put shared values in `Constants.swift`, not inline

## Project Structure

```
Ditch/
├── main.swift              # Entry point
├── AppDelegate.swift       # Menu bar, drag monitoring, state machine
├── AppCleaner.swift        # File scanning + cleanup logic
├── NotchDropView.swift     # Main SwiftUI view for the notch UI
├── NotchWindow.swift       # Transparent overlay window at the notch
├── NotchDetector.swift     # Notch detection + fallback for older Macs
├── Constants.swift         # Shared constants and layout values
├── Models.swift            # State types and data models
└── Components/
    ├── NotchShape.swift
    ├── PulsingDropIcon.swift
    ├── LiquidGlassButtonStyle.swift
    ├── AnimatedCheckmark.swift
    └── FileRowButton.swift
```

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
