return {
  {
    id = "forest",
    name = "Edge of the Forest",
    description = "Pines crowd close, their needles muffling every sound. A worn path leads north toward a dark cave mouth.",
    exits = { north = "cave_entrance" },
    items = { "lantern" },
  },
  {
    id = "cave_entrance",
    name = "Cave Entrance",
    description = "Cold air drifts from the mouth of the cave. A boulder slumps against the south wall. The passage continues into darkness to the north.",
    exits = { south = "forest", north = "cave_interior" },
    items = { "boulder" },
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
