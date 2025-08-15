# roblox-secure-score-ui

A drop-in Roblox score system: **secure server-side point grants (1–100)**, **persistent DataStore save/load**, **daily login bonus**, **critical hits**, and a clean **bottom-left UI** with a **level-progress bar**. Smooth count-up on join; level-ups trigger **only at thresholds**.
**Theme:** black / maroon / transparent.

---

## Features

* Server-authoritative random points (+**1–100** per click)
* **Save/Load** with DataStore (retry + backoff)
* **Daily bonus** (+500 once per UTC day)
* **Critical hits** & **streak multiplier** (server-side logic)
* **Aesthetic UI** (bottom-left card, level chip, progress bar)
* **Level up only at thresholds** (`score % 1000 == 0`)
* **Smooth animations**: startup 0→saved score, number tweens
* **Sounds**: click, crit, level-up, daily (configurable SoundIds)
* **Leaderstats** mirroring (works with Roblox default leaderboard)

---

## Structure

```
src/
  ScoreServer.lua            # Script → ServerScriptService
  ScoreClient.client.lua     # LocalScript → StarterPlayer/StarterPlayerScripts
README.md
LICENSE  (MIT)
.gitignore
```

> In Studio the objects are named **ScoreServer** (Script) and **ScoreClient** (LocalScript). On GitHub, we keep `.lua` filenames for versioning.

---

## Setup (Roblox Studio)

1. **Enable DataStore access**
   Home → **Game Settings** → **Security** → turn **Enable Studio Access to API Services** **ON** → Save.

2. **Add the scripts**

   * **ServerScriptService** → *Insert Object → Script* → name **ScoreServer** → paste `src/ScoreServer.lua`.
   * **StarterPlayer → StarterPlayerScripts** → *Insert Object → LocalScript* → name **ScoreClient** → paste `src/ScoreClient.client.lua`.

3. **Set sound IDs (in ScoreClient)**
   At the top of the client script:

   ```lua
   local SOUND_CLICK      = "rbxassetid://6042053626"
   local SOUND_CRITICAL   = "rbxassetid://3165700530"
   local SOUND_LEVELUP    = "rbxassetid://3120909354"
   local SOUND_DAILYBONUS = "rbxassetid://75506392957470"
   ```

   Use your own/public assets if needed.

4. **Test**

   * Play in Studio → click **+ Random Points**.
   * Stop & Play again → saved score loads and **animates from 0**.
   * Cross **1000** points → progress bar fills to 100%, **LEVEL UP!** triggers with SFX.

---

## Configuration

**Server (ScoreServer.lua)**

* `CLICK_COOLDOWN` – per-player request cooldown (default `0.5s`)
* `CRIT_CHANCE` – chance of double reward (default `0.10`)
* `STREAK_WINDOW`, `STREAK_MAX`, `STREAK_STEP` – server streak multiplier tuning
* `DAILY_BONUS` – daily login points (default `500`)
* DataStore names: `PlayerScore_V2`, `DailyBonus_V1`

**Client (ScoreClient.client.lua)**

* UI colors: `MAROON`, `BLACK`, `WHITE`
* Sounds: `SOUND_*` constants
* Placement: bottom-left (away from default PlayerList/leaderboard)

> UI shows **Level Progress** only. Streaks/crits still happen **on the server**, affecting awarded points.

---

## How it works

* **Server-authoritative**: client only requests; server computes rewards (base, streak, crit), saves via `UpdateAsync`, mirrors to leaderstats, and notifies client with `PointsGranted`.
* **Persistence**: server loads on join; saves on leave/server close (with retries).
* **Leveling**: `level = floor(score / 1000)`; progress = `(score % 1000) / 1000`; **LEVEL UP** only when crossing the threshold.

---

## 🔧 Troubleshooting

* **DataStore not saving in Studio?** Ensure **Enable Studio Access to API Services** is **ON**. Publishing and testing in a live server is more reliable.
* **Sounds don’t play?** Use valid `rbxassetid://` IDs that are public/owned; preview in Toolbox/Asset Manager.
* **UI overlap?** Card is anchored **bottom-left**; adjust `container.Position`/size in `buildUI()` if needed.
* **Spam clicking?** Server cooldown + client debounce already included.

---

## Roadmap

* Persist client settings (sound/reduce-motion)
* Global leaderboard (OrderedDataStore)
* Compact mobile layout / dynamic scaling
* Anti-autoclick heuristics

---

## Contributing

PRs welcome. Use Conventional Commits (e.g., `feat: …`, `fix: …`, `docs: …`).

---

## License

MIT — see [LICENSE](LICENSE).
