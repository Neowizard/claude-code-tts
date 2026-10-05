#!/bin/bash
# Claude Code SessionEnd Hook - Cleanup TTS processes and temporary files
# This hook is triggered when a Claude Code session ends

# Read hook input
input=$(cat)

# Extract session information
session_id=$(echo "$input" | jq -r '.session_id')
reason=$(echo "$input" | jq -r '.reason')

# Log session end
echo "[$(date)] SessionEnd hook triggered for session $session_id (reason: $reason)" >> /tmp/kokoro-hook.log

# Deliberately does NOT cancel TTS. This hook fires on leaving a session, not
# only on closing one, and tts-cancel.sh is global, so every switch between
# sessions killed whatever was being spoken anywhere. Cleanup
# below is limited to this session's own files; audio is left alone.
#
# UserPromptSubmit still cancels, so a hung kokoro-tts is still cleared by the
# next prompt.

# Clean up THIS session's TTS temporary files. The blanket glob that used to be
# here deleted every session's pending utterance, so an utterance queued behind
# the playback lock lost its text the moment any unrelated session exited.
rm -f /tmp/kokoro-input.txt /tmp/kokoro-pretool-input.txt 2>/dev/null
session_key=$(echo "$session_id" | tr -cd 'A-Za-z0-9-')
if [ -n "$session_key" ]; then
  rm -f "/tmp/kokoro-input.$session_key."* 2>/dev/null
fi

# Orphans from sessions that died without cleaning up. An hour is far longer
# than any utterance, so this can never race a queued one.
find /tmp -maxdepth 1 \( -name 'kokoro-input.*' -o -name 'kokoro-pretool-input.*' \) -mmin +60 -delete 2>/dev/null

# Clean up hash tracking files for fresh start in next session
rm -f /tmp/kokoro-pretool-last-hash.txt /tmp/kokoro-pretool-last-time.txt 2>/dev/null

echo "[$(date)] Session cleanup completed for session $session_id" >> /tmp/kokoro-hook.log

# Exit successfully
exit 0
