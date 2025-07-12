import Foundation

extension String {
    /// Constructs a proper poster URL from a poster path
    /// - Parameter size: The TMDB image size (e.g., "w92", "w154", "w185", "w342", "w500", "w780", "original")
    /// - Returns: A properly formatted poster URL
    func posterURL(size: String = "w500") -> URL? {
        // If the string is already a full URL, return it as is
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            return URL(string: self)
        }
        
        // If it's a relative path, construct the full TMDB URL
        let baseURL = "https://image.tmdb.org/t/p/"
        return URL(string: baseURL + size + self)
    }
} 