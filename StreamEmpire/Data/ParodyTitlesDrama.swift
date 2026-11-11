import Foundation

extension ParodyLibrary {
    /// More drama parodies. Format: "S|Name" for a series, "M|Name" for a movie.
    static let moreDrama = """
    S|Succession Planning
    S|The Crown Jewels
    S|Mad Women
    S|Boardwalk Empire State
    S|The Sopranos Quartet
    S|Deadwood Floor
    S|True Detective Story
    S|Big Little Fibs
    S|The Night Of The Long Shifts
    S|Mare of Eastwick
    S|Mindhunter Gatherer
    S|Ozark Plateau
    S|House of Cardigans
    S|The Affairs
    S|This Is Us Too
    S|Parenthood Rules
    S|Friday Night Plights
    S|Dawson's Creek Bed
    S|One Tree Hillside
    S|The O.K.
    S|Gossip Boy
    S|Pretty Little Fibbers
    S|Riverdale Lane
    S|Desperate Househusbands
    S|Grey's Anatomy Lesson
    S|ER-Rand
    S|Chicago Fire Drill
    S|Law & Order: Special Victims of Trends
    S|CSI: Cleveland
    S|NCIS: New Orleanz
    S|Criminal Minds Your Business
    S|Bones and All Night
    S|Castle on the Hill
    S|The Mentalist's Apprentice
    S|Lie to Me Gently
    S|Suits and Ties
    S|The Good Wife Beater
    S|How to Get Away with Parking
    S|Scandalous Behavior
    S|Homeland Security Guard
    S|24 Hours Later
    S|Prison Breakfast
    S|Lost and Found Footage
    S|Heroes in a Half Shell
    S|Fringe Benefits
    S|The 4400 Calories
    S|Battlestar Galaxia
    S|The Walking Dread
    S|Fear the Walking Fred
    S|Z Nation State
    S|The Leftovers Special
    S|Under the Domino
    S|Revenge of the Nerdy
    S|Nashville Hot Chicken
    S|Empire Records Division
    S|Power Hour
    S|Queen Sugarcoat
    S|Greenleaf Blower
    S|The Haves and the Have Yachts
    S|Dynasty Dynamo
    S|Dallas Cowboys and Daughters
    S|Knots Landing Page
    S|Falcon Crust
    S|Melrose Place Setting
    S|Beverly Hills 90210 Cal
    S|Models Inc Ink
    S|Party of Five Guys
    S|Felicity Huffman Puffman
    S|Roswell That Ends Well
    S|Smallville Voice
    S|Supernatural Selection
    S|Charmed and Dangerous
    S|Buffy the Vampire Slayer of Dragons
    S|Angel Food
    S|Vampire Diaries of a Wimpy Kid
    S|True Blood Orange
    S|The Originals Only
    S|Legacies of the Fall
    S|Teen Wolfpack
    S|Shadowhunters Cap
    S|The Magicians Hat
    S|Lucifer's Morning Star
    S|Constantine Cantina
    S|Gotham Knights Templar
    S|Arrowhead
    S|The Flash Drive
    S|Supergirl Scouts
    S|Legends of Tomorrowland
    S|Black Lightning Rod
    S|Titans Rule
    S|Doom Patrol Car
    S|Stargirl Power
    S|Peacemaker Faker
    S|Watchmen's Wristwatch
    S|Lovecraft Country Club
    S|The Leftovers Fridge
    S|Westworld Series
    S|Dark Matters Most
    S|Dark Knight Shift
    S|Dark Angelfish
    S|1899 and Counting
    S|Babylon Berlin Wall
    S|Das Boot Camp
    S|Deutschland 82.5
    S|Bad Banks
    S|Biohackers Union
    S|Tribes of Europa Minor
    S|Money Heist Pass
    S|Elite Eight
    S|Cable Girls Next Door
    S|The Telegraph Girls
    S|Vis a Vis Versa
    S|Locked Up Abroad Again
    S|Narcos: Mexico City Slickers
    S|Narcos Anonymous
    S|Griselda Greenhouse
    S|Pablo's Escobar Hair Pin
    S|Ozark Mountain Daredevil
    S|Bloodline Drive
    S|Sneaky Pete's Dragon
    S|Better Call Soul Food
    S|El Camino Real
    S|Breaking Better Call Soul
    S|The Wire Hanger
    S|Treme Dousness
    S|The Deuce Is Wild
    S|Show Me a Hero Sandwich
    S|Generation Kills Time
    S|Band of Brotherhood
    S|The Pacific Ocean Floor
    S|Chernobyl Hotel
    S|Mare of Easttown Crier
    S|Sharp Objects in Mirror
    S|Big Little Fries
    S|Gone Girlfriend
    S|The Undoing Redo
    S|The Night Manager's Special
    S|The Little Drummer Boys
    S|The Honourable Woman Beating
    S|Line of Duty Free
    S|Bodyguard Rail
    S|Happy Valley Girl
    S|Broadchurch Pew
    S|Luther Vandross
    S|Peaky Blinders and Blunders
    S|Gentleman Jack Frost
    S|Sanditon Rooms
    S|Bridgerton Bridge Loan
    S|Outlander Inlander
    S|Poldark Horse
    S|Victoria Falls
    S|The Tudors and Co.
    S|The Borgias Marmalade
    S|Rome Wasn't Built in a Day
    S|Spartacus Blood and Sandwiches
    S|Vikings Helmets
    S|The Last Kingdom Come
    S|Black Sails Away
    S|Game of Thrones and Roses
    S|House of the Dragonfruit
    S|Rings of Power Hour
    S|The Wheel of Time Zone
    S|Shadow and Bone Marrow
    S|The Witcher Hunt
    S|Cursed Handbag
    S|Merlin Monroe
    S|Camelot Crescent
    S|Atlantis Records
    S|Once Upon a Time Machine
    S|Grimm Reaper
    S|Sleepy Hollow Log
    S|Salem Witch Trials Edition
    S|American Gods and Monsters
    S|Penny Dreadful Moments
    S|Hannibal Lecter's Cookbook
    S|Bates Motel 6
    S|Dexter's Lab Report
    S|Dexter Morgan Freeman
    S|Breaking Bread
    S|Mr. Robot Vacuum
    S|Halt and Catch Flame
    S|Silicon Valley Girl
    S|Industry Standard
    S|Margin Call Waiting
    S|The Newsroom Service
    S|The West Wing Chun
    S|House of Lords of Dogtown
    S|Scandal in the Cloakroom
    S|Designated Survivor Guilt
    S|Madam Secretary of Snacks
    S|Commander in Chiefs
    S|Political Animals
    S|Boss Baby Mama
    S|Succession Bonus
    S|Yellowstone Park
    S|1883 Reasons
    S|Longmire Hair
    S|Justified Homicide
    S|Hell on Wheels of Cheese
    S|Westworld War Z
    S|Deadwood Chipper
    S|Godless Heathens
    S|The Son Rises
    S|Frontier Justice League
    S|Taboo Tuesday
    S|Peaky Fookin Blinders
    S|Knightfall Out Boy
    S|Marco Polo Shirt
    S|Altered Carbon Copy
    S|Love Death and Robot Dogs
    S|Foundation Garments
    S|The Expanse Pants
    S|Battlestar Galactic Gladiator
    S|Firefly Lane Closure
    S|Star Trek: Discovery Channel
    S|Star Trek: Picard Cut
    S|Star Trek: Deep Space Mine
    S|The Orville Redenbacher
    S|Raised by Wolves and Bears
    S|See Saw
    S|Silo Door
    S|Severance Pay
    S|Lodge 49ers
    S|Station Eleven Pm
    S|The Last of Us Two
    S|Chernobyl Chicken
    S|Yellowjackets Game
    S|Euphoria Pills
    S|Normal People Skills
    S|Sex Education Reform
    S|Skins and Bones
    S|Misfits and Toys
    S|Shameless Plug
    S|Gavin & Stacey's Mom
    S|The Bridge Over Troubled Waters
    S|The Killing Joke
    S|Forbrydelsen Fry
    S|Borgen Bagel
    S|Wallander's Wallet
    S|Bron Sauce
    S|Sandhamn Murders Inc
    S|Lilyhammer Time
    S|Occupied Territories
    S|Ragnarok and Roll
    S|Dark Desire Lines
    S|Rita's Rehab
    S|Equinox Edge
    S|The Rain Man Returns
    S|Prisoners of War Chest
    S|Homeland Insecurity
    S|Tehran Taxi Driver
    S|Shtisel Fisel
    S|Unorthodox Ones
    S|Call My Agent Smith
    S|Lupin Pasta
    S|Marseille Soap
    S|The Bureau of Weird Legends
    S|Les Revenants Reunion
    S|Engrenages Gear Shift
    S|Spiral Staircase
    S|Gomorrah Gone
    S|Suburra Burra
    S|Medici Ball
    S|My Brilliant Frenemy
    S|Il Miracolo Worker
    S|Trust Fall Guy
    S|The Young Pope's Hat
    S|The New Pope Mobile
    S|Pachinko Machine
    S|Squid Game Show
    S|Kingdom Come Together
    S|All of Us Are Dead Weight
    S|Sweet Home Alone Together
    S|Hellbound Heights
    S|Crash Landing on Youtube
    S|Descendants of the Sun Roof
    S|Goblin Shark
    S|Hotel del Luna Park
    S|Itaewon Class Act
    S|Vincenzo Cassano
    S|My Mister Rogers
    S|Reply 1988 Olympics
    S|Misaeng Incomplete Life
    S|Signal Booster
    S|Stranger Danger
    S|Mother Superior
    S|Secret Forest Fire
    S|Sky Castle in the Air
    S|The King: Eternal Monarchy Hour
    S|Extraordinary Attorney Wolf
    S|The Glory Days
    S|Business Proposal Writer
    S|Twenty-Five Twenty-One Pilots
    S|Our Beloved Summer Camp
    S|Hometown Cha-Cha-Cha-Chaos
    S|Mr. Sunshine State
    S|Healer Bar
    S|Sandglass Half Full
    S|Autumn in My Heart Attack
    S|Boys Over Flowers Shop
    S|Coffee Prince Charming
    S|My Love from the Star Wars
    S|Moon Lovers: Scarlet Heart Surgery
    S|Jewel in the Palace Pals
    S|Ruler of Your Own World
    S|The Untamed Beasts
    S|Nirvana in Fire Drill
    S|Eternal Love of Dream Catchers
    S|Story of Yanxi Palace Party
    S|Love O2O Two
    S|Meteor Garden Gnome
    S|Mr. Bachelor Pad
    S|Sacred Games Night
    S|Delhi Crime Scene
    S|Mirzapur Pur
    S|Panchayat Meeting
    S|Made in Heaven Sent
    S|Paatal Lok Down
    S|The Family Man Cave
    S|Scam 1992 Edition
    S|Special Ops Specialist
    S|Criminal Justice League
    S|Aarya's Ark
    S|Rocket Boys Club
    S|Kota Factory Reset
    S|Bandish Bandits
    S|Four More Shots Please
    S|Jamtara Sabka Number Ayega
    S|Asur: Welcome to Your Dark Side
    S|Inside Edge Case
    S|Breathe: Into the Shadows
    S|Little Things Mean a Lot
    S|The Great Indian Murder Mystery
    S|Kaun Banega Millionaire Next Door
    S|Taj Mahal 1989 Remake
    S|Bombay Begums Rule
    S|Leila's Library
    S|Ghoul Gone Bad
    S|Betaal Waaal
    S|Tabbar Down
    S|Gullak Jar
    S|Dahaad Dad
    S|Farzi Fez
    M|The Godfather Figure
    M|Citizen Cane
    M|Casablanca Blanca
    M|Gone with the Wind Chime
    M|Schindler's Shopping List
    M|The Shawshank Redecoration
    M|Forrest Gump Shrimp
    M|The Green Mile High
    M|Saving Private Brian
    M|Apocalypse Wow
    M|Full Metal Jacket Potato
    M|Platoon Leader Board
    M|Born on the Fourth of Jukebox
    M|Good Will Hunting Trip
    M|Dead Poets Society Page
    M|Rain Man's Umbrella
    M|Philadelphia Cream Cheese
    M|A Few Good Menus
    M|The Social Network Cable
    M|Moneyball Pit
    M|The Big Short Stack
    M|Margin Call of Duty
    M|Wall Street Journal
    M|The Wolf of Wall Mart
    M|American Hustle Bustle
    M|Argo Fuel Yourself
    M|Spotlight on Me
    M|Birdman or Unexpected Virtue of Chickens
    M|12 Years a Slacker
    M|Moonlight Savings Time
    M|The Shape of Water Balloons
    M|Three Billboards Outside Ebbing Out
    M|Nomadland Rover
    M|Parasite Remover
    M|Joker's Wild
    M|Roma Tomatoes
    M|The Irishman Cometh
    M|Marriage Story Time
    M|Little Women Who Lunch
    M|Ford v Ferrari Roast
    M|1917 and Counting
    M|Dunkirk Dairy
    M|Darkest Hour Glass
    M|The King's Speech Therapy
    M|The Imitation Game Night
    M|The Theory of Everything Bagel
    M|A Beautiful Mind Palace
    M|Gladiator Sandals
    M|Braveheart Burn
    M|Titanic Fridge
    M|Avatar: The Way of Water Cooler
    M|Dances with Wolves of Wall Street
    M|The Last Samurai Sword Swallower
    M|Seven Samurai Sudoku
    M|Rashomon Said What
    M|Tokyo Story Hour
    M|Spirited Away Message
    M|Drive My Car Wash
    M|Burning Down the House
    M|Oldboy Scouts
    M|Decision to Leave a Voicemail
    M|The Handmaiden's Tale of Two Cities
    M|Memories of Murder Mystery
    M|Mother Knows Best
    M|Minari Garden
    M|Burning Man
    M|Pather Panchali Dim Sum
    M|Lagaan Aid
    M|Dilwale Dulhania Le Jayenge Ice
    M|Mughal-E-Azam Ruling
    M|Mother Indians
    M|Sholay Sweater
    M|Devdas Dash
    M|Gangs of Wasseypur Pool
    M|3 Idiots Gambit
    M|Taare Zameen Par Fait
    M|Dangal Dangle
    M|Pink Floyd Lawn Flamingos
    M|Article 15 Minutes
    M|Gully Boy Band
    M|Queen's Gambit Accepted
    M|English Patient Zero
    M|Atonement Prayer
    M|Pride and Prejudice and Zombies Party
    M|Sense and Sensibility Training
    M|Emma. Thompson Twin
    M|Jane Eyre Roll
    M|Wuthering Frights
    M|Great Expectations Management
    M|Oliver Twist Tie
    M|David Copperfield Magic
    M|A Tale of Two Cities Skylines
    M|Les Miserables Misery Loves Company
    M|The Phantom of the Opera House
    M|Cyrano de Bergerac Stakeout
    M|Romeo and Juliet Rose
    M|Hamlet's Cigar
    M|Macbeth Mac
    M|Othello Stencil
    M|King Lear Jet
    M|A Midsummer Night's Dream Catcher
    M|The Tempest in a Teapot
    M|Much Ado About Muffins
    M|Twelfth Night Shift
    M|Julius Caesar Salad
    M|Antony and Cleopatra's Needle
    M|Henry V8
    M|Richard III-Ahead
    M|The Merchant of Venice Beach
    M|Titus Andronicus Bay
    M|Coriolanus Bar
    M|Timon of Athens Rules
    M|Pericles Of Persia
    M|Cymbeline and Co
    M|Troilus and Cressida Cream
    M|Measure for Measure Twice
    M|All's Well That Ends Well Done
    M|The Winter's Tale of Two Seasons
    M|The Taming of the Shrew Mouse
    M|The Two Gentlemen of Verona Pizza
    M|Love's Labour's Lost and Found
    M|Hamlet 2: Electric Boogaloo
    M|Ophelia's Floating Bakery
    M|Rosencrantz and Guildenstern Are Dead Tired
    M|West Side Story Time
    M|Rent-A-Car
    M|Chicago Pizza
    M|Cabaret Bar
    M|The Greatest Showman Show
    M|Les Mis-Understood
    M|Sunshine on Leith Rail
    M|Rocketman's Rocket
    M|Bohemian Rhapsody in Blue Cheese
    M|Walk the Line Dance
    M|Coal Miner's Daughter-in-Law
    M|Straight Outta Compton Cartridge
    M|Selma Blouse
    M|Glory Hole in One
    M|Lincoln Logs
    M|Gettysburg Address Book
    M|The Birth of a Nation State
    M|Amistad Boat
    M|Django Unchained Melody
    M|The Color Purple Rain
    M|Fences and Neighbors
    M|Hidden Figures of Speech
    M|The Help Desk
    M|The Blind Side Dish
    M|Remember the Titans Tennis
    M|Coach Carter Wash
    M|Friday Night Lights Out
    M|Hoosiers Hoosier
    M|Rudy's Rental
    M|Miracle on Ice Cream
    M|Rocky Road
    M|Raging Bull Market
    M|The Fighter's Pilot
    M|Million Dollar Baby Monitor
    M|Cinderella Man Cave
    M|Creed Philips
    M|Southpaw Station
    M|Warrior Queen Bee
    M|The Wrestler's Union
    M|Black Swan Lake
    M|Whiplash Injury
    M|Amadeus Radio
    M|Shine Bright Like a Lamp
    M|Tár and Feathered
    M|Birdman Flu
    M|Boyhood Friend
    M|Before Sunrise Sunset Boulevard
    M|Lost in Translation Error
    M|Her Majesty's Secret Service Dog
    M|Eternal Sunshine of the Spotless Sponge
    M|Being John Malkovich Bell
    M|Adaptation Station
    M|Synecdoche New York Strip
    M|The Truman Shown
    M|Fight Club Sandwich
    M|Se7en Eleven
    M|Zodiac Sign Here
    M|Gone Baby Gone Fishing
    M|Mystic River Phoenix
    M|The Prestige Pricing
    M|Memento Moriarty
    M|Inception Point
    M|Interstellar Overdrive
    M|Oppenheimer Hammer
    M|The Departed Flights
    M|Heat Wave
    M|Casino Royale with Cheese
    M|Goodfellas and Gals
    M|Scarface Wash
    M|Carlito's Way Out
    M|Donnie Brasco Bag
    M|American Gangster Rap
    M|Blow Dryer
    M|Traffic Jam Session
    M|Sicario Pizzeria
    M|Prisoners of Zenda
    M|Nightcrawler Space
    M|Drive Thru
    M|The Neon Demon Slayer
    M|Only God Forgives and Forgets
    M|Blue Valentine's Day
    M|Revolutionary Road Trip
    M|Brokeback Mountain Dew
    M|Carol Brady
    M|Call Me by Your Name Tag
    M|Portrait of a Lady on Fire Sale
    M|Moonrise Kingdom Come
    M|The Grand Budapest Hotel Chocolat
    M|The Royal Tenenbaums Tent
    M|Rushmore Ash
    M|The Life Aquatic with Steve Zissou-Zing
    M|Fantastic Mr. Fox Trot
    M|Asteroid City Limits
    M|Isle of Dogs Barking
    M|The French Dispatch Rider
    M|Lady Bird Brain
    M|Frances Haha
    M|Little Miss Sunshine Day
    M|Juno Beach
    M|Napoleon Dynamite Stick
    M|Superbad Joke
    M|Booksmart Alec
    M|Eighth Grade Math
    M|Mid90s Hits
    M|Lady Macbeth Inc
    M|Gosford Park Place
    M|Remains of the Day Spa
    M|Howards End Table
    M|A Room with a View Master
    M|Brideshead Revisited Twice
    M|Atonement Plan
    M|The Reader's Digest
    M|The Pianist's Piano Bar
    M|Life Is Beautiful Mind
    M|Cinema Paradiso Bar
    M|La Dolce Vita Coco
    M|8½ Inch Heels
    M|The Bicycle Thief Lane
    M|Bicycle Dreams
    M|Amélie Poulain Paper
    M|The Intouchables Cabinet
    M|Das Leben der Anderen Brothers
    M|Good Bye Lenin Statue
    M|Run Lola Run Rabbit
    M|Pan's Labyrinth Maze
    M|The Devil's Backbone Marrow
    M|The Orphanage Home
    M|Y Tu Mamá También Mama
    M|Amores Perros Park
    M|Cidade de Deus Ex Machina
    M|Central do Brasil Station
    M|Cinema Novo Newer
    M|Argentina's Secret in Their Eyes
    M|Nine Queens and a Joker
    M|A Fantastic Woman Wonder
    M|Roma Holiday
    M|Cold War Games
    M|Ida Lupino
    M|Leviathan Whale
    M|Loveless Fridays
    M|Andrei Rublev Cube
    M|Solaris Panels
    M|Stalker Alert
    M|Battleship Potemkin Village
    M|Come and See What Happens
    M|The Cranes Are Flying Cars
    M|Burnt by the Sun Cream
    M|Mongol Hordes
    M|Hero Sandwich
    M|House of Flying Daggers Ed
    M|Crouching Tiger Hidden Dragon Fruit
    M|In the Mood for Love Handles
    M|Chungking Express Lane
    M|2046 Odyssey
    M|Farewell My Concubine Bridge
    M|Raise the Red Lantern Festival
    M|A City of Sadness Park
    M|Eat Drink Man Woman Up
    M|Still Life Class
    M|Platform Nine and Three Quarters Sole
    M|Shoplifters Wanted
    M|Nobody Knows Your Name
    M|After Life Insurance
    M|Departures Gate
    M|Still Walking Dead
    M|Sweet Bean Paste Tray
    M|The Third Murder Mystery
    M|Our Little Sister Wives
    M|Like Father Like Son Shine
    M|Distance Learning
    M|Maborosi Dreamer
    M|Late Spring Cleaning
    M|An Autumn Afternoon Nap
    M|Floating Weeds Whacker
    M|Good Morning Vietnam Hour
    M|The Quiet American Dream
    M|The Lover's Lane
    M|Indochine Chine
    M|Platoon Of the Dead
    M|Hotel Rwandan Rice
    M|The Constant Gardener's Glove
    M|Blood Diamond Ring
    M|Last King of Scotland Yard
    M|Invictus Maneuvers
    M|District Nine to Five
    M|Tsotsi Soup
    M|Cry Freedom Fries
    M|Beasts of No Nation Building
    M|Timbuktu Two
    M|Black Girl Magic
    M|Xala Girl
    M|Yeelen Light
    M|Moolaadé Cheese
    M|Rafiki Bike
    M|Hotel Mumbai Mix
    M|Slumdog Millionaire Matchmaker
    M|Lion King Prawn
    M|The Lunchbox Meal
    M|Salaam Bombay Beach
    M|Monsoon Wedding Planner
    M|Mississippi Masala Chai
    M|The Namesake Day
    M|Life of Pi Day
    M|Water Park
    M|Earth Day
    M|Fire Drill
    M|Midnight's Children's Hospital
    M|The White Tiger Woods
    M|The Reluctant Fundamentalist Fund
    M|Kabul Express Lane
    M|The Kite Runner-Up
    M|A Thousand Splendid Suns Screen
    M|Zero Dark Thirty-One Flavors
    M|The Hurt Locker Room
    M|Jarhead Cheese
    M|Black Hawk Down Jacket
    M|American Sniper Bite
    M|Lone Survivor Tour
    M|Fury Road Rage
    M|Letters from Iwo Jima Slide
    M|Flags of Our Fathers Day
    M|Hacksaw Ridge Runner
    M|Dunkirk Spirit Week
    M|Atonement Day
    M|Sophie's Choice Cuts
    M|The Pianist's Choice
    M|Jojo Rabbit Hole
    M|The Boy in the Striped Pajamas Party
    M|Life Is Beautiful Day
    M|The Zone of Interest Rates
    M|Son of Saul Goodman
    M|Defiance Policy
    M|Valkyrie Cruise
    M|Downfall Foot
    M|Sophie Scholl Days
    M|Munich Beer Fest
    M|Schindler's Lift
    M|Judgment at Nuremberg Sausage
    M|Inglourious Basterds Beginners
    M|The Reader's Corner
    M|The Counterfeiters' Ball
    M|Das Experiment Station
    M|Wings of Desire Lines
    M|Paris Texas Hold'em
    M|Fitzcarraldo Aldo
    M|Aguirre Wrath of the Dryer
    M|Nosferatu Matches
    M|Metropolis Water Works
    M|M the Rhyming Kind
    M|The Cabinet of Dr. Caligari's Closet
    M|The Last Laugh Track
    M|Sunrise Service
    M|City Lights Out
    M|Modern Times Square
    M|The Gold Rush Hour
    M|The Great Dictator Pen
    M|The Kid Cudi
    M|Safety Last Minute
    M|The General's Gaze
    M|Sherlock Jr. High
    M|Steamboat Bill Jr. High
    M|The Passion of Joan of Arc Light
    M|Battleship Potemkin Ship
    M|Intolerance Test
    M|Birth of a Nation Wide
    M|Greed Is Good Enough
    M|Sunset Boulevard Stop
    M|Double Indemnity Plan
    M|The Maltese Falcon Heavy
    M|Chinatown Hall
    M|Vertigo Pillow
    M|Rear Window Washer
    M|Psycho Therapy
    M|North by Northwest Passage
    M|Rebecca's Dream Boat
    M|Rope Burn
    M|Notorious Big Dog
    M|Strangers on a Train Platform
    M|Dial M for Mortgage
    M|Marnie Be Mine
    M|The Birds and the Bees Knees
    M|Frenzy Friday
    M|Topaz Tuesday
    M|Family Plot Twist
    M|The Wrong Man Cave
    M|Shadow of a Doubt Fire
    M|Suspicion Box
    M|Lifeboat Drill
    M|Spellbound Book
    M|Saboteur Station
    M|Stage Fright Night
    M|I Confess Booth
    M|To Catch a Thief of Hearts
    M|The Trouble with Harry Potter
    M|The Man Who Knew Too Much Information
    """
}
