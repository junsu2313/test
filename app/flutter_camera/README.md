# Underlab Camera · Flutter UI prototype

This is the first native Flutter reconstruction of `remote-ui/0716-1.1.html`.
It preserves the dark viewfinder layout, status badges, control positions, and
AF/SHOT/LIVE/STOP/KILL/CLEAN interaction model.

Camera networking, WebSocket frame delivery, and the Opal scheduler remain
deliberately unconnected until the visual comparison is complete.

The project is pinned to Puro's `stable` environment. The default Puro root is
the ASCII-only `C:\puro-root`, whose Flutter SDK is `C:\flutter-sdk-ascii`.
