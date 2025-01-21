import gleam/string
import glexec as exec
import shared
import simplifile

pub type Room {
  //todo think about if we want to use a string
  //do I even want a time based thing on the server side.
  Room(key:String,queue:List(shared.Song),current:shared.Song,time:Int)
}
