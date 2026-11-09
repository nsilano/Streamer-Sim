import Foundation

/// A parody of a real show or movie, e.g. "The First of Us". Every license listing is drawn from this library.
struct ParodyTitle: Equatable {
    var name: String
    var kind: TitleKind
    var genre: Genre
    var language: Language
}

enum ParodyLibrary {
    // Format: "S|Name" for a series, "M|Name" for a movie. Local titles are "S|language|Name".
    private static let drama = """
    S|The First of Us
    S|Breaking Better
    S|Better Call Sol
    S|Procession
    S|Game of Thorns
    S|Sad Men
    S|The Bassos
    S|House of Cars
    S|Stranger Strings
    S|The Wi-Fi
    S|Peaky Binders
    S|Downturn Abbey
    S|The Handyman's Tale
    S|Eastworld
    S|Found
    S|Dexterous
    S|Greasy Anatomy
    S|Doctor Horse
    S|Boots
    S|This Is Them
    S|Yellowbone
    S|Reverence
    S|Dysphoria
    S|Abnormal People
    S|The King's Gamble
    S|Flea Market
    S|Small Big Lies
    S|Stallion of Westtown
    S|False Detective
    S|Killing Steve
    S|Bridgeburn
    S|Nark-Os
    S|Homelandia
    S|The Crowd
    S|The Morning Shoe
    S|The Bare
    S|Mindhunger
    S|Gray Mirror
    S|The Rightovers
    S|The Okay Place
    S|Shamefull
    S|Sons of Monarchy
    S|Bikings
    S|The Talking Dead
    S|Sherlocked
    S|Fargone
    S|Twin Pikes
    S|Ms. Robot
    S|The Expense
    S|Squad Games
    M|The Godmother
    M|The Shawshank Reduction
    M|Goodfellows
    M|Pulp Friction
    M|Flight Club
    M|The Departments
    M|Whip Cash
    M|Paraseat
    M|Poker
    M|Blah Blah Land
    M|Oppen-Hammer
    M|Intersellar
    M|Reception
    M|Gone Pearl
    M|Forest Bump
    M|Se8en
    M|Titanick
    M|Silence of the Clams
    M|The Whining
    M|Get In
    """

    private static let comedy = """
    S|The Offsite
    S|Fiends
    S|Sinfeld
    S|Brooklyn Nine-Five
    S|Parks and Wreckreation
    S|Stitch's Creek
    S|Ted Lacrosse
    S|Medieval Family
    S|How I Met Your Brother
    S|The Big Bank Theory
    S|Arrested Delivery
    S|Weep
    S|Curve Your Enthusiasm
    S|Abbot Elemental
    S|Only Burgers in the Building
    S|What We Do in the Shades
    S|30 Roll
    S|Immunity
    S|Old Girl
    S|Superscore
    S|Two and a Half Mensa
    S|Gals
    S|Silicone Valley
    S|Berry
    S|It's Always Rainy in Philadelphia
    S|Scrubbed
    S|Jeers
    S|Malcolm in the Muddle
    S|Everybody Loves Raymundo
    M|Supergood
    M|Step Mothers
    M|Groomsmen
    M|The Hungover
    M|Mean Squirrels
    M|Napoleon Dinomite
    M|Zoolandia
    M|Dumb and Dumbbell
    M|Home Along
    M|Ghostbusses
    M|Anchorwoman
    M|Shelf
    M|Knocked Down
    M|Tropic Blunder
    M|Meet the Parrots
    M|Shaun of the Bed
    M|Hot Fuss
    M|Dodgy Ball
    M|Clueful
    M|Airplane Mode!
    M|Mrs. Doubtful
    M|Paranormal Inactivity
    """

