import gleam/string

import glexec as exec
import shared
import simplifile
import frontend.{type Model,starting_vol}

pub fn encode_song(room:Room,song:shared.Song) {
  let assert Ok(ffmpeg) = exec.find_executable("ffmpeg")
  //todo check if we can cust write to std out
  let assert Ok(exec.Pids(_pid, ospid)) =
    exec.new()
    |> exec.with_stdin(exec.StdinPipe)
    |> exec.with_stdout(exec.StdoutCapture)
    |> exec.with_stderr(exec.StderrStdout)
    |> exec.with_stderr(exec.StderrStdout)
    |> exec.with_monitor(True)
    |> exec.with_pty(True)
    |> exec.run_async(exec.Execve([ffmpeg,"-i",song.path,"-f segment -segment_format mpegts -segment_time 10","-segment_list audio_pl.m3u8",string.append(room.path,string.append(song.name,"%05d.ts"))]))

  let assert Ok(out) = exec.obtain(500)
  // let assert Ok(Nil) = exec.send(ospid, "test\n")
  // let assert Ok(exec.ObtainStdout(_, "test\r\n")) = exec.obtain(500)
  let assert Ok(Nil) = exec.kill_ospid(ospid, 9)
}
type Room {
  RoomFileSystem(name:String,path:String,state:Model)
}

pub fn create_room_filesystem(name:String) {
  //create dir for room
  string.append("./",name)
  |> simplifile.create_directory


}

//steps for stream
//split into hls
// serve hls
// keep track of current segment for user
// delete after long perioud of time
//
// ffmpeg \
//         -i hello.opus \
//         -f segment -segment_format mpegts -segment_time 10 \
//         -segment_list audio_pl.m3u8 \
//         audio_segment%05d.ts

        // -vn -ac 2 -acodec aac \
