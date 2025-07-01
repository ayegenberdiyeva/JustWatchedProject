import Foundation

enum SearchResult: Identifiable, Hashable {
    case movie(Movie)
    case tvShow(TVShow)
    
    var id: String {
        switch self {
        case .movie(let movie):
            return "movie-\(movie.id)"
        case .tvShow(let show):
            return "tv-\(show.id)"
        }
    }
    
    var title: String {
        switch self {
        case .movie(let movie):
            return movie.title
        case .tvShow(let show):
            return show.name
        }
    }
    
    var releaseDate: String? {
        switch self {
        case .movie(let movie):
            return movie.releaseDate
        case .tvShow(let show):
            return show.firstAirDate
        }
    }
    
    var overview: String? {
        switch self {
        case .movie(let movie):
            return movie.overview
        case .tvShow(let show):
            return show.overview
        }
    }
    
    var posterPath: String? {
        switch self {
        case .movie(let movie):
            return movie.posterPath
        case .tvShow(let show):
            return show.posterPath
        }
    }
}
