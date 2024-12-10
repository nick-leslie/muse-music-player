import gleam/json
import gleam/io
import gleam/dynamic
import decode/zero
import gleam/dict


pub type Song  {
  Song(name:String,path:String,artist:String)
  SongWithLength(name:String,path:String,artist:String,length:Int)
}

pub type Playlist {
  Playlist(name:String,path:String,songs:List(Song))
}

pub fn decode_playlist(data:dynamic.Dynamic) {
  let decoder = {
    use name <- zero.field("name",zero.string)
    use path <- zero.field("path",zero.string)
    use songs <- zero.field("songs",zero.list(zero.new_primitive_decoder(decode_song,Song("","",""))))
    zero.success(Playlist(name,path,songs))
  }
  zero.run(data,decoder)
 }


pub fn decode_song(data:dynamic.Dynamic) {
  let decoder = {
    use name <- zero.field("name",zero.string)
    use path <- zero.field("path",zero.string)
    use artist <- zero.field("artist",zero.string)
    zero.success(Song(name,path,artist))
  }
  zero.run(data,decoder)
 }

pub fn decode_float(data:dynamic.Dynamic,feild:string) {
  let decoder = {
    use value <- zero.field(feild,zero.float)
    zero.success(value)
  }
  zero.run(data,decoder)
}



 pub fn encode_song(song:Song) {
   json.object([
     #("name",json.string(song.name)),
     #("path",json.string(song.path)),
     #("artist",json.string(song.artist))
   ])
 }

 pub fn song_is_equal(a_song:Song,b_song:Song) {
   a_song.name == b_song.name
 }
