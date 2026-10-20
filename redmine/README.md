# Redmine

Noctalia bar widget for open issues assigned to you.

Settings → Plugins → Redmine:

| Setting | What to put |
| --- | --- |
| Redmine URL | Base URL, such as `https://redmine.example.com` |
| API key | My account → API access key. Leave empty only if that Redmine allows anonymous access. |

Add the **assigned** widget from the Add-widget picker. It shows the open-issue count. Click it for the list; click an issue to open it in the browser. In the panel, type a title or a ticket number (`123` or `#123`) and press Enter.

Point a Noctalia path source at the parent of this directory (it must contain a `redmine/` folder), or copy this directory to `$XDG_DATA_HOME/noctalia/plugins/fragoso/redmine/`.
