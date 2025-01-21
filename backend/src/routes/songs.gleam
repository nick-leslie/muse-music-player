import gleam/list
import gleam/bytes_tree
import gleam/result
import gleam/string_tree
import gleam/string
import gleam/io
import shared
import glexec as exec
import wisp

pub fn create_image_thumbnail(song:shared.Song) {
  io.debug(song)
  //ffmpeg -i input.opus -an -c copy -f image2pipe -vcodec mjpeg -
  let assert Ok(ffmpeg) = exec.find_executable("ffmpeg")
  //todo check if we can cust write to std out
  let song_path = string_tree.new() |> string_tree.append("\"") |> string_tree.append(song.path) |> string_tree.append("\"") |> string_tree.to_string()
  //ffmpeg -i input.opus -map 0:v:0 -c:v png -f image2pipe -
  let command = string.join([ffmpeg,"-i",song_path,"-map","0:v:0","-c:v","png","-f","image2pipe","-"]," ") |> io.debug
  // let assert Ok(exec.Pids(_pid, ospid)) =
  exec.new()
  |> exec.with_stdin(exec.StdinPipe)
  |> exec.with_stdout(exec.StdoutCapture)
  // |> exec.with_stderr(exec.StderrStdout)
  |> exec.with_monitor(True)
  |> exec.with_pty(True)
  |> exec.run_sync(exec.Shell(command))
  |> result.map(fn(output) {
    case output {
      exec.Output(data) ->{
        //todo this sucks I hate the way this lib was designed
        case data {
          [] -> todo
          [data] -> {
            case data {
              exec.Stderr(_) -> todo
              exec.Stdout(data) -> list.fold(data,bytes_tree.new(),fn(tree,value) {
                bytes_tree.append_string(tree,value)

              })
            }
          }
          [_, ..] -> todo
        }

      }
    }
  })
  |> io.debug()
}


pub fn serve_song(song:shared.Song) {
  // todo move playback serverside
  wisp.ok()
  |> wisp.file_download(song.name,song.path)
}

pub fn serve_thumbnail(song:shared.Song) {
  case create_image_thumbnail(song) {
    Ok(data) -> {
      wisp.ok()
      |> wisp.set_header("content-type", "image/png")
      |> wisp.set_body(wisp.Bytes(data))
    }
    Error(_) -> wisp.internal_server_error()
  }
}
