import Foundation
@main struct LibraryChecks {
 static func main() {
  for link in ["https://www.youtube.com/watch?v=Y4G5H53X7Tw", "https://youtu.be/Y4G5H53X7Tw?t=9", "https://youtube.com/live/Y4G5H53X7Tw"] { precondition(YouTubeLink.videoID(link) == "Y4G5H53X7Tw") }
  for link in ["https://youtube.com.evil.test/watch?v=Y4G5H53X7Tw", "javascript:alert(1)", "https://user@youtube.com/watch?v=Y4G5H53X7Tw", "https://youtube.com/@channel"] { precondition(YouTubeLink.videoID(link) == nil) }
  let name = "SugrobTests-" + UUID().uuidString, defaults = UserDefaults(suiteName: name)!
  defer { defaults.removePersistentDomain(forName: name) }
  let city = WeatherCity(id: 123, name: "Лиссабон", latitude: 38.72, longitude: -9.14, timezone: "Europe/Lisbon")
  let library = CityLibrary(defaults: defaults)
  library.save(city, camera: nil)
  precondition(CityLibrary(defaults: defaults).places.count == 1)
  let camera = YouTubeLink.camera("https://youtu.be/Y4G5H53X7Tw", title: "Камера", city: city)!
  library.save(city, camera: camera);library.save(city, camera: camera)
  precondition(CityLibrary(defaults: defaults).places[0].cameras.count == 1)
  library.removeCamera(city: city, key: camera.key)
  precondition(CityLibrary(defaults: defaults).places[0].cameras.isEmpty)
  library.remove(city);precondition(CityLibrary(defaults: defaults).places.isEmpty)
  print("PASS: YouTube validation, city persistence, deduplication and deletion")
 }
}
