import Foundation

extension ParodyLibrary {
    /// More kids parodies. Format: "S|Name" for a series, "M|Name" for a movie.
    static let moreKids = """
    S|Paw Patrol Car
    S|Peppa Pig Latin
    S|Bluey Jeans
    S|Bluey Bingo
    S|Blue's Clues Crew
    S|Dora the Explorer Bag
    S|Sesame Street Smarts
    S|Mister Rogers' Neighborhood Watch
    S|Barney & Friends Without Benefits
    S|Teletubbies Teddies
    S|In the Night Garden Gnome
    S|Postman Pat Down
    S|Thomas the Tank Top
    S|Fireman Sam's Club
    S|Bob the Builder's Tape
    S|Noddy's Cap
    S|Ben & Holly's Little Kingdom Hearts
    S|Hey Duggee Doggy
    S|Octonauts Nuts
    S|Sarah & Duck Soup
    S|Teen Titans Go Karts
    S|Ben 10 Cent
    S|Adventure Time Out
    S|Regular Show Off
    S|Steven Universe Today
    S|Gravity Falls Down
    S|Phineas and Ferb Fur
    S|Kim Possible Mission
    S|Lilo & Stitch Up
    S|Recess Bell
    S|Hey Arnold! Schwarzenegger
    S|The Wild Thornberrys Berries
    S|Rocket Power Rangers
    S|As Told by Ginger Beer
    S|Invader Zim Zam
    S|Jimmy Neutron Boy Genius Grant
    S|SpongeBob SquarePants on Fire
    S|The Loud House Rules
    S|The Casagrandes Casa
    S|Henry Danger Zone
    S|Bunk'd Beds
    S|Sofia the First Mate
    S|Doc McStuffins Stuffing
    S|Mickey Mouse Clubhouse Rules
    S|Mickey Mouse Roadster Racers
    S|Minnie's Bow-Toons
    S|Handy Manny's Tools
    S|Special Agent Oso Obo
    S|The Lion Guard Dog
    S|Elena of Avalor Aisle
    S|Mira Royal Detective Agency
    S|Gabby's Dollhouse Arrest
    S|Spidey and His Amazing Friends and Family
    S|Ms. Rachel Rescue
    S|CoComelon Melon
    S|Baby Shark Tank
    S|Blippi Hippie
    S|Super Simple Songs of Praise
    S|Numberblocks Party
    S|Alphablocks Letters
    S|Cyberchase Case
    S|Wild Kratts Cats
    S|Curious George Washington
    S|Arthur's Seat
    S|Clifford the Big Red Dog Park
    S|Martha Speaks Volumes
    S|Wordgirl Power
    S|Super Why Not
    S|Sid the Science Kid Gloves
    S|Dinosaur Train Wreck
    S|Odd Squad Car
    S|Peg + Cat Nap
    S|Molly of Denali Mountain
    S|Elinor Wonders Why Not
    S|Pinkalicious & Peterrific Peaks
    S|Daniel Tiger's Neighborhood Watch
    S|The Magic School Bus Stop
    S|Liberty's Kids Table
    S|Reading Rainbow Bridge
    S|Zoboomafoo Foo
    S|Between the Lions' Den
    S|Mr. Wizard's World War
    S|Bill Nye the Science Guy Fawkes
    S|Beakman's World Cup
    S|Lazytown Town
    S|The Wiggles Giggles
    S|Hi-5 Highs
    S|Play School's Out
    S|Sooty Shoes
    S|Rainbow Rhyme
    S|Rosie and Jim Beam
    S|Teletubbies Tummies
    S|Tweenies Weenies
    S|Fimbles Bumbles
    S|Balamory Mansions
    S|Bagpuss Puss
    S|The Clangers Hangers
    S|Ivor the Engine Room
    S|Noggin the Nog Log
    S|Pingu Pongu
    S|Wallace & Gromit's Cracking Contraptions
    S|Morph Dress
    S|Mr. Benn Bean
    S|Danger Mouse Trap
    S|Dogtanian and the Three Muskehounds Dogs
    S|Willy Fog and Friends
    S|The Raccoons Rock
    S|Fraggle Rock Hard
    S|The Muppet Show Business
    S|Muppet Babies Cries
    S|Jim Henson's Dog City Walk
    S|Dinosaurs Walk
    S|Sesame Street Fighter
    S|Pee-wee's Playhouse Call
    S|Shining Time Station Wagon
    S|Mighty Morphin Power Rangers Ranger
    S|Power Rangers Dino Charge Card
    S|Teenage Mutant Ninja Turtles Soup
    S|He-Man and the Masters of the Universe Today
    S|She-Ra and the Princesses of Power
    S|ThunderCats Hooo
    S|Transformers Prime Time
    S|Transformers: Rescue Bots Rescue
    S|My Little Pony Express
    S|Care Bears Beers
    S|Strawberry Shortcake Walk
    S|Rainbow Brite Bite
    S|The Smurfs Village
    S|The Snorks Snorkel
    S|Gummi Bears Beers
    S|DuckTales Woo-oo
    S|Chip 'n Dale Rescue Rangers Station
    S|TaleSpin Doctor
    S|Darkwing Duck Hunt
    S|Goof Troop Goofy
    S|Gargoyles Gargles
    S|Recess Rec
    S|Pepper Ann Arbor
    S|Doug Funnie
    S|Rugrats Rats
    S|All Grown Up Down
    S|Wild Thornberries Pie
    S|Catscratch Post
    S|Danny Phantom Menace
    S|Avatar: The Last Airbender Bender
    S|The Legend of Korra Rock
    S|Teen Titans Titan
    S|Young Justice League
    S|Batman: The Animated Series Finale
    S|Superman: The Animated Series Premiere
    S|Justice League Unlimited Data
    S|Static Shock Absorber
    S|Batman Beyond Belief
    S|The Zeta Project Manager
    S|Spider-Man and His Amazing Friends Request
    S|X-Men: The Animated Series Pilot
    S|Biker Mice from Mars Bars
    S|Captain Planet and the Planeteers Sneers
    S|Swat Kats Cats
    S|Earthworm Jim Dandy
    S|Bobby's World Tour
    S|Eek! The Cat Nap
    S|Tiny Toons Looniversity Toons
    S|Pinky and The Brain Dead
    S|Histeria Hysteria
    S|Johnny Bravo Zulu
    S|Dexter's Laboratory Rats
    S|The Powerpuff Girls Night Out
    S|Courage the Cowardly Dog Days
    S|Ed, Edd n Eddy Eddie
    S|Codename: Kids Next Door Knob
    S|Foster's Home for Imaginary Friends Zone
    S|My Gym Partner's a Monkey Business
    S|The Marvelous Misadventures of Flapjack Jack
    S|Chowder Powder
    S|Uncle Grandpa Pa
    S|Steven Universe Future Tense
    S|We Bare Bears Bearly
    S|Craig of the Creek Bed
    S|Summer Camp Island Hopper
    S|OK K.O.! Let's Be Heroes Hero
    S|Infinity Train Wreck
    S|Over the Garden Wall Street
    S|Mighty Magiswords Words
    S|Wander Over Yonder Wonder
    S|Star vs. the Forces of Evil Eye
    S|The Owl House Wine
    S|Amphibia Rain
    S|Big City Greens Grocer
    S|Milo Murphy's Law School
    S|The Ghost and Molly McGee Gee
    S|Kiff Cliff
    S|Bluey's Big Play
    S|The Rocketeer Racer
    S|Lego Friends Request
    S|Lego City Adventures Awaits
    S|Chima Chimera
    S|Bakugan Battle Planet Earth
    S|Beyblade Burst Bubble
    S|Yu-Gi-Oh! Duel Monsters Inc
    S|Pokemon Journeys Ends
    S|Digimon Adventure Park
    S|Pokemon Master Journeys Master
    S|Sailor Moon Crystal Ball
    S|Medabots Bots
    S|Monster Rancher Ranch
    S|Shaman King Kong
    S|Inuyasha Inu
    S|Totally Spies Spy
    S|Martin Mystery Tour
    S|The Winx Club Sandwich
    S|Miraculous: Tales of Ladybug & Cat Noir
    S|Miraculous Lady Bag
    S|Ever After High School
    S|Monster High Class
    S|Barbie: Dreamhouse Adventures Await
    S|Barbie Life in the Dreamhouse Rules
    S|Polly Pocket Watch
    S|LOL Surprise! Party
    S|Hatchimals Pixies
    S|Shopkins Cart
    S|L.O.L. Gold
    S|Ryan's Mystery Playdate Date
    S|Ryan's World Tour
    S|Danger Force Field
    S|Henry Danger Mouse
    S|Game Shakers and Movers
    S|Nicky, Ricky, Dicky & Dawn Patrol
    S|The Thundermans Pants
    S|Sam & Cat Nap
    S|Max & Shred Beard
    S|Make It Pop Corn
    S|The Haunted Hathaways Hall
    S|Every Witch Way Out
    S|Fred: The Show Biz
    S|Supah Ninjas Pie
    S|Big Time Rush Hour
    S|Victorious Cool
    S|Sanjay and Craig Ruth
    S|Harvey Beaks Beets
    S|Pig Goat Banana Cricket Match
    S|Breadwinners Bakery
    S|T.U.F.F. Puppy Love
    S|Making Fiends Friends
    S|Back at the Barnyard Barn
    S|Penguins of Madagascar Madness
    S|The Mighty B! Bee
    S|The Backyardigans Digans
    S|Team Umizoomi Zoomi
    S|Bubble Guppies Guppy
    S|Ni Hao Kai-Lan Land
    S|Fresh Beat Band of Spies Band
    S|Nick Jr's Face
    S|Little Bear Hug
    S|Franklin and Friends Frenzy
    S|Maisy Mouse Trap
    S|Charlie and Lola Lolly
    S|Angelina Ballerina Ballet
    S|Higglytown Heroes Hero
    S|Little Einsteins Einstein
    S|Jungle Junction Box
    S|Imagination Movers Shakers
    S|Johnny and the Sprites Sprite
    S|The Book of Pooh Poo
    S|Stanley Cup
    S|Fillmore! Fill More
    S|Lloyd in Space Cadet
    S|Teacher's Pet Peeve
    S|The Weekenders Weekend
    S|American Dragon: Jake Long Dong
    S|The Replacements Parts
    S|Pair of Kings and Queens
    S|Jake and the Never Land Pirates Cove
    S|Sheriff Callie's Wild West Side
    S|Vampirina Ballerina
    S|PJ Masks Mask
    S|Muppet Babies Boomers
    S|Mickey Mouse Funhouse Fun
    S|Bluey Baby Racer
    S|Alice's Wonderland Bakery Bake Off
    S|Hilda and the Mountain King Kong
    S|Dragons: Race to the Edge of Seventeen
    S|Trollhunters Hunters
    S|Wizards: Tales of Arcadia Arcade
    S|3Below: Tales of Arcadia Arcade
    S|The Dragon Prince Charming
    S|Kipo and the Age of Wonderbeasts Beast
    S|She-Ra Princess Pride
    S|Carmen Sandiego Sandwiches
    S|Where on Earth Is Carmen Sandiego Diego
    S|The Magic Roundabout Out
    M|Frozen Lake
    M|Frozen Too: The Thaw
    M|Toy Story of Terror
    M|Toy Story That Time Forgot
    M|Inside Out Loud
    M|Coco Puffs
    M|Moana Moan
    M|The Lion King Kong
    M|Aladdin and the King of Thieves Guild
    M|Beauty and the Beast Mode
    M|The Little Mermaid's Purse
    M|Pocahontas Wish
    M|Mulan Jacket
    M|The Hunchback of Notre Dame Dames
    M|Tarzan Zan
    M|The Emperor's New Groove Walker
    M|Atlantis: The Lost Empire Strikes Back
    M|Lilo & Stitch Wound
    M|Treasure Planet Hollywood
    M|Brother Bear Hug
    M|Home on the Range Rover
    M|Meet the Robinsons Crusoe
    M|Bolt Cutter
    M|The Princess and the Frog Prince
    M|Tangled Up in Blue
    M|Wreck-It Ralph Wreck It
    M|Big Hero 6 Million Dollar Man
    M|Zootopia Mania
    M|Moana Lisa Smile
    M|Encanto Bruno
    M|Strange World Wide Web
    M|Wish Upon a Star
    M|Elemental Table
    M|Luca Lu
    M|Turning Red Hot
    M|Lightyear Years
    M|Cars 3 Wheeler
    M|The Good Dinosaur Bones
    M|Brave New World
    M|Monsters University Challenged
    M|Up Over
    M|Ratatouille Rat
    M|WALL-E Wall
    M|Kung Fu Panda Bear Hug
    M|Puss in Boots: The Last Wish List
    M|The Croods: A New Age of Reason
    M|Rise of the Guardians Reunion
    M|Trolls Band Together Again
    M|Megamind Mind
    M|Madagascar 3: Europe's Most Wanted
    M|Penguins of Madagascar Madness Monday
    M|The Boss Baby Bottle
    M|Captain Underpants Pants
    M|Abominable Snowman
    M|The Bad Guys Gang
    M|Sing 2 Gether
    M|The Secret Life of Pets Pests
    M|Despicable Me 4 Four
    M|Minions Break
    M|The Lorax Fax
    M|Horton Hears a Who's Who
    M|The Grinch Who Stole Christmas Tree
    M|Dr. Seuss' The Cat in the Hat Rack
    M|Hop Scotch
    M|Hotel Transylvania Summer Vacation
    M|Smallfoot Bigfoot
    M|The Angry Birds Movie Night
    M|Ferdinand the Bull Run
    M|Ice Age: Continental Drift Net
    M|Rio 2 Grande
    M|Epic Fail
    M|Robots Dance
    M|Happy Feet Sweat
    M|Open Season Opener
    M|Over the Hedge Trimmer
    M|Surf's Up Down
    M|Cloudy 2: Revenge of the Leftovers Fridge
    M|The Emoji Movie Night
    M|The Peanuts Movie Theater
    M|Paddington 2 Cars
    M|Peter Rabbit Hole
    M|Dolittle Little
    M|Stuart Little Big
    M|Babe: Pig in the City Pig
    M|Charlotte's Web Page
    M|Garfield Gets Real Fat
    M|Scooby-Doo Where Are You Now
    M|The Flintstones Fred
    M|The Jetsons Movie Marathon
    M|Space Jam Session
    M|Looney Tunes: Back in Action Figure
    M|Tom and Jerry Fit
    M|Alvin and the Chipmunks Nuts
    M|The Smurfs Movie Night
    M|Teen Titans Go! To the Movies Theater
    M|The Lego Movie Night
    M|The Lego Batman Movie Marathon
    M|Ninjago Movie Night
    M|Mario Kart Movie Night
    M|The Super Mario Galaxy Movie
    M|Sonic Boom Box
    M|Pokemon: The First Movie Night
    M|Digimon: The Movie Theater
    M|Pokémon Detective Quest
    M|Spirited Away Day
    M|My Neighbor Totoro Toto
    M|Kiki's Delivery Service Dog
    M|Howl's Moving Castle Duty
    M|Ponyo Pony
    M|The Wind Rises and Shines
    M|Castle in the Sky Fall
    M|The Cat Returns Policy
    M|Arrietty Pretty
    M|From Up on Poppy Hill Bill
    M|The Tale of the Princess Kaguya Boy
    M|When Marnie Was There Where
    M|Earwig and the Witch Hunt
    M|Flee Market
    M|Wolfwalkers Walkers
    M|The Secret of Kells Bells
    M|Song of the Sea Shanty
    M|The Breadwinner Bread
    M|Kubo and the Two Strings Attached
    M|Coraline Caroline
    M|ParaNorman Norm
    M|The Boxtrolls Troll
    M|Missing Link Links
    M|Isle of Dogs Days
    M|Fantastic Mr. Fox Hunt
    M|Chicken Run: Dawn of the Nugget
    M|Shaun the Sheep Movie Night
    M|Early Man Eater
    M|Arthur Christmas Present
    M|Flushed Away Day
    M|Wallace & Gromit: Vengeance Most Fowl
    M|The Curse of the Were-Rabbit Hole
    """
}
