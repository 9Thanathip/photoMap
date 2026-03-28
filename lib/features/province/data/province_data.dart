class Province {
  const Province({required this.name, required this.region, required this.emoji});

  final String name;
  final String region;
  final String emoji;
}

const List<Province> thaiProvinces = [
  // North
  Province(name: 'Chiang Mai', region: 'North', emoji: '🏔️'),
  Province(name: 'Chiang Rai', region: 'North', emoji: '🌿'),
  Province(name: 'Lamphun', region: 'North', emoji: '🌸'),
  Province(name: 'Lampang', region: 'North', emoji: '🐘'),
  Province(name: 'Uttaradit', region: 'North', emoji: '🌾'),
  Province(name: 'Phrae', region: 'North', emoji: '🪵'),
  Province(name: 'Nan', region: 'North', emoji: '🎋'),
  Province(name: 'Phayao', region: 'North', emoji: '🦢'),
  Province(name: 'Mae Hong Son', region: 'North', emoji: '🌫️'),
  Province(name: 'Sukhothai', region: 'North', emoji: '🏛️'),
  Province(name: 'Tak', region: 'North', emoji: '🌊'),
  Province(name: 'Phichit', region: 'North', emoji: '🌺'),
  Province(name: 'Phitsanulok', region: 'North', emoji: '🙏'),
  Province(name: 'Kamphaeng Phet', region: 'North', emoji: '🗿'),
  Province(name: 'Phetchabun', region: 'North', emoji: '☕'),
  Province(name: 'Uthai Thani', region: 'North', emoji: '🌻'),

  // Northeast (Isan)
  Province(name: 'Nakhon Ratchasima', region: 'Northeast', emoji: '🦖'),
  Province(name: 'Buriram', region: 'Northeast', emoji: '⚽'),
  Province(name: 'Surin', region: 'Northeast', emoji: '🐘'),
  Province(name: 'Si Sa Ket', region: 'Northeast', emoji: '🌾'),
  Province(name: 'Ubon Ratchathani', region: 'Northeast', emoji: '🕯️'),
  Province(name: 'Yasothon', region: 'Northeast', emoji: '🚀'),
  Province(name: 'Chaiyaphum', region: 'Northeast', emoji: '🌺'),
  Province(name: 'Amnat Charoen', region: 'Northeast', emoji: '🌿'),
  Province(name: 'Bueng Kan', region: 'Northeast', emoji: '🦅'),
  Province(name: 'Nong Bua Lamphu', region: 'Northeast', emoji: '🌸'),
  Province(name: 'Khon Kaen', region: 'Northeast', emoji: '🎓'),
  Province(name: 'Udon Thani', region: 'Northeast', emoji: '🏺'),
  Province(name: 'Loei', region: 'Northeast', emoji: '🌡️'),
  Province(name: 'Nong Khai', region: 'Northeast', emoji: '🌉'),
  Province(name: 'Maha Sarakham', region: 'Northeast', emoji: '🌱'),
  Province(name: 'Roi Et', region: 'Northeast', emoji: '🌙'),
  Province(name: 'Kalasin', region: 'Northeast', emoji: '🦕'),
  Province(name: 'Sakon Nakhon', region: 'Northeast', emoji: '🏯'),
  Province(name: 'Nakhon Phanom', region: 'Northeast', emoji: '🎆'),
  Province(name: 'Mukdahan', region: 'Northeast', emoji: '🌅'),

  // Central
  Province(name: 'Bangkok', region: 'Central', emoji: '🏙️'),
  Province(name: 'Nonthaburi', region: 'Central', emoji: '🌆'),
  Province(name: 'Pathum Thani', region: 'Central', emoji: '🏫'),
  Province(name: 'Samut Prakan', region: 'Central', emoji: '🚢'),
  Province(name: 'Nakhon Nayok', region: 'Central', emoji: '🌊'),
  Province(name: 'Chachoengsao', region: 'Central', emoji: '🐊'),
  Province(name: 'Phra Nakhon Si Ayutthaya', region: 'Central', emoji: '🏛️'),
  Province(name: 'Ang Thong', region: 'Central', emoji: '🍊'),
  Province(name: 'Lop Buri', region: 'Central', emoji: '🐒'),
  Province(name: 'Sing Buri', region: 'Central', emoji: '⚓'),
  Province(name: 'Chainat', region: 'Central', emoji: '🌾'),
  Province(name: 'Saraburi', region: 'Central', emoji: '🌻'),
  Province(name: 'Nakhon Pathom', region: 'Central', emoji: '🕌'),
  Province(name: 'Samut Sakhon', region: 'Central', emoji: '🦐'),
  Province(name: 'Samut Songkhram', region: 'Central', emoji: '🌹'),
  Province(name: 'Ratchaburi', region: 'Central', emoji: '🏺'),
  Province(name: 'Kanchanaburi', region: 'Central', emoji: '🌉'),
  Province(name: 'Suphan Buri', region: 'Central', emoji: '🦆'),
  Province(name: 'Prachin Buri', region: 'Central', emoji: '🌿'),
  Province(name: 'Sa Kaeo', region: 'Central', emoji: '🦎'),

  // East
  Province(name: 'Chonburi', region: 'East', emoji: '🏖️'),
  Province(name: 'Rayong', region: 'East', emoji: '🍍'),
  Province(name: 'Chanthaburi', region: 'East', emoji: '💎'),
  Province(name: 'Trat', region: 'East', emoji: '🏝️'),

  // West
  Province(name: 'Phetchaburi', region: 'West', emoji: '🌊'),
  Province(name: 'Prachuap Khiri Khan', region: 'West', emoji: '🐬'),

  // South
  Province(name: 'Chumphon', region: 'South', emoji: '🦞'),
  Province(name: 'Surat Thani', region: 'South', emoji: '🌴'),
  Province(name: 'Ranong', region: 'South', emoji: '🌧️'),
  Province(name: 'Nakhon Si Thammarat', region: 'South', emoji: '🐘'),
  Province(name: 'Phang Nga', region: 'South', emoji: '🧗'),
  Province(name: 'Krabi', region: 'South', emoji: '🪨'),
  Province(name: 'Phuket', region: 'South', emoji: '🏄'),
  Province(name: 'Trang', region: 'South', emoji: '🦭'),
  Province(name: 'Phatthalung', region: 'South', emoji: '🦜'),
  Province(name: 'Satun', region: 'South', emoji: '🐢'),
  Province(name: 'Songkhla', region: 'South', emoji: '🐟'),
  Province(name: 'Pattani', region: 'South', emoji: '🕌'),
  Province(name: 'Yala', region: 'South', emoji: '🌙'),
  Province(name: 'Narathiwat', region: 'South', emoji: '🌊'),
];
