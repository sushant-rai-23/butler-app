---
name: user
description: Stable facts about the person Butler serves. Loaded into every model call. Written by the user during onboarding, refined over time.
updated: 2026-09-19
aliases: [profile, me, sir]
---
_Lines starting with an underscore are comments and are stripped before the model sees this file. Replace the placeholders; delete what does not apply._

# User

## Identity
Name: _your name_
Address as: sir
Timezone: _e.g. Asia/Kolkata_

## Work
_What you do, in two lines. Butler uses this to tell work from drift._

## Working hours
Active: _e.g. 09:00 to 23:00_. Butler stays silent outside these hours.

## Apps and sites that are always work
_e.g. Xcode, Terminal, Figma_

## Apps and sites that are usually drift
_e.g. YouTube, Twitter. Butler asks before assuming; a video can be research._

## What helps when stuck
_e.g. "Ask me to name the next physical action." Butler will try this first._

## What does not help
_e.g. "Cheerleading." Butler will avoid it._
