{ config, pkgs, ... }:

let
  tmxTag = pkgs.writeShellScriptBin "tmx-tag" ''
    set -eu

    tag_input="''${1:-}"
    session="''${2:-$(tmux display-message -p '#{session_name}')}"

    case "$tag_input" in
      act|active)
        tag="act"
        ;;
      arc|archive)
        tag="arc"
        ;;
      tmp|temp|scratch)
        tag="tmp"
        ;;
      *)
        echo "usage: tmx-tag <act|arc|tmp> [session]" >&2
        exit 64
        ;;
    esac

    case "$session" in
      act-*)
        base="''${session#act-}"
        ;;
      arc-*)
        base="''${session#arc-}"
        ;;
      tmp-*)
        base="''${session#tmp-}"
        ;;
      *)
        base="$session"
        ;;
    esac

    new_name="$tag-$base"

    if [ "$session" = "$new_name" ]; then
      exit 0
    fi

    if tmux has-session -t "$new_name" 2>/dev/null; then
      tmux display-message "session already exists: $new_name"
      exit 1
    fi

    tmux rename-session -t "$session" "$new_name"
    tmux display-message "session -> $new_name"
  '';

  tmx = pkgs.writeShellScriptBin "tmx" ''
    set -eu

    slugify() {
      printf '%s' "$1" \
        | tr ' /:.' '-' \
        | tr -cd '[:alnum:]_+-' \
        | sed -E 's/-+/-/g; s/^-+//; s/-+$//'
    }

    requested_name="''${1:-}"
    start_dir="''${2:-$PWD}"

    if [ -z "$requested_name" ]; then
      if [ "$PWD" = "$HOME" ]; then
        echo "usage: tmx <session-name> [directory]" >&2
        exit 64
      fi
      requested_name="$(basename "$PWD")"
    fi

    if [ ! -d "$start_dir" ]; then
      start_dir="$HOME"
    fi

    session="$(slugify "$requested_name")"

    if [ -z "$session" ]; then
      echo "session name resolved to empty after normalization" >&2
      exit 64
    fi

    case "$session" in
      act-*|arc-*|tmp-*)
        ;;
      *)
        session="act-$session"
        ;;
    esac

    if tmux has-session -t "$session" 2>/dev/null; then
      if [ -n "''${TMUX:-}" ]; then
        exec tmux switch-client -t "$session"
      else
        exec tmux attach-session -t "$session"
      fi
    fi

    if [ -n "''${TMUX:-}" ]; then
      tmux new-session -d -s "$session" -c "$start_dir" -n mgr
      exec tmux switch-client -t "$session"
    else
      exec tmux new-session -s "$session" -c "$start_dir" -n mgr
    fi
  '';

  tmxSessionSwitcher = pkgs.writeShellScriptBin "tmx-session-switcher" ''
    set -eu

    mode="''${1:-active}"

    case "$mode" in
      active)
        prompt="active> "
        empty_message="no active sessions"
        ;;
      all)
        prompt="all> "
        empty_message="no sessions"
        ;;
      archive)
        prompt="archive> "
        empty_message="no archive sessions"
        ;;
      scratch)
        prompt="scratch> "
        empty_message="no scratch sessions"
        ;;
      *)
        echo "usage: tmx-session-switcher <active|all|archive|scratch>" >&2
        exit 64
        ;;
    esac

    sessions="$(
      tmux list-sessions -F '#{session_name} :: #{?session_attached,attached,detached} :: #{session_windows}w' \
        | awk -F ' :: ' -v mode="$mode" '
            mode == "all" { print; next }
            mode == "archive" && $1 ~ /^arc-/ { print; next }
            mode == "scratch" && $1 ~ /^tmp-/ { print; next }
            mode == "active" && ($1 ~ /^act-/ || ($1 !~ /^arc-/ && $1 !~ /^tmp-/)) { print; next }
          ' \
        | sort -f
    )"

    if [ -z "$sessions" ]; then
      tmux display-message "$empty_message"
      exit 0
    fi

    selected="$(
      printf '%s\n' "$sessions" | ${pkgs.fzf}/bin/fzf \
        --layout=reverse \
        --height=100% \
        --border \
        --delimiter=' :: ' \
        --with-nth=1.. \
        --prompt="$prompt" \
        --header='enter switch session, esc cancel' \
        --preview='tmux list-windows -t {1} -F "#{?window_active,> ,  }#{window_index}:#{window_name}  #{window_panes}p  #{pane_current_path}"' \
        --preview-window='right,60%,wrap'
    )"

    if [ -z "$selected" ]; then
      exit 0
    fi

    session="$(printf '%s' "$selected" | awk -F ' :: ' '{print $1}')"

    if [ -n "''${TMUX:-}" ]; then
      exec tmux switch-client -t "$session"
    else
      exec tmux attach-session -t "$session"
    fi
  '';

  tmxSessionContext = pkgs.writeShellScriptBin "tmx-session-context" ''
    set -eu

    session="''${1:-$(tmux display-message -p '#S')}"
    printf 'Session metadata\n'
    tmux display-message -p -t "$session" 'name=#{session_name} attached=#{session_attached} windows=#{session_windows} activity=#{t/p:session_activity}'
    printf '\n'
    printf 'Window and pane metadata\n'
    tmux list-windows -t "$session" -F 'window #{window_index}: name=#{window_name} active=#{window_active} panes=#{window_panes} flags=#{window_flags}'
    printf '\n'

    while IFS=$'\t' read -r window_index window_name; do
      printf 'Window %s (%s)\n' "$window_index" "$window_name"
      tmux list-panes -t "$session:$window_index" -F 'pane #{pane_index}: active=#{pane_active} cwd=#{pane_current_path} cmd=#{pane_current_command} title=#{pane_title}'
      active_pane="$(tmux list-panes -t "$session:$window_index" -F '#{?pane_active,1,0}	#{pane_id}' | awk '$1 == 1 { print $2; exit }')"
      if [ -n "$active_pane" ]; then
        printf 'Recent output from the active pane in window %s\n' "$window_index"
        tmux capture-pane -p -t "$active_pane" -S -40
      fi
      printf '\n'
    done <<EOF
