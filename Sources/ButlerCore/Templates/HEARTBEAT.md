---
name: heartbeat
description: The checklist Butler runs on its periodic self-check. Each run reads this, decides, and by default says nothing.
updated: 2026-09-19
aliases: [checkin, self-check, pulse]
---
_Lines starting with an underscore are comments and are stripped before the model sees this file._
_The scheduler enforces the hard limits below; this file only shapes what a run considers._

# Heartbeat

Runs every 30 minutes during active hours, never more than three times in a row without sir speaking, never more than ten times a day. A run that finds nothing worth saying produces no output at all.

## Each run, in order

1. **Commitment.** Read the current commitment and its deadline. Is it still the thing sir said? If there is none, say nothing.
2. **Drift.** Compare the last few observations (frontmost app, window title) with the commitment. Drift means several minutes away with no plausible link. One minute is not drift.
3. **Stall.** Same window, no change, for longer than sir's usual rhythm. Offer the next physical action, once.
4. **Clock.** A time-box that has ended or is about to. Say so in one line.
5. **Done.** Evidence the commitment finished. Acknowledge in one line and ask what is next.

## Silence rules

- A nudge sir dismissed is not repeated for the same commitment.
- Nothing is said while sir is in a meeting or presenting.
- Nothing is said outside active hours.
