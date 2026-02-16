import Foundation

internal enum ResourceBundleLocator {
  internal static let bundleName = "VibeWave_VibeWave"

  // Keep app launch resilient even if packaging is imperfect.
  internal static let resourceBundle: Bundle = locateBundle() ?? .main

  internal static func locateBundle(
    in candidateDirectories: [URL],
    bundleName: String = bundleName,
    fileManager: FileManager = .default
  ) -> Bundle? {
    let expectedDirectoryName = bundleName + ".bundle"

    for directory in candidateDirectories {
      let directBundleURL = directory.appendingPathComponent(expectedDirectoryName, isDirectory: true)
      if fileManager.fileExists(atPath: directBundleURL.path),
         let bundle = Bundle(url: directBundleURL)
      {
        return bundle
      }

      let contentsResourcesURL = directory
        .appendingPathComponent("Contents", isDirectory: true)
        .appendingPathComponent("Resources", isDirectory: true)
      let appResourcesBundleURL = contentsResourcesURL.appendingPathComponent(expectedDirectoryName, isDirectory: true)
      if fileManager.fileExists(atPath: appResourcesBundleURL.path),
         let bundle = Bundle(url: appResourcesBundleURL)
      {
        return bundle
      }

      let resourcesBundleURL = directory
        .appendingPathComponent("Resources", isDirectory: true)
        .appendingPathComponent(expectedDirectoryName, isDirectory: true)
      if fileManager.fileExists(atPath: resourcesBundleURL.path),
         let bundle = Bundle(url: resourcesBundleURL)
      {
        return bundle
      }
    }

    return nil
  }

  internal static func locateBundle() -> Bundle? {
    locateBundle(in: candidateDirectories())
  }

  internal static func candidateDirectories() -> [URL] {
    var directories: [URL] = []

    directories.append(Bundle.main.bundleURL)
    if let resourceURL = Bundle.main.resourceURL {
      directories.append(resourceURL)
    }
    if let executableURL = Bundle.main.executableURL {
      var directory = executableURL.deletingLastPathComponent()
      for _ in 0..<6 {
        directories.append(directory)
        directory.deleteLastPathComponent()
      }
    }

    // Test runs and some packaging environments can surface resources here.
    let finderBundle = Bundle(for: BundleFinder.self)
    directories.append(finderBundle.bundleURL)
    if let finderResourceURL = finderBundle.resourceURL {
      directories.append(finderResourceURL)
    }

    var seen = Set<String>()
    return directories.filter { candidate in
      seen.insert(candidate.standardizedFileURL.path).inserted
    }
  }
}

private final class BundleFinder {}