    private static let action = """
    M|John Wicker
    M|Mission: Improbable
    M|Fast & Curious
    M|Die Hardly
    M|Top Bun
    M|Mad Maxine
    M|Determinator
    M|The Mattress
    M|Gladiolus
    M|Bravehurt
    M|Rambow
    M|Preda-Tor
    M|Alienated
    M|Jurassic Perk
    M|Indiana Bones
    M|The Dork Knight
    M|Iron Pan
    M|Thorn
    M|Black Pantry
    M|Star Wares
    M|Star Trick
    M|Dunce
    M|Casino Royal Flush
    M|Skyfail
    M|Sweat
    M|Speed Limit
    M|Given
    M|The Unequalizer
    M|Pay Bill
    M|Crouching Tiger, Hidden Cat
    M|Raiders of the Lost Arc
    M|Scram
    M|Seesaw
    S|25
    S|Prison Brunch
    S|The Mandolinian
    S|Teacher
    S|Jack Ryanair
    S|Dairydevil
    S|The Pitcher
    S|Narrow
    S|The Splash
    """

    private static let kids = """
    S|Paw Parole
    S|Pepa Pug
    S|Blooey
    S|Sesame Seed Street
    S|SpongeBub RoundPants
    S|Adventure Dime
    S|Dora the Ex-Plorer
    S|Thomas the Think Engine
    S|Rob the Builder
    S|Author
    S|Scooby-Don't
    S|Tween Titans Go!
    S|Ben 11
    S|PB Masks
    S|Cocomelonade
    S|The Magic School Bass
    S|Wild Cratts
    S|Gravity Fails
    S|Phineas and Fern
    S|The Last Hairbender
    S|Kim Impossible
    S|Winnie the Pooch
    M|Frosted
    M|Toy Storey
    M|Finding Memo
    M|The Lyin' King
    M|Shrink
    M|Encanted
    M|Carts
    M|Down
    M|Outside In
    M|Delectable Me
    M|Mini-Onions
    M|Rat-a-Tooey
    M|Wall-F
    M|Kung Fu Pasta
    M|How to Train Your Pigeon
    M|Madagastar
    M|Rice Age
    M|Cocoa
    M|Big Hero 7
    M|Monsters, Ink.
    """

    private static let anime = """
    S|Snack on Titan
    S|Lemon Slayer
    S|One Peace
    S|Depth Note
    S|Dragon Bowl
    S|My Zero Academia
    S|Jujitsu Kaizen
    S|Spy x Family Dinner
    S|Cowboy Be-Flop
    S|Fullmental Alchemist
    S|Sailor Noon
    S|Naruto-e
    S|Poke-Bowl Monsters
    S|Bleached
    S|Hunter x Gatherer
    S|Tokyo Goul-ash
    S|Sword Art Offline
    S|Fairy Tailor
    S|Chainsaw Mime
    S|Neon Genesis Evangelism
    S|Haiku-u!!
    S|Dessert Parade
    S|Dr. Scone
    S|Mob Psycho 101
    S|One-Pinch Man
    S|Finland Saga
    S|Be-Serk
    S|Black Rover
    S|Code Geese
    S|Stains;Gate
    M|Spirited Aways
    M|My Neighbor Toto
    M|Your Aim
    M|A-Kira
    M|Princess Mononope
    M|Howl's Moving Apartment
    M|Weathering with Me
    M|Phonyo
    M|Perfect Green
    """

    private static let reality = """
    S|Love Highland
    S|Big Bother
    S|Survivors Anonymous
    S|The Bake-lor
    S|The Great British Bake Out
    S|Drag Pace
    S|Selling Sunrise
    S|Too Cold to Handle
    S|Love Is Blurry
    S|Married at First Bite
    S|The Noise
    S|American Idle
    S|Dancing with the Cars
    S|MasterChief
    S|Top Chip
    S|Shark Bank
    S|Dragon's Pen
    S|Dressed and Afraid
    S|Together
    S|The Floor Is Gravy
    S|The Square
    S|Hell's Kitchenette
    S|Deal or No Meal
    S|The Amazing Face
    S|Fear Fiction
    S|Prawn Stars
    S|Storage Wares
    S|The Real Housemice
    S|Jersey Snore
    S|Say Yes to the Mess
    S|Pet Swap
    S|Come Dine Without Me
    """

