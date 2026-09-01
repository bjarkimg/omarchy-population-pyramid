# Demographics & Population Decline (Omarchy Shell Plugin)

An interactive demographic analysis, population decline tracker, and vertical age-sex pyramid for Omarchy Linux.

![Population & Decline Tracker](preview.png)

## Features

- **3 Flag Quick-Picker Rows with Scrollbar:**
  - **🔴 Ultra-Low TFR / Rapid Decline (< 1.3):** 🇰🇷 S.Korea, 🇹🇼 Taiwan, 🇭🇰 HK, 🇸🇬 Singapore, 🇯🇵 Japan, 🇮🇹 Italy, 🇪🇸 Spain, 🇺🇦 Ukraine, 🇵🇱 Poland, 🇬🇷 Greece, 🇵🇹 Portugal, 🇨🇳 China, 🇹🇭 Thailand
  - **🟡 Aging & Sub-Replacement (1.3–2.0):** 🇩🇪 Germany, 🇬🇧 UK, 🇫🇷 France, 🇺🇸 USA, 🇨🇦 Canada, 🇦🇺 Australia, 🇮🇸 Iceland, 🇳🇴 Norway, 🇸🇪 Sweden, 🇫🇮 Finland, 🇩🇰 Denmark, 🇷🇺 Russia, 🇧🇷 Brazil, 🇲🇽 Mexico, 🇨🇱 Chile
  - **🟢 Growth & Global (≥ 2.0):** 🌍 World, 🇮🇳 India, 🇮🇩 Indonesia, 🇻🇳 Vietnam, 🇵🇭 Philippines, 🇹🇷 Turkey, 🇿🇦 S.Africa, 🇪🇬 Egypt, 🇵🇰 Pakistan, 🇳🇬 Nigeria, 🇪🇹 Ethiopia, 🇰🇪 Kenya, 🇦🇷 Argentina, 🇨🇴 Colombia
- **Vertical Age-Sex Population Pyramid:** 21 age brackets (0–4 to 100+) with male (cyan) and female (rose) bilateral cohorts and hover tooltips.
- **Continuous Trajectory Line Chart:**
  - **Sub-Replacement (TFR < 2.1):** Historical curve (1950–2026) followed by post-peak decline to **Zero / Extinction Horizon**.
  - **Above-Replacement (TFR ≥ 2.1):** Forward 100-year expansion trajectory to 2126.
  - Milestone markers for Peak Year, 2026 Current Year, Halving Year ($T_{1/2}$), and Zero Year ($\sim 0$).
- **Interactive Scrubber:** Scrub across the line chart or flag picker to update demographic charts in real time.

## Controls & Shortcuts

- **Click Bar Icon (`󰄹`):** Toggle dashboard.
- **`Space`:** Play / Pause timeline animation.
- **`Left` / `Right` Arrow:** Step backward / forward through milestone years.
- **`Esc`:** Dismiss dashboard.
- **Right-Click Bar Icon:** Send desktop notification with quick demographic summary.

## CLI & Shell IPC

```bash
# Toggle dashboard
omarchy-shell shell toggle bmg.population-pyramid
```
