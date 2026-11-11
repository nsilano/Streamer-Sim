import Foundation

extension ParodyLibrary {
    /// More local-language parodies. Format: "S|language|Name" for a series, "M|language|Name" for a movie.
    static let moreLocal = """
    S|spanish|La Casa de Papel Higiénico
    S|spanish|Élite de Cartón
    S|spanish|Las Chicas del Cable Coaxial
    S|spanish|Money Heist Mini
    S|spanish|El Ministerio del Tiempo Libre
    S|spanish|Cuéntame Cómo Pasó el Rato
    S|spanish|Médico de Familia Numerosa
    S|spanish|Aquí No Hay Quien Viva
    S|spanish|La Que Se Avecina Se Acabó
    S|spanish|Los Serrano Jamón
    S|spanish|Física o Química Orgánica
    S|spanish|El Barco Fantasma
    S|spanish|Velvet Colección
    S|spanish|Gran Hotel Paraíso
    S|spanish|Isabel la Católica Romana
    S|spanish|Narcos México City
    S|spanish|La Reina del Sur de Polonia
    S|spanish|El Señor de los Cielos Abiertos
    S|spanish|La Usurpadora Lista
    S|spanish|Rebelde Sin Causa
    S|spanish|Amores Perros Calientes
    S|spanish|Café con Aroma de Mujer
    S|spanish|Yo Soy Betty la Fea Mala
    S|spanish|Pasión de Gavilanes Gavilán
    S|spanish|El Cartel de los Sapos Ranas
    S|spanish|Rosario Tijeras Cortar
    S|spanish|Sin Tetas No Hay Paraíso Terrenal
    S|spanish|El Capo Mafioso
    S|spanish|La Casa de las Flores Secas
    S|spanish|La Familia P. Luche Leche
    S|spanish|Los Simuladores Auditores
    S|spanish|El Marginal Gain
    S|spanish|Esperanza Mía Tuya
    S|spanish|Los Protegidos del Rey
    S|spanish|Patito Feo Pato
    S|spanish|Floricienta Cenienta
    S|spanish|Violetta y Sus Amigas
    S|spanish|Chiquititas Titas
    S|spanish|El Chapulín Colorado Rojo
    S|spanish|El Chavo del Ocho Nueve
    S|spanish|La Rosa de Guadalupe y Más Rosas
    S|spanish|Mujeres Asesinas en Serie
    S|spanish|Sábado Gigante Chiquito
    S|spanish|Despacito Poco a Poco
    S|spanish|La Vida Es un Carnaval de Venecia
    S|spanish|Pedro Páramo Duro
    S|spanish|Cien Años de Soledad Compartida
    S|spanish|El Amor en los Tiempos del Cólera Morbus
    S|spanish|La Casa de los Espíritus Santos
    S|spanish|Como Agua para Chocolate Caliente
    S|spanish|El Laberinto del Fauno y la Flora
    S|spanish|El Orfanato Infantil
    S|spanish|Mar Adentro Afuera
    S|spanish|Volver al Futuro
    S|spanish|Todo Sobre Mi Madre Tierra
    S|spanish|Hable con Ella o Él
    S|spanish|Átame Desátame
    S|spanish|Torrente el Brazo Tonto de la Ley
    S|spanish|Ocho Apellidos Vascos y Catalanes
    S|spanish|Truman Ruman
    S|spanish|Relatos Salvajes y Mansos
    S|spanish|El Secreto de Sus Ojos Cerrados
    S|spanish|Nueve Reinas Rey
    S|spanish|Un Cuento Chino de Bolsillo
    S|spanish|Elsa & Fred y Ginger
    S|spanish|El Hijo de la Novia Suegra
    S|spanish|Roma Alfonso Cuarón Cuarto
    S|spanish|Gravedad Cero
    S|spanish|Coco Chanel Número 5
    M|spanish|La Casa de Papel Maché
    M|spanish|Pan's Labyrinth Español
    M|spanish|El Ministerio Público
    M|spanish|Campeones Mundiales
    M|spanish|La Llorona Llora
    M|spanish|El Libro de la Vida Loca
    M|french|Lupin Troisième
    M|french|Dix Pour Cent de Réduction
    M|french|Le Bureau des Légendes Urbaines
    M|french|Engrenages Mécaniques
    M|french|Les Revenants du Futur
    M|french|Plus Belle la Vie en Rose
    M|french|Fais Pas Ci, Fais Pas Ça
    M|french|Kaamelott Camelot
    M|french|Un Gars, Une Fille Gars
    M|french|Caméra Café Crème
    M|french|Les Visiteurs Cachés
    M|french|Intouchables Aux Doigts
    M|french|Amélie Poulain Poulet
    M|french|Le Fabuleux Destin de Cookie
    M|french|Bienvenue chez les Ch'tis Beaux
    M|french|Le Grand Bleu Marine
    M|french|Léon le Professionnel du Dimanche
    M|french|Le Cinquième Élément Chimique
    M|french|Astérix et Obélix Mission Cléopâtre Reine
    M|french|Les Choristes Choir
    M|french|Les Misérables Misère
    M|french|Mon Oncle Antoine
    M|french|Jean de Florette Fleurette
    M|french|La Gloire de Mon Père Noël
    M|french|Le Château de Ma Mère Teresa
    M|french|Portrait de la Jeune Fille en Feu Follet
    M|french|Titane Titan
    M|french|Anatomie d'une Chute Libre
    S|french|Dix Pour Cent Ou Presque
    S|french|Les Hommes de l'Ombre Portée
    S|french|Baron Noir Blanc
    S|french|Marseille Mars
    S|french|Le Chalet Ski
    S|french|Mythomaniacs Anonymes
    S|french|Plan Cœur Coeur
    S|french|Skam France Sans Cam
    S|french|Fiertés Fières
    S|german|Dark Dunkel
    S|german|Dark Matters Material
    S|german|Babylon Berlin Wand
    S|german|Deutschland 83 Bis
    S|german|Unsere Mütter, Unsere Väter Land
    S|german|Tatort Münster Wurst
    S|german|Der Tatortreiniger Reiniger
    S|german|Der Alte Hase
    S|german|Kommissar Rex Hund
    S|german|Stromberg Strom
    S|german|Dr. Stefan Frank Frei
    S|german|Lindenstraße Strasse
    S|german|Die Sendung mit der Maus Haus
    S|german|Sesamstraße Straße
    S|german|Pumuckl Muckl
    S|german|Biohackers Hackers
    S|german|Skylines Himmel
    S|german|Haus des Geldes Hauses
    S|german|Lauchhammer Hammer
    S|german|Ku'damm 56 Kuhdamm
    S|german|Charité Kirche
    S|german|Weissensee Weiß
    S|german|Das Leben der Anderen Leben
    S|german|Good Bye Lenin Leinen
    S|german|Das Wunder von Bern Bärn
    S|german|Der Untergang Aufgang
    S|german|Sophie Scholl Schule
    S|german|Fack ju Göhte Goethe
    S|german|Toni Erdmann Mann
    S|german|Systemsprenger Sprenger
    S|german|Werk ohne Autor Auto
    S|german|Zeit der Kannibalen Kaninchen
    S|german|Wickie und die Starken Männer Männchen
    S|german|Der Schuh des Manitu Manitou
    S|german|Traumschiff Surprise Schiff
    S|german|Das Traumhotel Hotel
    S|german|Rosamunde Pilcher Pilz
    S|italian|Suburra Beach
    S|italian|Il Commissario Montalbano Balbano
    S|italian|I Medici Medicine
    S|italian|La Piovra Polpo
    S|italian|Un Posto al Sole Solo
    S|italian|L'Amica Geniale Genio
    S|italian|Baby Bimbo
    S|italian|Il Giovane Papa Papà
    S|italian|Rocco Schiavone Schiavo
    S|italian|Il Paradiso delle Signore Signori
    S|italian|Che Dio Ci Aiuti Aiuta
    S|italian|Il Trono di Spade Spada
    S|italian|La Vita è Bella Bellissima
    S|italian|Roma Termini Terminale
    S|italian|Perfetti Sconosciuti Conosciuti
    S|italian|Benvenuti al Nord Sud
    S|italian|Quo Vado Dove
    S|italian|La Dolce Vita Dolce
    S|italian|Otto e Mezzo Quarto
    S|italian|Il Buono, il Brutto, il Cattivo Gatto
    S|italian|C'era una Volta il West Est
    S|italian|Per un Pugno di Dollari Dollaro
    S|portuguese|A Casa de Papel Higiênico
    S|portuguese|Dark Escuro
    S|portuguese|3% Por Cento
    S|portuguese|O Mecanismo Mecânico
    S|portuguese|Sintonia Sintonizada
    S|portuguese|Cidade Invisível Visível
    S|portuguese|Coisa Mais Linda Feia
    S|portuguese|Onisciente Ciente
    S|portuguese|Elite Brasil Brasileira
    S|portuguese|Round 6 Rodada Seis
    S|portuguese|Avenida Brasil Portugal
    S|portuguese|Mulheres Apaixonadas Raivosas
    S|portuguese|Senhora do Destino Sorte
    S|portuguese|Verdades Secretas Mentiras
    S|portuguese|Cheias de Charme Charmosas
    S|portuguese|Carrossel Cavalinho
    S|portuguese|A Grande Família Pequena
    S|portuguese|Sítio do Picapau Amarelo Azul
    S|portuguese|Castelo Rá-Tim-Bum Bum
    S|portuguese|Cidade de Deus Dos Homens
    S|portuguese|Que Horas Ela Volta Vai
    S|portuguese|O Auto da Compadecida Comadre
    S|portuguese|Dona Flor e Seus Dois Maridos Flores
    S|portuguese|Bacurau Bacu
    S|portuguese|Aquarius Aquário
    S|portuguese|O Som ao Redor Silêncio
    S|japanese|Terrace House Casa
    S|japanese|Midnight Diner Dinner
    S|japanese|Alice in Borderland Bordado
    S|japanese|Gokusen Sen
    S|japanese|Hotaru no Hikari Luz
    S|japanese|Long Vacation Vocation
    S|japanese|Beautiful Life Vida
    S|japanese|Asadora Asa
    S|japanese|Gachinko Gachi
    S|japanese|Takeshi's Castle Fortaleza
    S|japanese|Iron Chef Iron Chef
    S|japanese|Shokugeki Plato
    S|japanese|Sparrow's Nest Nido
    S|japanese|Shiroi Kyotō Torre
    S|japanese|Ultraman Raman
    S|japanese|Godzilla Singular Point Punto
    S|japanese|Shin Godzilla Gojira
    S|japanese|Shin Ultraman Uru
    S|japanese|Departures Okuribito
    S|japanese|Shoplifters Manbiki
    S|japanese|Still Walking Caminando
    S|japanese|Like Father Like Son Hijo
    S|korean|Squid Game Games
    S|korean|Crash Landing on You Me
    S|korean|Descendants of the Sun Moon
    S|korean|Hotel del Luna Sun
    S|korean|Itaewon Class Classe
    S|korean|Sky Castle Cielo
    S|korean|Reply 1988 1989
    S|korean|My Love from the Star Estrella
    S|korean|Boys Over Flowers Girls
    S|korean|Coffee Prince Princess
    S|korean|Winter Sonata Autumn
    S|korean|Full House Casa
    S|korean|Dae Jang Geum Jang
    S|korean|Jewel in the Palace Joya
    S|korean|Moon Embracing the Sun Embrace
    S|korean|Mr. Sunshine Sunny
    S|korean|Kingdom Reino
    S|korean|All of Us Are Dead Alive
    S|korean|Sweet Home Hogar
    S|korean|Hellbound Libre
    S|korean|The Glory Gloria
    S|korean|Vincenzo Vicenzo
    S|korean|Extraordinary Attorney Woo Moo
    S|korean|Reply 1997 Respuesta
    S|korean|Misaeng Vida
    S|korean|Signal Señal
    S|korean|Stranger Bosque
    S|korean|Secret Forest Bosque
    S|korean|Healer Sanador
    S|korean|It's Okay to Not Be Okay Fine
    S|korean|Hospital Playlist Lista
    S|korean|Reply 1994 Respuesta
    S|korean|Weightlifting Fairy Kim Bok-joo Joo
    S|korean|Business Proposal Propuesta
    S|korean|Twenty-Five Twenty-One Veinte
    S|korean|Our Blues Azules
    S|korean|Parasite Parásito
    S|korean|Oldboy Viejo
    S|korean|Train to Busan Pusan
    S|korean|The Handmaiden Doncella
    S|korean|Memories of Murder Memorias
    S|korean|The Host Anfitrión
    S|korean|Snowpiercer Piercer
    S|korean|Okja Oks
    S|korean|Burning Quemar
    S|korean|Decision to Leave Dejar
    S|korean|Mother Madre
    S|korean|Peppermint Candy Caramelo
    S|korean|My Sassy Girl Chica
    S|korean|A Taxi Driver Conductor
    S|korean|The Wailing Lamento
    S|korean|The Chaser Perseguidor
    S|korean|I Saw the Devil Vi
    S|korean|A Tale of Two Sisters Hermanas
    S|hindi|Sacred Games Sagrado
    S|hindi|Mirzapur Mirza
    S|hindi|Delhi Crime Delito
    S|hindi|Paatal Lok Mundo
    S|hindi|The Family Man Hombre
    S|hindi|Panchayat Panchayati
    S|hindi|Kota Factory Fábrica
    S|hindi|Gullak Alcancía
    S|hindi|Asur Demonio
    S|hindi|Aspirants Aspirantes
    S|hindi|Scam 1992 Estafa
    S|hindi|Made in Heaven Cielo
    S|hindi|Sacred Games Dos
    S|hindi|Kaun Banega Crorepati Rico
    S|hindi|Balika Vadhu Novia
    S|hindi|Taarak Mehta Ka Ooltah Chashmah Chasma
    S|hindi|CID Sid
    S|hindi|Ramayan Rama
    S|hindi|Mahabharat Mahabharata
    S|hindi|Chanakya Canakia
    S|hindi|Malgudi Days Dias
    S|hindi|Byomkesh Bakshi Baksh
    S|hindi|Shaktimaan Shaktiman
    S|hindi|Dilwale Dulhania Le Jayenge Novia
    S|hindi|Kabhi Khushi Kabhie Gham Gam
    S|hindi|Lagaan Impuesto
    S|hindi|3 Idiots Tres
    S|hindi|Dangal Dang
    S|hindi|Bajrangi Bhaijaan Hermano
    S|hindi|Sultan Sultán
    S|hindi|Baahubali Bahubali
    S|hindi|RRR Triple
    S|hindi|Pushpa Pushpita
    S|hindi|Kantara Cantar
    S|hindi|Drishyam Visual
    S|hindi|Andhadhun Ciego
    S|hindi|Tumbbad Tumba
    S|hindi|Gully Boy Calle
    S|hindi|Queen Reina
    S|hindi|Barfi Bar
    S|hindi|Rang De Basanti Pinta
    S|hindi|Swades Patria
    S|hindi|Chak De India Ahora
    S|hindi|Zindagi Na Milegi Dobara Vida
    S|hindi|Dil Chahta Hai Corazón
    S|hindi|Devdas Dev
    S|hindi|Mughal-e-Azam Gran
    S|hindi|Sholay Llamas
    S|hindi|Mother India Madre
    S|hindi|Pyaasa Sediento
    S|hindi|Guide Guía
    S|turkish|Diriliş Ertuğrul Ertugrul
    S|turkish|Kurulus Osman Osmán
    S|turkish|Kara Sevda Negro
    S|turkish|Çukur Pozo
    S|turkish|Bir Zamanlar Çukurova Çukur
    S|turkish|Gönül Dağı Dağ
    S|turkish|Yargı Juicio
    S|turkish|Ezel Ezelito
    S|turkish|Kurtlar Vadisi Valle
    S|turkish|Mercimek Lentil
    S|turkish|Binbir Gece Noches
    S|turkish|Dolunay Luna
    S|turkish|Sen Çal Kapımı Puerta
    S|turkish|Erkenci Kuş Pájaro
    S|turkish|Bir Başkadır Başka
    S|turkish|Kağıttan Hayatlar Papel
    S|turkish|Babam ve Oğlum Hijo
    S|turkish|Recep İvedik Rep
    S|turkish|G.O.R.A. Gora
    S|turkish|Yeşilçam Yesilcam
    S|dutch|Penoza Penzoa
    S|dutch|Flikken Maastricht Maastrich
    S|dutch|Baantjer Baantje
    S|dutch|Gooische Vrouwen Gooi
    S|dutch|Het Klokhuis Klok
    S|dutch|Expeditie Robinson Robin
    S|dutch|Sinterklaasjournaal Journaal
    S|dutch|Penoza Pennoza
    S|dutch|Suspects Suspect
    S|dutch|Undercover Overdekt
    S|dutch|De Overname Over
    S|dutch|Dertigers Dertig
    S|dutch|Fawlty Towers Nederland
    S|dutch|Karakter Karaktertje
    S|dutch|Zwartboek Boek
    S|dutch|Spoorloos Sporen
    S|dutch|Gooische Vrouwen De Film
    S|polish|Wiedźmin Wiedźma
    S|polish|Rodzinka.pl Rodzinka
    S|polish|Na Wspólnej Wspólna
    S|polish|Barwy Szczęścia Szczęście
    S|polish|Ranczo Rancho
    S|polish|Alternatywy 4 Cztery
    S|polish|Kiepscy Kiepski
    S|polish|Pod Mocnym Aniołem Aniołek
    S|polish|Zimna Wojna Wojenka
    S|polish|Pianista Pianino
    S|polish|Ogniem i Mieczem Miecz
    S|polish|Krzyżacy Krzyż
    S|polish|Faraon Faraonek
    S|polish|Znachor Znachorek
    S|polish|Seksmisja Seks
    S|arabic|Bab Al-Hara Hara
    S|arabic|Ramez Qalb Al-Asad Asad
    S|arabic|Bint Al-Shahbandar Shahbandar
    S|arabic|Hadouta Masreya Masri
    S|arabic|Wadjda Wajda
    S|arabic|Yacoubian Building Yaqoubian
    S|swedish|Bonusfamiljen Bonus
    S|swedish|Vikings Vikingar
    S|swedish|Caliphate Kalifat
    S|swedish|Quicksand Kvicksand
    S|swedish|Young Royals Kungliga
    S|swedish|The Hunt Jakten
    S|swedish|Let the Right One In Rätta
    S|swedish|Smultronstället Smultron
    S|swedish|Det Sjunde Inseglet Sjunde
    S|swedish|Triangle of Sadness Sorg
    S|swedish|Bullerbyn Bullerby
    S|danish|Borgen Borgå
    S|danish|The Killing Dræbt
    S|danish|The Bridge Broen
    S|danish|Riget Rige
    S|danish|Forbrydelsen Forbryder
    S|danish|Follow the Money Penge
    S|danish|Ragnarok Ragna
    S|danish|The Rain Regn
    S|danish|Adam's Apples Æbler
    S|danish|Another Round Runde
    S|danish|The Hunt Jagten
    S|danish|Festen Fest
    S|danish|Babette's Feast Fest
    S|danish|Melancholia Melankoli
    S|danish|Antichrist Antikrist
    S|danish|Nymphomaniac Nymfoman
    S|norwegian|Lilyhammer Lilleham
    S|norwegian|Occupied Besatt
    S|norwegian|Doktor Proktors Prompepulver Pulver
    S|norwegian|Headhunters Hodejegere
    S|norwegian|Flåklypa Grand Prix Flå
    S|finnish|Bordertown Rajakaupunki
    S|finnish|Deadwind Kuollut
    S|finnish|Aallonmurtaja Aalto
    S|finnish|The Man Without a Past Mies
    S|finnish|Leningrad Cowboys Go America Cow
    S|finnish|Fallen Leaves Lehdet
    S|czech|Most! Most
    S|czech|Slunce, seno, jahody Seno
    S|czech|Ordinace v růžové zahradě Zahrada
    S|czech|Comeback Návrat
    S|greek|Mamma Mia Greek Mama
    S|greek|Dogtooth Kynodontas
    S|greek|The Lobster Astakos
    S|greek|Zorba the Greek Zorbas
    S|greek|Never on Sunday Ποτέ
    S|greek|Z Zeta
    S|greek|My Big Fat Greek Wedding Gamos
    S|romanian|4 Months, 3 Weeks and 2 Days Zile
    S|romanian|Police, Adjective Politist
    S|romanian|Toni Erdmann Romania
    S|romanian|Aferim! Aferim
    S|romanian|Bad Luck Banging Ghinion
    S|hebrew|Tehran Teheran
    S|hebrew|When Heroes Fly Heroes
    S|hebrew|Waltz with Bashir Vals
    S|vietnamese|Cô Ba Sài Gòn Sài
    S|vietnamese|Tiệc Trăng Máu Trăng
    S|vietnamese|The Scent of Green Papaya Đu Đủ
    S|vietnamese|Cyclo Xích Lô
    S|thai|Ong-Bak Ong
    S|thai|Tom-Yum-Goong Goong
    S|thai|Uncle Boonmee Boonme
    S|indonesian|Satan's Slaves Setan
    """
}
