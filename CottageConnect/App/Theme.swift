import SwiftUI

enum Theme {
    static let moss = Color(red: 0.33, green: 0.45, blue: 0.27)
    static let clay = Color(red: 0.72, green: 0.45, blue: 0.30)
    static let wheat = Color(red: 0.80, green: 0.66, blue: 0.38)
}

/// Small rounded label used for roles, categories and statuses.
struct Tag: View {
    let text: String
    var color: Color = Theme.moss

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// Initials in a colored circle.
struct Avatar: View {
    let name: String
    var size: CGFloat = 36

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }

    private var color: Color {
        let palette = [Theme.moss, Theme.clay, Theme.wheat, Color.brown, Color.teal]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

struct ItemRow: View {
    let item: SpareItem
    var ownerName: String?

    var body: some View {
        HStack(spacing: 12) {
            ItemImage(item: item)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.headline)
                Text([item.quantity, ownerName ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if !item.isAvailable { Tag(text: "Traded", color: .secondary) }
        }
    }
}

/// The listing's USDA photo, or its illustration on a soft moss tile.
struct ItemImage: View {
    let item: SpareItem
    var padding: CGFloat = 6

    var body: some View {
        if let photo = Photo.forItem(item) {
            PhotoView(photo: photo)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Image(item.imageName)
                .resizable()
                .scaledToFit()
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.moss.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

extension View {
    /// Gives sheets a usable size on macOS, where they otherwise shrink to fit.
    func sheetSize() -> some View {
        #if os(macOS)
        frame(minWidth: 460, minHeight: 520)
        #else
        self
        #endif
    }
}

// MARK: - Current user

private struct CurrentUserKey: EnvironmentKey {
    static let defaultValue: Member? = nil
}

extension EnvironmentValues {
    /// The member using the app. In the demo this can be switched from the profile sheet.
    var currentUser: Member? {
        get { self[CurrentUserKey.self] }
        set { self[CurrentUserKey.self] = newValue }
    }
}
