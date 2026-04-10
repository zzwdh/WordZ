# App

Owns application entry points and top-level composition.

- App lifecycle, commands, menu bar items, and app delegate stay here.
- `Composition` contains live wiring and domain factories.

Do not put feature logic here; app code should assemble domains rather than implement them.
