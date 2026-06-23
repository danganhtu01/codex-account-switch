# codex-account-switch

Switch between **N OpenAI Codex CLI accounts** from the terminal with one command.

The [Codex CLI](https://developers.openai.com/codex/) caches your login in a plaintext file at
`~/.codex/auth.json`. `codex-account-switch` snapshots that file under named profiles and swaps the
active one in — so you can keep an arbitrary number of accounts (work, personal, client-a, client-b,
…) side by side and switch instantly. No more logging out and back in.

---

## Requirements

- [OpenAI Codex CLI](https://developers.openai.com/codex/) installed (`codex`)
- `bash` (4+) and a POSIX environment (Linux / macOS / WSL)
- **File-based credential storage.** If your `~/.codex/config.toml` sets
  `cli_auth_credentials_store = "keyring"`, change it to `"file"` so credentials live in `auth.json`
  (that is the file this tool swaps).

---

## Install

```sh
git clone https://github.com/danganhtu01/codex-account-switch.git
cd codex-account-switch
./install.sh
```

This installs the `codex-switch` command to `~/.local/bin` (no `sudo` needed). If that directory is
not on your `PATH`, the installer tells you the one line to add.

Options:

```sh
./install.sh --symlink              # symlink instead of copy (so `git pull` updates the command)
./install.sh --prefix /usr/local    # install to /usr/local/bin
BINDIR=/somewhere/bin ./install.sh  # install to an explicit directory
```

## Uninstall

```sh
./uninstall.sh            # remove the command, KEEP your saved accounts
./uninstall.sh --purge    # also delete saved account profiles (destructive)
```

---

## Authenticate (initial setup)

First authenticate each account with the Codex CLI. **The auth command is:**

```sh
codex login
```

This opens the Sign in with ChatGPT flow and writes your credentials to `~/.codex/auth.json`.

For headless / remote machines (no local browser):

```sh
codex login --device-auth
```

With an existing access token (CI / scripted):

```sh
printenv CODEX_ACCESS_TOKEN | codex login --with-access-token
```

After each successful `codex login`, save that account under a name (next section).

---

## Usage

Save the account you are currently logged into:

```sh
codex login            # log in as account #1
codex-switch add work  # save the current login as "work"
```

Add more accounts — re-login as each, then save it under a new name:

```sh
codex login                # log in as account #2
codex-switch add personal

codex login                # log in as account #3
codex-switch add client-a
```

Switch between them:

```sh
codex-switch list          # show all accounts (active marked with *)
codex-switch use work      # switch to "work"
codex-switch work          # shorthand for `use work`
codex-switch current       # print the active account
```

Manage them:

```sh
codex-switch rename work day-job
codex-switch remove client-a          # asks to confirm
codex-switch remove client-a --force  # no prompt
```

### Command reference

| Command                      | What it does                                          |
| ---------------------------- | ----------------------------------------------------- |
| `add <name> [--force]`       | Save the current Codex login as account `<name>`      |
| `list` / `ls`                | List saved accounts (active marked `*`)               |
| `use <name>` / `<name>`      | Switch the active account to `<name>`                 |
| `current` / `who`            | Print the active account name                         |
| `remove <name> [--force]`    | Delete a saved account (your live login is untouched) |
| `rename <old> <new>`         | Rename a saved account                                |
| `help` / `version`           | Help / version                                        |

---

## How it works

- Saved accounts live in `~/.codex/account-switch/profiles/<name>/auth.json` (dir `700`, files `600`).
- `add` copies the live `~/.codex/auth.json` into a named profile.
- `use` copies a profile's `auth.json` back to `~/.codex/auth.json` (backing up the current one to
  `~/.codex/account-switch/.auth.json.bak` first).
- The active account is detected by comparing file contents, so `list`/`current` stay correct even if
  you log in/out directly with `codex`.

Override locations with environment variables:

- `CODEX_HOME` — Codex's home (default `~/.codex`); `codex-switch` follows it.
- `CODEX_SWITCH_HOME` — where profiles are stored (default `$CODEX_HOME/account-switch`).

---

## Security

`auth.json` contains live access tokens — treat each saved profile like a password. Profiles are
stored with restrictive permissions (`700`/`600`), but they are **not** encrypted. Don't commit them,
share them, or back them up to untrusted locations. `uninstall.sh` keeps them by default so you don't
lose accounts on a reinstall; use `--purge` to wipe them.

---

## License

[MIT](LICENSE)
