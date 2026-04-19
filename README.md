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

## Usage

```janet
(import chronos)

# 1. Simple parsing
(def res (chronos/parse "2026-04-19 18:30:10.456 +0300"))
# Returns @{:unix 1776612610 :frac 0.456 :format :iso :raw "..."}

# 2. Extracting from logs (with indices)
(def log-line "2026-04-19 17:53:22 INFO [main] Application started")
(if-let [found (chronos/find log-line)]
  (do
    (print "Found timestamp at: " (found :start) " to " (found :end))
    (print "Unix time: " (found :unix))
    # Extract and clean the message part using the :end index
    (print "Message: " (string/trim (string/slice log-line (found :end))))))

# 3. High-precision timing
(let [f (chronos/parse "2026-04-19T13:20:00.123456Z")]
  (print "Unix: " (f :unix) " plus " (f :frac) " seconds"))
  # Result: Unix: 1776604800 plus 0.123456 seconds

# 4. Multiline detection (Java Stack Trace example)
(def logs [
  "2026-04-19 17:55:05 ERROR com.app.Main - NullPointer"
  "    at com.app.Main.process(Main.java:42)"
  "    at com.app.Main.main(Main.java:10)"])

(var current-timestamp nil)

(each line logs
  (if-let [found (chronos/find line)]
    (do 
      (set current-timestamp (found :unix))
      (print "--- New Log Entry: " (os/date current-timestamp) " ---")
      (print (string/trim (string/slice line (found :end)))))
    (if current-timestamp
      (print "  Stack Trace: " (string/trim line)))))


```

