# Backlog Gaming — контекст для агента

## Язык и общение

- Ответы пользователю — **на русском**, если он пишет по-русски.
- Код, имена символов и цитаты из репозитория — **как в проекте** (английские идентификаторы).
- При двусмысленной формулировке — **одно короткое уточнение**, не лекция.

## Стек проекта

| Что | Как |
|-----|-----|
| **iOS** | 18.0+ |
| **UI** | SwiftUI; UIKit только через `UIViewControllerRepresentable` |
| **Архитектура** | MVVM. View → `@Observable` ViewModel/Store → сервисы через протоколы |
| **Навигация** | `NavigationStack` + `NavigationPath` на фичу |
| **Хранение** | JSON в `UserDefaults` через `GameBacklogStore` / `GameBacklogPersistence` (версионированный `FileEnvelope`). Декодирование терпимое (`decodeTolerant`, `LossyDecodableArray`); снимки в `Documents/Backups` при запуске и при ошибке чтения |
| **Платформы** | Только iPhone / iPad (без macOS / visionOS) |
| **Сеть** | Нет (полностью локальное приложение) |
| **Тесты** | Пока нет; при появлении — XCTest, правило `ios-testing.mdc` вернётся |
| **DI** | Протоколы + инициализатор; `@Environment` для Store |

**Не смешивать** с TCA, VIPER, Clean без отдельной постановки.

## Структура проекта

```
Backlog_Gaming/
├── Backlog_GamingApp.swift          # Entry point, wires Store
├── MainTabView.swift                # Root tab view
├── GamesTabView.swift               # Kanban board (drag-and-drop)
├── GameDetailView.swift             # Edit game details
├── GameTaskEditorSheet.swift        # Edit task details
├── GameTaskVisual.swift             # Shared palettes, symbols
├── PeriodFlowView.swift             # Flow tab (timeline)
├── FlowTimelineViews.swift          # Timeline row components
├── BacklogStatsView.swift           # Stats screen
├── Models/
│   ├── GameEntry.swift              # Game model + enums
│   └── GameTask.swift               # Task model
├── Services/
│   ├── GameBacklogStore.swift       # @Observable store, CRUD
│   └── GameBacklogPersistence.swift # JSON encode/decode
└── Utilities/
    ├── DateFormatting.swift         # Единый формат дат (ru)
    └── TaskNoteFormatting.swift     # Markdown в заметках дел
```

## Контракт задачи

Пользователь может формулировать кратко; агент дозаполняет пропуски и при необходимости одной строкой озвучивает принятые границы.

| Поле | Смысл |
|------|--------|
| **Цель** | Что должно измениться или появиться |
| **Границы** | Что **не** делаем |
| **Формат** | Анализ / план / сразу код |

Режимы по формулировке — см. `ios-workflow.mdc`.

## Готово, когда (DoD)

После изменения **модели данных**:
- Есть обратная совместимость (`decodeIfPresent` с дефолтами) или миграция.
- Старые данные не теряются.

После видимой фичи в UI:
- Основной сценарий работает; перечислены затронутые файлы.
- Предложено сообщение коммита одной строкой.

## Чеклисты типовых операций

### Добавить поле в модель (`GameEntry` / `GameTask`)

1. **Модель**: добавить `var`, дефолт в `init`, `CodingKeys`, `decodeIfPresent` в `init(from:)`, `encode` в `encode(to:)`
2. **Store**: если `addEntry(...)` / `addTask(...)` принимает параметры — добавить с дефолтами
3. **Views**: отобразить в карточке / строке таймлайна; добавить редактирование в detail/sheet
4. **Visual**: если поле визуальное (иконка, цвет) — расширить `GameTaskVisual`

### Новый экран

1. Создать `View` файл
2. Добавить `navigationDestination` или `.sheet` в родительском view
3. Добавить store-методы если нужна новая логика

### Изменить жесты / взаимодействие карточки

1. Прочитать `swiftui-pitfalls.mdc` — там зафиксированы все грабли
2. Не использовать `List` в `ScrollView`, не использовать `onTapGesture` рядом с `draggable`
3. Проверить `xcodebuild` после изменений

## Публичный API модулей

Ломать контракты без пометки (deprecated / major) — запрещено; согласовывай в постановке.
