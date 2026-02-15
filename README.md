# Skada Damage Meter

Skada is a modular damage meter for World of Warcraft with various viewing modes, segmented fights, and customizable windows. It is designed for efficiency with minimal memory and CPU impact.

"Skada" is Swedish for "Damage".

---

## Midnight Edition (WoW 12.0+)

This version of Skada is updated for **World of Warcraft: Midnight** and uses Blizzard's new session-based combat systems.

### Features

- **Midnight Optimized**: Uses Blizzard's internal session data for performance and accuracy.
- **Combat Reliability**: Handles modern combat data restrictions for a stable experience.
- **Updated UI**: Includes new presets with smooth animations, gradients, and textures.
- **Dynamic Elements**: Alternating row colors, highlight overlays, spark effects, and icon scaling.
- **LDB Integration**: Compatible with Data Broker displays such as Titan Panel, ChocolateBar, and ElvUI.
- **Extensible Architecture**: The API allows developers to create additional plugins.

## Usage

### Getting Started
A default window is created upon first load. Access the configuration menu by clicking the **cog icon** on the window title bar or via the minimap button. Select **Configure** to access settings.

### Multiple Windows
Skada supports multiple windows. Create new ones under the **Windows** section of the configuration panel. Windows can be:
- **Bar**: The standard customizable meter.
- **Inline**: A horizontal line for custom UI setups.
- **Data Text**: For LDB displays and minimal setups.

### Navigation
- **Left-Click**: View more detailed information.
- **Right-Click**: Return to the previous view.
- **Mousewheel**: Scroll through lists.
- **Tooltips**: Hover over bars to see additional context and shortcut keys (e.g., Shift-click for targets).

### Themes
Manage window designs with the built-in **Theme Engine**. You can import and export themes by using theme strings.

## Versions

- **Midnight (Default)**: For WoW 12.0+ using the Native API.
- **[Classic Version](https://github.com/zarnivoop/skada/tree/main)**: The version for older WoW releases.

## Support

If you find Skada helpful, consider supporting its development through [GitHub Sponsors](https://github.com/sponsors/zarnivoop).

## Links

- [GitHub Repository](https://github.com/zarnivoop/skada/tree/midnight)
- [API Documentation](https://github.com/zarnivoop/skada/blob/midnight/API.md)
- [CurseForge](https://www.curseforge.com/wow/addons/skada)
- [Wago.io](https://addons.wago.io/addons/skada)
