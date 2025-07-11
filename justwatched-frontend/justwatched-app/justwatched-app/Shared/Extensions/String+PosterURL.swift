import Foundation

extension String {
    /// Constructs a proper poster URL from a poster path
    /// - Parameter size: The TMDB image size (e.g., "w92", "w154", "w185", "w342", "w500", "w780", "original")
    /// - Returns: A properly formatted poster URL
    func posterURL(size: String = "w500") -> URL? {
        print("PosterURL Debug: Input path='\(self)', size='\(size)'")
        
        // If the string is already a full URL, return it as is
        if self.hasPrefix("http://") || self.hasPrefix("https://") {
            print("PosterURL Debug: Full URL detected, returning as is")
            return URL(string: self)
        }
        
        // If it's a relative path, construct the full TMDB URL
        let baseURL = "https://image.tmdb.org/t/p/"
        let fullURL = baseURL + size + self
        print("PosterURL Debug: Constructed URL='\(fullURL)'")
        return URL(string: fullURL)
    }
} 