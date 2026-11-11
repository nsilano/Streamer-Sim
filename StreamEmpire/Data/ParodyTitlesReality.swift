import Foundation

extension ParodyLibrary {
    /// More reality / competition / talk parodies. Format: "S|Name" for a series, "M|Name" for a movie.
    static let moreReality = """
    S|Survivor Guilt
    S|Big Brother Bear
    S|The Amazing Race Car
    S|The Bachelor Party
    S|The Bachelorette Party
    S|Bachelor in Paradise Lost
    S|Love Island Hopping
    S|Too Hot to Handle It
    S|Love Is Blind Date
    S|Naked and Afraid of Commitment
    S|Dating Naked Sushi
    S|The Circle Jerk
    S|The Traitors Wheel
    S|Squid Game: The Challenge Coin
    S|Alone in the Dark
    S|Alone Together Again
    S|Lost in the Wild
    S|Man vs. Wild Card
    S|Naked Wanderers
    S|Wipeout Wipe
    S|American Ninja Warrior Princess
    S|Ninja Warrior Squad
    S|Fear Factor Five
    S|Hell's Kitchen Sink
    S|MasterChef Chef
    S|MasterChef Junior Senior
    S|Top Chef Hat
    S|Chopped Liver
    S|Guy's Grocery Games Game
    S|Cupcake Wars Of the Roses
    S|Cake Boss Baby
    S|Ace of Cakes Aces
    S|Nailed It! Nails
    S|Great British Bake Off Day
    S|The Great British Sewing Bee Bees
    S|Race Across the World Wide
    S|Strictly Come Dancing Queen
    S|Dancing with the Stars Wars
    S|America's Got Talent Scout
    S|Britain's Got Talent Show
    S|The Voice of Reason
    S|American Idol Worship
    S|The X Factor Fifty
    S|Pop Idol Hands
    S|Popstars Stars
    S|Making the Band Aid
    S|America's Next Top Model Home
    S|Project Runway Show
    S|Drag Race Car
    S|RuPaul's Drag Race Track
    S|Say Yes to the Dress Code
    S|My Super Sweet 16 Candles
    S|Teen Mom Moms
    S|16 and Pregnant Pause
    S|Jersey Shore Thing
    S|The Hills Have Eyes
    S|Laguna Beach Boys
    S|The Real World Peace
    S|Real Housewives of Atlanta Georgia
    S|Real Housewives of New Jersey Devils
    S|Newlyweds Nick and Jessica Alba
    S|Toddlers & Tiaras Tiara
    S|19 Kids and Counting Sheep
    S|Sister Wives Club
    S|Little People Big World Wide
    S|Dance Moms Day
    S|Bring It! Brought
    S|Pawn Stars Wars
    S|American Pickers Pickles
    S|Antiques Roadshow Road
    S|Cash Cab Cabs
    S|Deal or No Deal Breaker
    S|Who Wants to Be a Millionaire's Row
    S|Wheel of Fortune Cookie
    S|Jeopardy! Danger
    S|The Price Is Right Wrong
    S|Family Feud Fest
    S|The Weakest Link Chain
    S|Countdown to Extinction
    S|Mastermind Games
    S|Only Connect Four
    S|University Challenge Accepted
    S|Fifteen to One Hundred
    S|Blockbusters Busters
    S|The Chase Scene
    S|Tipping Point Break
    S|Bargain Hunt Hunters
    S|Homes Under the Hammer Time
    S|Grand Designs Don't Stop
    S|Escape to the Country Club
    S|A Place in the Sun Block
    S|Selling Sunset Boulevard
    S|Million Dollar Listing Los Angeles
    S|Love It or List It Out
    S|Property Brothers Bros
    S|Fixer Upper Hand
    S|Flip or Flop House
    S|House Hunters International Relations
    S|Tiny House Nation State
    S|Trading Spaces Cadets
    S|What Not to Wear Out
    S|10 Years Younger Brother
    S|Supernanny Nanny
    S|Wife Swap Meet
    S|Undercover Boss Baby
    S|Shark Tank Top
    S|Dragons' Den Mother
    S|The Apprentice Wizard
    S|Mythbusters Busters
    S|Dirty Jobs Done Dirt Cheap
    S|Deadliest Catch Phrase
    S|Ice Road Truckers Union
    S|Ax Men Women
    S|Swamp People Pleasers
    S|Gold Rush Hour
    S|Mountain Men's Room
    S|Life Below Zero Sum
    S|Alaskan Bush People Pleaser
    S|Naked Castaway Cast
    S|Marooned with Ed Stafford Ford
    S|I'm a Celebrity Get Me Out of Here Now
    S|Celebrity Big Brother Bear
    S|Celebrity Apprentice Mentice
    S|Celebrity Fit Club Soda
    S|Dancing on Ice Cube
    S|Taskmaster Master
    S|Brooklyn Bake Off
    S|Bake Squad Goals
    S|The Great Canadian Baking Show Down
    S|Canada's Drag Race Rage
    S|Canada's Got Talent Scouts
    S|Big Brother Canada Goose
    S|Dragons' Den Canada Dry
    S|The Amazing Race Canada Dry
    S|MasterChef Australia Day
    S|My Kitchen Rules Dinner
    S|The Block Party
    S|Australian Survivor Guilt
    S|I'm a Celebrity Australia Day
    S|Love Island Australia Day
    S|Married at First Sight Unseen
    S|The Bachelor Australia
    S|Farmer Wants a Wife Beater
    S|First Dates Hungary
    S|Naked Attraction Distraction
    S|Come Dine with Me Myself
    S|Gogglebox Set
    S|Celebrity Gogglebox Set
    S|Don't Tell the Bride Groom
    S|Four Weddings Funeral
    S|Bridezillas Zilla
    S|Say I Do Don't
    S|Love After Lockup Lock
    S|Sex Sent Me to the ER Visit
    S|My 600-lb Life Lifts
    S|The Biggest Loser Winner
    S|Extreme Weight Loss Gain
    S|The Doctors Orders
    S|Divorce Court Jester
    S|Cops Come
    S|To Catch a Predator Prey
    S|Hoarders Hoard
    S|Storage Hunters Hunt
    S|Cheaters Beaters
    S|Blind Date Night
    S|Taken Out Takeaway
    S|Take Me Out Tonight
    S|Dinner Date Night
    S|The Dating Game Show
    S|Elimidate Date
    S|I Love New York Strip
    S|Rock of Love Bus Tour
    S|Charm School Bus
    S|Bad Girls Club Soda
    S|Vanderpump Rules Rule
    S|Below Deck Plans
    S|Southern Charm Bracelet
    S|Summer House Rules
    S|Winter House Rules
    S|Selling the OC Soda
    S|Bling Empire Strikes Back
    S|Love & Hip Hop Hip
    S|Basketball Wives Club
    S|Dancing with the Stars Lars
    S|American Grit Gritty
    S|The Challenge Accepted
    S|Are You the One Direction
    S|Ex on the Beach Ball
    S|Geordie Shore Thing
    S|The Only Way Is Essex Boy
    S|Towie Tower
    S|Love Island USA Today
    S|Love Island Games Console
    S|Perfect Match Maker
    S|The Ultimatum Game
    S|Indian Matchmaking Match
    S|Too Hot to Handle Hot Tub
    S|Sexy Beasts Beast
    S|Dated & Related Elated
    S|Selling the City Hall
    S|Ultimate Beastmaster Master
    S|Floor Is Lava Lamp
    S|Is It Cake Pops
    S|Nailed It Down
    S|Legendary Hell
    S|Glow Up Britain's Next Make-Up Star Wars
    S|Next in Fashion Week
    S|Making the Cut Above
    S|Glass Blowing Games
    S|The Great Pottery Throw Down Under
    S|Forged in Fire Starter
    S|Barbecue Showdown Town
    S|Sugar Rush Hour
    S|Holiday Baking Championship Ring
    S|Halloween Baking Championship Ring
    S|Kids Baking Championship Ring
    S|Spring Baking Championship Ring
    S|Worst Cooks in America Ica
    S|Iron Chef America Ica
    S|Iron Chef Gauntlet
    S|Chef's Table Top
    S|Salt Fat Acid Heat Wave
    S|The Final Table Cloth
    S|Ugly Delicious Pie
    S|Somebody Feed Phil Phillips
    S|Street Food Fight
    S|Taco Chronicles Chronicle
    S|Night on Earth Day
    S|Our Planet Earth
    S|Blue Planet Hollywood
    S|Frozen Planet Plan
    S|Dynasties Dynasty
    S|Wild Isles Islands
    S|Seven Worlds One Planet Plan
    S|Our Universe Verse
    S|Hubble's Cosmic Journey Journal
    S|The Solar System Systems
    S|The Mars Generation Gen
    """
}
