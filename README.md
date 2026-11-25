# lem-consult

Consult-style search and navigation for Lem: collect candidates, show them in
the ordinary Vertico prompt, and act on the selected one.

This is a Lem port of the parts of [Consult](https://github.com/minad/consult)
that fit Lem's prompt.  The commands use `prompt-for-string`, so they get the
same popup, count field, orderless filtering and Return-to-select behaviour as
`C-x b` and `M-x`.  No global keys are taken; bind the commands you want in
`init.lisp` (see the end of this file).

## Commands

### Virtual buffers

| Command | What it does |
| --- | --- |
| `consult-buffer` | Buffers, then recent files, then bookmarks in one prompt. |
| `consult-project-buffer` | The same three sources, restricted to the project root. |
| `consult-recent-file` | Recently opened files. |
| `consult-bookmark` | Jump to a bookmark (needs Lem's bookmark extension). |

### Search

| Command | What it does |
| --- | --- |
| `consult-line` | Lines of the current buffer. |
| `consult-line-multi` | Lines of every switchable buffer. |
| `consult-grep` | Ask for a pattern, then list grep matches. |
| `consult-ripgrep` | Same, with ripgrep. |
| `consult-git-grep` | Same, with `git grep`. |
| `consult-find` | Find files under the project root with `find`. |
| `consult-fd` | Same, with `fd`. |

### Navigation

| Command | What it does |
| --- | --- |
| `consult-goto-line` | Go to `LINE` or `LINE:COLUMN`. |
| `consult-outline` | Headings of the current Org, Organ or Markdown buffer. |
| `consult-org-heading` | Headings of the current Org or Organ buffer. |
| `consult-imenu` | Definitions in the current buffer. |
| `consult-imenu-multi` | Definitions in project buffers of the same major mode. |

### Editing, histories, modes

| Command | What it does |
| --- | --- |
| `consult-yank-from-kill-ring` | Insert an item from the kill ring. |
| `consult-yank-pop` | Same, as a Consult-style replacement for `M-y`. |
| `consult-history` | Insert an entry from a prompt history. |
| `consult-theme` | Load a color theme. |
| `consult-mode-command` | Run a command belonging to an active mode. |
| `consult-minor-mode-menu` | Enable or disable a minor mode. |

## Differences from Emacs Consult

- **Search is two steps, not asynchronous.**  `consult-grep` asks for the
  pattern, runs grep, then lists the matches.  Consult streams matches while you
  type; Lem's prompt does not have an asynchronous completion source here, so a
  search is run to completion first.  `*consult-async-min-input*` is reserved
  for that future behaviour and currently unused.
- **No live preview.**  Selecting a candidate and pressing Return jumps to it;
  merely moving through the list does not move the source buffer.
- **No narrowing keys** such as `f SPC` for files or `b SPC` for buffers.
  Orderless input narrows the list instead.
- **Imenu is regexp-based.**  Lem has no Imenu, so `consult-imenu` uses the
  `*consult-imenu-rules*` table: a regular expression per mode finds the lines
  where definitions start.  Lisp, Python, Ruby, JavaScript/TypeScript, Go and
  Rust have rules; other modes use a generic fallback.  Add or change rules in
  `init.lisp` if your mode needs another definition form.
- **`consult-history` cannot be opened from inside a prompt.**  Lem rejects a
  second prompt while one is active.  Run it outside a prompt; it lists every
  prompt history and inserts the choice at point.

Not ported because Lem has no equivalent building block: `consult-register*`
(Lem has no register system), `consult-mark`/`consult-global-mark` (no mark
ring), `consult-flymake`/`consult-compile-error` (no shared diagnostics or
compilation-error API), `consult-info`/`consult-man`, `consult-kmacro`,
`consult-completion-in-region` (Lem has no `completion-at-point`), and
`consult-keep-lines`/`consult-focus-lines` (no buffer filtering/visibility
primitive).

## Knobs

| Variable | Default | Meaning |
| --- | --- | --- |
| `*consult-max-candidates*` | 1000 | Most candidates handed to the prompt. |
| `*consult-max-files*` | 5000 | Most files collected by `consult-find`/`consult-fd`. |
| `*consult-command-timeout*` | 10 | Seconds a grep/find child may run before it is killed. |
| `*consult-grep-command*` | `grep -rnI ...` | Command used by `consult-grep`. |
| `*consult-ripgrep-command*` | `rg ...` | Command used by `consult-ripgrep`. |
| `*consult-git-grep-command*` | `git grep -n -I ...` | Command used by `consult-git-grep`. |
| `*consult-find-command*` | `find ...` | Command used by `consult-find`. |
| `*consult-fd-command*` | `fd ...` | Command used by `consult-fd`. |
| `*consult-imenu-rules*` | see `navigate.lisp` | Mode regexps used by `consult-imenu`. |

`consult-grep`, `consult-ripgrep` and `consult-find` start at the project root
when one is found, and at the buffer's directory otherwise.  Lem's `find-root`
returns the home directory when it finds no project marker; this extension
treats that as "no project", so a non-project buffer never causes a search of
all of `$HOME`.

## Keybindings

The commands are on `M-x` after the system loads, and `init.lisp` binds the
`C-c h` prefix to `*consult-keymap*`:

| Key | Command |
| --- | --- |
| `C-c h b` | `consult-buffer` |
| `C-c h p` | `consult-project-buffer` |
| `C-c h r` | `consult-recent-file` |
| `C-c h m` | `consult-bookmark` |
| `C-c h l` | `consult-line` |
| `C-c h L` | `consult-line-multi` |
| `C-c h g` | `consult-grep` |
| `C-c h G` | `consult-ripgrep` |
| `C-c h f` | `consult-find` |
| `C-c h F` | `consult-fd` |
| `C-c h i` | `consult-imenu` |
| `C-c h I` | `consult-imenu-multi` |
| `C-c h o` | `consult-outline` |
| `C-c h O` | `consult-org-heading` |
| `C-c h j` | `consult-goto-line` |
| `C-c h y` | `consult-yank-from-kill-ring` |
| `C-c h h` | `consult-history` |
| `C-c h t` | `consult-theme` |
| `C-c h c` | `consult-mode-command` |
| `C-c h n` | `consult-minor-mode-menu` |

Local keymaps keep precedence; for example `C-c h` in an LSP buffer remains
`lsp-hover`.

## Loading

The extension lives in `~/.config/lem/extensions/consult` and is loaded by
`init.lisp` through the same `asdf:*central-registry*` entry as `vertico`,
`orderless` and `marginalia`:

```lisp
(asdf:load-system "lem-consult")
```
