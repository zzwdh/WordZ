# App

Owns application entry points and top-level composition.

- App lifecycle, commands, menu bar items, and app delegate stay here.
- `Composition` contains live wiring and domain factories.
- Window presentation is layered on purpose:
  scene declarations own scene-level defaults,
  `adaptiveWindowScaffold` owns SwiftUI window surfaces,
  and `bindWindowRoute` owns `NSWindow` registration, role policy, and chrome.

Do not put feature logic here; app code should assemble domains rather than implement them.
