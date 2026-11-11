import Foundation

extension ParodyLibrary {
    /// More documentary parodies. Format: "S|Name" for a series, "M|Name" for a movie.
    static let moreDocs = """
    S|Making a Murderer's Row
    S|The Jinx Removal
    S|Tiger Queen
    S|Don't F**k with Cats Dogs
    S|Abducted in Plain Sight Seeing
    S|The Staircase Lift
    S|Tales from the Hood Ornament
    S|Cheer Squad Goals
    S|Last Chance U Turn
    S|Drive to Survive Another Day
    S|Formula 1: Drive to Thrive
    S|Full Swing Dance
    S|Break Point Blank
    S|Welcome to Wrexham Hamlet
    S|Sunderland 'Til I Fry
    S|The Last Dance Floor
    S|Hard Knocks Off
    S|Quarterback Sneak
    S|Losers Weepers
    S|Icons Unearthed Earthed
    S|The Defiant Ones Too
    S|Hip-Hop Evolution Revolution
    S|Montage of Heck Yeah
    S|Searching for Sugar Man Cave
    S|20 Feet from Stardom Boulevard
    S|The Wrecking Crew Cut
    S|Muscle Shoals Sound Check
    S|Standing in the Shadows of Motown Town
    S|Gimme Shelter Skelter
    S|Woodstock Stock
    S|Stop Making Sense Sensibility
    S|The Last Waltz Time
    S|Don't Look Back Pack
    S|Let It Be Me
    S|Get Back Pay
    S|Rattle and Hum Drum
    S|Shut Up and Play the Hits Parade
    S|Dig! The Garden
    S|Anvil! The Story of Anvil Seat
    S|Some Kind of Monster Mash
    S|Searching for Sound Bite
    S|Blackfish Fry
    S|The Cove Cruise
    S|Seaspiracy Piracy
    S|The Social Dilemma Lemma
    S|The Great Hack Saw
    S|Citizenfour Square
    S|Inside Job Hunt
    S|Enron: The Smartest Guys in the Room Service
    S|The Corporation Tax
    S|Food, Inc. Corp
    S|Super Size Me Too
    S|Fast Food Nation State
    S|Forks Over Knives and Spoons
    S|What the Health Care
    S|Cowspiracy Piracy
    S|Okja's Hogs
    S|Planet of the Humans Beans
    S|An Inconvenient Truth Serum
    S|An Inconvenient Sequel Equal
    S|Before the Flood Gate
    S|Chasing Ice Age
    S|Chasing Coral Reef
    S|My Octopus Teacher's Pet
    S|Fantastic Fungi Guy
    S|Gunda's Hog
    S|The Biggest Little Farm Hand
    S|March of the Penguins Parade
    S|Happy Feet Two
    S|Born to Be Wild Ones
    S|Winged Migration Plan
    S|Microcosmos Cosmos
    S|Home Sweet Home Page
    S|Man on Wire Cutter
    S|Free Solo Mid
    S|The Dawn Wall Street
    S|Meru Rue
    S|180° South Pole
    S|Valley Uprising Down
    S|Maiden Voyage
    S|The Mystery of Dyatlov Pass Port
    S|Into the Wild Child
    S|Grizzly Man Bear
    S|Encounters at the End of the World Wide
    S|Cave of Forgotten Dreams Machine
    S|Into the Inferno Turf
    S|Lo and Behold Gold
    S|Capturing the Friedmans Boys
    S|Paradise Lost Soul
    S|West of Memphis Belle
    S|The Thin Blue Line Dance
    S|Brother's Keeper Keepers
    S|Hoop Dreams Come True
    S|When We Were Kings Queens
    S|Senna Samba
    S|Icarus Wax
    S|Dirty Money Matters
    S|Dirty John Smith
    S|The Dropout Rates
    S|The Inventor: Out for Blood Tests
    S|Bad Blood Test
    S|Fyre Starter
    S|Fyre Fraud Detector
    S|Trainwreck: Woodstock '99 Problems
    S|The Tinder Swindler's List
    S|The Puppet Master Class
    S|Don't Pick Up the Phone Call
    S|Abducted in Plain Sight Unseen
    S|Evil Genius Loci
    S|Wormwood Floor
    S|Mommy Dead and Dearest Dear
    S|I Love You, Now Die Hard
    S|The Keepers Weepers
    S|Leaving Neverland Land
    S|Finding Neverland Land
    S|Allen v. Farrow and Sow
    S|Icarus Descent
    S|Cocaine Cowboys and Indians
    S|Cocaine Bear Hugs
    S|Narco Cultura Culture
    S|Holy Hell Fire
    S|Going Clear Water
    S|Jesus Camp Ground
    S|Deliver Us from Evil Eye
    S|Spotlight on Sunday School
    S|The Family Fam
    S|Escaping Twin Flames Out
    S|Keep Sweet: Pray and Obey Me
    S|Daughters of the Cult Following
    S|The Vow Renewal
    S|Heaven's Gate Crashers
    S|Waco: American Apocalypse Now
    S|Jonestown: Terror in the Jungle Gym
    S|Murder on Middle Beach Boys
    S|Unsolved Mysteries Solved
    S|Cold Case Files Cabinet
    S|Forensic Files Folder
    S|48 Hours Mystery House
    S|60 Minutes Maid
    S|Frontline Backline
    S|American Experience Needed
    S|The War That Peace Built
    S|Baseball Bats
    S|Jazz Hands
    S|Country Music Hall
    S|The National Parks: America's Best Idea Box
    S|Prohibition Era
    S|The Vietnam War Room
    S|The Dust Bowl Cut
    S|The Brooklyn Bridge Club
    S|The Statue of Liberty Bell
    S|The Congress Room
    S|The Gate Keepers
    S|The Weight of Water Weight
    S|Chef's Table Manners
    S|Mind of a Chef Hat
    S|Cooked Books
    S|Salt Fat Acid Hot Sauce
    S|Street Food Latin America Day
    S|Street Food Asia Pacific
    S|Rotten Fruit
    S|The Chefs' Line
    S|Magic for Humans Beings
    S|Abstract: The Art of Design Time
    S|Explained Further
    S|Vox Pop
    S|Dope Sick
    S|Cheat Sheet Music
    S|Dirty Money Honey
    S|Daughters of Destiny Child
    S|Last Chance U Basketball
    S|Cheer Up Buttercup
    S|Tiny Shiny Home
    S|Don't F with Cats Out of the Bag
    S|The Imposter Syndrome
    S|Three Identical Strangers Danger
    S|Dig Two Graves
    S|Stolen Childhoods
    S|Fire in Paradise Lost
    S|Welcome to Chechnya Cheche
    S|The Act of Killing Time
    S|The Look of Silence Golden
    S|The Square Dance
    S|Hotel Rwanda Room Service
    S|Do You Hear the People Sing Along
    S|The Great Hack Attack
    S|Nanette Netty
    S|Homecoming Queen
    S|One Direction: This Is Us Too
    M|Man on Wire Fence
    M|Grizzly Bear Man
    M|Bowling for Columbine Wall
    M|Fahrenheit 9/11 Sandwich
    M|Sicko Mode
    M|Capitalism: A Love Story Time
    M|Roger & Me Too
    M|Where to Invade Next Door
    M|Super Size Me Medium
    M|Spellbound Rounds
    M|Mad Hot Ballroom Dancing
    M|Etre et Avoir Un
    M|The Overnighters Night
    M|The Look of Love Actually
    M|20,000 Days on Earth Day
    M|Searching for Sugar Man Hole
    M|Exit Through the Gift Shop Lifting
    M|Waste Land Lord
    M|Hearts of Darkness Light
    M|Burden of Dreams Team
    M|Tarnation Station
    M|Capturing the Friedmans Friends
    M|Paradise Lost Boys
    M|Strong Island Time
    M|The Social Network Dilemma
    M|My Octopus Teacher Pet
    M|Honeyland Honey
    M|For Sama Mama
    M|The Cave In
    M|American Factory Floor
    M|Hale County This Morning This Evening Standard
    M|Minding the Gap Year
    M|Won't You Be My Neighbor Hood
    M|RBG Cut
    M|Free Solo Flight
    M|Faces Places Please
    M|Cartel Land Lord
    M|The Act of Killing Floor
    M|Citizenfour Door
    M|Last Men in Aleppo Pepper
    M|13th Floor
    M|I Am Not Your Negro Leagues
    M|Strong Island Girl
    M|Icarus Wings
    M|Navalny Navel
    M|Summer of Soul Food
    M|Flee Fleas
    M|Attica Alley
    M|Descendant Dent
    M|Fire of Love Handles
    M|All That Breathes Easy
    M|Navalny Salad
    M|Moonage Daydream Believer
    M|Sugarcane Sugar
    M|Poker Face Off
    M|20 Days in Mariupol Mall
    M|The Mole Hill
    M|Hundreds of Beavers Dam
    """
}
