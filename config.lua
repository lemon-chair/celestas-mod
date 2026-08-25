--- Default mod config. Steamodded loads this once, then persists any changes
--- the player makes to %APPDATA%/Balatro/config/CelestasMod.jkr.
--- Saved values are merged over these defaults, so new keys added here show up
--- for existing players too.
--- Read it anywhere with: SMODS.current_mod.config
return {
    -- Draw the animated arena texture (rain, snow, ...). Turn this off to keep
    -- only the colour wash, which still shows an arena effect is running.
    arena_animation = true,
    -- Writes arena-effect diagnostics to Mods/lovely/log/.
    verbose_logging = false,
    -- Forces a Downpour on without needing Aquwa in play. Still only visible
    -- during a round, so start a blind to see it.
    debug_downpour = false,
}
