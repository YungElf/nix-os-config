# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Applying Configuration

```bash
# Rebuild, commit, and push in one step (preferred)
nixsave "optional commit message"

# Or manually
sudo nixos-rebuild switch       # apply and persist
sudo nixos-rebuild test         # apply temporarily (rolls back on reboot)
sudo nixos-rebuild dry-run      # preview changes without applying
```

`nixsave` is a custom shell script defined in `configuration.nix` via `writeShellScriptBin`. It runs `nixos-rebuild switch`, then commits and pushes to GitHub.

## Architecture

This is a single-file NixOS configuration. Everything lives in `configuration.nix` (~230 lines); there are no modules or sub-files beyond the auto-generated `hardware-configuration.nix`.

**Package organization pattern:** Packages are grouped into named `let` bindings (`devStuff`, `java`, `gamingStuff`, `basicStuff`, `terminalStuff`, `customScripts`) and concatenated under `environment.systemPackages`. Add new packages to the appropriate group or create a new one.

**Asset files** (tmux, kitty, Firefox profile) live in `assets/` and are referenced by absolute path (`/etc/nixos/assets/...`). The Firefox profile directory is gitignored.

**Custom scripts** are defined inline using `writeShellScriptBin` inside the `customScripts` let binding — no separate script files needed for simple tools.

## Key System Details

- **User:** `elf`, auto-login via SDDM, KDE Plasma 6 on X11
- **Storage:** Home dir is bind-mounted from `/mnt/sparkle/home`; second data drive at `/mnt/Ultra`
- **Unfree packages** are allowed (`nixpkgs.config.allowUnfree = true`)
- **Flakes and nix-command** are enabled as experimental features
- **NixOS version** pinned to `24.11` in `stateVersion` (running 25.05 in practice — do not change `stateVersion`)
- **Smart card (CAC) support** is configured: pcscd, OpenSC, ccid, pinentry-qt
- **Hardware graphics** (32-bit) and Pipewire audio are enabled for gaming

You're helping me optimize my NixOS configuration. Important constraints and context first.

## Hard constraints — DO NOT VIOLATE
- DO NOT remove any installed applications, packages, or programs. Preserve every package currently in my config.
- DO NOT remove anything that is referenced anywhere in my current configuration.nix. Before deleting any file or directory, grep my config for references to that path. If anything references it, leave it alone and flag it.
- DO NOT replace KDE Plasma with another desktop environment. Keep Plasma as the base.
- DO NOT alter my user account, hostname, networking identity, or anything that would require re-authentication or break my system identity.
- DO NOT migrate me to flakes. I'm intentionally staying on channels — it's closer to the original Nix philosophy and I prefer the simpler mental model. Don't suggest flakes, don't add flake.nix, don't reference them as a future improvement.
- DO NOT split my config into multiple files. Single configuration.nix, organized by sections with comment dividers. Improve the structure, don't fragment it.
- DO NOT add experimental or bleeding-edge options without flagging them clearly.

## My environment (for context)
- NixOS with KDE Plasma — I'm not sure if I'm on Plasma 5 or 6. Check first (`plasmashell --version` or look at my config) and tell me before making KDE-related changes. If I'm on 5, propose the upgrade path to 6 as a separate step.
- Hardware: Ryzen 7 5800X, Radeon RX 5700 XT
- Filesystem layout: root drive is small and should stay LEAN. `/home` is on `/mnt/Sparkle` (separate drive). Anything user-data-shaped belongs there, not on root.
- Terminal font preference: JetBrains Mono Nerd Font
- I do full-stack Java/Spring Boot work, some Go, some Lua, and JVM internals tinkering (Project Panama)
- I use JetBrains IDEs
- Previously ran Arch/i3/ArchCraft — I miss the keyboard-driven workflow and want KDE tuned in that direction
- Channels-based setup (not flakes) — keep it that way
- Config is already organized into sections within a single configuration.nix — preserve that pattern

## STEP 1 — STORAGE AUDIT AND CLEANUP (do this FIRST, before anything else)

My root drive is dirty. I previously had `/home` on the root drive, then moved it to `/mnt/Sparkle`, so there are almost certainly stale leftovers. Also, my Firefox profile is currently being stored somewhere under `/etc` (or referenced from there), which is wrong — `/etc` is for system config, not user profile data. Profile data needs to live on `/mnt/Sparkle`.

Do the following, in order:

1. **Disk inventory**: Run `df -h`, `du -h --max-depth=1 /` (sorted), and `du -h --max-depth=2 /var` and `du -h --max-depth=2 /etc` to find where space is going on root. Report the top 20 biggest offenders on the root drive. Also report `/nix/store` size separately since GC will handle that.

2. **Find the Firefox profile situation**: Locate where Firefox is actually storing profile data right now. Check `/etc`, `/var`, `/root`, and look for `~/.mozilla` symlink trickery. Determine:
   - The current physical location of the profile
   - Whether the config references it explicitly
   - Whether it's a symlink, bind mount, or actual directory
   - How big it is
   
   Then propose a clean move to `/mnt/Sparkle/<somewhere sensible under my home>`. Use the standard `~/.mozilla/firefox/` location if possible. If my config has a `programs.firefox` or `home.file` declaration pinning it elsewhere, fix that declaration too.

