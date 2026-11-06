# backlog-gaming

[![iOS CI](https://github.com/KiryaChainik/backlog-gaming/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/KiryaChainik/backlog-gaming/actions/workflows/ios-ci.yml)

Gaming backlog для iOS 18+ (SwiftUI): канбан игр, дела внутри игры, «Поток» по дням/неделям/месяцам.

## CI

Каждый пуш в `main` и каждый PR собирается и тестируется на GitHub Actions (`macos-26`, Xcode 26, iOS Simulator) —
см. `.github/workflows/ios-ci.yml`. Статус текущего коммита из терминала:

```sh
python3 scripts/ci_status.py --wait
```
