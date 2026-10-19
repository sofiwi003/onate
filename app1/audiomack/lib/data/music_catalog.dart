/// Datos de demostración usados por Home y la búsqueda local.
class MusicTrack {
  const MusicTrack(this.title, this.artist, this.cover);
  final String title;
  final String artist;
  final String cover;
}

const topPicks = [
  MusicTrack('Hello', 'Adele', 'adele'),
  MusicTrack('Bailando Solo', 'Los Bunkers', 'los_bunkers'),
];
const recentlyPlayed = [
  MusicTrack('Roar', 'Katy Perry', 'katy_perry'),
  MusicTrack('Baby', 'Justin Bieber', 'justin_bieber'),
  MusicTrack('Gabriela', 'KATSEYE', 'katseye'),
];
const madeForYou = [
  ...recentlyPlayed,
  MusicTrack('Thriller', 'Michael Jackson', 'michael_jackson'),
  MusicTrack('Un verano sin ti', 'Bad Bunny', 'un_verano_sin_ti'),
  MusicTrack('Soda Stereo', 'Soda Stereo', 'soda_stereo'),
  MusicTrack('31 canciones de amor', '31 Minutos', '31_minutos'),
  MusicTrack('Beauty Behind the Madness', 'The Weeknd', 'the_weeknd'),
  MusicTrack('Mon Laferte Vol. 1', 'Mon Laferte', 'mon_laferte'),
  MusicTrack('Me gustan todas', 'Luis Miguel', 'luis_miguel'),
];
const initialTrack = MusicTrack('WELTiTA', 'Bad Bunny', 'bad_bunny');
const musicCatalog = [initialTrack, ...topPicks, ...madeForYou];
