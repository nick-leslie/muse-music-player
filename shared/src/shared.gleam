import gleam/json
import gleam/io
import gleam/dynamic
import decode/zero


pub type Song  {
  Song(name:String,path:String)
}

pub fn decode_song(data:dynamic.Dynamic) {
  let decoder = {
    use name <- zero.field("name",zero.string)
    use path <- zero.field("path",zero.string)
    zero.success(Song(name,path))
  }
  zero.run(data,decoder)
 }

 pub fn encode_song(song:Song) {
   json.object([
     #("name",json.string(song.name)),
     #("path",json.string(song.path))
   ])
 }

 pub fn song_is_equal(a_song:Song,b_song:Song) {
   a_song.name == b_song.name
 }