$(tmux list-windows -t "$session" -F '#{window_index}	#{window_name}')
EOF
  '';

  tmxSessionSummary = pkgs.writeShellScriptBin "tmx-session-summary" ''
    set -eu

    session="''${1:-$(tmux display-message -p '#S')}"
    prompt_file="$(mktemp)"
    output_file="$(mktemp)"
    log_file="$(mktemp)"
    trap 'rm -f "$prompt_file" "$output_file" "$log_file"' EXIT

    {
      printf 'You are writing a tmux resume note for a power user returning to this session later.\n'
      printf 'Optimize for fast re-entry, not generic recap.\n'
      printf 'Use only the evidence in the tmux metadata and recent pane output.\n'
      printf 'If evidence is weak, say you are uncertain instead of guessing.\n'
      printf 'Prefer concrete next actions over broad summaries.\n'
      printf '\n'
      printf 'Return Markdown with exactly these sections:\n'
      printf '1. Resume In 30 Seconds\n'
      printf '2. Window Map\n'
      printf '3. Next Concrete Steps\n'
      printf '\n'
      printf 'Section guidance:\n'
      printf -- '- Resume In 30 Seconds: 2 to 4 bullets covering the likely goal of the session, what changed recently, any blocker/risk, and the best next move.\n'
      printf -- '- Window Map: one bullet per window in the form [index:name] cwd, current command, what it appears to be doing, and whether it looks active, blocked, or stale.\n'
      printf -- '- Next Concrete Steps: 1 to 3 numbered actions. Prefer specific commands, files, or checks when supported by the context.\n'
      printf '\n'
      printf 'Do not waste space repeating obvious metadata unless it changes the recommendation.\n'
      printf 'If the recent output is mostly noise, say that and rely on cwd, command, and window name.\n'
      printf '\n'
      tmx-session-context "$session"
    } > "$prompt_file"

    printf 'Generating session summary for %s...\n' "$session"

    if codex exec \
      --skip-git-repo-check \
      --ephemeral \
      --color never \
      --sandbox read-only \
      -C "$HOME" \
      -o "$output_file" \
      < "$prompt_file" \
      > "$log_file" 2>&1; then
      exec env LESS=RX less -R "$output_file"
    fi

    {
      printf 'codex exec failed while generating a tmux summary.\n'
      printf '\n'
      sed -n '1,220p' "$log_file"
    } > "$output_file"
    exec env LESS=RX less -R "$output_file"
  '';

  tmxSessionScratchpad = pkgs.writeShellScriptBin "tmx-session-scratchpad" ''
    set -eu

    command="''${1:-edit}"
    session="''${2:-$(tmux display-message -p '#S')}"
    scratch_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tmux-scratchpads"
    start_marker='<!-- AI-SCRATCH-START -->'
    end_marker='<!-- AI-SCRATCH-END -->'
    editor="''${VISUAL:-''${EDITOR:-vi}}"

    base_session() {
      case "$1" in
        act-*)
          printf '%s\n' "''${1#act-}"
          ;;
        arc-*)
          printf '%s\n' "''${1#arc-}"
          ;;
        tmp-*)
          printf '%s\n' "''${1#tmp-}"
          ;;
        *)
          printf '%s\n' "$1"
          ;;
      esac
    }

    append_manual_note() {
      note="$1"
      rewritten_file="$(mktemp)"

      awk -v note="$note" '
        BEGIN {
          in_manual = 0
          inserted = 0
          saw_manual_content = 0
        }
        /^## Manual Notes$/ {
          in_manual = 1
          print
          next
        }
        /^## AI Session Note$/ {
          if (!inserted) {
            print ""
            print note
            print ""
            inserted = 1
          }
          in_manual = 0
          print
          next
        }
        {
          if (in_manual) {
            if (($0 == "-" || $0 == "- ") && !saw_manual_content) {
              next
            }
            if ($0 != "") {
              saw_manual_content = 1
            }
          }
          print
        }
      ' "$file" > "$rewritten_file"

      mv "$rewritten_file" "$file"
    }

    ensure_file() {
      mkdir -p "$scratch_dir"
      if [ ! -f "$file" ]; then
        cat > "$file" <<EOF
# Scratchpad: $base

Session base: \`$base\`

## Manual Notes


## AI Session Note
$start_marker
_Not generated yet. Run \`prefix + G\` to refresh the AI note._
$end_marker
EOF
      fi
    }

    base="$(base_session "$session")"
    file="$scratch_dir/$base.md"
    ensure_file

    case "$command" in
      path)
        printf '%s\n' "$file"
        ;;
      edit)
        exec "$editor" "$file"
        ;;
      view)
        exec env LESS=RX less -R "$file"
        ;;
      prompt)
        printf 'Scratch note for %s\n' "$base"
        printf 'note> '
        IFS= read -r note || exit 0
        if [ -z "$note" ]; then
          exit 0
        fi
        append_manual_note "- [$(date '+%Y-%m-%d %H:%M')] $note"
        tmux display-message "scratchpad updated: $base"
        ;;
      capture)
        snapshot="$(tmux display-message -p 'window=#{window_index}:#{window_name} :: #{pane_current_path} :: #{pane_current_command}')"
        append_manual_note "- [$(date '+%Y-%m-%d %H:%M')] snapshot: $snapshot"
        tmux display-message "scratchpad snapshot saved: $base"
        ;;
      ai)
        prompt_file="$(mktemp)"
        output_file="$(mktemp)"
        generated_file="$(mktemp)"
        rewritten_file="$(mktemp)"
        log_file="$(mktemp)"
        trap 'rm -f "$prompt_file" "$output_file" "$generated_file" "$rewritten_file" "$log_file"' EXIT

        {
          printf 'You are updating the AI section of a tmux scratchpad for a power user.\n'
          printf 'The scratchpad should help the user resume this session later with minimal context switching.\n'
          printf 'Use only the current tmux session context and the existing scratchpad contents.\n'
          printf 'If evidence is weak, say you are uncertain instead of guessing.\n'
          printf '\n'
          printf 'Return Markdown only with exactly these headings:\n'
          printf '## Current Objective\n'
          printf '## What Changed\n'
          printf '## Blockers / Risks\n'
          printf '## Next Moves\n'
          printf '## Useful References\n'
          printf '\n'
          printf 'Rules:\n'
          printf -- '- Current Objective: 1 to 2 bullets.\n'
          printf -- '- What Changed: 2 to 5 bullets, recent and evidence-based.\n'
          printf -- '- Blockers / Risks: bullets only if real; otherwise use `- None obvious from current context.`\n'
          printf -- '- Next Moves: 1 to 5 concrete, actionable bullets. Prefer exact commands, files, checks, or windows when supported.\n'
          printf -- '- Useful References: include relevant commands, files, or tmux window names. If nothing useful is captured, use `- None captured.`\n'
          printf '\n'
          printf 'Existing scratchpad contents\n'
          cat "$file"
          printf '\n'
          tmx-session-context "$session"
        } > "$prompt_file"

        printf 'Generating AI scratchpad for %s...\n' "$session"

        if codex exec \
          --skip-git-repo-check \
          --ephemeral \
          --color never \
          --sandbox read-only \
          -C "$HOME" \
          -o "$output_file" \
          < "$prompt_file" \
          > "$log_file" 2>&1; then
          {
            printf '_Updated: %s_\n\n' "$(date '+%Y-%m-%d %H:%M')"
            cat "$output_file"
          } > "$generated_file"

          awk -v start="$start_marker" -v end="$end_marker" -v repl="$generated_file" '
            BEGIN {
              while ((getline line < repl) > 0) {
                replacement = replacement line ORS
              }
              close(repl)
            }
            $0 == start {
              print
              printf "%s", replacement
              skip = 1
              next
            }
            $0 == end {
              skip = 0
              print
              next
            }
            !skip { print }
          ' "$file" > "$rewritten_file"

          mv "$rewritten_file" "$file"
          exec "$editor" "$file"
        fi

        {
          printf 'codex exec failed while generating the AI scratchpad.\n'
          printf '\n'
          sed -n '1,220p' "$log_file"
        } > "$output_file"
        exec env LESS=RX less -R "$output_file"
        ;;
      *)
        printf 'usage: tmx-session-scratchpad <edit|view|prompt|capture|ai|path> [session]\n' >&2
        exit 64
        ;;
      esac
  '';

  tmxCodexCreditMonitor = pkgs.writeShellScriptBin "tmx-codex-credit-monitor" ''
    set -eu

    command="''${1:-start}"
    requested_session="''${2:-}"
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tmux-codex-credit-monitor"
    default_dir="$HOME/Documents/Code"
    default_session="''${TMX_CODEX_CREDIT_SESSION:-arc-codex-monitor}"
    window_name="codex-credits"
    threshold="''${TMX_CODEX_CREDIT_THRESHOLD:-300}"
    interval="''${TMX_CODEX_CREDIT_INTERVAL_SECONDS:-120}"

    mkdir -p "$state_dir"

    resolve_session() {
      if [ -n "$requested_session" ]; then
        printf '%s\n' "$requested_session"
      else
        printf '%s\n' "$default_session"
      fi
    }

    session="$(resolve_session)"

    session_key="$(printf '%s' "$session" | tr -c '[:alnum:]_.-' '_')"
    pid_file="$state_dir/$session_key.pid"
    lock_dir="$state_dir/$session_key.lock"
    state_file="$state_dir/$session_key.state"

    current_alerted() {
      if [ -f "$state_file" ]; then
        sed -n 's/^alerted=//p' "$state_file" | tail -n 1
      fi
    }

    write_state() {
      credits="$1"
      alerted="$2"
      last_error="$3"

      {
        printf 'session=%s\n' "$session"
        printf 'window_name=%s\n' "$window_name"
        printf 'threshold=%s\n' "$threshold"
        printf 'interval=%s\n' "$interval"
        printf 'credits=%s\n' "$credits"
        printf 'alerted=%s\n' "$alerted"
        printf 'updated_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'last_error=%s\n' "$last_error"
      } > "$state_file"
    }

    find_window_id() {
      tmux list-windows -t "$session" -F '#{window_name}	#{window_id}' \
        | awk -F '	' -v target="$window_name" '$1 == target { print $2; exit }'
    }

    pane_id_for_window() {
      tmux list-panes -t "$1" -F '#{pane_id}' | head -n 1
    }

    ensure_session() {
      if tmux has-session -t "$session" 2>/dev/null; then
        return 0
      fi

      window_id="$(tmux new-session -d -P -F '#{window_id}' -s "$session" -n "$window_name" -c "$default_dir")"
      tmux set-window-option -t "$window_id" automatic-rename off >/dev/null
      tmux rename-window -t "$window_id" "$window_name"
    }

    create_window() {
      window_id="$(tmux new-window -P -F '#{window_id}' -d -t "$session" -n "$window_name" -c "$default_dir")"
      tmux set-window-option -t "$window_id" automatic-rename off >/dev/null
      tmux rename-window -t "$window_id" "$window_name"
      printf '%s\n' "$window_id"
    }

    wait_for_codex() {
      pane_id="$1"
      attempt=0

      while [ "$attempt" -lt 45 ]; do
        pane_text="$(tmux capture-pane -p -t "$pane_id" -S -120 2>/dev/null || true)"
        if printf '%s\n' "$pane_text" | grep -q 'OpenAI Codex' && printf '%s\n' "$pane_text" | grep -q '› '; then
          return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
      done

      return 1
    }

    launch_codex() {
      pane_id="$1"
      tmux send-keys -t "$pane_id" "codex --no-alt-screen" Enter
      wait_for_codex "$pane_id"
    }

    ensure_codex_pane() {
      ensure_session
      window_id="$(find_window_id)"

      if [ -z "$window_id" ]; then
        window_id="$(create_window)"
      fi

      pane_id="$(pane_id_for_window "$window_id")"
      current_command="$(tmux display-message -p -t "$pane_id" '#{pane_current_command}')"

      if [ "$current_command" != "node" ]; then
        launch_codex "$pane_id" || {
          tmux kill-window -t "$window_id"
          window_id="$(create_window)"
          pane_id="$(pane_id_for_window "$window_id")"
          launch_codex "$pane_id"
        }
      else
        wait_for_codex "$pane_id" || {
          tmux kill-window -t "$window_id"
          window_id="$(create_window)"
          pane_id="$(pane_id_for_window "$window_id")"
          launch_codex "$pane_id"
        }
      fi

      tmux set-window-option -t "$window_id" automatic-rename off >/dev/null
      tmux rename-window -t "$window_id" "$window_name"
      printf '%s\n' "$pane_id"
    }

    read_credits() {
      pane_id="$1"
      attempt=0

      tmux send-keys -t "$pane_id" '/status' Enter
      sleep 1
      tmux send-keys -t "$pane_id" Enter

      while [ "$attempt" -lt 12 ]; do
        pane_text="$(tmux capture-pane -p -t "$pane_id" -S -240 2>/dev/null || true)"
        credits="$(printf '%s\n' "$pane_text" | sed -nE 's/.*Credits:[[:space:]]*([0-9]+) credits.*/\1/p' | tail -n 1)"
        if [ -n "$credits" ]; then
          printf '%s\n' "$credits"
          return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
      done

      return 1
    }

    show_low_credit_popup() {
      credits="$1"
      clients="$(tmux list-clients -F '#{client_name}' 2>/dev/null || true)"

      if [ -z "$clients" ]; then
        return 1
      fi

      while IFS= read -r client; do
        [ -n "$client" ] || continue
        tmux display-popup -c "$client" -w 60% -h 20% -T "Codex Credits Low" "CREDITS=$credits sh -lc 'printf \"%s\n\n%s\n%s\n\n\" \"Codex credits are low.\" \"\$CREDITS credits remaining.\" \"Go buy more credits.\"; printf \"Press Enter to close... \"; IFS= read -r _'" >/dev/null 2>&1 || true
      done <<EOF
$clients
EOF

      return 0
    }

    run_check() {
      alerted="''${1:-$(current_alerted || true)}"
      pane_id="$(ensure_codex_pane)" || {
        write_state "unknown" "$alerted" "unable to start Codex"
        return 1
      }

      credits="$(read_credits "$pane_id" || true)"

      if [ -z "$credits" ]; then
        write_state "unknown" "$alerted" "unable to parse credits from /status"
        return 1
      fi

      if [ "$credits" -lt "$threshold" ]; then
        if [ "$alerted" != "1" ] && show_low_credit_popup "$credits"; then
          alerted="1"
        fi
      else
        alerted="0"
      fi

      write_state "$credits" "$alerted" ""
      printf '%s\n' "$credits"
    }

    case "$command" in
      start)
        if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
          exit 0
        fi
        nohup "$(command -v tmx-codex-credit-monitor)" daemon "$session" >/dev/null 2>&1 &
        ;;
      daemon)
        if ! mkdir "$lock_dir" 2>/dev/null; then
          if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
            exit 0
          fi
          rm -rf "$lock_dir"
          mkdir "$lock_dir"
        fi

        echo $$ > "$pid_file"
        trap 'rm -f "$pid_file"; rmdir "$lock_dir" 2>/dev/null || true' EXIT INT TERM

        while :; do
          tmx-codex-credit-monitor check "$session" >/dev/null 2>&1 || true
          sleep "$interval"
        done
        ;;
      stop)
        if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
          kill "$(cat "$pid_file")"
          rm -f "$pid_file"
        fi
        rm -rf "$lock_dir"
        ;;
      check)
        run_check
        ;;
      check-now)
        if credits="$(run_check)"; then
          tmux display-message "codex credits: $credits"
          exit 0
        fi
        tmux display-message "codex credit check failed"
        exit 1
        ;;
      open)
        pane_id="$(ensure_codex_pane)"
        window_id="$(tmux display-message -p -t "$pane_id" '#{window_id}')"
        if [ -n "''${TMUX:-}" ]; then
          tmux switch-client -t "$session"
          tmux select-window -t "$window_id"
        else
          exec tmux attach-session -t "$session"
        fi
        ;;
      status)
        if [ -f "$state_file" ]; then
          cat "$state_file"
          exit 0
        fi
        printf 'session=%s\nwindow_name=%s\ncredits=unknown\nalerted=0\nlast_error=not checked yet\n' "$session" "$window_name"
        ;;
      *)
        printf 'usage: tmx-codex-credit-monitor <start|stop|check|check-now|open|status> [session]\n' >&2
        exit 64
        ;;
      esac
  '';

  tmxCodexAttentionMonitor = pkgs.writeShellScriptBin "tmx-codex-attention-monitor" ''
    set -euo pipefail
    shopt -s nullglob

    command="''${1:-start}"
    arg1="''${2:-}"
    filter_prefix="''${arg1:-''${TMX_CODEX_ATTENTION_SESSION_PREFIX:-act-}}"
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/tmx-codex-attention-monitor"
    panes_dir="$state_dir/panes"
    pid_file="$state_dir/daemon.pid"
    lock_dir="$state_dir/daemon.lock"
    interval="''${TMX_CODEX_ATTENTION_INTERVAL_SECONDS:-2}"
    debounce_seconds="''${TMX_CODEX_ATTENTION_DEBOUNCE_SECONDS:-4}"
    prompt_marker="$(printf '\342\200\272 ')"
    monitor_script="$(command -v tmx-codex-attention-monitor)"

    mkdir -p "$panes_dir"

    pane_key() {
      printf '%s' "$1" | tr -c '[:alnum:]_.-' '_'
    }

    pane_file() {
      printf '%s/%s.state\n' "$panes_dir" "$(pane_key "$1")"
    }

    resolve_pane() {
      if [ -n "''${1:-}" ]; then
        printf '%s\n' "$1"
      else
        tmux display-message -p '#{pane_id}'
      fi
    }

    read_state() {
      local key="$1"
      local file="$2"

      [ -f "$file" ] || return 1
      sed -n "s/^$key=//p" "$file" | tail -n 1
    }

    pane_exists() {
      tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qx "$1"
    }

    pane_info() {
      tmux display-message -p -t "$1" '#{session_name}	#{window_index}	#{window_name}	#{pane_id}	#{pane_current_command}'
    }

    window_seen_by_client() {
      local session="$1"
      local window_index="$2"

      tmux list-clients -F '#{session_name}	#{window_index}' 2>/dev/null | awk -F '\t' -v session="$session" -v window_index="$window_index" '
        $1 == session && $2 == window_index {
          found = 1
        }
        END {
          exit(found ? 0 : 1)
        }
      '
    }

    monitor_pids() {
      ps -Ao pid=,command= | awk -v self="$monitor_script" '
        index($0, self " daemon") > 0 {
          print $1
        }
      '
    }

    pane_state() {
      local pane="$1"
      local visible_height
      local pane_text

      visible_height="$(tmux display-message -p -t "$pane" '#{pane_height}' 2>/dev/null || printf '40')"
      if ! printf '%s\n' "$visible_height" | grep -Eq '^[0-9]+$'; then
        visible_height='40'
      fi

      pane_text="$(tmux capture-pane -p -t "$pane" -S "-$visible_height" 2>/dev/null || true)"

      printf '%s\n' "$pane_text" | awk -v prompt="$prompt_marker" '
        { lines[NR] = $0; n = NR }
        END {
          start = n - 12
          if (start < 1) start = 1
          tail_start = n - 5
          if (tail_start < 1) tail_start = 1

          for (i = start; i <= n; i++) {
            if (index(lines[i], "Press enter to confirm or esc to cancel") || index(lines[i], "Would you like to run the following command?")) {
              approval = 1
            }
            if (index(lines[i], "• Working (") && index(lines[i], "esc to interrupt")) {
              busy = 1
            }
            if (index(lines[i], "Waiting for background terminal")) {
              busy = 1
            }
          }

          for (i = tail_start; i <= n; i++) {
            if (index(lines[i], prompt) == 1) {
              prompt_near_end = 1
            }
            if (lines[i] ~ /^[[:space:]]+gpt-[^[:space:]]+/) {
              model_near_end = 1
            }
          }

          if (approval) {
            print "0\t0\t1"
          } else if (busy) {
            print "1\t0\t0"
          } else if (prompt_near_end && model_near_end) {
            print "0\t1\t0"
          } else {
            print "0\t0\t0"
          }
        }
      '
    }

    write_state() {
      local file="$1"
      local pane="$2"
      local session="$3"
      local window_index="$4"
      local window_name="$5"
      local current_command="$6"
      local busy="$7"
      local waiting="$8"
      local approval="$9"
      local attention_kind="''${10}"
      local candidate_since="''${11}"
      local acknowledged="''${12}"
      local alerted="''${13}"

      {
        printf 'pane=%s\n' "$pane"
        printf 'session=%s\n' "$session"
        printf 'window_index=%s\n' "$window_index"
        printf 'window_name=%s\n' "$window_name"
        printf 'current_command=%s\n' "$current_command"
        printf 'busy=%s\n' "$busy"
        printf 'waiting=%s\n' "$waiting"
        printf 'approval=%s\n' "$approval"
        printf 'attention_kind=%s\n' "$attention_kind"
        printf 'candidate_since=%s\n' "$candidate_since"
        printf 'acknowledged=%s\n' "$acknowledged"
        printf 'alerted=%s\n' "$alerted"
        printf 'updated_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
      } > "$file"
    }

    acknowledge_pane() {
      local pane="$1"
      local file
      local session
      local window_index
      local window_name
      local current_command
      local busy
      local waiting
      local approval
      local attention_kind
      local candidate_since

      file="$(pane_file "$pane")"
      [ -f "$file" ] || return 0

      session="$(read_state session "$file" 2>/dev/null || printf '?')"
      window_index="$(read_state window_index "$file" 2>/dev/null || printf '?')"
      window_name="$(read_state window_name "$file" 2>/dev/null || printf '?')"
      current_command="$(read_state current_command "$file" 2>/dev/null || printf '?')"
      busy="$(read_state busy "$file" 2>/dev/null || printf '0')"
      waiting="$(read_state waiting "$file" 2>/dev/null || printf '0')"
      approval="$(read_state approval "$file" 2>/dev/null || printf '0')"
      attention_kind="$(read_state attention_kind "$file" 2>/dev/null || true)"
      candidate_since="$(read_state candidate_since "$file" 2>/dev/null || printf '0')"

      write_state "$file" "$pane" "$session" "$window_index" "$window_name" "$current_command" "$busy" "$waiting" "$approval" "$attention_kind" "$candidate_since" "1" "0"
    }

    refresh_status() {
      local clients

      clients="$(tmux list-clients -F '#{client_name}' 2>/dev/null || true)"
      [ -n "$clients" ] || return 0

      while IFS= read -r client; do
        [ -n "$client" ] || continue
        tmux refresh-client -S -t "$client" >/dev/null 2>&1 || true
      done <<EOF
$clients
EOF
    }

    notify_attention() {
      local session="$1"
      local window_index="$2"
      local window_name="$3"
      local attention_kind="$4"
      local clients

      osascript -e 'beep' >/dev/null 2>&1 || true

      clients="$(tmux list-clients -F '#{client_name}' 2>/dev/null || true)"
      if [ -n "$clients" ]; then
        while IFS= read -r client; do
          [ -n "$client" ] || continue
          tmux display-message -t "$client" "codex $attention_kind: $session:$window_index $window_name" >/dev/null 2>&1 || true
        done <<EOF
$clients
EOF
      fi
    }

    update_pane() {
      local pane="$1"
      local file
      local session
      local window_index
      local window_name
      local pane_id
      local current_command
      local busy
      local waiting
      local approval
      local old_attention_kind
      local old_candidate_since
      local old_acknowledged
      local old_waiting
      local old_approval
      local old_attention
      local attention
      local attention_kind
      local candidate_since
      local acknowledged
      local old_alerted
      local alerted
      local now_epoch

      file="$(pane_file "$pane")"

      if ! pane_exists "$pane"; then
        rm -f "$file"
        return 10
      fi

      IFS=$'\t' read -r session window_index window_name pane_id current_command < <(pane_info "$pane")
      IFS=$'\t' read -r busy waiting approval < <(pane_state "$pane")

      now_epoch="$(date +%s)"
      old_attention_kind="$(read_state attention_kind "$file" 2>/dev/null || true)"
      old_candidate_since="$(read_state candidate_since "$file" 2>/dev/null || printf '0')"
      old_acknowledged="$(read_state acknowledged "$file" 2>/dev/null || printf '0')"
      old_waiting="$(read_state waiting "$file" 2>/dev/null || printf '0')"
      old_approval="$(read_state approval "$file" 2>/dev/null || printf '0')"
      old_alerted="$(read_state alerted "$file" 2>/dev/null || printf '0')"
      if [ "$old_waiting" = "1" ] || [ "$old_approval" = "1" ]; then
        old_attention="1"
      else
        old_attention="0"
      fi
      if [ "$waiting" = "1" ] || [ "$approval" = "1" ]; then
        attention="1"
      else
        attention="0"
      fi
      alerted="$old_alerted"

      if [ "$approval" = "1" ]; then
        attention_kind="approval"
      elif [ "$waiting" = "1" ]; then
        attention_kind="waiting"
      else
        attention_kind=""
      fi

      candidate_since="$old_candidate_since"
      acknowledged="$old_acknowledged"

      if [ "$attention" != "1" ]; then
        candidate_since="0"
        acknowledged="0"
        alerted="0"
      elif [ "$attention_kind" != "$old_attention_kind" ] || [ "$old_attention" != "1" ]; then
        candidate_since="$now_epoch"
        acknowledged="0"
        alerted="0"
      elif [ "$old_alerted" = "1" ] && window_seen_by_client "$session" "$window_index"; then
        acknowledged="1"
        alerted="0"
      elif window_seen_by_client "$session" "$window_index" && [ "$candidate_since" -gt 0 ] && [ $((now_epoch - candidate_since)) -ge "$debounce_seconds" ]; then
        acknowledged="1"
        alerted="0"
      elif window_seen_by_client "$session" "$window_index"; then
        alerted="0"
      elif [ "$acknowledged" = "1" ]; then
        alerted="0"
      elif [ "$candidate_since" -le 0 ]; then
        candidate_since="$now_epoch"
        alerted="0"
      elif [ "$old_alerted" = "1" ]; then
        alerted="1"
      elif [ "$candidate_since" -gt 0 ] && [ $((now_epoch - candidate_since)) -ge "$debounce_seconds" ]; then
        alerted="1"
        notify_attention "$session" "$window_index" "$window_name" "$attention_kind"
      else
        alerted="0"
      fi

      write_state "$file" "$pane_id" "$session" "$window_index" "$window_name" "$current_command" "$busy" "$waiting" "$approval" "$attention_kind" "$candidate_since" "$acknowledged" "$alerted"

      if [ "$old_waiting" != "$waiting" ] || [ "$old_approval" != "$approval" ] || [ "$old_alerted" != "$alerted" ]; then
        return 10
      fi

      return 0
    }

    collect_attention() {
      local prefix="$1"
      local file
      local pane
      local session
      local window_index
      local window_name
      local waiting
      local approval
      local alerted
      local attention_kind

      for file in "$panes_dir"/*.state; do
        [ -e "$file" ] || continue
        pane="$(read_state pane "$file" 2>/dev/null || true)"
        session="$(read_state session "$file" 2>/dev/null || true)"
        window_index="$(read_state window_index "$file" 2>/dev/null || true)"
        window_name="$(read_state window_name "$file" 2>/dev/null || true)"
        waiting="$(read_state waiting "$file" 2>/dev/null || printf '0')"
        approval="$(read_state approval "$file" 2>/dev/null || printf '0')"
        alerted="$(read_state alerted "$file" 2>/dev/null || printf '0')"

        if [ "$approval" = "1" ]; then
          attention_kind="approval"
        elif [ "$waiting" = "1" ]; then
          attention_kind="waiting"
        else
          continue
        fi
        [ "$alerted" = "1" ] || continue
        if window_seen_by_client "$session" "$window_index"; then
          continue
        fi
        case "$session" in
          "$prefix"*) ;;
          *) continue ;;
        esac

        printf '%s\t%s\t%s\t%s\t%s\n' "$pane" "$session" "$window_index" "$window_name" "$attention_kind"
      done
    }

    case "$command" in
      start)
        tmx-codex-attention-monitor stop >/dev/null 2>&1 || true
        nohup "$monitor_script" daemon >/dev/null 2>&1 < /dev/null &
        ;;
      daemon)
        mkdir -p "$panes_dir"
        echo $$ > "$pid_file"
        trap '
          if [ "$(cat "$pid_file" 2>/dev/null || true)" = "$$" ]; then
            rm -f "$pid_file"
          fi
          rm -rf "$lock_dir" 2>/dev/null || true
        ' EXIT INT TERM

        while :; do
          if [ "$(cat "$pid_file" 2>/dev/null || true)" != "$$" ]; then
            exit 0
          fi

          changed=0
          for file in "$panes_dir"/*.state; do
            [ -e "$file" ] || continue
            pane="$(read_state pane "$file" 2>/dev/null || true)"
            [ -n "$pane" ] || continue
            if update_pane "$pane"; then
              :
            else
              status=$?
              if [ "$status" -eq 10 ]; then
                changed=1
              fi
            fi
          done

          if [ "$changed" -eq 1 ]; then
            refresh_status
          fi

          sleep "$interval"
        done
        ;;
      stop)
        if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
          kill "$(cat "$pid_file")" >/dev/null 2>&1 || true
          rm -f "$pid_file"
        fi
        mapfile -t pids < <(monitor_pids)
        for pid in "''${pids[@]:-}"; do
          [ -n "$pid" ] || continue
          kill "$pid" >/dev/null 2>&1 || true
        done
        sleep 0.2
        mapfile -t pids < <(monitor_pids)
        for pid in "''${pids[@]:-}"; do
          [ -n "$pid" ] || continue
          kill -9 "$pid" >/dev/null 2>&1 || true
        done
        rm -rf "$lock_dir"
        ;;
      toggle)
        pane="$(resolve_pane "$arg1")"
        file="$(pane_file "$pane")"

        if [ -f "$file" ]; then
          session="$(read_state session "$file" 2>/dev/null || printf '?')"
          window_index="$(read_state window_index "$file" 2>/dev/null || printf '?')"
          window_name="$(read_state window_name "$file" 2>/dev/null || printf '?')"
          rm -f "$file"
          tmux display-message "codex watcher off: $session:$window_index $window_name"
          refresh_status
          exit 0
        fi

        if ! pane_exists "$pane"; then
          tmux display-message "codex watcher: pane not found"
          exit 1
        fi

        IFS=$'\t' read -r session window_index window_name pane_id current_command < <(pane_info "$pane")
        IFS=$'\t' read -r busy waiting approval < <(pane_state "$pane")
        if [ "$approval" = "1" ]; then
          attention_kind="approval"
          candidate_since="$(date +%s)"
        elif [ "$waiting" = "1" ]; then
          attention_kind="waiting"
          candidate_since="$(date +%s)"
        else
          attention_kind=""
          candidate_since="0"
        fi
        acknowledged="0"
        alerted="0"
        write_state "$file" "$pane_id" "$session" "$window_index" "$window_name" "$current_command" "$busy" "$waiting" "$approval" "$attention_kind" "$candidate_since" "$acknowledged" "$alerted"
        tmux display-message "codex watcher on: $session:$window_index $window_name"
        refresh_status
        tmx-codex-attention-monitor start
        ;;
      status-line)
        lines="$(collect_attention "$filter_prefix" || true)"
        if [ -z "$lines" ]; then
          printf 'clear\n'
          exit 0
        fi

        printf '%s\n' "$lines" | awk -F '\t' '{printf "%s[%s %s] ", $2, $3, $5}'
        ;;
      pick)
        mapfile -t panes < <(collect_attention "$filter_prefix" | awk -F '\t' '{print $1}')

        case "''${#panes[@]}" in
          0)
            tmux display-message "no waiting codex panes"
            ;;
          1)
            acknowledge_pane "''${panes[0]}"
            refresh_status
            tmux switch-client -t "''${panes[0]}"
            ;;
          *)
            filter="#{==:#{pane_id},''${panes[0]}}"
            for pane in "''${panes[@]:1}"; do
              filter="#{||:''${filter},#{==:#{pane_id},$pane}}"
            done
            tmux choose-tree -Zw -f "$filter"
            ;;
        esac
        ;;
      status)
        for file in "$panes_dir"/*.state; do
          [ -e "$file" ] || continue
          printf '%s\n' "--- $file"
          cat "$file"
        done
        ;;
      *)
        printf 'usage: tmx-codex-attention-monitor <start|stop|toggle|status-line|pick|status> [session-prefix] [pane]\n' >&2
        exit 64
        ;;
    esac
  '';
in
{
  home.packages = [
    tmx
    tmxTag
    tmxSessionSwitcher
    tmxSessionContext
    tmxSessionSummary
    tmxSessionScratchpad
    tmxCodexCreditMonitor
    tmxCodexAttentionMonitor
  ];

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 100000;
    keyMode = "vi";

    extraConfig = ''
      set -g renumber-windows on
      set -g status-keys vi
      setw -g automatic-rename on
      set -g bell-action other
      set -g silence-action other
      set -g visual-bell off
      set -g visual-silence off
      set -g status 2
      set -g window-status-bell-style fg=colour231,bg=colour160,bold
      set -g window-status-activity-style fg=colour16,bg=colour220,bold
      setw -g monitor-activity off
      setw -g monitor-bell off
      setw -g monitor-silence 0
      set -g status-format[1] "#[align=left]#[fg=colour16,bg=colour81,bold] codex waiting #[default] #(tmx-codex-attention-monitor status-line act-)"

      bind-key c new-window -c "#{pane_current_path}"
      bind-key C new-window -c "#{HOME}"
      bind-key '"' split-window -v -c "#{pane_current_path}"
      bind-key % split-window -h -c "#{pane_current_path}"

      bind-key s if-shell "tmux list-sessions | cut -d: -f1 | grep -Ev '^(arc-|tmp-)' | grep -q ." "choose-tree -sZw -O name -f '#{||:#{m:act-*,#{session_name}},#{&&:#{!:#{m:arc-*,#{session_name}}},#{!:#{m:tmp-*,#{session_name}}}}}' -F '#{?session_attached,[*],[ ]} #{session_windows}w'" "display-message 'no active sessions'"
      bind-key S display-popup -E -w 85% -h 75% -T "All Sessions" "tmx-session-switcher all"
      bind-key r if-shell "tmux list-sessions | cut -d: -f1 | grep -q '^arc-'" "choose-tree -sZw -O name -f '#{m:arc-*,#{session_name}}' -F '#{?session_attached,[*],[ ]} #{session_windows}w'" "display-message 'no archive sessions'"
      bind-key t if-shell "tmux list-sessions | cut -d: -f1 | grep -q '^tmp-'" "choose-tree -sZw -O name -f '#{m:tmp-*,#{session_name}}' -F '#{?session_attached,[*],[ ]} #{session_windows}w'" "display-message 'no scratch sessions'"
      bind-key / display-popup -E -w 85% -h 75% -T "Active Session Search" "tmx-session-switcher active"
      bind-key e run-shell "tmx-codex-attention-monitor pick act-"
      bind-key E run-shell "tmx-codex-attention-monitor toggle '#{pane_id}'"
      bind-key H run-shell "tmx-session-scratchpad capture"
      bind-key J display-popup -E -w 60% -h 20% -T "Scratch Note" "tmx-session-scratchpad prompt"
      bind-key N display-popup -E -w 90% -h 85% -T "Scratchpad" "tmx-session-scratchpad edit"
      bind-key V display-popup -E -w 90% -h 85% -T "Scratchpad View" "tmx-session-scratchpad view"
      bind-key G display-popup -E -w 90% -h 85% -T "AI Scratchpad" "tmx-session-scratchpad ai"
      bind-key i display-popup -E -w 90% -h 85% -T "Session Summary" "tmx-session-summary"
      bind-key I display-message
      bind-key u run-shell "tmx-codex-credit-monitor open"
      bind-key U run-shell "tmx-codex-credit-monitor check-now"

      bind-key A run-shell "tmx-tag act"
      bind-key R run-shell "tmx-tag arc"
      bind-key T run-shell "tmx-tag tmp"

      bind-key M command-prompt -I "#{b:pane_current_path}" -p "managed session" "run-shell \"tmx '%%' '#{pane_current_path}'\""

      run-shell -b "tmx-codex-credit-monitor start"
      run-shell -b "tmx-codex-attention-monitor start"
    '';
  };

}
