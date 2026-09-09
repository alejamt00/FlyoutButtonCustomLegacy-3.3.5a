# FlyoutButtonCustomLegacy

<p align="center">
	<img src="media/FlyoutButtonCustomLegacy.png" alt="FlyoutButtonCustomLegacy icon" width="256">
</p>

An adaptation of the original Cataclysm-era **FlyoutButtonCustom** addon for
World of Warcraft 3.3.5a.

> This addon is not intended for World of Warcraft Classic. It targets the
> legacy 3.3.5a client available on private servers.

## About this project

This project starts from the original Cataclysm version and adapts it to the
legacy 3.3.5a client, with several additions of my own.

- Original addon: [FlyoutButton Custom on CurseForge](https://www.curseforge.com/wow/addons/flyoutbutton-custom)
- Original author: **vladimiseven**
- Target client: World of Warcraft 3.3.5a

## Features

- Create custom flyout lists for spells, items, mounts...
- Attach a flyout to an action-bar macro containing `/fbc <number of slots>`.
- Open lists by click or mouseover.
- Keep one flyout list open at a time.
- Configure the addon using the movable minimap button or / commands.
- Supports the default Blizzard action bars (other action-bar addons have not been tested).

## Installation

Copy the `FlyoutButtonCustomLegacy` folder into:

```text
.\World of Warcraft\Interface\AddOns\
```

## Usage

Create a uniquely named macro containing, for example:

```text
/fbc 4
```

Drag that macro onto an action bar. Drag spells or items into the flyout slots,
and drag entries from the flyout onto an action bar.

Due to API limitations in the WoW 3.3.5a client, flyout contents can only be
modified while the spellbook is open.

Click the circular minimap button to open or close the settings window.

## Settings

The settings window includes:

- **Border**: show borders around flyout buttons.
- **Hide**: close the flyout after selecting an item.
- **Mouseover**: open flyouts when the cursor enters the button.
- **Mouseover in combat**: allow mouseover opening while in combat.

Use **Save** to apply changes without closing the window, or **Save and exit**
to apply changes and close it.

## Slash commands

- `/fbc` or `/fbcustom`: open the settings window.
- `/fbc border`: toggle flyout button borders.
- `/fbc hide`: toggle closing the list after selection.
- `/fbc mouseover`: toggle opening lists on mouseover.
- `/fbc mouseoverincombat`: toggle mouseover while in combat.

## Compatibility

Tested with the default Blizzard action bar. Other action-bar addons have not been tested.

## Credits

The original concept and addon were created by **vladimiseven**. This repository
contains the legacy client adaptation and its additional interface changes.
