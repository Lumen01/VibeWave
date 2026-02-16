<div align="center">
<h1>VibeWave</h1>
A native Mac app for understanding your vibe coding flow.




> **Note**: Currently only supports OpenCode

<img src="art/VibeWave.png" width="60%">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue.svg)](https://www.apple.com/macos)

[English](README.md)  |  [中文](README.zh_CN.md)

[Features](#features) • [Quick Start](#quick-start) • [Contributing](#contributing)

</div>

---

## Features

VibeWave provides a comprehensive set of features for tracking and analyzing OpenCode AI usage:

### Statistics
- **Usage Metrics**: Token consumption, session count, total cost
- **Model Analysis**: Top 5 models by usage
- **Project Analysis**: Top 5 projects by usage
- **Time Trends**: View usage trends by day/week/month
- **Efficiency Metrics**: Token output ratio, reasoning token percentage, etc.

### Internationalization
- **Multi-language Support**: Chinese, English
- **Bilingual Interface**: Complete i18n support

---

## Quick Start

### Requirements
- macOS 14.0 or later
- Xcode 15.0 or later (for development)
- Swift 5.10 or later

### Installation

```bash
# Clone the repository
git clone https://github.com/lumenvibewave/vibewave.git
cd vibewave

# Build and run (default)
./run-app.sh

# Or build only
./run-app.sh --build

# Or build and run explicitly
./run-app.sh --run
```

### Configuration

After first launch, configure the OpenCode data source path in Settings:

1. Open VibeWave
2. Click on the Settings tab
3. Select the OpenCode data directory in "Data Sync" section
4. Choose a sync strategy (Recommended: Automatic)

---

## Contributing

Contributions, issues, and feature requests are welcome!

### How to Contribute
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

This project is licensed under the [MIT License](LICENSE).

---

<div align="center">
<b>Built with ❤️</b>

**[Back to Top ↑](#vibewave)**

</div>
