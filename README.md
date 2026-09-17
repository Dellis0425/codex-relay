# Codex Relay

Codex Relay is a small AutoHotkey v2 utility for scheduling a prompt to be delivered to the ChatGPT desktop app for Codex workflows at a later time.

It was built for a simple problem: Codex usage can reset hours or days after work stops, and you may already know exactly what you want to send next. Codex Relay lets you prepare that prompt in advance, choose when it should run, and let the computer handle the waiting.

Codex Relay is intentionally **not** an autonomous coding agent. It does not decide what Codex should do, inspect your project, or guess whether unfinished work should continue. You choose the prompt, the time, and whether Enter should be pressed.

## Features

- Schedule one Codex prompt at a time
- Built-in **Continue where you left off** prompt
- Custom multiline prompts
- Choose the day and reset time
- Add a configurable safety buffer after a usage reset
- Optional **Press Enter and actually send the prompt** setting
- Automatically focuses the ChatGPT desktop app before interacting with Codex
- Saves scheduled prompts as local Markdown files
- Uses unique prompt filenames containing both creation time and scheduled time
- Saves active schedule state locally
- Restores a future schedule after Codex Relay is restarted
- Detects a schedule that was missed while Codex Relay was not running
- Never automatically sends a missed prompt late
- Keeps local prompt files and schedule state out of Git through `.gitignore`

## Why it exists

A common Codex workflow looks something like this:

1. Codex is working on a task.
2. Usage runs out and the next reset is several hours away.
3. You already know the next prompt you want to send, but you may be asleep or away from the computer when usage resets.
4. You schedule the prompt in Codex Relay and leave the ChatGPT desktop app open on the correct Codex conversation.
5. At the scheduled time, Codex Relay brings ChatGPT to the front, places the prompt in the Codex input box, and optionally presses Enter.

The same idea can also be useful for weekly usage resets or for a planned custom prompt several days in the future.

## What Codex Relay does not do

Codex Relay deliberately keeps automation limited.

It does **not**:

- Decide whether Codex finished a task
- Detect usage limits automatically
- Use computer vision or OCR to inspect Codex
- Decide what prompt should be sent
- Navigate to a project or conversation for you
- Open the correct Codex workspace automatically
- Queue a chain of prompts
- Automatically retry a missed schedule

The goal is assisted automation: **you make the decisions; Codex Relay handles the waiting and delivery.**

## Requirements

- Windows
- [AutoHotkey v2](https://www.autohotkey.com/)
- ChatGPT desktop app
- A Codex conversation/project already open and ready to receive the scheduled prompt

## Installation

1. Download or clone this repository.
2. Install AutoHotkey v2 if it is not already installed.
3. Run `CodexRelay.ahk`.
4. Press `Ctrl + Alt + K` to open the scheduler.

The `Scheduled Prompts` folder is created automatically when needed.

## Basic usage

Press:

```text
Ctrl + Alt + K
```

to open Codex Relay.

### Continue an interrupted task

1. Leave **Continue where you left off** selected.
2. Choose the day and the time Codex says your usage resets.
3. Choose a safety buffer. The default workflow uses 10 minutes.
4. Check **Press Enter and actually send the prompt** if you want the prompt submitted automatically.
5. Click **Arm Timer**.

### Schedule a custom prompt

1. Choose **Custom Prompt** from the prompt dropdown.
2. Type or paste your prompt into the multiline prompt box.
3. Choose the day, reset time, and safety buffer.
4. Decide whether Codex Relay should only paste the prompt or also press Enter.
5. Click **Arm Timer**.

Only one schedule is active at a time.

## Scheduled prompt files

When a prompt is armed, Codex Relay saves it as a Markdown file in:

```text
Scheduled Prompts\
```

Prompt filenames include the time the prompt was created and the time it is scheduled to run, for example:

```text
created_2026-09-15_23-06-49__scheduled_2026-09-16_04-16-00.md
```

This gives each scheduled prompt a unique file and provides a simple local history of what was prepared.

These Markdown files are ignored by Git by default so personal or project-specific prompts are not accidentally committed to the repository.

## Persistence

Codex Relay stores the active schedule in a local `schedule.ini` file.

If Codex Relay is closed and reopened **before** the scheduled time, the future schedule is restored automatically.

If Codex Relay is reopened **after** the scheduled time has already passed, it marks the schedule as missed and does **not** send the prompt late.

This is an intentional safety behavior.

The local `schedule.ini` file is ignored by Git.

## Starting with Windows

Persistence only works after the script is running again.

If you want Codex Relay to restore schedules automatically after signing in to Windows, you can place a shortcut to `CodexRelay.ahk` in the Windows Startup folder.

Open the Startup folder with:

```text
Win + R
shell:startup
```

Then place a shortcut to `CodexRelay.ahk` there.

This startup behavior should be tested on your own system before relying on it for an important schedule.

## Canceling a schedule

Open Codex Relay with `Ctrl + Alt + K` and click **Cancel**.

Canceling clears the armed state so the schedule will not be restored the next time Codex Relay starts.

## Safety behavior

Codex Relay includes several intentionally conservative behaviors:

- ChatGPT must already be running.
- ChatGPT must successfully become the active window before the prompt is inserted.
- Focus is checked again before Enter is pressed.
- A missed schedule is not sent late.
- Only one prompt can be scheduled at a time.
- Prompt text is saved locally before the timer is armed.

## Current limitations

Codex Relay currently interacts with the ChatGPT desktop app using a tested window-relative click position for the Codex prompt box.

Because of that, a major ChatGPT UI change, unusual display scaling, or a significantly different layout could require adjustment to the click position in `CodexRelay.ahk`.

The script also assumes the correct Codex conversation/project is already open. It does not navigate between projects or conversations.

## Project status

Codex Relay is currently being prepared for its first public release.

The core scheduling workflow has been tested for:

- Scheduled prompt delivery
- Custom prompt files
- Schedule restoration after restarting the script
- Canceling an armed schedule
- Safe handling of a missed schedule

Windows startup behavior is the remaining system-level test before the first public release.

## Disclaimer

Codex Relay is an independent utility and is not affiliated with or endorsed by OpenAI.

Use scheduled prompts carefully, especially when working on important codebases. Review and test the workflow on your own system before relying on unattended execution.
