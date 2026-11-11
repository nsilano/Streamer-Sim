import Foundation

/// Endless parody titles: the recognisable heart of a famous film or show ("Godfather", "Breaking") spun into a
/// pun ("Godfather Cheese", "The Shawshank Hour", "Rocky Meets Jaws"). A stem is never used on its own, so no
/// result is ever a real title.
enum PunTitles {
    struct Stems {
        var movies: [String]
        var series: [String]
    }

    static let stems: [Genre: Stems] = [
        .drama: Stems(
            movies: ["Godfather", "Shawshank", "Casablanca", "Titanic", "Gladiator", "Braveheart", "Forrest Gump", "Goodfellas",
                     "Scarface", "Chinatown", "Vertigo", "Psycho", "Citizen Kane", "Rocky", "Raging Bull", "Taxi Driver", "Apocalypse",
                     "Platoon", "Rain Man", "Philadelphia", "Moonlight", "Parasite", "Joker", "Whiplash", "Birdman", "Spotlight", "Argo",
                     "Avatar", "Inception", "Interstellar", "Oppenheimer", "Dunkirk", "Fargo", "Memento", "Zodiac", "Prisoners", "Gone Girl",
                     "Social Network", "Moneyball", "Big Short", "Wall Street", "American Beauty", "Fight Club", "Trainspotting", "Amadeus",
                     "Ben-Hur", "Spartacus", "Zhivago", "Out of Africa", "Dances with Wolves", "Unforgiven",
                     "Heat", "Casino", "Departed", "Mystic River", "Million Dollar Baby", "Gran Torino", "Green Mile", "Seabiscuit",
                     "Hotel Rwanda", "Blood Diamond", "Slumdog", "Life of Pi", "Pianist", "Cinema Paradiso", "Amelie", "Pan's Labyrinth",
                     "Roma", "Nomadland", "Minari", "Green Book", "Spotlight", "Selma", "Hidden Figures", "Moonrise", "Lost in Translation",
                     "Eternal Sunshine", "Brokeback Mountain", "Black Swan", "Revenant", "Revolutionary Road", "Atonement", "King's Speech",
                     "Theory of Everything", "Imitation Game", "Beautiful Mind", "Good Will Hunting", "Dead Poets Society", "Shine",
                     "Network", "Serpico", "Deer Hunter", "Chariots of Fire", "Rebel Without a Cause",
                     "East of Eden", "Streetcar", "Sunset Boulevard", "On the Waterfront", "12 Angry Men", "To Kill a Mockingbird",
                     "Grapes of Wrath", "Gone with the Wind", "Wizard of Oz", "It's a Wonderful Life", "Roman Holiday", "Breakfast at Tiffany's"],
            series: ["Sopranos", "The Wire", "Breaking Bad", "Mad Men", "Succession", "The Crown", "Downton Abbey", "Game of Thrones",
                     "Westworld", "True Detective", "Lost", "Fringe", "House", "ER", "Grey's Anatomy", "This Is Us", "Better Call Saul",
                     "Ozark", "Peaky Blinders", "Narcos", "Money Heist", "Squid Game", "Stranger Things", "Handmaid's Tale", "Black Mirror",
                     "Boardwalk Empire", "Deadwood", "Six Feet Under", "Rome", "Vikings", "Outlander", "Bridgerton", "Yellowstone",
                     "Homeland", "Prison Break", "Dexter", "Sons of Anarchy", "Justified", "Mindhunter", "Chernobyl", "Euphoria",
                     "White Lotus", "Big Little Lies", "Mare of Easttown", "Line of Duty", "Broadchurch", "Luther", "Sherlock", "Skins",
                     "Shameless", "Gossip Girl", "Riverdale", "Dawson's Creek", "One Tree Hill", "Friday Night Lights", "Parenthood",
                     "Desperate Housewives", "Dynasty", "Dallas", "Melrose Place", "Beverly Hills", "Vampire Diaries", "True Blood", "Buffy",
                     "Charmed", "Supernatural", "Lucifer", "Gotham", "Daredevil", "Mandalorian", "Andor", "Severance", "Silo", "Foundation",
                     "Expanse", "Battlestar", "Walking Dead", "Fargo", "Hannibal", "Bates Motel", "Twin Peaks", "X-Files", "Dark",
                     "Babylon Berlin", "Borgen", "The Killing", "The Bridge", "Gomorrah", "Suburra", "Sacred Games", "Delhi Crime",
                     "Crash Landing", "Kingdom", "Goblin", "Sky Castle", "Reply 1988", "Pachinko", "Shogun", "House of the Dragon",
                     "Rings of Power", "Witcher", "Wheel of Time", "Shadow and Bone", "Last of Us", "Fallout", "Yellowjackets", "The Bear",
                     "Industry", "Billions", "Margin Call", "Newsroom", "West Wing", "House of Cards", "Scandal", "Madam Secretary"]),
        .comedy: Stems(
            movies: ["Anchorman", "Step Brothers", "Talladega Nights", "Elf", "Old School", "Dodgeball", "Zoolander", "Tropic Thunder",
                     "Meet the Parents", "Dumb and Dumber", "Ace Ventura", "The Mask", "Liar Liar", "Bruce Almighty", "Billy Madison",
                     "Happy Gilmore", "Waterboy", "Wedding Singer", "50 First Dates", "Big Daddy", "Hangover", "Wedding Crashers",
                     "Bridesmaids", "Knocked Up", "40-Year-Old Virgin", "Pineapple Express", "Superbad", "Forgetting Sarah Marshall",
                     "Neighbors", "Horrible Bosses", "American Pie", "Clueless", "Mean Girls", "Legally Blonde", "Bring It On",
                     "Easy A", "Sixteen Candles", "Breakfast Club", "Weird Science", "Dazed and Confused", "Clerks",
                     "Mallrats", "Big Lebowski", "O Brother", "Raising Arizona", "Blazing Saddles", "Young Frankenstein", "Spaceballs",
                     "Airplane", "Naked Gun", "Hot Shots", "Caddyshack", "Stripes", "Animal House", "Ghostbusters", "Groundhog Day",
                     "Tootsie", "Mrs. Doubtfire", "Big", "Splash", "Dirty Rotten Scoundrels", "Planes Trains and Automobiles", "Uncle Buck",
                     "Home Alone", "Vacation", "Fletch", "Beverly Hills Cop", "Trading Places", "Coming to America", "Nutty Professor",
                     "Rush Hour", "Jumanji", "Pink Panther", "A Fish Called Wanda", "Holy Grail", "Life of Brian", "Hot Fuzz",
                     "Shaun of the Dead", "Notting Hill", "Love Actually", "Four Weddings", "Full Monty", "Kinky Boots",
                     "In Bruges", "Borat", "Spinal Tap", "Best in Show", "Napoleon Dynamite", "Juno", "Little Miss Sunshine", "Booksmart",
                     "Shrek", "Toy Story", "Despicable Me", "Madagascar", "Ice Age", "Monsters Inc", "Finding Nemo", "Incredibles"],
            series: ["The Office", "Parks and Recreation", "Brooklyn Nine-Nine", "Community", "30 Rock", "Arrested Development",
                     "Always Sunny", "Curb Your Enthusiasm", "Seinfeld", "Frasier", "Cheers", "Friends", "How I Met Your Mother",
                     "Big Bang Theory", "Modern Family", "Everybody Hates Chris", "My Name Is Earl", "Malcolm in the Middle", "That '70s Show",
                     "Home Improvement", "Full House", "Saved by the Bell", "Fresh Prince", "Golden Girls", "I Love Lucy", "M*A*S*H",
                     "Happy Days", "Three's Company", "Scrubs", "New Girl", "Superstore", "Good Place", "Schitt's Creek", "Rick and Morty",
                     "BoJack Horseman", "Archer", "Bob's Burgers", "The Simpsons", "Family Guy", "Futurama", "King of the Hill", "South Park",
                     "Ted Lasso", "Only Murders", "Abbott Elementary", "Hacks", "Barry", "Atlanta", "Insecure", "Broad City", "Veep",
                     "Fawlty Towers", "Blackadder", "Only Fools and Horses", "Red Dwarf", "Father Ted", "IT Crowd", "Peep Show",
                     "Inbetweeners", "Gavin and Stacey", "Derry Girls", "Fleabag", "Taskmaster", "Saturday Night Live", "Key and Peele",
                     "Portlandia", "Nathan for You", "Louie", "Master of None", "Kim's Convenience", "Letterkenny", "Trailer Park Boys",
                     "Corner Gas", "Mythic Quest", "Dead to Me", "Grace and Frankie", "Kimmy Schmidt", "Brooklyn Bridge", "Girls", "Entourage"]),
        .action: Stems(
            movies: ["Die Hard", "Lethal Weapon", "Mad Max", "Terminator", "Matrix", "John Wick", "Taken", "Mission Impossible", "Skyfall",
                     "Goldeneye", "Casino Royale", "Fast and Furious", "Transporter", "Crank", "Expendables", "Rambo", "Cobra", "Cliffhanger",
                     "Demolition Man", "Total Recall", "Predator", "Commando", "True Lies", "Last Action Hero", "Eraser",
                     "Bloodsport", "Kickboxer", "Universal Soldier", "Timecop", "Hard Target", "Under Siege", "Blade", "Underworld",
                     "Resident Evil", "Mortal Kombat", "Street Fighter", "Tomb Raider", "Hitman", "Prince of Persia", "Tron", "Fifth Element",
                     "Leon", "Atomic Blonde", "Salt", "Wanted", "Edge of Tomorrow", "Top Gun", "Days of Thunder", "Minority Report", "Speed", "Point Break", "Air Force One", "Con Air", "Face/Off", "Broken Arrow", "Ronin", "Heat",
                     "Ocean's Eleven", "Italian Job", "Inside Man", "Dark Knight", "Batman Begins", "Superman", "Wonder Woman", "Aquaman",
                     "Black Panther", "Iron Man", "Captain America", "Thor", "Avengers", "Spider-Man", "Doctor Strange", "Guardians of the Galaxy",
                     "Ant-Man", "Deadpool", "Logan", "X-Men", "Kingsman", "Hellboy", "Aliens", "Prometheus", "Starship Troopers", "RoboCop",
                     "Elysium", "Dredd", "Pacific Rim", "Godzilla", "Kong", "Cloverfield", "Raid", "Ong-Bak", "Enter the Dragon", "Rumble in the Bronx",
                     "Karate Kid", "Kung Fu Hustle", "Crouching Tiger", "Seven Samurai", "Yojimbo", "Battle Royale", "Oldboy", "Train to Busan"],
            series: ["24", "Hawaii Five-0", "Magnum", "Miami Vice", "A-Team", "Knight Rider", "Airwolf", "MacGyver",
                     "Walker Texas Ranger", "Xena", "Highlander", "Stargate", "Farscape", "Babylon 5", "Burn Notice", "Chuck", "Alias",
                     "Leverage", "White Collar", "Strike Back", "Spooks", "Bourne", "Americans", "Night Agent", "Slow Horses", "Killing Eve",
                     "Banshee", "Spartacus", "Warrior", "Last Kingdom", "Punisher", "Jessica Jones", "Luke Cage", "Iron Fist", "Defenders",
                     "Agents of SHIELD", "Moon Knight", "Loki", "Hawkeye", "WandaVision", "Falcon and Winter Soldier", "She-Hulk", "Ms. Marvel",
                     "Star Wars Rebels", "Clone Wars", "Bad Batch", "Orphan Black", "Killjoys", "Lost in Space", "Colony", "Terra Nova",
                     "Heroes", "Quantum Leap", "Star Trek", "Doctor Who", "Torchwood", "Blake's 7", "Thunderbirds", "The Prisoner", "The Avengers",
                     "The Saint", "The Professionals", "The Sweeney", "Minder", "Bergerac", "Taggart", "Morse", "Endeavour", "Midsomer Murders"]),
        .kids: Stems(
            movies: ["Frozen", "Toy Story", "Inside Out", "Coco", "Moana", "Lion King", "Aladdin", "Beauty and the Beast", "Little Mermaid",
                     "Pocahontas", "Mulan", "Hercules", "Hunchback", "Tarzan", "Emperor's New Groove", "Atlantis", "Lilo and Stitch",
                     "Treasure Planet", "Brother Bear", "Chicken Little", "Bolt", "Princess and the Frog", "Tangled", "Winnie the Pooh",
                     "Wreck-It Ralph", "Big Hero 6", "Zootopia", "Raya", "Encanto", "Strange World", "Wish", "Elemental", "Luca",
                     "Turning Red", "Lightyear", "Finding Dory", "Cars", "Good Dinosaur", "Brave", "Monsters University", "Up", "Ratatouille",
                     "WALL-E", "Kung Fu Panda", "Puss in Boots", "Croods", "Rise of the Guardians", "Trolls", "Megamind", "Boss Baby",
                     "Captain Underpants", "Abominable", "Bad Guys", "Sing", "Secret Life of Pets", "Minions", "Lorax", "Horton", "Grinch",
                     "Cat in the Hat", "Hop", "Hotel Transylvania", "Smallfoot", "Angry Birds", "Ferdinand", "Rio", "Epic", "Robots",
                     "Happy Feet", "Open Season", "Over the Hedge", "Surf's Up", "Cloudy with a Chance of Meatballs", "Emoji Movie", "Peanuts",
                     "Paddington", "Peter Rabbit", "Dolittle", "Stuart Little", "Babe", "Charlotte's Web", "Garfield", "Scooby-Doo",
                     "Flintstones", "Jetsons", "Space Jam", "Looney Tunes", "Tom and Jerry", "Alvin and the Chipmunks", "Smurfs",
                     "Lego Movie", "Ninjago", "Mario", "Sonic", "Pikachu", "Pokemon", "Digimon", "Spirited Away", "Totoro", "Kiki", "Howl's Moving Castle", "Ponyo"],
            series: ["Paw Patrol", "Peppa Pig", "Bluey", "Blue's Clues", "Dora", "Sesame Street", "Barney", "Teletubbies",
                     "Thomas the Tank Engine", "Fireman Sam", "Bob the Builder", "Octonauts", "Teen Titans", "Ben 10", "Adventure Time",
                     "Regular Show", "Steven Universe", "Gravity Falls", "Phineas and Ferb", "Kim Possible", "Recess", "Hey Arnold",
                     "Rugrats", "Wild Thornberrys", "Rocket Power", "Invader Zim", "Jimmy Neutron", "SpongeBob", "Loud House",
                     "Henry Danger", "Sofia the First", "Doc McStuffins", "Mickey Mouse Clubhouse", "Handy Manny", "Lion Guard", "Elena of Avalor",
                     "Gabby's Dollhouse", "Spidey", "Ms. Rachel", "CoComelon", "Baby Shark", "Blippi", "Numberblocks", "Cyberchase", "Wild Kratts",
                     "Curious George", "Arthur", "Clifford", "Martha Speaks", "Wordgirl", "Super Why", "Dinosaur Train", "Odd Squad", "Molly of Denali",
                     "Daniel Tiger", "Magic School Bus", "Liberty's Kids", "Wishbone", "Reading Rainbow", "Zoboomafoo", "Lazytown",
                     "Yo Gabba Gabba", "Wiggles", "Pingu", "Muppet Show", "Fraggle Rock", "Muppet Babies", "Power Rangers", "Ninja Turtles",
                     "He-Man", "She-Ra", "ThunderCats", "Transformers", "My Little Pony", "Care Bears", "Smurfs", "Gummi Bears", "DuckTales",
                     "Rescue Rangers", "TaleSpin", "Darkwing Duck", "Gargoyles", "Avatar", "Legend of Korra", "Young Justice", "Batman Animated",
                     "Powerpuff Girls", "Dexter's Laboratory", "Courage the Cowardly Dog", "Ed Edd n Eddy", "Foster's Home", "Samurai Jack",
                     "We Bare Bears", "Craig of the Creek", "Owl House", "Amphibia", "Big City Greens", "Miraculous", "Winx Club", "Dragon Prince"]),
        .anime: Stems(
            movies: ["Your Name", "Weathering with You", "Suzume", "Akira", "Ghost in the Shell", "Perfect Blue", "Paprika", "Spirited Away",
                     "Princess Mononoke", "Grave of the Fireflies", "Nausicaa", "Castle in the Sky", "Porco Rosso", "Silent Voice",
                     "Summer Wars", "Wolf Children", "Evangelion", "Gundam", "Cowboy Bebop", "Demon Slayer Movie", "Jujutsu Kaisen 0",
                     "One Piece Film", "Dragon Ball Super Broly", "Naruto Movie", "My Hero Academia Movie", "Detective Conan Movie", "Doraemon Movie",
                     "Redline", "Metropolis", "Steamboy", "Ninja Scroll", "Vampire Hunter D", "Berserk", "Hellsing", "Violet Evergarden Movie"],
            series: ["Attack on Titan", "Death Note", "Fullmetal Alchemist", "Naruto", "Bleach", "One Piece", "Hunter x Hunter", "My Hero Academia",
                     "Demon Slayer", "Jujutsu Kaisen", "Chainsaw Man", "Spy x Family", "Tokyo Ghoul", "Sword Art Online", "Re:Zero",
                     "Overlord", "Mob Psycho", "One Punch Man", "Dr. Stone", "Promised Neverland", "Fire Force", "Black Clover", "Fairy Tail",
                     "Seven Deadly Sins", "Dragon Ball", "Cowboy Bebop", "Samurai Champloo", "Trigun", "Rurouni Kenshin", "Gintama",
                     "Yu Yu Hakusho", "Slam Dunk", "Haikyu", "Kuroko's Basketball", "Prince of Tennis", "Free!", "Ace of Diamond",
                     "Inazuma Eleven", "Captain Tsubasa", "Initial D", "Hajime no Ippo", "Sailor Moon", "Cardcaptor Sakura", "Fruits Basket",
                     "Ouran High School", "Kaguya-sama", "Toradora", "Clannad", "Your Lie in April", "Violet Evergarden", "Anohana",
                     "Steins;Gate", "Code Geass", "Gurren Lagann", "Evangelion", "Psycho-Pass", "Monster", "Made in Abyss", "Vinland Saga",
                     "Mushishi", "Spice and Wolf", "Space Brothers", "Planetes", "Outlaw Star", "Macross", "Gundam Wing", "Darling in the Franxx",
                     "Kill la Kill", "FLCL", "Soul Eater", "Black Butler", "Blue Exorcist", "Noragami", "Konosuba", "No Game No Life", "Log Horizon",
                     "Fate", "Date A Live", "High School DxD", "Food Wars", "Magi", "Little Witch Academia", "Madoka Magica", "Frieren",
                     "Dungeon Meshi", "Solo Leveling", "Tower of God", "Mashle", "Dandadan", "Kaiju No. 8", "Blue Lock", "Oshi no Ko", "Bocchi the Rock",
                     "Lycoris Recoil", "Cyberpunk Edgerunners", "Horimiya", "Bakemonogatari", "Baccano", "Durarara", "Black Lagoon", "Jormungand",
                     "Hyouka", "Detective Conan", "Lupin III", "Golden Kamuy", "Dororo", "Dorohedoro", "Pokemon", "Digimon", "Yo-kai Watch",
                     "Beyblade", "Yu-Gi-Oh", "Shaman King", "Inuyasha", "Totally Spies", "Ranma", "Urusei Yatsura", "Maison Ikkoku", "City Hunter",
                     "Fist of the North Star", "Saint Seiya", "Mazinger", "Astro Boy", "Devilman", "Kimba"]),
        .reality: Stems(
            movies: [],
            series: ["Survivor", "Big Brother", "Amazing Race", "The Bachelor", "The Bachelorette", "Love Island", "Too Hot to Handle",
                     "Love Is Blind", "Married at First Sight", "Naked and Afraid", "Dating Naked", "The Circle", "The Traitors", "The Challenge",
                     "Alone", "Man vs. Wild", "Wipeout", "American Ninja Warrior", "Fear Factor", "Hell's Kitchen", "MasterChef", "Top Chef",
                     "Chopped", "Guy's Grocery Games", "Cupcake Wars", "Cake Boss", "Nailed It", "Great British Bake Off", "Sewing Bee",
                     "Race Across the World", "Strictly Come Dancing", "Dancing with the Stars", "So You Think You Can Dance", "America's Got Talent",
                     "Britain's Got Talent", "The Voice", "American Idol", "X Factor", "Pop Idol", "Making the Band", "Top Model", "Project Runway",
                     "Drag Race", "Queer Eye", "Say Yes to the Dress", "Sweet 16", "Teen Mom", "Jersey Shore", "The Hills", "Laguna Beach",
                     "The Real World", "Real Housewives", "Kardashians", "Osbournes", "Duck Dynasty", "Honey Boo Boo", "Toddlers and Tiaras",
                     "Sister Wives", "Little People Big World", "Dance Moms", "Pawn Stars", "American Pickers", "Storage Wars", "Antiques Roadshow",
                     "Cash Cab", "Deal or No Deal", "Who Wants to Be a Millionaire", "Wheel of Fortune", "Jeopardy", "Price Is Right", "Family Feud",
                     "Weakest Link", "Pointless", "Countdown", "Mastermind", "University Challenge", "The Chase", "Bargain Hunt", "Grand Designs",
                     "Selling Sunset", "Million Dollar Listing", "Love It or List It", "Property Brothers", "Fixer Upper", "Flip or Flop",
                     "House Hunters", "Trading Spaces", "Extreme Makeover", "What Not to Wear", "Supernanny", "Wife Swap", "Undercover Boss",
                     "Shark Tank", "Dragons' Den", "The Apprentice", "Mythbusters", "Dirty Jobs", "Deadliest Catch", "Ice Road Truckers",
                     "Swamp People", "Gold Rush", "Mountain Men", "Life Below Zero", "I'm a Celebrity", "Celebrity Big Brother", "Taskmaster",
                     "Come Dine with Me", "Gogglebox", "Don't Tell the Bride", "Four Weddings", "Bridezillas", "90 Day Fiance", "Love After Lockup",
                     "Biggest Loser", "Cops", "Intervention", "Hoarders", "Cheaters", "Blind Date", "Take Me Out", "Flavor of Love",
                     "Bad Girls Club", "Vanderpump Rules", "Below Deck", "Southern Charm", "Summer House", "Bling Empire", "Are You the One",
                     "Ex on the Beach", "Geordie Shore", "Made in Chelsea", "Perfect Match", "The Ultimatum", "Indian Matchmaking", "Sexy Beasts"]),
        .docs: Stems(
            movies: ["Man on Wire", "Grizzly Man", "Bowling for Columbine", "Fahrenheit 9/11", "Sicko", "Super Size Me", "Spellbound",
                     "Hoop Dreams", "Searching for Sugar Man", "Exit Through the Gift Shop", "Hearts of Darkness", "Burden of Dreams",
                     "Capturing the Friedmans", "Paradise Lost", "My Octopus Teacher", "Honeyland", "For Sama", "American Factory",
                     "Free Solo", "Three Identical Strangers", "Cartel Land", "Act of Killing", "Citizenfour",
                     "13th", "I Am Not Your Negro", "Icarus", "Summer of Soul", "Flee", "Fire of Love", "All That Breathes",
                     "March of the Penguins", "Winged Migration", "Blackfish", "The Cove", "Seaspiracy", "Social Dilemma", "Great Hack",
                     "Inside Job", "Enron", "The Corporation", "Food Inc.", "Fed Up", "Fast Food Nation", "Forks Over Knives", "Cowspiracy",
                     "Inconvenient Truth", "Chasing Ice", "Chasing Coral", "Touching the Void", "Dawn Wall", "Meru", "180 South", "20 Feet from Stardom", "Muscle Shoals", "Stop Making Sense", "Last Waltz", "Gimme Shelter"],
            series: ["Making a Murderer", "The Jinx", "Tiger King", "Wild Wild Country", "Don't F**k with Cats", "Abducted in Plain Sight",
                     "The Staircase", "Cheer", "Last Chance U", "Drive to Survive", "Full Swing", "Break Point", "Welcome to Wrexham",
                     "All or Nothing", "The Last Dance", "Hard Knocks", "Defiant Ones", "Hip-Hop Evolution", "Planet Earth", "Blue Planet",
                     "Frozen Planet", "Our Planet", "Night on Earth", "Dynasties", "Life in Colour", "Cosmos", "Mind of a Chef", "Chef's Table",
                     "Salt Fat Acid Heat", "Ugly Delicious", "Somebody Feed Phil", "Street Food", "Abstract", "Explained", "Dirty Money",
                     "The Dropout", "Fyre", "Tinder Swindler", "Evil Genius", "Wormwood", "Mommy Dead and Dearest", "I Love You Now Die",
                     "The Keepers", "Surviving R. Kelly", "Leaving Neverland", "Framing Britney", "Cocaine Cowboys", "Holy Hell", "Going Clear",
                     "Jesus Camp", "The Vow", "Heaven's Gate", "Waco", "Unsolved Mysteries", "Cold Case Files", "Forensic Files", "Dateline",
                     "48 Hours", "60 Minutes", "Frontline", "American Experience", "The Civil War", "Baseball", "Jazz", "Country Music",
                     "National Parks", "Prohibition", "The Roosevelts", "The Vietnam War", "Dust Bowl", "The Last Alaskans", "Our Universe", "The Planets"]),
    ]

