# MCP Config

A local web UI for reading and safely editing the MCP (Model Context Protocol)
servers that Claude Code loads — at user scope and per project.

Inspired by [icefort-ai/config](https://github.com/icefort-ai/config), rebuilt on
Rails 8, ViewComponents and Stimulus, and focused on a single engine.

## What it does

- **Web interface** — browse and edit every MCP server without opening a JSON file.
- **Real-time updates** — a file watcher notices changes made by the Claude Code
  CLI or an editor and refreshes open pages in place.
- **Safe editing** — every write is preceded by a timestamped backup, validated
  against a JSON Schema, and swapped into place atomically.
- **Overlap detection** — finds server names defined in more than one scope for
  the same project, and says which definition actually wins.
- **Warnings** — flags servers that are structurally valid but almost certainly
  wrong, without blocking you from saving them.
- **A view of local scope** — every local server across every project in one
  place, because that scope is otherwise the hardest to see.
- **Colour-coded scopes** — user, project and local each have a colour that is
  used consistently everywhere a server appears.
- **Dark / light themes** — light, dark, or follow the system, rendered
  server-side so there is no flash on first paint.

## The three scopes

Claude Code reads MCP servers from three places. Higher precedence wins.

| Scope   | Location                                    | Precedence | Shared? |
| ------- | ------------------------------------------- | ---------- | ------- |
| User    | `~/.claude.json` → `mcpServers`              | 1          | no      |
| Project | `<project>/.mcp.json` → `mcpServers`         | 2          | yes, committed |
| Local   | `~/.claude.json` → `projects[path].mcpServers` | 3        | no      |

Overlaps are classified rather than just listed:

- **Duplicate** — the same name defined identically in two scopes. Harmless, but
  the lower-precedence copy does nothing.
- **Override** — the same name defined *differently*. The app shows a field-level
  diff and marks which definition is shadowed.

The same name in two *different* projects is not an overlap: they never apply at
the same time, so it is not reported.

Scope names match the Claude Code CLI deliberately — what the UI calls "local"
is what `claude mcp add --scope local` writes. Note that local is the **default**
when no `--scope` is passed, and that it outranks the other two, which is why
`/local` exists as its own view.

## Warnings

Separate from validation. A validation error blocks a save; a warning never
does, because Claude Code will happily store any of these and refusing to edit a
file you already have would be unhelpful.

| Code | Fires when |
| ---- | ---------- |
| `url_as_command` | A `stdio` server's `command` is a URL, so it cannot start. Almost always means the transport should be `http`. |
| `ignored_headers` | `headers` set on a `stdio` server, which never sends them. |
| `ignored_env` | `env` set on an `http`/`sse` server, which never passes it. |
| `literal_credential` | An env name matching `token`/`secret`/`key`/`password`/`credential` holds a literal value rather than a `${VAR}` reference. |

These are semantic, not structural, which is exactly why the JSON Schema cannot
catch them: `"command": "http://..."` is a perfectly good non-empty string.

## Getting started

Requires Ruby 4.0 (see `.ruby-version` / `mise.toml`).

```sh
bundle install
bin/rails tailwindcss:build
bin/dev                       # web server + Tailwind watcher
```

Then open <http://localhost:3000>.

Run the tests:

```sh
bundle exec rspec
```

## Configuration

All settings are read from the environment at boot.

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `MCP_CONFIG_USER_FILE` | `~/.claude.json` | The user config file to read and write. |
| `MCP_CONFIG_BACKUP_DIR` | `~/.mcp-config/backups` | Where backups are kept. |
| `MCP_CONFIG_BACKUP_RETENTION` | `50` | Backups kept per source file. |
| `MCP_CONFIG_WATCH` | `true` (`false` in test) | Enable the file watcher. |
| `MCP_CONFIG_FORCE_POLLING` | `false` | Use polling instead of FSEvents/inotify. |
| `MCP_CONFIG_MAX_WATCHED_PROJECTS` | `200` | Cap on watched project directories. |

Pointing `MCP_CONFIG_USER_FILE` at a copy is the safest way to try the app out.

## How it is put together

There is **no database**. The JSON files on disk are the only state.

```text
app/models/mcp/
  workspace.rb       aggregate root; the only thing controllers talk to
  scope.rb           user / project / local, with precedence and colour
  server.rb          one server definition, with validation and a fingerprint
  json_document.rb   read, backup, validate, atomic write
  user_config.rb     ~/.claude.json
  project_config.rb  <project>/.mcp.json
  project.rb         one project across both project-scoped sources
  overlap.rb         one contested name, classified and diffed
  overlap_report.rb  finds every overlap, per project
  backup.rb          timestamped copies, listing and restore
  schema.rb          JSON Schema fragments and validation
  change_log.rb      when the config last moved, and whether we did it
  change_notifier.rb turns a filesystem event into a Turbo refresh

lib/mcp_config/watcher.rb
  Listen-based file watcher. Lives outside app/ because it owns a long-lived
  thread that must survive code reloading.

app/components/
  ui/*               card, badge, button, stat, flash, empty state, page header
  layout/*           sidebar, theme toggle, live status
  server_*, project_card, overlap_card, backup_card, scope_badge, json_block
```

### Writes

Every write follows the same path, in `Mcp::JsonDocument#write`:

1. The full parsed document is deep-copied and the change applied to the copy,
   so keys this app knows nothing about are preserved.
2. The result is validated against the JSON Schema. A failure raises before
   anything touches the disk.
3. The current file is copied into the backup directory verbatim.
4. The new contents are written to a temp file in the same directory, given the
   original's permissions, and renamed over the target.

### Real-time updates

`McpConfig::Watcher` watches the user config's directory plus every project
directory, with an ignore pattern that prunes everything except the two
filenames it cares about — so watching `$HOME` costs nothing and never walks
into `node_modules`.

On a change it broadcasts a Turbo refresh to the `mcp:config` stream. The layout
subscribes and asks Turbo to morph, so an open page updates in place without
losing scroll position or focus.

### Security notes

- Environment values whose names look like credentials (`token`, `secret`,
  `key`, `password`, …) are masked in the UI until you click to reveal them.
- The raw JSON editor is deliberately scoped to the `mcpServers` block. It will
  not hand you a textarea containing your whole `~/.claude.json`, which also
  holds OAuth account details and session history.
- The app binds to localhost and has no authentication. It is a local tool; do
  not expose it.

## Not included

Multi-engine support (Codex, Gemini CLI) was intentionally left out. `Mcp::Scope`
and the accent palette are the two places that would need to grow to add it.
