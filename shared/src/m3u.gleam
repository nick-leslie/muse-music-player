import gleam/io
import gleam/result
import gleam/int
import gleam/string
import shared
import gleam/list
import gleam/string_tree
import gleam/otp/task

pub fn serlize(songs:List(shared.Song)) {
  let top_tree = string_tree.new()
  |> string_tree.append("#EXTM3U\n\n")
 // sets up the m3p string ormat
  list.map(songs,fn(song) {
    task.async(fn(){
      let builder =string_tree.new()
      |> string_tree.append("#EXTINF:")
      case song {
        shared.Song(_,_,_) -> string_tree.append(builder,"0")
        shared.SongWithLength(_,_,_,length) -> string_tree.append(builder,int.to_string(length))
      }
      |> string_tree.append(",")
      |> string_tree.append(song.artist)
      |> string_tree.append(" - ")
      |> string_tree.append(string.replace(song.name," - ", "-"))
      |> string_tree.append("\n")
      |> string_tree.append(song.path)
      |> string_tree.append("\n\n")
    })
  })
  |> task.try_await_all(1000)
  |> result.all()
  |> result.unwrap([])
  |> list.fold(top_tree,fn (acc_tree,tree) {
    string_tree.append_tree(acc_tree,tree)
  })
  |> string_tree.to_string()
}

pub type PlaylistDeserlizeError {
  MissingFirstTag
  BadSong(song_string:String,stage:Int)
}

pub fn deserlize(input:String) -> Result(List(shared.Song),PlaylistDeserlizeError) {
  case string.split(input,"#EXT") {
    ["","M3U\n\n" , ..rest] -> {
      list.map(rest,fn(song_string){
          use #(line1,line2) <-  result.try(result.replace_error(
            string.split(song_string,"\n")
              |> list.filter(fn (playlist_part) {string.length(playlist_part) > 0})
              |> list.combination_pairs
              |> list.first
            ,BadSong(song_string,1))
          )
          use #(_time_tag,artist_and_title) <- result.try(result.replace_error(
            string.split(line1,",")
              |> list.combination_pairs
              |> list.first
          ,BadSong(song_string,2)))

          use #(artisit,song_name) <- result.try(result.replace_error(
            string.split(artist_and_title," - ")
              |> list.combination_pairs
              |> list.first()
          ,BadSong(song_string,3)))

          Ok(shared.Song(name:song_name, artist:artisit, path:line2))
      })
      |> io.debug
      |> result.all
    }
    value -> {
      io.debug(value)
      Error(MissingFirstTag)
    }
  }
}
