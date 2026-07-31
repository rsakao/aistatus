import AppKit

/// Produces a non-template SF Symbol so macOS preserves its status color in the menu bar.
enum MenuBarIconFactory {
    static func image(for health: ServiceHealth) -> NSImage {
        let baseImage = NSImage(
            systemSymbolName: health.symbolName,
            accessibilityDescription: health.title
        ) ?? NSImage()

        let sizeConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let colorConfiguration = NSImage.SymbolConfiguration(
            paletteColors: paletteColors(for: health)
        )
        let configuredImage = baseImage.withSymbolConfiguration(
            sizeConfiguration.applying(colorConfiguration)
        ) ?? baseImage

        // Template images are recolored monochrome by the menu bar. Keeping this false
        // preserves green, orange, red, or gray as the service state changes.
        configuredImage.isTemplate = false
        return configuredImage
    }

    static func paletteColors(for health: ServiceHealth) -> [NSColor] {
        [.black, statusColor(for: health)]
    }

    private static func statusColor(for health: ServiceHealth) -> NSColor {
        switch health {
        case .operational: .systemGreen
        case .degraded: .systemOrange
        case .outage: .systemRed
        case .unknown: .systemGray
        }
    }
}