    /// Wordplay add-ons that turn a stem into a pun.
    static let twists = [
        "Cheese", "Waffle", "Pasta", "Salad", "Sandwich", "Burrito", "Pickle", "Muffin", "Donut", "Noodle", "Taco", "Biscuit", "Pretzel",
        "Pancake", "Cookie", "Smoothie", "Casserole", "Pudding", "Nachos", "Lasagna", "Cupcake", "Dumpling", "Cereal", "Toast", "Gravy",
        "Drive", "Stick", "Bag", "Box", "Chair", "Lamp", "Sock", "Hat", "Boots", "Jacket", "Mug", "Spoon", "Fork", "Brush", "Comb",
        "Bucket", "Broom", "Ladder", "Hammock", "Backpack", "Umbrella", "Pillow", "Blanket", "Candle", "Clock", "Mirror", "Window",
        "Hour", "Night", "Day", "Club", "Party", "Rules", "Tapes", "Files", "Anonymous", "Academy", "Camp", "Island", "Hotel", "Diner",
        "Cafe", "Salon", "Bar", "Tour", "Games", "Wars", "Cup", "Show", "Time", "Zone", "Mode", "Pass", "Lane", "Street", "Road", "Park",
        "Town", "Land", "World", "Square", "Garden", "Market", "Studio", "Factory", "Express", "Special", "Edition", "Remix", "Redux",
        "Reloaded", "Unplugged", "Unleashed", "Unboxed", "Rewind", "Forever", "Again", "Too", "Jr.", "Deluxe", "Lite", "Supreme", "Anyway",
        "Next Door", "After Dark", "for Dummies", "in Space", "in Paris", "in Training", "on Ice", "on a Budget", "Gone Wrong", "Goes Viral",
        "Gets a Job", "Goes to Camp", "Takes Manhattan", "Wants a Cookie", "Needs a Nap", "at the Mall", "Day Off", "Weekend", "Christmas",
        "Summer", "Winter", "Spring", "Birthday", "Wedding", "Vacation", "Homework", "Lunch", "Breakfast", "Dinner", "Brunch", "Snack Time",
        "Squad", "Gang", "Crew", "Buddies", "Pals", "Bros", "Cousins", "Neighbors", "Roommates", "Uncle", "Aunt", "Grandpa", "Nana",
    ]

