# Third-party materials

## Original Puzznic cartridge materials

The following files contain data or material extracted from the Puzznic USA
NES cartridge supplied for this project:

- `data/levels.json`: original Puzznic and Gravnic level data, passwords, timers,
  and scoring bonuses.
- `data/nes_symbols.png`: original block graphics.
- `data/nes_music.wav`: a captured segment of the original game music.
- `artifacts/*.png`: game screenshots containing original block graphics.

Puzznic and these original materials belong to their original rights holders,
including Taito/IGS. They are excluded from this project's MIT license. No
ownership or relicensing of these materials is claimed. The ROM itself is not
included in the repository or the application.

## Development dependencies

- [py65](https://github.com/mnaberez/py65), BSD-3-Clause: used by the importer
  to execute the cartridge's decoding routines during development.
- [JSNES](https://github.com/bfirsh/jsnes), Apache-2.0: used for development
  reference captures and audio extraction.

Neither dependency is included in or required by the native Godot game.

## Godot Engine

The native application uses [Godot Engine](https://godotengine.org/license/),
distributed under the MIT license. Godot's engine license and its third-party
notices are available at that link. The source project requires a separate
Godot installation; macOS application releases bundle the engine runtime.
