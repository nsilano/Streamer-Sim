import Foundation

extension ParodyLibrary {
    /// More action parodies. Format: "S|Name" for a series, "M|Name" for a movie.
    static let moreAction = """
    M|Die Hard Drive
    M|Die Harder Drive
    M|Die Hard with a Voucher
    M|Live Free or Dye Hard
    M|Lethal Weapon Wars
    M|Lethal Wedding Planner
    M|Mad Max: Fury Dryer
    M|Mad Max Beyond Thunder Dome Pillow
    M|The Road Warrior Princess
    M|Terminator Judgment Day Trader
    M|Terminator Salvation Army
    M|The Matrix Reloaded Pistol
    M|The Matrix Revolutions Per Minute
    M|John Wick Candle
    M|John Wick: Chapter Eleven
    M|Nobody Knows Karate
    M|Taken Out for Lunch
    M|Taken 2 for 1
    M|Mission: Impossible Burger
    M|Mission: Impossible Ghost Protocol Droid
    M|Mission: Impossible Fall Out Boy
    M|Mission: Impossible Dead Reckoning Wall
    M|Skyfall Out
    M|Spectre Inspector
    M|Goldeneye Drops
    M|Tomorrow Never Dies Hard
    M|The World Is Not Enough Already
    M|Die Another Day Off
    M|Quantum of Solace Cup
    M|No Time to Die Cast
    M|Licence to Kill Bill
    M|The Spy Who Loved Mess
    M|From Russia with Love Handles
    M|Dr. No Thanks
    M|Thunderball Pit
    M|You Only Live Twice Over
    M|Live and Let Die Hard
    M|Moonraker Space
    M|Octopussy Willow
    M|A View to a Kilt
    M|The Living Daylights Saving
    M|Casino Royale Flush
    M|Fast & Furious Plans
    M|The Fast and the Furriest
    M|2 Fast 2 Furious Curious
    M|Tokyo Drift King
    M|Fast Five Finger Discount
    M|Furious 7-Eleven
    M|Fate of the Furiouser
    M|Hobbs & Shaw Mart
    M|F9 Keys
    M|Fast X Marks the Spot
    M|The Transporter Beam
    M|Crank Call
    M|Taken Over
    M|The Expendables Mini
    M|Rambo: First Blood Orange
    M|Rambo Last Blood Bank
    M|Rocky Horror
    M|Cobra Commander
    M|Cliffhanger Hanger
    M|Demolition Man Cave
    M|Judge Dredd Scott
    M|Total Recall Notice
    M|Predator Drone
    M|Commando Cody
    M|Kindergarten Cop Out
    M|True Lies Detector
    M|Last Action Hero Worship
    M|Eraser Head
    M|The 6th Day Off
    M|Jingle All the Way Home
    M|Twins Peaks
    M|Junior Varsity
    M|Raw Deal or No Deal
    M|Red Heat Wave
    M|Bloodsport Utility
    M|Kickboxer Shorts
    M|Universal Soldier Boy
    M|Timecop Shop
    M|Hard Target Practice
    M|Maximum Risk Tolerance
    M|Under Siege Engine
    M|Above the Law Firm
    M|Marked for Death Valley
    M|Out for Justice League
    M|Hard to Kill Time
    M|The Punisher Dog
    M|Daredevil Dog
    M|Elektra Complex
    M|Blade Runner Up
    M|Blade II: Bladier
    M|Underworld Awakening Call
    M|Resident Evil Retribution Tax
    M|Resident Evil Apocalypse Now Maybe
    M|Mortal Kombat Karaoke
    M|Street Fighter Pilot
    M|Tekken Heart
    M|Double Dragon Slayer
    M|Doom Scrolling
    M|Max Payne Killer
    M|Hitman Agent 47 Ronin
    M|Tomb Raider Cemetery
    M|Lara Croft Soft
    M|Prince of Persia Rug
    M|Uncharted Waters
    M|Assassin's Creed Cream
    M|Far Cry Wolf
    M|Warcraft Craft
    M|Monster Hunter Wanted
    M|Angry Birds of Prey
    M|Sonic the Hedgehog Fund
    M|Detective Pikachu Pika
    M|Super Mario Bros Brothers
    M|Pixels Per Inch
    M|Ready Player One Direction
    M|Tron: Legacy Pad
    M|The Fifth Element Fire
    M|Lucy in the Sky with Diamonds Are Forever
    M|Leon: The Professional Photographer
    M|Nikita's Dream
    M|Atomic Blonde Roast
    M|Haywire Fence
    M|Salt Water Taffy
    M|Wanted Poster
    M|Hancock Park
    M|Edge of Tomorrow Land
    M|Oblivion Hotel
    M|Top Gun Maverick Mavrick
    M|Top Gun Loaded
    M|Days of Thunder Dome
    M|Cocktail Hour
    M|Jack Reacher Around
    M|Knight and Day Care
    M|Collateral Damage Control
    M|Minority Report Card
    M|Vanilla Skyscraper
    M|Mission Impossible Fallout Shelter
    M|Rogue Nation Wide
    M|Skyscraper Sale
    M|Rampage Rental
    M|San Andreas Fault Line
    M|The Rock Climbing
    M|Jungle Cruise Control
    M|Black Adam Smith
    M|Fast Furious Fastest
    M|Baby Driver's Education
    M|Drive Angry Birds
    M|Gone in 60 Seconds Thought
    M|The Italian Job Offer
    M|Bullitt Train
    M|The French Connection Speed
    M|Speed Dial
    M|Speed 2: Cruise Control
    M|Point Break Dance
    M|Under Siege 2: Dark Territory
    M|Air Force One Way
    M|Con Air Fryer
    M|The Rock Star
    M|Face/Off Brand
    M|Broken Arrow Pointe
    M|Hard Rain Check
    M|Ronin Warrior Princess
    M|Heat Wave Two
    M|Ocean's Eleven Plus One
    M|Ocean's Twelve Days
    M|Ocean's Thirteen Colonies
    M|Now You See Me Now You Don't
    M|The Italian Heist Job
    M|Inside Man Bun
    M|The Town Hall
    M|The Dark Knight Rises and Shines
    M|Batman Begins Again
    M|Batman Returns Policy
    M|Batman Forever Young
    M|Batman & Robin Hood
    M|The Batman and Robin Williams
    M|Superman Returns Dept
    M|Man of Steel Wool
    M|Batman v Superman: Dawn of Justice League
    M|Wonder Woman 1984
    M|Aquaman and the Lost Kingdom Hearts
    M|Justice League Snyder Cut
    M|The Flash Gordon
    M|Shazam! Fury of the Gods
    M|Suicide Squad Car
    M|Birds of Prey Aviary
    M|Black Panther Wakanda Forever and a Day
    M|Iron Man Cave
    M|Captain America: Civil Service
    M|Thor: Ragnarok and Roll
    M|Thor: Love and Thunder Storm
    M|Avengers: Endgame Set
    M|Avengers: Infinity War of the Worlds
    M|Spider-Man: No Way Home Alone
    M|Spider-Man: Far From Home Alone
    M|Spider-Man: Into the Spider-Verse Chorus
    M|The Amazing Spider-Man's Aunt
    M|Guardians of the Galaxy Quest
    M|Ant-Man and the Wasp Spray
    M|Eternals Rebirth
    M|Shang-Chi and the Legend of the Ten Rings
    M|Black Widow Maker
    M|Deadpool Pool
    M|Logan Cabin
    M|X-Men: Days of Future Past Due
    M|X-Men: First Class Action
    M|Fantastic Four Seasons
    M|Venom Anti
    M|Morbius Strip
    M|Kick-Ass Kicker
    M|Kingsman: The Secret Service Charge
    M|Hellboy Girl
    M|Hancock Hall
    M|Chronicle of Riddick
    M|Pitch Black Tie
    M|Riddick Me This
    M|Alien: Resurrection Day
    M|Prometheus Unbound Ish
    M|Alien: Covenant Marriage
    M|Predators Ball
    M|Alien vs. Predator Prey
    M|Starship Troopers Camp
    M|RoboCop Roll
    M|Total Recall Check
    M|Elysium Fields
    M|Chappie Chap
    M|Equilibrium Roll
    M|I, Robot Vacuum
    M|Minority Majority Report
    M|Surrogates Mom
    M|Looper Loop
    M|Source Code Red
    M|Moon Pie
    M|Predestination Station
    M|Dredd Locks
    M|Pacific Rim Shot
    M|Godzilla King of the Monsters Inc
    M|Kong: Skull Island Time
    M|Cloverfield Lane
    M|10 Cloverfield Lane Closure
    M|A Quiet Place to Meet
    M|Edge of Darkness Moon
    M|The Raid: Redemption Center
    M|The Raid 2: Berandal Bear
    M|The Night Comes for Us Both
    M|Ong-Bak Boom
    M|Tom-Yum-Goong Show
    M|Fist of Legend Zelda
    M|Fist of Fury Road
    M|Enter the Dragon Fruit
    M|The Big Boss Baby
    M|Game of Death Star
    M|Way of the Dragon Slayer
    M|Drunken Master Class
    M|Police Story Time
    M|Project A Plus
    M|Rumble in the Bronx Zoo
    M|Rush Hour Glass
    M|Shanghai Noon Day
    M|The Karate Kid Kidding
    M|Karate Kid III Eyes
    M|Cobra Kai Katz
    M|Kung Fu Hustle Bustle
    M|Shaolin Soccer Mom
    M|Iron Monkey Business
    M|Once Upon a Time in China Town
    M|Hero Sandwich Shop
    M|House of Flying Daggers Cutlery
    M|Curse of the Golden Flower Pot
    M|Red Cliff Notes
    M|Wolf Warrior Princess
    M|Operation Red Sea Salt
    M|Ip Man Bun
    M|Ip Man 2: Electric Boogaloo
    M|Legend of the Fist Pump
    M|Flashpoint Break
    M|SPL: Sha Po Lang Syne
    M|Infernal Affairs Bureau
    M|Hard Boiled Egg
    M|The Killer Whale
    M|A Better Tomorrow Land
    M|Bullet in the Head Rest
    M|City on Fire Escape
    M|Fallen Angels in America
    M|Election Day
    M|Exiled Exile
    M|PTU Pay
    M|Mad Detective Story
    M|Drug War Games
    M|Breaking News Alert
    M|The Mission Statement
    M|Throw Down Payment
    M|A Hero Never Dies Hard
    M|Eastern Condors Nest
    M|Zu Warriors Cup
    M|A Chinese Ghost Story Time
    M|Swordsman II: The Sequel
    M|The Bride with White Hair Dye
    M|Dragon Inn Keeper
    M|A Touch of Zen Garden
    M|The One-Armed Swordsman's Tailor
    M|Come Drink with Me Too
    M|Master of the Flying Guillotine Block
    M|Five Deadly Venoms Bites
    M|36th Chamber of Shaolin Temple
    M|The Eight Diagram Pole Fighter Jet
    M|Seven Swords and Sandals
    M|Sword of Destiny's Child
    M|Crouching Tiger 2: Hidden Dragon Slayer
    M|Zatoichi's Cane
    M|Lone Wolf and Cub Scout
    M|Yojimbo Bear
    M|Seven Samurai Swords
    M|The Hidden Fortress Knox
    M|Ran Run
    M|Kagemusha Shadow
    M|Throne of Blood Drive
    M|Harakiri Stuff
    M|13 Assassins Creed
    M|Battle Royale with Cheese
    M|Ichi the Killer Whale
    M|Audition Tape
    M|Takeshi's Castle Bravo
    M|Hana-bi Fireworks
    M|Sonatine Neatine
    M|Violent Cop Out
    M|Outrage Beyond Tolerance
    M|Gozu Zoo
    M|Cure Alls
    M|Pulse Check
    M|Kairo Cairo
    M|Tokyo Gore Police Academy
    M|Versus Match
    M|Azumi's Tea
    M|Alita: Battle Angel Dust
    M|Ghost in the Shell Game
    M|Appleseed Orchard
    M|Akira's Bike
    M|Ninja Scroll Down
    M|Vampire Hunter D: Bloodlust Season
    M|Blood: The Last Vampire Bank
    M|Jin-Roh Wolf Brigade Army
    M|Patlabor Taylor
    M|Gunbuster Bluster
    M|Casshern Sins
    M|Gatchaman Gotcha
    M|Speed Racer Car
    M|Redline Reddit
    S|24 Hour Fitness
    S|Jack Ryan Gosling
    S|Reacher Grabber
    S|Jack Reacher: Never Go Back
    S|Hawaii Five-0 Hour
    S|Magnum P.I. Guy
    S|Miami Vice Squad
    S|The A-Team Spirit
    S|Knight Rider Mower
    S|Airwolf Pack
    S|The Fall Guy Ropes
    S|MacGyver Cut
    S|Walker, Texas Ranger Danger
    S|Renegade Rules
    S|Hercules: The Legendary Journeys End
    S|Xena: Warrior Princess Bride
    S|Highlander: The Series Finale
    S|Stargate SG-1000
    S|Stargate Atlantis Records
    S|Stargate Universe Today
    S|Farscape Gape
    S|Babylon 5 O'Clock
    S|Andromeda Strain
    S|Space: Above and Beyond Belief
    S|Earth: Final Conflict Resolution
    S|The X-Files Cabinet
    S|Millennium Falcon
    S|Alias Smith and Jones
    S|La Femme Nikita Dos
    S|Burn Notice Board
    S|Chuck Roast
    S|Covert Affairs Of State
    S|Leverage Buyout
    S|White Collar Dryer
    S|Strike Back Door
    S|Spooks and Ghouls
    S|MI-5 Alive
    S|Hustle Bustle
    S|Spiral Stairs
    S|The Bourne Supremacy Sale
    S|The Bourne Identity Theft
    S|The Bourne Ultimatum Day
    S|The Bourne Legacy Admission
    S|Jason Bourne Identity Again
    S|Treadstone Hill
    S|The Americans Abroad
    S|The Night Agent Orange
    S|The Terminal List Maker
    S|Tom Clancy's Without Remorse Code
    S|Slow Horses Play
    S|Killing Eve's Day
    S|Barry Bluejeans
    S|Banshee Wail
    S|Strike Force Five
    S|Spartacus: Gods of the Gladiator Arena
    S|Vikings: Valhalla Mall
    S|Warrior Nun Run
    S|The Last Kingdom Hearts
    S|Beforeigners Abroad
    S|The Rig Up
    S|Britannia Biscuits
    S|Troy: Fall of a City Block
    S|Sons of Anarchy Tea
    S|Mayans M.C. Hammer
    S|Hell on Wheels Chair
    S|Banshee Cheese
    S|The Shield Wall
    S|The Unit Circle
    S|The Wire Cutter
    S|24: Legacy Lawns
    S|Dirk Gently's Holistic Detective Agency Fee
    S|Taken: The Series Finale
    S|The Punisher's Pizza
    S|Jessica Jones Soda
    S|Luke Cage Match
    S|Iron Fist Pump
    S|The Defenders Union
    S|Agents of S.H.I.E.L.D. Charm
    S|Agent Carter's Cab
    S|Cloak & Dagger Dance
    S|Runaways Home
    S|Inhumans Rights
    S|Moon Knight Rider
    S|Loki Lockers
    S|Hawkeye Exam
    S|WandaVision Test
    S|The Falcon and the Winter Soldier of Fortune
    S|She-Hulk Attorney at Law School
    S|Ms. Marvel Universe
    S|Daredevil: Born Again Christian
    S|Echo Chamber
    S|Secret Invasion of Privacy
    S|The Mandalorian Mandate
    S|The Book of Boba Fett Fetch
    S|Obi-Wan Kenobi Bi
    S|Andor Door
    S|Ahsoka Tano Tan
    S|The Acolyte Alley
    S|Skeleton Crew Cut
    S|The Clone Wars Chest
    S|Star Wars Rebels Without a Cause
    S|The Bad Batch Of Cookies
    S|Visions Quest
    S|Resident Alien Nation
    S|Orphan Black Mirror
    S|Killjoys Gloves
    S|Dark Matter Of Fact
    S|Lost in Space Camp
    S|The 100 Meter Dash
    S|Defiance County
    S|Falling Skies the Limit
    S|Colony Collapse
    S|Revolution Number Nine
    S|The Event Horizon
    S|V for Vacation
    S|FlashForward Pass
    S|Heroes Reborn Again
    S|Jericho Beach
    S|Threshold Guardian
    S|Surface Tension
    S|Invasion of the Body Scrubbers
    S|Sliders Home
    S|Quantum Leap of Faith
    S|Seaquest DSV Dives
    S|Star Trek: Voyager of the Seas
    S|Star Trek: Enterprise Zone
    S|Star Trek: Lower Decks of Cards
    S|Star Trek: Strange New Whirled
    S|Star Trek: Prodigy Pro
    S|Star Trek: The Next Generation Gap
    S|Star Trek: The Original Series Pilot
    S|Doctor Who Dat
    S|Torchwood Chipper
    S|Class Act
    S|Sapphire & Steel Beam
    S|Blake's 7-Eleven
    S|Red Dwarf Mine
    S|Hitchhiker's Guide to the Galaxy Brain
    S|Thunderbirds Are Go-Go
    S|Captain Scarlet Letter
    S|Space: 1999 Problems
    S|UFO Sighting
    S|The Prisoner Number Six
    S|The Avengers Assemble Line
    S|The Saint Paul
    S|The Persuaders Rule
    S|The Professionals Union
    S|The Sweeney Tod
    S|Minder Binder
    S|Bergerac Cherries
    S|Taggart Tagline
    S|Rebus Puzzle
    S|Inspector Morse Code
    S|Lewis Carroll
    S|Endeavour Day
    S|A Touch of Frost Bite
    S|Midsomer Murders Most Foul
    S|Vera Wang
    S|Shetland Pony
    S|Silent Witness Stand
    S|Waking the Dead Sea
    S|Spooks National Security
    """
}
