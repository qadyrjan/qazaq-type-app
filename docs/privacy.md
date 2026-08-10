# Privacy

QazaqType performs conversion locally and works without a network connection.

The input method must never:

- record complete key events or user-entered text
- upload composition or committed text
- create typing history
- include composition text in crash reports
- bypass secure-input restrictions

Development diagnostics may record event categories such as `mode switched`,
`composition committed`, or `context changed`, but never key values or text.
Detailed diagnostics are disabled in release builds.

