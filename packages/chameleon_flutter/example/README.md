# serial_probe

Spike A probe (Phase 0): enumerates serial ports through `libserialport_plus`
and shows each port's name, description, transport, USB VID/PID and
manufacturer. It exists to prove the package's code-assets build hook compiles
libserialport on macOS, Windows and Linux — see `docs/research/spikes.md`.

Phase 3 replaces this with the real serial transport example.

```
export PATH="$(mise where flutter)/bin:$HOME/.pub-cache/bin:$PATH" && mise x -- flutter run -d macos
```
