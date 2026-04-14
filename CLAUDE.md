# Goby Roguelike — Project Context for Claude Code

## What this is
A single-player top-down roguelike game built in Godot 4.
The player controls a goby fish navigating the ocean floor.
Fights other fish, collects upgrades, avoids traps, completes levels.
At the end of each level the player chooses from 3 upgrades, 
then moves to a new procedurally generated map.

## Engine & Language
- Godot 4.x
- GDScript (not C#)
- 2D top-down view

## Project structure
- res://scenes/ — all Godot scenes (.tscn files)
- res://scripts/ — all GDScript files (.gd)
- res://assets/ — sprites, tilesets, sounds

## Key scenes
- res://scenes/Game.tscn — main game scene
- res://scenes/Player.tscn — the goby fish player
- res://scenes/HUD.tscn — UI overlay

## Coding rules
- Do not use deprecated Godot 3 APIs
- Keep scenes and scripts in their respective folders
- Each feature should be self-contained where possible
- Use GDScript only, no C#