    private static let docs = """
    S|Planet Worth
    S|Making a Burger
    S|Liger King
    S|Costmos
    S|The Social Lemma
    M|Free Polo
    M|My Octopus Preacher
    S|Our Plant
    S|Blue Planter
    M|Super Size Us
    S|Fire Sale
    M|Ickarus
    M|Jiro Dreams of Sashimi
    M|The 14th
    S|The Last Dunk
    S|Drive to Thrive
    S|Chef's Tablet
    S|Wild Wild Countryside
    S|The Escalator
    S|Don't Mess with Cats
    S|The Lynx
    S|Abducted in Plain Site
    S|The Tender Swindler
    M|Exit Through the Gift Card
    M|March of the Pigeons
    M|An Inconvenient Tooth
    M|Searching for Sugar Cane
    M|Bowling for Cucumbers
    M|Man on Wifi
    M|Hoop Schemes
    """

    private static let local = """
    S|spanish|La Casa de Papá
    S|spanish|Élito
    S|spanish|Café con Aroma de Pan
    S|spanish|La Reina del Surf
    S|spanish|El Chavo del Nueve
    S|spanish|Control Y
    S|spanish|Pasión de Gallinas
    M|spanish|El Laberinto del Faro
    S|french|Lupine
    S|french|Neuf pour Cent
    S|french|Les Revenus
    M|french|Le Fabuleux Destin d'Amélie Poulet
    M|french|Les Touchables
    S|german|Darker
    S|german|Babylon Bremen
    S|german|Das Boat
    M|german|Das Leben der Ameisen
    M|german|Lola rennt nicht
    M|german|Good Bye, Linen!
    S|korean|Squid Frame
    S|korean|Crash Landing on Me
    S|korean|Kingdumb
    S|korean|Itaewon Glass
    S|korean|Gobblin'
    S|korean|Reply 1989
    S|korean|Extraordinary Attorney Moo
    S|korean|All of Us Are Fed
    M|korean|Bus to Busan
    M|korean|Oldgirl
    S|hindi|Scared Games
    S|hindi|Mirzapour
    S|hindi|The Family Pan
    S|hindi|Quota Factory
    S|hindi|Scam 1993
    M|hindi|4 Idiots
    M|hindi|Lag Again
    S|portuguese|Avenida Basil
    M|portuguese|Cidade de Pão
    M|portuguese|Tropa de Elfo
    S|italian|La Pioggia
    M|italian|La Vita è Pizza
    M|italian|Il Postino Pazzo
    M|italian|Cinema Paradosso
    S|turkish|Reservation: Ertuğrul
    S|swedish|The Fridge
    S|swedish|Young Rascals
    S|japanese|Terrace Mouse
    S|japanese|Hanzawa Naomi
    S|japanese|Midnight Dinner
    """

    private static func parse(_ raw: String, genre: Genre) -> [ParodyTitle] {
        raw.split(separator: "\n").compactMap { line -> ParodyTitle? in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2 else { return nil }
            let kind: TitleKind = parts[0] == "M" ? .movie : .series
            if parts.count == 3 {
                return ParodyTitle(name: parts[2], kind: kind, genre: genre, language: Language(rawValue: parts[1]) ?? .english)
            }
            let language: Language = genre == .anime ? .japanese : .english
            return ParodyTitle(name: parts[1], kind: kind, genre: genre, language: language)
        }
    }

    /// Every parody, by genre.
    static let byGenre: [Genre: [ParodyTitle]] = [
        .drama: parse(drama, genre: .drama),
        .comedy: parse(comedy, genre: .comedy),
        .action: parse(action, genre: .action),
        .kids: parse(kids, genre: .kids),
        .anime: parse(anime, genre: .anime),
        .reality: parse(reality, genre: .reality),
        .docs: parse(docs, genre: .docs),
        .local: parse(local, genre: .local),
    ]

    static var all: [ParodyTitle] { Genre.allCases.flatMap { byGenre[$0] ?? [] } }
}
