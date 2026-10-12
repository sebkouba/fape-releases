# fape for Omarchy

Dictate into your applications. Tap **Ctrl+Super+X** to start and stop, or hold
the same shortcut to talk. Existing installations keep their shortcut.

## Install

Requires Omarchy 4 on x86_64 Linux. Paste this into a terminal:

```sh
curl -fsSL https://tokenschmiede.com/fape-trial/install.sh | bash
```

The installer opens setup automatically. Choose **Start free trial**, try
dictation, then finish setup. No email, account or API key is required.
The trial lasts seven days from activation, with up to five hours of audio.
Reinstalling does not restart the trial. Trial recordings are limited to four minutes.

Prefer a file? [Download the self-extracting installer](https://tokenschmiede.com/fape-trial/installer)
and run `bash ~/Downloads/fape-*.run` (use the specific filename if you have several).
Alternatively, [download the ZIP](https://tokenschmiede.com/fape-trial/download),
extract it, and run `bash install.sh` inside the extracted folder. In Omarchy's
file manager you can also open **Install Fape.desktop** and choose **Launch Anyway**.

[Read the installation script](install.sh) before running it if you prefer.
Downloads are verified against SHA-256 checksums before installation.
Reinstalling an update preserves your keys, settings and history.

## Your own keys

Choose **Use my own keys** during setup, or add them later in Settings.
Your own Soniox key takes precedence over the trial. Cerebras is optional:
basic dictation works without it. The funded trial is dictation only, even if a
Cerebras key is configured. Correction and voice actions require both your own
Soniox and Cerebras keys.
Provider usage with your own keys is billed by those providers.

**This beta expires on 2026-11-11T07:40:04Z**, including when you use your own keys.
The deadline is 30 days from building, not installation. Install a newer beta
before that date. This is a beta cutoff, not tamper-resistant licensing.

Current release: **0.2.356**, application source revision `7949b75591de`.
See [Releases](https://github.com/sebkouba/fape-releases/releases) for installers,
checksums and earlier versions. This repository distributes the app; its source
code is private.

## Add voice actions with your coding agent

Give your agent [the fape-tools skill](skills/fape-tools/SKILL.md), or copy that
folder into the agent's skills directory. It explains how to add local action
extensions without the app source. Voice actions require your own Soniox and Cerebras keys
and an action shortcut configured in Settings.

## Feedback

Use **Feedback** in the app, or [contact TokenSchmiede](https://tokenschmiede.com/kontakt/).
[Website and demo](https://tokenschmiede.com/fape/) ·
[Privacy policy](https://tokenschmiede.com/datenschutz/#fape).
