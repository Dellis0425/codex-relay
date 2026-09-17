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
3. Choose a safety buffer.
4. Check **Press Enter and actually send the prompt** if you want the prompt submitted automatically.
5. Click **Arm Timer**.

### What the safety buffer does

The safety buffer delays delivery for a few extra minutes after the reset time you enter. It exists so Codex Relay does not try to send the prompt at the exact instant a usage reset is expected to occur.

For example:

```text
Usage reset time: 6:00 PM
Safety buffer:    10 minutes
Prompt fires at:  6:10 PM
```

The current default is **10 minutes**. You can choose a different buffer or set it to `0` if you want the prompt to fire at the exact scheduled time.

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

## Display and click-position compatibility

Codex Relay does **not** target a specific numbered monitor and it is not hard-coded for a four-monitor desktop.

Before inserting a prompt, the script activates the ChatGPT desktop window and then uses **client-area coordinates relative to that ChatGPT window**. The current code uses:

```ahk
clickX := 390
clickY := clientH - 80
```

Because these coordinates are relative to the active ChatGPT window, the absolute position of that window on the Windows desktop usually does not matter. A single-monitor setup, multi-monitor setup, or moving ChatGPT from one monitor to another does not by itself require changing the code.

However, the location of the Codex prompt box **inside the ChatGPT window** can vary with window size, display scaling, portrait orientation, resolution, sidebar width, or future ChatGPT UI changes. A 4K monitor or portrait monitor is not automatically incompatible, but it is worth verifying the prompt click position on your own setup before relying on unattended sending.

### Verify or adjust the click position with Window Spy

AutoHotkey includes **Window Spy**, which can show the mouse position relative to the active application's client area.

1. Open the ChatGPT desktop app and navigate to the Codex conversation you intend to use.
2. Put the ChatGPT window in the size and layout you normally use.
3. Open **Window Spy** from AutoHotkey.
4. Move the mouse over the Codex prompt input box.
5. In Window Spy, look at the **Client** mouse coordinates.
6. Compare those values with the click-position section in `CodexRelay.ahk`.

The current horizontal coordinate is:

```ahk
clickX := 390
```

The vertical coordinate is intentionally measured from the bottom of the ChatGPT client area:

```ahk
clickY := clientH - 80
```

That means Codex Relay clicks 390 client pixels from the left side of the ChatGPT window and 80 client pixels above the bottom.

If your prompt box is elsewhere, adjust these values and run a test with **Press Enter and actually send the prompt** unchecked. Confirm that Codex Relay focuses ChatGPT and pastes into the correct prompt box before enabling unattended sending.

For a different horizontal location, change `390` to the Client X coordinate that lands safely inside your prompt box. For vertical adjustment, change `80` to the distance from the bottom of the ChatGPT client area that lands inside your prompt box.

## Safety behavior

Codex Relay includes several intentionally conservative behaviors:

- ChatGPT must already be running.
- ChatGPT must successfully become the active window before the prompt is inserted.
- Focus is checked again before Enter is pressed.
- A missed schedule is not sent late.
- Only one prompt can be scheduled at a time.
- Prompt text is saved locally before the timer is armed.
- You can test positioning with Enter disabled before allowing automatic submission.

## Current limitations

Codex Relay currently interacts with the ChatGPT desktop app using a tested window-relative click position for the Codex prompt box.

A major ChatGPT UI change, significantly different window layout, unusual display scaling, portrait-oriented display, or other layout difference may require adjusting the click position in `CodexRelay.ahk` using Window Spy as described above.

The script also assumes the correct Codex conversation/project is already open. It does not navigate between projects or conversations.

## Project status

Codex Relay is currently being prepared for its first public release.

The core scheduling workflow has been tested for:

- Scheduled prompt delivery
- Custom prompt files
- Schedule restoration after restarting the script
- Canceling an armed schedule
- Safe handling of a missed schedule

Windows startup behavior is the remaining system-level test before the first public release. Once that test is complete, this section will be updated for the release build.

## Disclaimer

Codex Relay is an independent utility and is not affiliated with or endorsed by OpenAI.

Use scheduled prompts carefully, especially when working on important codebases. Review and test the workflow on your own system before relying on unattended execution.
