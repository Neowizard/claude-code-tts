#!/bin/bash
# Cancels TTS: kills whatever is speaking and drops everything queued behind it.
# Used by the interrupt (UserPromptSubmit) hook.

LOG_FILE="${KOKORO_LOG:-/tmp/kokoro-hook.log}"
LOCK_DIR="${KOKORO_LOCK_DIR:-/tmp/kokoro-tts.lock}"
GEN_FILE="${KOKORO_GEN_FILE:-/tmp/kokoro-tts-generation}"

# Bump the generation token first, so queued waiters give up instead of
# grabbing the lock the moment the current utterance is killed.
echo "$$-$(date +%s)" > "$GEN_FILE"

# Kill exactly the kokoro-tts process the player recorded. (The old
# "pkill kokoro-tts" never matched - kokoro-tts runs under python - and a
# command-line pattern also hits unrelated processes that mention the name.)
kokoro_pid=$(cat "$LOCK_DIR/kokoro-pid" 2>/dev/null)
if [ -n "$kokoro_pid" ] && kill -9 "$kokoro_pid" 2>/dev/null; then
  echo "[$(date)] [tts-cancel] Stopped running kokoro-tts (pid $kokoro_pid)" >> "$LOG_FILE"
  killed=0
else
  echo "[$(date)] [tts-cancel] No kokoro-tts process was running" >> "$LOG_FILE"
  killed=1
fi

# Stale locks (player died without releasing) are cleared by waiting players,
# one at a time - not here, where removing by pathname could race a new player.

exit $killed
