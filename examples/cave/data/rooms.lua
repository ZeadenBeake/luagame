return {
  {
    id = "forest",
    name = "Edge of the Forest",
    description = "Pines crowd close, their needles muffling every sound. A worn path leads north toward a dark cave mouth. A rocky ledge juts out to the east -- too high to climb without wings.",
    exits = {
      north = "cave_entrance",
      east = {
        to = "rocky_ledge",
        requires = { flight = true },
        blockedMessage = "The ledge is twenty feet up. You'd need wings to reach it.",
      },
    },
    items = { "lantern" },
  },
  {
    id = "rocky_ledge",
    name = "Rocky Ledge",
    description = "The forest spreads out below you. A small hollow in the rock face holds something glinting.",
    exits = { west = "forest" },
    items = { "silver_coin" },
  },
  {
    id = "cave_entrance",
    name = "Cave Entrance",
    description = "Cold air drifts from the mouth of the cave. A boulder slumps against the south wall. The passage continues into darkness to the north.",
    exits = { south = "forest", north = "cave_interior" },
    items = { "boulder", "feather_amulet" },
    creatures = { "old_hermit" },
  },
  {
    id = "cave_interior",
    name = "Inside the Cave",
    description = "Your footsteps echo. Glistening minerals catch what little light there is. The way back is south.",
    exits = { south = "cave_entrance" },
    items = { "rusty_key" },
  },
}
