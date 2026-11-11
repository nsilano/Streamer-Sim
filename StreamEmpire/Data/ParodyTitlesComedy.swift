import Foundation

extension ParodyLibrary {
    /// More comedy parodies. Format: "S|Name" for a series, "M|Name" for a movie.
    static let moreComedy = """
    S|The Office Hours
    S|Parks and Recreational Vehicles
    S|Brooklyn Nine-Nine Lives
    S|Community Chest
    S|30 Rocks
    S|Arrested Development Hell
    S|It's Always Sunny in Philadelphia Cream
    S|Curb Your Enthusiasm Gap
    S|Seinfeld Soup
    S|Frasier Crane Operator
    S|Cheers to That
    S|Friends with Benefits Package
    S|How I Met Your Mother Tongue
    S|The Big Bang Theory of Everything Else
    S|Young Sheldon Cooper Union
    S|Two and a Half Menus
    S|Modern Family Feud
    S|The Middle Child
    S|Black-ish Sheep
    S|Fresh Off the Boat Shoes
    S|Everybody Hates Chris Brown
    S|My Name Is Earl Grey
    S|Malcolm in the Middle Seat
    S|That '70s Showtime
    S|That '90s Showtime
    S|Home Improvement Plan
    S|Full House Party
    S|Fuller House Arrest
    S|Family Matters Most
    S|Step by Step Dancing
    S|Saved by the Bell Jar
    S|Boy Meets World Series
    S|Girl Meets Whirled
    S|Sabrina the Teenage Witch Hunt
    S|Living Single Ladies
    S|Roseanne Barr None
    S|The Conners Connection
    S|The Golden Girls Gone Wild
    S|Designing Women Rule
    S|Murphy Brown Bag
    S|Mary Tyler Moore Show Me
    S|I Love Lucy Goosey
    S|The Honeymooners Suite
    S|M*A*S*H Potatoes
    S|All in the Family Tree
    S|The Jeffersons Gone Moving On Up
    S|Good Times Square
    S|Taxi Driver Training
    S|Happy Days Inn
    S|Laverne & Shirley Temple
    S|Mork & Mindy Games
    S|Three's Company Picnic
    S|Newhart's Inn
    S|Night Court Jester
    S|Wings Chicken
    S|Mad About Your Mother
    S|NewsRadio Silence
    S|Spin City Slickers
    S|Scrubs and Mops
    S|Cougar Town Hall
    S|Happy Endings Soon
    S|Don't Trust the B---- in Apartment 23
    S|New Girl Gone Wild
    S|Superstore Wars
    S|The Good Place Setting
    S|Schitt's Creek Bed
    S|Kim's Convenience Store Hours
    S|Letterkenny Kenny
    S|Trailer Park Boys Club
    S|Corner Gas Station
    S|Rick and Morty and Me
    S|BoJack Horseman Mask
    S|Archer's Bow
    S|Bob's Burgers King
    S|The Simpsons Hold the Wall
    S|Family Guy Fawkes
    S|American Dad Joke
    S|Futurama Llama
    S|King of the Hill Billy
    S|South Park Ranger
    S|Beavis and Butt-Head Rest
    S|Daria Morgendorffer
    S|Big Mouth Breather
    S|Harvey Birdman Attorney at Lawn
    S|Aqua Teen Hunger Strike
    S|The Venture Bros. Grimm
    S|Metalocalypse Now
    S|Robot Chicken Little
    S|Rick and Mortgage
    S|Solar Opposites Attract
    S|Final Space Cadet
    S|Disenchantment Ring
    S|Paradise PD Dog
    S|Tuca & Bertie Bott's
    S|Undone Zipper
    S|Mythic Quest for Fire
    S|Ted Lasso Tie
    S|Only Murders in the Building Blocks
    S|Abbott Elementary Teacher
    S|Hacks and Slashers
    S|Barry Manilow
    S|Atlanta Falcons Nest
    S|Insecure Password
    S|Girls Trip Advisor
    S|Broad City Limits
    S|Workaholics Anonymous
    S|Parks & Wreck
    S|Silicon Valley of the Dolls
    S|Veep Show
    S|The Thick of It's Complicated
    S|Yes Minister Mister
    S|Blackadder Goes Fourth Down
    S|Fawlty Towers Hamlet
    S|Only Fools and Horses Heads
    S|Dad's Army Navy
    S|Are You Being Served Cold
    S|Keeping Up Appearances Matter
    S|One Foot in the Gravy
    S|Red Dwarf Planet
    S|Father Ted Talk
    S|The IT Crowd Control
    S|Black Books and Records
    S|Spaced Out Invaders
    S|Peep Show and Tell
    S|The Inbetweeners Club
    S|Gavin & Stacy Stacey
    S|Absolutely Fabulous Dahling
    S|Bottom Dollar
    S|The Young Ones Again
    S|Porridge Time
    S|Rising Damp Proof
    S|Open All Hours Long
    S|Last of the Summer Wine Cellar
    S|Hi-de-Hi-Hat
    S|Mrs. Brown's Boys Own
    S|Derry Girls Gone Wild
    S|The Royle Family Tree
    S|Phoenix Nights Out
    S|Benidorm Beach
    S|Bad Education Reform
    S|Fresh Meat Pie
    S|Friday Night Dinner Party
    S|Plebs and Gents
    S|Detectorists Club
    S|Catastrophe Bay
    S|Fleabag Boy
    S|Motherland Security
    S|Ghosts of Christmas Past
    S|Brassic Pickups
    S|This Country Club
    S|Stath Lets Flats
    S|People Just Do Nothing Special
    S|Taskmaster Class
    S|QI Whiz
    S|Have I Got News for Yule
    S|Mock the Weak
    S|Would I Lie to Your Face
    S|8 Out of 10 Cats Does Countdown to Countdown
    S|Never Mind the Buzzcocks Deck
    S|Whose Line Is It Mine Anyway
    S|Saturday Night Live Stream
    S|SCTV Tuned
    S|Kids in the Hallway Walk
    S|In Living Colour Blind
    S|MADtv Tuned
    S|The State of Denial
    S|Key & Peele Pelé
    S|Portlandia Spice
    S|I Think You Should Leave It Be
    S|Tim and Eric's Awesome Show Great Job Chip
    S|Nathan for You and Me
    S|Master of None of the Above
    S|The Daily Showdown
    S|The Colbert Reportage
    S|Carpool Karaoke Bar
    S|Drunk History Class
    S|Reno 911 Dial
    S|Parks and Rec Room
    S|The League of Gentlemen's Club
    S|Little Britain Fry-Up
    S|Come Fly with Me Maybe
    S|Fawlty Towers of Pisa
    S|Monty Python's Flying Circus Tent
    S|The Goodies and the Baddies
    S|The Two Ronnies and Me
    S|Morecambe and Wise Guys
    S|The Fast Show Down
    S|Harry Enfield's Television Programme
    S|Alan Partridge Trees
    S|I'm Alan Partridge Pear Tree
    S|The Day Today Tomorrow
    S|Brass Eye Contact
    S|Spitting Image Consultant
    S|Yes Prime Minister Mister Prime Minister
    S|Dinnerladies Night
    S|The Vicar of Dibley Dobley
    S|Birds of a Feather Duster
    S|Men Behaving Badly Behaved
    S|Coupling Bar
    S|Green Wing Nut
    S|Extras Large
    S|Life's Too Short Notice
    S|Derek Trotter
    S|Rev. Gone Wild
    S|The Windsors Knot
    S|Mum's the Word
    S|Outnumbered Moms
    S|Not Going Out of Business
    S|2 Point 4 Children's Hour
    S|My Family and Other Strangers
    S|Ever Decreasing Circles Around
    S|Brush Strokes of Luck
    S|The Good Life Hacks
    S|Butterflies Are Free
    S|Citizen Smith and Wesson
    S|Hancock's Half Hour Glass
    S|Steptoe and Sun
    S|Till Death Us Do Part-Time
    S|Love Thy Neighbour's Wife
    S|Not Only But Also
    S|The Andy Griffith Show Mercy
    S|Gilligan's Island Hopper
    S|Bewitched Bothered
    S|I Dream of Jeannie Genie
    S|The Addams Family Values Fund
    S|The Munsters Mash
    S|Get Smart Cookie
    S|Green Acres and Acres
    S|Petticoat Junction Box
    S|The Beverly Hillbillies Hills
    S|Hogan's Heroes Hoagies
    S|F Troop Carrier
    S|McHale's Navy Seal
    S|Gomer Pyle USMC Corps
    S|The Brady Bunch of Grapes
    S|The Partridge Family Plan
    S|Eight Is Enough Already
    S|Diff'rent Strokes of Genius
    S|The Facts of Life Lessons
    S|Silver Spoons Out
    S|Webster's Dictionary
    S|Alf Alfa
    S|Perfect Strangers Danger
    S|Who's the Boss Baby
    S|Growing Pains Relief
    S|The Wonder Years Later
    S|Doogie Howser MD
    S|Blossom Time
    S|Salute Your Shorts
    S|Clarissa Explains It All Away
    S|The Adventures of Pete & Pete's Dragon
    S|Are You Afraid of the Dark Chocolate
    S|All That Jazz
    S|Kenan & Kel's Keys
    S|Drake & Josh Dr. Pepper
    S|iCarly Simon
    S|Victorious Secret
    S|Zoey 101 Dalmatians
    S|Hannah Montana Mountain
    S|The Suite Life of Zack & Cody Banks
    S|Wizards of Waverly Place Mat
    S|Lizzie McGuire Wire
    S|That's So Raven Roost
    S|Phil of the Future Perfect
    S|Even Stevens and Odds
    S|Good Luck Charlie Brown
    S|Jessie's Girl
    S|Austin & Ally Oop
    S|Liv and Maddie in Manhattan
    S|Girl Meets World Series
    S|The Fairly OddParents Weekend
    S|Hey Arnold's Football Head
    S|Rugrats in Pieces
    S|Recess Pieces
    S|Doug Dug
    S|Rocko's Modern Strife
    S|Ren & Stimpy Show
    S|The Angry Beavers Dam
    S|CatDog Walker
    S|Pinky and the Brain Freeze
    S|Animaniacs Zone
    S|Tiny Toon Adventures of Toonie
    S|Freakazoid Zone
    S|The Critic's Choice
    S|The PJs and Slippers
    S|Home Movies Night
    S|Duckman Duck
    S|Dilbert Doodles
    S|The Oblongs Squares
    S|Futurama Mama
    S|Napoleon Dynamite Cartoon
    S|Loiter Squad Car
    S|Eastbound & Down Under
    S|Vice Principals Office
    S|The Righteous Gemstones Throw
    S|Kevin Can F**k Himself
    S|Dead to Me Too
    S|Grace and Frankie Furter
    S|Russian Doll House
    S|Santa Clarita Diet Coke
    S|Sunnyside Up
    S|Stumptown Fair
    S|The Mindy Project Runway
    S|Parks and Recreation Station
    S|Unbreakable Kimmy Schmidt Parts
    S|One Day at a Time Machine
    S|The Kominsky Method Acting
    S|Atypical Typical
    S|Ramy Hammer
    S|Never Have I Ever Had
    S|Sex Lives of College Girls Gone Wild
    S|PEN15 Club
    S|Shrill Voices
    S|Dollface Mask
    S|Insatiable Appetite
    S|Dead Pixels Per Inch
    S|Alone Together Forever
    S|Wellington Paranormal Activity
    S|What We Do in the Shadows Of Doubt
    S|Flight of the Conchords Tell
    S|Rake Receipts
    S|Kath & Kim Chee
    S|Summer Heights High Heels
    S|Please Like Me Too
    S|Utopia Planitia
    S|The Hollowmen Hollow
    S|Housos vs Authority Figure
    S|Fat Pizza Delivery
    S|Black Comedy Hour
    S|Upper Middle Bogan Boss
    S|Mother and Son Day
    S|Hey Dad Joke
    S|Home and Away Game
    S|Neighbours Next Door
    M|Anchorman Dolls
    M|Step Brothers Grimm
    M|Talladega Nights Out
    M|Elf Shelf
    M|Old School of Rock
    M|Dodgeball Pool
    M|Zoolander Dancer
    M|Tropic Thunder Cloud
    M|Meet the Parents Weekend
    M|There's Something About Mary Poppins
    M|Dumb and Dumberer
    M|Ace Ventura Pet Detective Dog
    M|The Mask of Zorro Eyes
    M|Bruce Almighty Mighty
    M|Billy Madison Square Garden
    M|Happy Gilmore Park
    M|The Waterboy Band
    M|The Wedding Singer Songwriter
    M|50 First Dates Night
    M|Click Bait
    M|Grown Ups Table
    M|Big Daddy Warbucks
    M|Mr. Deeds Goes to Town
    M|Punch-Drunk Love Hangover
    M|Uncut Gems Stones
    M|Hustle Muscle
    M|The Hangover Cure
    M|Wedding Crashers Dummies
    M|Bridesmaids Maid of Honor
    M|Knocked Up Down
    M|The 40-Year-Old Virgin Mary
    M|Pineapple Express Lane
    M|Superbad Santa
    M|Step Up to the Plate
    M|Forgetting Sarah Marshall Law
    M|Neighbors with Benefits
    M|Horrible Bosses Baby
    M|Dumb and Dumber To Go
    M|Kingpin Cushion
    M|There's Something Fishy About Mary
    M|Me Myself & Irene Cara
    M|Shallow Hal Hall
    M|Stuck on You Too
    M|Osmosis Jones Soda
    M|Old School Bus
    M|EuroTrip Hop
    M|American Pie Chart
    M|American Wedding Dress
    M|She's All That and a Bag of Chips
    M|10 Things I Hate About You Know
    M|Clueless Crossword
    M|Mean Girls on Fire
    M|Legally Blonde Brownie
    M|Bring It On and On
    M|Easy A+ Plus
    M|Sixteen Candles Light
    M|The Breakfast Club Sandwich
    M|Ferris Bueller's Day Offline
    M|Weird Science Fair
    M|Pretty in Pink Slip
    M|Some Kind of Wonderful Life
    M|Say Anything Goes
    M|Fast Times at Ridgemont Hi
    M|Dazed and Confused Dot Com
    M|Adventureland Park
    M|Slacker Rack
    M|Clerks Office
    M|Mallrats Maze
    M|Dogma Daycare
    M|Jay and Silent Bob Strike Out Back
    M|Reservoir Dogs Day
    M|The Big Lebowski Bowl
    M|O Brother Where Art Thou Art
    M|Raising Arizona Iced Tea
    M|Fargo Crate
    M|Burn After Reading Glasses
    M|Hail Caesar Salad
    M|Intolerable Cruelty Free
    M|The Ladykillers' Ball
    M|Blazing Saddles Up
    M|Young Frankenstein Monster
    M|Spaceballs of Fire
    M|Airplane! Mode
    M|The Naked Gun Show
    M|Hot Shots Parts Deux
    M|Top Secret Santa
    M|History of the World Part Whenever
    M|Robin Hood Men in Tights Night
    M|Dracula Dead and Loving It Out
    M|Caddyshack Attack
    M|Stripes Hall
    M|Meatballs Spaghetti
    M|Animal House Hunting
    M|Ghostbusters Afterlife Insurance
    M|Groundhog Day Planner
    M|Tootsie Roll
    M|Mrs. Doubtfire Alarm
    M|Big Fish Tank
    M|Splash Mountain
    M|Bachelor Party Bus
    M|Dirty Rotten Scoundrels Gold
    M|Planes Trains and Automobiles Parts
    M|Uncle Buck Rogers
    M|Home Alone Together
    M|Vacation Station
    M|European Vacation Rental
    M|Christmas Vacation Package
    M|Caddyshack Two Hole
    M|Fletch Lives On
    M|Beverly Hills Cop Out
    M|Trading Places Please
    M|Coming to America Next Door
    M|The Nutty Professor Plum
    M|Dr. Dolittle Little
    M|Norbit Cartoon
    M|Bowfinger's Chance
    M|Life Sentence
    M|Boomerang Bar
    M|The Distinguished Gentleman's Club
    M|Harlem Nights Out
    M|Raw Deal
    M|Delirious Dreaming
    M|House Party Crashers
    M|Barbershop Quartet
    M|Soul Plane Crash
    M|Think Like a Man Cave
    M|Girls Trip Planner
    M|Ride Along Side
    M|Night School Bus
    M|Jumanji Welcome to the Concrete Jungle
    M|The Pink Panther Strikes Back Again
    M|A Fish Called Wando
    M|Monty Python and the Holy Grain
    M|Life of Brian Eno
    M|The Meaning of Life Insurance
    M|Time Bandits Thieves
    M|Brazil Nuts
    M|Hot Fuzz Buzz
    M|Shaun of the Dead Sea
    M|The World's End Zone
    M|Paul Revere
    M|Tintin Tin
    M|Bridget Jones's Diary of a Wimpy Kid
    M|Love Actually Fantastic
    M|Notting Hill Billy
    M|Four Weddings and a Funeral Home
    M|About Time Capsule
    M|Sliding Doors Open
    M|Billy Elliot Spitzer
    M|The Full Monty Python
    M|Brassed Off the Block
    M|Kinky Boots Strap
    M|Calendar Girls Gone Wild
    M|Waking Ned Devine Wine
    M|The Commitments Issue
    M|Once Upon a Time in Ireland
    M|In Bruges Waffles
    M|The Guard Dog
    M|Calvary Cavalry
    M|The Banshees of Inisherin Bar
    M|Intermission Impossible
    M|Moon over Parador
    M|Local Hero Worship
    M|Gregory's Girl Guides
    M|Trainspotting Hobby
    M|Shallow Grave Digger
    M|Sunshine on Leith Lane
    M|Kes Boxes
    M|The Italian Job Interview
    M|Carry On Camping Trip
    M|Carry On Up the Khyber Pass
    M|Carry On Screaming Loud
    M|Carry On Cleo Patra
    M|The Ladykillers Club
    M|Kind Hearts and Coronets Crown
    M|The Lavender Hill Mob Mobile
    M|Passport to Pimlico Park
    M|The Man in the White Suit Jacket
    M|Tampopo Noodles
    M|Shall We Dance Floor
    M|Waterboys Splash
    M|Swing Girls Club
    M|Kamikaze Girls Night
    M|Departures Lounge
    M|Funky Forest Gump
    M|Tokyo Godfathers Day
    M|Princess Mononoke Hime
    M|Lost in La Mancha Hancha
    M|Amélie Mélie
    M|Delicatessen Counter
    M|The City of Lost Children's Hospital
    M|A Very Long Engagement Ring
    M|Dinner for Schmucks Club
    M|Dinner Rush Hour
    M|The Dinner Game Show
    M|Le Dîner de Cons Tables
    M|Les Visiteurs du Soir Eclipse
    M|Bienvenue chez les Ch'tis Bis
    M|Intouchables Table
    M|La Cage aux Folles Cage
    M|Le Grand Blond Wig
    M|Jour de Fête Day
    M|Mon Oncle Tom
    M|Playtime Fun
    M|Monsieur Hulot's Holiday Inn
    M|Zazie in the Metro Stop
    M|Belle de Jour Off
    M|Toto the Hero Cat
    M|Il Postino Mail
    M|La Strada Closed
    M|Divorce Italian Style Guide
    M|Big Deal on Madonna Street
    M|Bread and Tulips Vase
    M|Mediterraneo Sea
    M|Cinema Paradiso Lost
    M|Johnny Stecchino Piatto
    M|Life Is Beautiful Girl
    M|Benvenuti al Sud Pole
    M|Perfetti Sconosciuti Strangers
    M|The Great Beauty Salon
    M|Tie Me Up Tie Me Down Jacket
    M|Talk to Her Mother
    M|All About My Mother's Day
    M|Pain and Glory Hole
    M|Almost Famous Last Words
    M|School of Rock Garden
    M|High Fidelity Test
    M|Empire Records Store
    M|This Is Spinal Tap Dance
    M|Waiting for Guffman Gaffer
    M|Best in Show Dogs
    M|A Mighty Wind Chime
    M|For Your Consideration Prize
    M|Mascots Mascot
    M|Borat Subsequent Moviefilm
    M|Brüno Bruno
    M|Team America World Police Academy
    M|South Park Bigger Longer and Uncut Gems
    M|Austin Powers Goldmember Berries
    M|The Emperor's New Groove Ve
    M|Toy Story Time
    M|Despicable Me Too
    M|Minions Rise of Gru's Garden
    M|Kung Fu Panda Express
    M|Madagascar Escape 2 Antarctic
    M|Ice Age Collision Coarse
    M|Monsters Inc Ink
    M|Finding Nemo's Cousin
    M|The Incredibles Gamers
    M|Ratatouille Fly
    M|Cars 2 Parking
    M|Wall-E Waldo
    M|Up Down
    M|Inside Out Cold
    M|Coco Channel
    M|Soul Food
    M|Luca Brasi
    M|Turning Red Alert
    M|Onward and Upward
    M|Encanto Cantina
    M|Moana Lisa
    M|Zootopia Tropolis
    M|Big Hero 6 Pack
    M|Wreck-It Ralph Breaks the Wifi
    M|Frozen Fire
    M|Tangled Hair Up
    M|Brave Heart Rate
    M|Rise of the Guardians Angels
    M|Trolls World Tour Guide
    M|Sing Along
    M|The Secret Life of Pets Rock
    M|Megamind Meld
    M|Cloudy with a Chance of Meatballs Deluxe
    M|Hotel Transylvania Room Service
    M|Shark Tale Tail
    M|Over the Hedge Fund
    M|Bee Movie Marathon
    M|Antz in Your Pantz
    M|A Bug's Life Hack
    M|Chicken Run Rabbit
    M|Wallace and Gromit Hit
    M|Curse of the Were-Rabbit Habit
    M|Early Man Cave
    M|Flushed Away Games
    M|Shaun the Sheep Dog
    """
}
