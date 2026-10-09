import SwiftUI
import CoreGraphics

/// A public-domain photo from the USDA ARS Image Gallery, with its BlurHash placeholder.
struct Photo {
    let asset: String
    let blurHash: String
    let alt: String
    let credit: String
    let source: String

    static let gallery: [String: Photo] = [
        "dairy": Photo(asset: "photo-dairy", blurHash: "LuDTI,xaofWC.Aj@ofa~gPR+t6kC", alt: "Dairy cows at the fence",
                     credit: "Photo by Keith Weller, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/featuredphoto/jun19/dairycows/"),
        "vegetables": Photo(asset: "photo-vegetables", blurHash: "LFDSgJ,0YYRUQ1EQx=kVtea5=_x?", alt: "Fresh beets and leafy greens",
                     credit: "Photo by Peggy Greb, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/featuredphoto/aug20/produce/"),
        "meat": Photo(asset: "photo-meat", blurHash: "LCCs.~%K9HM{8zs:RkRj01RS%1jc", alt: "Sheep grazing in a mountain meadow",
                     credit: "Photo by Scott Bauer, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/k5629-2"),
        "tools": Photo(asset: "photo-tools", blurHash: "L#Hf6gR+S6of%jofoga#S%oeV@WV", alt: "Tractor cultivating rows",
                     credit: "Photo by Keith Weller, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/k5197-3"),
        "eggs": Photo(asset: "photo-eggs", blurHash: "LaExj*s.oLWDoea|oKoK0jR+WVWC", alt: "Backlit eggs being candled",
                     credit: "Photo by Steve Ausmus, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/featuredphoto/sep19/eggs/"),
        "honey": Photo(asset: "photo-honey", blurHash: "LEIzCy3i*|5kGC;3K*M~1GvhF|SQ", alt: "Technician working a frame of honeycomb",
                     credit: "Photo by Vanessa Corby-Harris, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/may15/d3413-1/"),
        "garden": Photo(asset: "photo-garden", blurHash: "L8DT6AIo%d-;8|xt?aM{?wxtog%L", alt: "Broccoli and greens growing in a vegetable plot",
                     credit: "Photo by USDA-ARS U.S. Vegetable Laboratory (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/sep17/d3832-1/"),
        "fruit": Photo(asset: "photo-fruit", blurHash: "LDD+YgH@WA0%rqspoz?E58?ZRRr?", alt: "Baskets of strawberries, blackberries and blueberries",
                     credit: "Photo by Scott Bauer, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/k7229-19"),
        "seeds": Photo(asset: "photo-seeds", blurHash: "LII|~]I;tR-:~9I[bcR.%MIV%LNa", alt: "Dry bean seed varieties spilling from a seed packet",
                     credit: "Photo by Steve Ausmus, USDA-ARS (public domain)", source: "https://www.ars.usda.gov/oc/images/photos/featuredphoto/mar24/drybeans/"),
    ]

    /// Seeded listings that get a specific photo.
    private static let forImageName: [String: String] = [
        "item-cheddar": "dairy", "item-kraut": "vegetables", "item-lesson": "dairy", "item-lamb": "meat",
        "item-fleece": "meat", "item-fencing": "tools", "item-eggs": "eggs", "item-honey": "honey",
        "item-greens": "garden", "item-raisedbed": "garden",
    ]

    /// Everything else uses its category's photo. Wood has none yet, so it keeps the illustration.
    private static let forCategory: [ItemCategory: String] = [
        .veggies: "vegetables", .fruit: "fruit", .meat: "meat", .dairy: "dairy",
        .eggs: "eggs", .timeSkill: "tools", .other: "seeds",
    ]

    static func forItem(_ item: SpareItem) -> Photo? {
        if item.imageName == "item-firewood" { return nil }
        guard let key = forImageName[item.imageName] ?? forCategory[item.category] else { return nil }
        return gallery[key]
    }
}

/// Shows the BlurHash first, then fades the photo in over it.
struct PhotoView: View {
    let photo: Photo
    @State private var shown = false

    var body: some View {
        ZStack {
            if let blur = BlurHash.image(photo.blurHash) {
                Image(decorative: blur, scale: 1).resizable()
            }
            Image(photo.asset).resizable().scaledToFill()
                .opacity(shown ? 1 : 0)
                .accessibilityLabel(photo.alt)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onAppear { withAnimation(.easeIn(duration: 0.35)) { shown = true } }
    }
}

/// Minimal BlurHash decoder (https://blurha.sh).
enum BlurHash {
    private static let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~")
    private static let lookup: [Character: Int] = Dictionary(uniqueKeysWithValues: chars.enumerated().map { ($1, $0) })
    @MainActor private static var cache: [String: CGImage] = [:]

    private static func decode83(_ s: ArraySlice<Character>) -> Int? {
        var v = 0
        for c in s { guard let d = lookup[c] else { return nil }; v = v * 83 + d }
        return v
    }
    private static func toLinear(_ v: Int) -> Double {
        let x = Double(v) / 255
        return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
    }
    private static func toSRGB(_ v: Double) -> UInt8 {
        let x = max(0, min(1, v))
        let s = x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055
        return UInt8(max(0, min(255, (s * 255 + 0.5).rounded(.down))))
    }
    private static func signPow(_ v: Double, _ e: Double) -> Double { v < 0 ? -pow(-v, e) : pow(v, e) }

    @MainActor static func image(_ hash: String, width: Int = 32, height: Int = 24) -> CGImage? {
        if let hit = cache[hash] { return hit }
        let h = Array(hash)
        guard h.count >= 6, let size = decode83(h[0...0]) else { return nil }
        let nx = size % 9 + 1, ny = size / 9 + 1
        guard h.count == 4 + 2 * nx * ny, let qMax = decode83(h[1...1]), let dc = decode83(h[2...5]) else { return nil }
        let maxAC = Double(qMax + 1) / 166
        var colors: [(Double, Double, Double)] = [(toLinear(dc >> 16), toLinear((dc >> 8) & 255), toLinear(dc & 255))]
        for i in 1..<(nx * ny) {
            guard let v = decode83(h[(4 + i * 2)...(5 + i * 2)]) else { return nil }
            func q(_ n: Int) -> Double { signPow((Double(n) - 9) / 9, 2) * maxAC }
            colors.append((q(v / (19 * 19)), q((v / 19) % 19), q(v % 19)))
        }
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                var r = 0.0, g = 0.0, b = 0.0
                for j in 0..<ny {
                    for i in 0..<nx {
                        let basis = cos(Double.pi * Double(x * i) / Double(width)) * cos(Double.pi * Double(y * j) / Double(height))
                        let c = colors[i + j * nx]
                        r += c.0 * basis; g += c.1 * basis; b += c.2 * basis
                    }
                }
                let p = (y * width + x) * 4
                pixels[p] = toSRGB(r); pixels[p + 1] = toSRGB(g); pixels[p + 2] = toSRGB(b)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let img = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return nil }
        cache[hash] = img
        return img
    }
}
