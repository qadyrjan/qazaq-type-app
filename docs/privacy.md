# Privacy

QazaqType performs conversion locally and works without a network connection.

The input method process never uses the network. Once a day, when update
checks are enabled (the default; switch off in settings), it starts the
separate settings helper, which asks GitHub for the latest release version.
That request carries no typed text, no settings, and no identifiers beyond
what any HTTPS request reveals. A downloaded update is installed only if its
installer is signed with QazaqType's Developer ID.

The input method must never:

- record complete key events or user-entered text
- upload composition or committed text
- create typing history
- include composition text in crash reports
- bypass secure-input restrictions

Development diagnostics may record event categories such as `mode switched`,
`composition committed`, or `context changed`, but never key values or text.
Detailed diagnostics are disabled in release builds.