3. **Stale leftover hunt on root**: Look for orphaned directories that shouldn't be on root anymore now that /home is on /mnt/Sparkle. Common suspects:
   - Old `/home` contents that weren't moved (a `/home.old`, `/home_backup`, or just leftover files under what was `/home` before the mount)
   - User caches in `/root` if I ever used sudo with caches
   - Old Steam libraries, game data, downloads under `/var` or `/opt`
   - Crash dumps in `/var/crash` and `/var/lib/systemd/coredump`
   - Old journals (`journalctl --disk-usage`)
   - Pre-move `.mozilla`, `.config`, `.cache` directories anywhere on root
   
   For EACH candidate for deletion:
   - Grep my entire configuration.nix for any reference to the path
   - If referenced, DO NOT delete — flag and explain
   - If not referenced, show me the path and size and ASK before deleting
   - Never `rm -rf` without explicit approval per directory

4. **Nix store cleanup**: After identifying the above, but BEFORE deleting user data:
   - Show me current store size
   - Show me number of generations: `sudo nix-env --list-generations --profile /nix/var/nix/profiles/system`
   - Recommend a cleanup command (e.g., `sudo nix-collect-garbage --delete-older-than 14d`) and run it after I approve
   - Run `sudo nix-store --optimise` after GC to dedupe

5. **Configure ongoing store hygiene in configuration.nix**:
   - `nix.gc.automatic` with weekly schedule and `--delete-older-than 14d` (or whatever I approve)
   - `nix.settings.auto-optimise-store = true`
   - `boot.loader.systemd-boot.configurationLimit = 10` (or grub equivalent)
   - `services.journald.extraConfig` to cap journal size (`SystemMaxUse=500M` or similar)

After Step 1 is done, report total space recovered and current root drive usage. Then wait for my go-ahead on Step 2.

## STEPS 2+ — CONFIG OPTIMIZATION (after storage is clean)

Walk through my config section by section and make it as efficient, clean, and well-organized as possible.

1. **Section organization**: My config is already split into sections (gaming, development, etc.) within one file. Keep that. If you find packages or settings in the wrong section, move them. Add a consistent section header style if missing.

2. **Deduplication**: Find duplicate package declarations, redundant service enables, or settings that are already defaults.

3. **Idiomatic Nix**: Replace verbose patterns with idiomatic ones (`lib.mkDefault`, `lib.mkForce`, `with pkgs;` where it helps).

4. **Performance**: Look for things that hurt boot or rebuild time — unused services, redundant systemd units, stale kernel params. Flag, don't auto-remove.

5. **AMD GPU / drivers**: RX 5700 XT cleanup:
   - `hardware.graphics` (or `hardware.opengl` on older NixOS) with Mesa drivers and 32-bit support for Steam/Wine
   - Vulkan (amdvlk and/or RADV — recommend which fits my use)
   - ROCm if useful
   - `hardware.enableRedistributableFirmware`
   - `hardware.cpu.amd.updateMicrocode = true`
   - AMD-relevant kernel params if helpful

6. **KDE keyboard-centric tuning** (Plasma stays, lean toward i3-style):
   - Confirm Plasma version first.
   - Propose tiling: built-in Plasma 6 tiling or `krohnkite`.
   - Global shortcuts: directional window focus (Meta+H/J/K/L), virtual desktop switching, window-to-desktop moves.
   - Tune Krunner — it's basically dmenu/rofi when configured.
   - Reduce visual cruft: minimize animations, identify unused services (kdeconnect, baloo, akonadi). FLAG before disabling.
   - I don't want Home Manager / Plasma Manager — that'd mean a second config file. KDE config stays in configuration.nix where it can, GUI for the rest.

7. **Other additions to propose (ask before adding)**:
   - `programs.nix-ld` for non-Nix binaries (JetBrains, some Java tooling)
   - Proper Java/JDK setup with multiple versions
   - JetBrains Mono Nerd Font in font config
   - Desktop-appropriate power management
   - Channel cleanup if messy
   - `zramSwap` — cheap win on a 5800X
   - Kernel choice review (LTS / latest stable / Zen)

8. **Comments**: Consistent section headers throughout. Comment non-obvious choices, skip the obvious ones.

## How to work with me — INCREMENTAL REBUILD WORKFLOW

This is critical: I want to catch failures one change at a time, not after a massive refactor.

- First, show me the Step 1 storage audit results and proposed plan. I'll approve before any deletions.
- Then proceed ONE LOGICAL CHANGE AT A TIME.
- After each change that touches configuration.nix:
  1. Run `sudo nixos-rebuild test` yourself — actually execute it.
  2. If it fails, STOP. Show me the error. Do not stack more changes on a broken state.
  3. If it succeeds, confirm what works, then ask whether to proceed or run `sudo nixos-rebuild switch` to make it permanent.
- For changes requiring reboot or session restart (kernel params, KDE-level, drivers), say so and ask first.
- Never batch unrelated changes into a single rebuild.
- For storage deletions: never `rm -rf` without explicit approval per target. Always grep configuration.nix for references first.
- If unsure whether something is intentional, ASK.
- No TODOs in final output.

Start by running the Step 1 storage audit. Report findings before touching anything.
