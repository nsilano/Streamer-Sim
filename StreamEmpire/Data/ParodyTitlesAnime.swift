import Foundation

extension ParodyLibrary {
    /// More anime parodies. Format: "S|Name" for a series, "M|Name" for a movie.
    static let moreAnime = """
    S|Attack on Titan Up
    S|Death Note Pad
    S|Fullmetal Alchemist Brotherhood Hood
    S|Naruto Shippuden Shipping
    S|Bleach Out
    S|One Piece of Cake
    S|My Hero Academia Awards
    S|Demon Slayer Layer
    S|Jujutsu Kaisen Kaison
    S|Chainsaw Man Cave
    S|Spy x Family Matters
    S|Tokyo Ghoul School
    S|Sword Art Online Offline
    S|Re:Zero Hero
    S|Overlord Lord
    S|That Time I Got Reincarnated as a Spreadsheet
    S|Mob Psycho 100 Percent
    S|One Punch Man Cave
    S|Dr. Stone Cold
    S|Fire Force Field
    S|Black Clover Leaf
    S|Fairy Tail Gate
    S|Seven Deadly Sins and Virtues
    S|Dragon Ball Super Sized
    S|Dragon Ball GT Gets Lost
    S|Cowboy Bebop Bop
    S|Trigun Gun
    S|Gintama Llama
    S|Slam Dunk Tank
    S|Haikyu!! Hi-Yah
    S|Kuroko's Basketball Bounce
    S|Prince of Tennis Court
    S|Yowamushi Pedal Pushers
    S|Free! Iwatobi Swim Club Soda
    S|Ace of Diamond Ring
    S|Inazuma Eleven Players
    S|Initial D Drift
    S|Ping Pong the Animation Station
    S|Eyeshield 21 Questions
    S|Hajime no Ippo Ipo
    S|Megalo Box Office
    S|Cardcaptor Sakura Blossom
    S|Fruits Basket Case
    S|Ouran High School Host Club Sandwich
    S|Kaguya-sama: Love Is War Games
    S|Toradora! Dora
    S|Clannad After Story Time
    S|Your Lie in April Fools
    S|Violet Evergarden Gnome
    S|A Silent Voice Mail
    S|Anohana Banana
    S|Steins;Gate Keeper
    S|Code Geass Glass
    S|Gurren Lagann Lagoon
    S|Neon Genesis Evangelion Eva Longoria
    S|Serial Experiments Lain Lane
    S|Ghost in the Shell: Stand Alone Complex Plex
    S|Psycho-Pass Pass
    S|Paranoia Agent Orange
    S|Monster Mash
    S|Death Parade Float
    S|Erased Eraser
    S|Another Brother
    S|Higurashi When They Cry Baby
    S|Made in Abyss Chasm
    S|Berserk Mode
    S|Vinland Saga Sandwich
    S|Mushishi Shishi
    S|Natsume's Book of Friends Book
    S|Spice and Wolf Pack
    S|Space Brothers Sisters
    S|Planetes Planets
    S|Cowboy Bebop Pop
    S|Space Dandy Handy
    S|Outlaw Star Wars
    S|Macross Frontier Town
    S|Gundam Wing Man
    S|Mobile Suit Gundam Seed Corn
    S|Mobile Suit Gundam: Iron-Blooded Orphans Annie
    S|Aldnoah.Zero Hero
    S|Darling in the Franxx Wax
    S|Kill la Kill Bill
    S|Promare Mare
    S|Panty & Stocking with Garterbelt Loop
    S|FLCL Cool
    S|D.Gray-man Gray Man
    S|Blue Exorcist Cist
    S|Noragami Stray God Gam
    S|Kekkai Sensen Beyond Dawn
    S|Mononoke Monokini
    S|Natsume Yujin-Cho Cho
    S|Hozuki's Coolheadedness Heads
    S|Grimgar of Fantasy and Ash Tray
    S|No Game No Life Savers
    S|Log Horizon Hours
    S|Sword Art Online Alicization Station
    S|Accel World Wide Web
    S|The Irregular at Magic High School Reunion
    S|A Certain Magical Index Fund
    S|A Certain Scientific Railgun Gun
    S|Toaru Majutsu Majestic
    S|Fate/stay night Light
    S|Fate/Zero Hero
    S|Fate/Grand Order Orders
    S|Re:Creators Creators
    S|Date A Live Wire
    S|High School DxD x D
    S|Shimoneta Nee
    S|Prison School Bell
    S|Food Wars! Shokugeki no Soma Chilli
    S|Kuroshitsuji Shitsuji
    S|Magi: The Labyrinth of Magic Maze
    S|Akko's Little Witch Sandwich
    S|Kiki's Delivery Service Charge
    S|Puella Magi Madoka Magica Kica
    S|Magical Girl Raising Project Plan
    S|Wandering Witch: The Journey of Elaina Elena
    S|Frieren: Beyond Journey's End Notes
    S|Dungeon Meshi Mesh
    S|Solo Leveling Up
    S|Tower of God Gods
    S|The God of High School Highschool
    S|Noblesse Oblige
    S|Mashle: Magic and Muscles Flexes
    S|Black Torch Light
    S|Zom 100: Bucket List of the Dead Bucket
    S|Dandadan Dan
    S|Kaiju No. 8 Eight
    S|Bocchi the Rock Roll
    S|Lycoris Recoil Foil
    S|Cyberpunk: Edgerunners Runners
    S|Pluto Planet
    S|Blue Period Pains
    S|Skip and Loafer Loaf
    S|Horimiya Miya
    S|Wotakoi: Love Is Hard for Otaku Taku
    S|My Dress-Up Darling Dolling
    S|The Quintessential Quintuplets Quints
    S|Love, Chunibyo & Other Delusions Illusions
    S|Nisekoi False Love Lace
    S|Bakemonogatari Monogatari
    S|Monogatari Series Second Season Third Season
    S|Baccano! Bacon
    S|Durarara!! Rara
    S|Gangsta Gangster
    S|91 Days Weeks
    S|Black Lagoon Pond
    S|Hellsing Ultimate Mate
    S|Jormungand Gand
    S|Gunslinger Girl Boy
    S|Michiko & Hatchin Chin
    S|Samurai Flamenco Flamingo
    S|Zankyou no Terror Terrorism
    S|Terror in Resonance Reverb
    S|Occultic;Nine Eleven
    S|Chaos;Head Case
    S|Hyouka Hyoka
    S|Case Closed Doors
    S|Lupin III Pin
    S|Magic Kaito Kito
    S|Golden Kamuy Kamui
    S|Dororo Doro
    S|Dorohedoro Hedoro
    S|Digimon Frontier Town
    S|Yo-kai Watch Dog
    S|Beyblade Burst Bust
    S|Gatchaman Crowds Crowd
    S|Ultraman Z Zee
    S|Kamen Rider Ryder
    S|Super Sentai Sandwich
    S|Voltron Legendary Defender Tron
    S|Cardfight!! Vanguard Guard
    S|Duel Masters Mastery
    S|Mix Master King of Bakugan
    S|Rave Master Mind
    S|Zatch Bell! Belle
    S|Rurouni Kenshin: Trust and Betrayal Trust Fall
    S|Samurai X Marks the Spot
    S|Berserk of Gluttony Glutton
    S|The Rising of the Shield Hero Zero
    S|The Eminence in Shadow Garden
    S|Mushoku Tensei: Jobless Reincarnation Station
    S|The Devil Is a Part-Timer! Timer
    S|Goblin Slayer Layer
    S|Re:Monster Mash
    S|Reincarnated as a Slime Mold
    S|Youjo Senki Senkei
    S|Shield Hero Warrior
    S|Overlord Underlord
    S|Vivy: Fluorite Eye's Song Birds
    S|86 Eighty-Six Sixty Six
    S|Odd Taxi Cab
    S|Ranking of Kings Queens
    S|Summertime Render Return
    S|Link Click Clack
    S|Great Pretender Defender
    S|Ya Boy Kongming! Kong
    S|Mr. Villain's Day Off Day
    S|Spy Classroom Class
    S|Spy x Family Mission Impossible
    S|Bleach: Thousand-Year Blood War Zone
    S|Naruto: Boruto Next Generations Gen
    S|Jujutsu Kaisen 0
    S|Tokyo Revengers Revenge
    S|Dr. Slump Dunk
    S|Urusei Yatsura Yatsuri
    S|Maison Ikkoku House
    S|Fist of the North Star Wars
    S|Saint Seiya Knights of Zodiac Killer
    S|Dragon Ball Daima Time
    S|Captain Harlock Space Pirate Radio
    S|Space Battleship Yamato Won
    S|Galaxy Express 999 Pm
    S|Queen Millennia Millennium
    S|Tetsujin 28 Gou Go
    S|Mazinger Z Zee
    S|Getter Robo Go
    S|Cutey Honey Money
    S|Devilman Crybaby Boy
    S|Astro Boy Band
    S|Kimba the White Lion King
    S|Princess Knight Rider
    S|Phoenix Flame
    S|Metropolis Mall
    M|Your Name Tag
    M|Weathering with You Know Who
    M|Suzume Door
    M|The Garden of Words Wars
    M|5 Centimeters per Second Counter
    M|Children Who Chase Lost Voices Mail
    M|The Place Promised in Our Early Days Off
    M|Voices of a Distant Star Light
    M|A Silent Voice Over
    M|Liz and the Blue Bird Brain
    M|Josee, the Tiger and the Fish Fry
    M|I Want to Eat Your Pancreas Pizza
    M|Wolf Children Parent Teacher Night
    M|The Girl Who Leapt Through Time Machine
    M|Summer Wars War Games
    M|Mirai of the Future Is Now
    M|Belle and the Beast Mode
    M|Perfect Blue Moon
    M|Millennium Actress Strike
    M|Paprika Powder
    M|Paranoia Agent Smith
    M|Ghost in the Shell Shock
    M|Innocence Day
    M|Patlabor 2: The Movie Theatre
    M|Jin-Roh: The Wolf Brigade Wolves
    M|Blood Club
    M|Vampire Hunter D Bloodlust Lust
    M|Wicked City Lights
    M|Ninja Scroll Wars
    M|Metropolis Highway
    M|Steamboy Boy
    M|Memories Remember
    M|Roujin Z Zee
    M|Neo Tokyo Drift
    M|Wings of Honneamise Honey
    M|Royal Space Force Field
    M|Grave of the Fireflies Lies
    M|Only Yesterday Today
    M|My Neighbors the Yamadas Yamada
    M|The Boy and the Heron Heroine
    M|How Do You Live Alive
    M|Laputa Puta
    M|Dragon Ball Z: Battle of Gods and Goats
    M|Boruto: Naruto the Movie Theatre
    M|The Last: Naruto the Movie Premiere
    M|One Piece Film: Red Hair
    M|One Piece Film: Gold Digger
    M|One Piece Film: Strong World Wide
    M|One Piece: Stampede Horse
    M|My Hero Academia: Heroes Rising Sun
    M|Demon Slayer: Mugen Train Station
    M|Demon Slayer: Infinity Castle Sand
    M|Jujutsu Kaisen 0: The Movie Night
    M|Doraemon: Nobita's Dinosaur Rex
    M|Doraemon: Nobita and the Steel Troops Troop
    M|Crayon Shin-chan: Fierceness Gone Wrong
    M|Pokemon: The Rise of Darkrai Dark
    M|Pokemon 3: The Movie Night
    M|Sailor Moon R: The Movie Reel
    M|Sailor Moon Eternal Eternally
    M|Evangelion: 3.0+1.0 Thrice Upon a Time Machine
    M|Evangelion: Death & Rebirth Day
    M|The End of Evangelion Deva
    M|Mobile Suit Gundam: Char's Counterattack Ack
    M|Mobile Suit Gundam: Hathaway Way
    M|Fate/stay night: Heaven's Feel Good
    M|Fate/Grand Order: Camelot Cot
    M|Violet Evergarden: The Movie Theater
    M|Hotarubi no Mori e Moray
    M|Josee Josie
    M|A Letter to Momo Mama
    M|The Wind Rises Up
    M|Maquia: When the Promised Flower Blooms Bloom
    M|Bubble Bobble
    M|Inu-Oh Ohhh
    M|Mind Game Show
    M|Tekkonkinkreet Concrete
    M|Redline Rider
    M|Berserk: The Golden Age Arc Light
    M|Hellsing Ultimate Overkill
    M|Mushishi: The Next Passage Way
    M|Space Pirate Captain Harlock Hardlock
    M|Tower of the Sun
    M|Lupin III: The Castle of Cagliostro Castro
    M|Lupin III: The First Time
    M|Gatchaman Fighter Pilot
    M|Mazinger Z: Infinity Zero
    M|Cutie Honey Universe Honey
    """
}
