import gleam/io
import mist
import gleam/erlang/process.{type Pid}
import gleam/option
import gleam/otp/actor




pub fn socket_init(seconds:Int) {
  fn (req) {
    mist.websocket(
      req,
        on_init:fn(conn) {
          let selector = process.new_selector()
          #(option.None,option.Some(selector))
      },
      on_close:fn(state) {
        case state {
          option.Some(pid) -> process.kill(pid)
          option.None -> Nil
        }
      },
      handler:fn(optional_pid,conn,msg) {
        case msg {
            mist.Closed | mist.Shutdown -> {
              case optional_pid {
                option.Some(pid) -> process.kill(pid)
                option.None -> Nil
              }
              actor.Stop(process.Normal)
            }
            mist.Text("client-init") -> {
            let deamon_pid = process.start(heart_beat(conn,seconds),False)

              actor.continue(option.Some(deamon_pid))
            }
            _ -> actor.continue(optional_pid)
        }
      }
    )
  }
}


pub fn heart_beat(conn,seconds) {
    process.sleep(seconds*1000) // sleep for 5 seconds
    case mist.send_text_frame(conn,"keep alive") {
      Error(_) -> {
        process.kill(process.self())
      }
      Ok(_) -> Nil
    }
    heart_beat(conn,seconds)
}
