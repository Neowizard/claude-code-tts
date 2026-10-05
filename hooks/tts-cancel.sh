#!/bin/bash
# Cancels TTS: kills whatever is speaking and drops everything queued behind it.
# Used by the interrupt (UserPromptSubmit) and SessionEnd hooks.

LOG_FILE="${KOKORO_LOG:-/tmp/kokoro-hook.log}"
LOCK_DIR="${KOKORO_LOCK_DIR:-/tmp/kokoro-tts.lock}"
GEN_FILE="${KOKORO_GEN_FILE:-/tmp/kokoro-tts-generation}"
KOKORO_PROC_NAME="${KOKORO_PROC_NAME:-kokoro-tts}"

# Match the full command line, not the process name. kokoro-tts runs as
# ".../kokoro-tts/bin/python .../bin/kokoro-tts", so its process name is
# "python" and a name-only pkill never matched it: every cancel logged "No
# kokoro-tts process was running" while a hung run kept holding the playback
# lock forever (observed 2026-08-23). The "bin/" prefix keeps the pattern from
# matching log tails or lock listings that merely mention kokoro-tts.
KOKORO_PROC_PATTERN="${KOKORO_PROC_PATTERN:-bin/$KOKORO_PROC_NAME}"

# Bump the generation token first, so queued waiters give up instead of
# grabbing the lock the moment the current utterance is killed.
echo "$$-$(date +%s)" > "$GEN_FILE"

if pkill -9 -f "$KOKORO_PROC_PATTERN" 2>/dev/null; then
  echo "[$(date)] [tts-cancel] Stopped running $KOKORO_PROC_NAME" >> "$LOG_FILE"
  killed=0
else
  echo "[$(date)] [tts-cancel] No $KOKORO_PROC_NAME process was running" >> "$LOG_FILE"
  killed=1
fi

# The player releases the lock via its EXIT trap; clear it if that process is
# already gone.
holder=$(cat "$LOCK_DIR/pid" 2>/dev/null)
if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
  rm -rf "$LOCK_DIR"
fi

exit $killed
