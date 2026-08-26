# Security demo

Normal **Markdown** remains readable.

<script>document.body.dataset.pwned = "script";</script>

<img src="x" onerror="document.body.dataset.pwned='image'">

<iframe src="https://example.com"></iframe>

<img src="https://example.com/tracker.png" onload="document.body.dataset.pwned='remote'">

<svg onload="document.body.dataset.pwned='svg'"><circle r="10"></circle></svg>

[Unsafe JavaScript link](javascript:alert(1))

[Blocked local file](file:///C:/Windows/win.ini)

```html
<script>This is code and must stay visible as text.</script>
```
