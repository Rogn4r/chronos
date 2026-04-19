# Chronos

A lightweight, high-performance time and date parser for the Janet programming language. Built with PEGs for speed and reliability.

## Features

- **Universal Parsing**: Handles ISO8601, Nginx, and Syslog formats out of the box.
- **Localization Support**: Built-in support for English and Russian month names (UTF-8 friendly).
- **Log Processor Ready**: The `find` function returns precise start/end indices, making it ideal for multiline log detection (e.g., Java stack traces).
- **Correct Indexing**: Transparently handles Janet's unique 0-indexed months (0-11) and days (0-30), returning standard Unix Timestamps.
- **Zero Dependencies**: Pure Janet, no external C libraries or FFI required.

## Installation

```bash
jpm install https://github.com/Rogn4r/chronos.git
```

