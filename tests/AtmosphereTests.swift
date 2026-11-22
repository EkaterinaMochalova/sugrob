import AppKit

func checkAtmosphere() throws {
    let parse = ISO8601DateFormatter()
    let winter = parse.date(from: "2026-01-15T12:00:00Z")!
    let summer = parse.date(from: "2026-06-15T12:00:00Z")!
    precondition(CityPortrait.destinations.count == 8)
    precondition(Set(CityPortrait.destinations.map { $0.city.id }).count == 8)
    precondition(CityMood.localTime(winter, city: CityPortrait.newyork.city) == "07:00")
    precondition(CityMood.localTime(summer, city: CityPortrait.newyork.city) == "08:00")
    precondition(CityMood.localTime(summer, city: CityPortrait.nizhny.city) == "15:00")
    precondition(CityMood(city: CityPortrait.newyork.city).soundAsset == nil)
    for portrait in CityPortrait.destinations {
        let city = portrait.city
        precondition(CityPortrait.matching(city) == portrait)
        precondition(TimeZone(identifier: city.timezone!) != nil)
        let encoded = try JSONEncoder().encode(city)
        let restored = try JSONDecoder().decode(WeatherCity.self, from: encoded)
        precondition(restored == city)
        precondition(CityMood(city: city, date: winter).season == .winter)
        precondition(CityMood(city: city, date: summer).season == .summer)
        precondition(CityMood(city: city, date: summer, code: 71).precipitation)
        precondition(CityMood(city: city, date: summer, code: 61).precipitation)
        precondition(!CityMood(city: city, date: summer).precipitation) // offline atmosphere
        precondition(!CityMood(city: city, date: summer, code: 0).precipitation)
        precondition(CityMood(city: city, code: 45).fog)
        precondition(CityMood(city: city, code: 3).overcast)
    }
    precondition(CityMood.localTime(winter, city: CityPortrait.moscow.city) == "15:00")
    precondition(CityMood.localTime(winter, city: CityPortrait.tokyo.city) == "21:00")
    precondition(CityMood.localTime(winter, city: CityPortrait.rome.city) == "13:00")
    precondition(CityMood.localTime(summer, city: CityPortrait.rome.city) == "14:00")
    precondition(CityMood.localTime(winter, city: CityPortrait.athens.city) == "14:00")
    precondition(CityMood.localTime(summer, city: CityPortrait.athens.city) == "15:00")
    precondition(CityMood.localTime(winter, city: CityPortrait.nizhny.city) == "15:00")
    let juneNight = parse.date(from: "2026-06-15T20:30:00Z")!
    precondition(CityMood(city: CityPortrait.petersburg.city, date: juneNight).light == .whiteNight)
    precondition(CityMood(city: CityPortrait.moscow.city, date: juneNight).light == .night)
    let april = parse.date(from: "2026-04-15T03:00:00Z")!
    precondition(CityMood(city: CityPortrait.tokyo.city, date: april).particle == .petal)
    let november = parse.date(from: "2026-11-15T03:00:00Z")!
    precondition(CityMood(city: CityPortrait.tokyo.city, date: november).particle == .leaf)
    var legacy = CityPortrait.tokyo.city
    legacy.timezone = nil
    precondition(CityMood.localTime(winter, city: legacy) == "21:00")
    let southern = WeatherCity(id: 9, name: "Sydney", latitude: -33.87, longitude: 151.21, timezone: "Australia/Sydney")
    precondition(CityPortrait.matching(southern) == .neutral)
    precondition(CityMood(city: southern, date: winter).season == .summer)
    precondition(CityMood(city: CityPortrait.tokyo.city, date: april).edgeAsset == "cherry")
    precondition(CityMood(city: CityPortrait.tokyo.city, date: november).edgeAsset == "maple")
    precondition(CityMood(city: CityPortrait.moscow.city, date: winter).edgeAsset == nil)
    precondition(CityMood(city: CityPortrait.athens.city, date: winter).edgeAsset == "olive")
    precondition(CityMood(city: CityPortrait.petersburg.city, code: 0).soundAsset == nil)
    precondition(CityMood(city: CityPortrait.petersburg.city, code: 61).soundAsset == nil)
    for name in ["autumn", "olive", "pine", "maple", "cherry", "gull"] { precondition(PresenceAssets.image(name) != nil) }
    for name in ["florence-market", "florence-bells", "rome-pantheon", "tokyo-street"] { precondition(PresenceAssets.url(name, extension: "mp3") != nil) }
    for city in [CityPortrait.moscow, .athens, .petersburg, .nizhny] {
        for code in [0, 61, 71] { precondition(CityMood(city: city.city, code: code).soundAsset == nil) }
    }
    precondition(CityMood(city: CityPortrait.florence.city, code: 61).soundAsset == "florence-market")
    precondition(CityMood(city: CityPortrait.rome.city, code: 71).soundAsset == "rome-pantheon")
    precondition(CityMood(city: CityPortrait.tokyo.city).soundAsset == "tokyo-street")
    print("PASS: eight portraits, city matching, persistence, local clocks, DST, seasons, white nights, offline and precipitation")
}
