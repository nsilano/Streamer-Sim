import Foundation

enum DatacenterNames {
    private static let sites: [Region: [String]] = [
        .northAmerica: ["Virginia", "Oregon", "Toronto", "Dallas"],
        .latinAmerica: ["Sao Paulo", "Santiago", "Mexico City", "Bogota"],
        .europe: ["Dublin", "Frankfurt", "Amsterdam", "Stockholm"],
        .asiaPacific: ["Singapore", "Tokyo", "Sydney", "Mumbai"],
        .middleEast: ["Dubai", "Riyadh", "Doha", "Muscat"],
        .africa: ["Johannesburg", "Lagos", "Nairobi", "Cairo"],
    ]

    /// Names the nth datacenter in a region, e.g. "Dublin DC".
    static func name(region: Region, index: Int) -> String {
        let list = sites[region] ?? ["Central"]
        let site = list[index % list.count]
        return index >= list.count ? "\(site) DC \(index / list.count + 1)" : "\(site) DC"
    }
}