    /// Build one pun title for a genre. Never returns a stem on its own.
    static func make(genre: Genre, rng: inout SeededRNG) -> (name: String, kind: TitleKind)? {
        guard let pool = stems[genre] else { return nil }
        let wantMovie: Bool
        if pool.movies.isEmpty { wantMovie = false }
        else if pool.series.isEmpty { wantMovie = true }
        else { wantMovie = rng.chance(Double(pool.movies.count) / Double(pool.movies.count + pool.series.count)) }
        let list = wantMovie ? pool.movies : pool.series
        guard !list.isEmpty else { return nil }
        let stem = rng.pick(list)
        let other = rng.pick(list + (wantMovie ? pool.series : pool.movies))
        let twist = rng.pick(twists)
        let possessive = stem.hasSuffix("s") ? "\(stem)'" : "\(stem)'s"
        let article = stem.lowercased().hasPrefix("the ") ? "" : "The "
        let patterns = [
            "\(stem) \(twist)", "\(article)\(stem) \(twist)", "\(possessive) \(twist)", "\(stem) and the \(twist)",
            "\(twist) of the \(stem)", "Return of the \(stem) \(twist)", "\(stem) Meets \(other)", "\(stem) & \(other)",
            "\(stem): The \(twist) Years", "Anti-\(stem) \(twist)", "\(stem) 2: \(twist)", "Mr. \(stem)'s \(twist)",
            "Little \(stem)", "\(stem) Jr.", "Baby \(stem)", "Super \(stem) \(twist)", "\(twist) Wars: \(stem)",
        ]
        var name = rng.pick(patterns)
        if name.lowercased() == stem.lowercased() { name += " Too" }
        return (name, wantMovie ? .movie : .series)
    }
}
