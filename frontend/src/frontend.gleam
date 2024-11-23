import gleam/float
import gleam/queue
import gleam/io
import gleam/list
import shared
import lustre/element/html
import gleam/dynamic
import gleam/int
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import plinth/browser/document
import plinth/browser/element as browser_element
import lustre/event
import gleam/dict
import gleam/uri
import gleam/option.{Some,None}
import gleam/string
import gleam/json
pub const starting_vol:Float = 0.2

pub fn main() {
  let assert Ok(json_string) =
    document.query_selector("#model")
    |> result.map(browser_element.inner_text)

  //todo could do loading
  let inital_play_list =
    json.decode(json_string, dynamic.list(shared.decode_song))
    |> result.unwrap([]) |> list.map(fn(song) { #(song.name,song)}) |> dict.from_list()

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", inital_play_list)
}

fn init(inital_play_list) -> #(Model, Effect(Msg)) {
  document_audio("audio-controls") |> set_volume(starting_vol)
  #(Model(inital_play_list,[],starting_vol,"",False,False,False),effect.none())
}

pub type Model {
  Model(
    songs:dict.Dict(String,shared.Song),
    queue:List(shared.Song),
    volume:Float,
    search:String,
    is_playing:Bool,
    is_looping:Bool,
    is_infinite:Bool
  )
}

pub type Msg {
  Play(shared.Song)
  Resume
  Pause
  SetVol(vol:option.Option(Float))
  SearchLibrary(String)
  End
  Skip(option.Option(shared.Song))
  Loop(should:Bool)
  Infinite(should:Bool)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Play(song) -> {
      #(Model(..model,queue:list.append(model.queue,[song])),effect.none())
    }
    Resume -> {
      set_playing(document_audio("audio-controls"),True)
      #(Model(..model,is_playing:True),effect.none())
    }
    Pause -> {
      set_playing(document_audio("audio-controls"),False)
      #(Model(..model,is_playing:False),effect.none())
    }
    SetVol(vol) -> {
      case vol {
        Some(vol) -> {
          set_volume(document_audio("audio-controls"),vol)
          #(Model(..model,volume:vol),effect.none())
        }
        None -> {
          let vol = document_audio("audio-controls").volume
          #(Model(..model,volume:vol),effect.none())
        }
      }
    }
    SearchLibrary(value) -> {
      io.debug(value)
      #(Model(..model,search:value),effect.none())
    }
    Skip(optional_song) -> skip(model,optional_song)
    End -> {
      io.debug(model.is_looping)
      io.debug(model.is_infinite)

      case model.is_looping {
        True -> #(model,effect.none())
        False -> skip(model,None)
      }
    }
    Loop(should) -> {
      #(Model(..model,is_looping:should),effect.none())
    }
    Infinite(should) -> {
      #(Model(..model,is_infinite:should),effect.none())
    }
  }
}

fn skip(model,optional_song) {
  io.debug(model)
  case optional_song {
    Some(song) -> #(Model(..model,queue:list.filter(model.queue,fn(queue_song) { !shared.song_is_equal(song,queue_song) })),effect.none())
    None -> {
      let new_queue = list.drop(model.queue,1)
      io.debug(new_queue)
      case list.first(new_queue) {
        Ok(song) ->  {
          set_src(document_audio("audio-controls"),song_src(song))
          #(Model(..model,queue:new_queue),effect.none())
        }
        Error(_) -> {
          case model.is_infinite {
            False-> {
              reset_audio(document_audio("audio-controls"))
              #(Model(..model,queue:new_queue),effect.none())
            }
            True -> {
              io.debug(model.queue)
              let songs = dict.values(model.songs)
              let songs = list.drop(songs,int.random(list.length(songs)))
              io.debug("below should be all songs with the start cut off")
              io.debug(songs)
              case songs {
                [song,..] -> {
                  let new_queue = [song]
                  set_src(document_audio("audio-controls"),song_src(song))
                  #(Model(..model,queue:new_queue),effect.none())
                }
                [] -> {
                  let assert Ok(song) = list.first(songs)
                  set_src(document_audio("audio-controls"),song_src(song))
                  #(Model(..model,queue:[song]),effect.none())
                }
              }
            }
          }
        }
      }
    }
  }
}



pub fn song_view(song:shared.Song) {
  html.div([],[
    html.h2([],[html.text(song.name)]),
    html.button([event.on_click(Play(song))],[
      html.text("Play!!!")
    ])
  ])
}

//todo figure out this css
pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("px-5 h-screen flex flex-row gap-5")],[
    queue_view(model),
    html.div([attribute.class("flex flex-col")],[
      search_view(),
      html.div([attribute.class("grid grid-cols-6 gap-5 overflow-y-scroll")],
        dict.values(model.songs)
        |> list.filter(fn(song) {
            song_filter(song,model.search)
        })
        |> list.map(song_view)
      ),
      control_pannel(model),
    ]),
  ])
}

fn song_filter(song:shared.Song,current_search:String) -> Bool {
  //todo generate similar strings
  string.contains(string.lowercase(song.name),string.lowercase(current_search))
}
//search todo

pub fn search_view() -> Element(Msg) {
  html.div([attribute.class("w-full p-2")],[
    html.input([attribute.class("w-full rounded-lg p-2 border-2"),attribute.placeholder("Search"), event.on_input(fn(value) {
        SearchLibrary(value)
    })])
  ])
}

//----- controlls todo

//todo add space to pause
//todo add margin make pretty

pub fn on_end() {
  use _ <- attribute.on("ended")
  Ok(End)
}

pub fn on_vol_change() {
  use _ <- attribute.on("volumechange")
  Ok(SetVol(None))
}

pub fn control_pannel(model: Model) -> element.Element(Msg) {
  io.debug("re render")
  let song = list.first(model.queue)
  html.div([attribute.class("sticky top-[100vh]")],[
    html.div([attribute.class("flex flex-row gap-5")],[
      html.button([event.on_click(SetVol(Some(model.volume +. 0.01)))],[html.text("+")]),
      html.div([],[html.text(float.to_string(model.volume))]),
      html.button([event.on_click(SetVol(Some(model.volume -. 0.01)))],[html.text("-")]),
      html.button([event.on_click(Skip(None))],[html.text("skip")]),
      html.button([event.on_click(Loop(!model.is_looping))],[
        html.text("loop")
      ]),
      html.button([event.on_click(Infinite(!model.is_infinite))],[
        html.text("infinite")
      ])
      // play_pause(model)
    ]),
    case song {
      Ok(song) -> html.div([],[
        html.h1([],[html.text(string.append("now playing: ",song.name))]),
      ])
      Error(_) -> html.div([],[html.text("please select play song")])
    },
    html.audio([
      on_end()
      ,on_vol_change()
      ,attribute.id("audio-controls")
      ,attribute.loop(model.is_looping)
      ,attribute.autoplay(True)
      ,attribute.controls(True)
      ,add_song_src(song)
      ],[])
    ])
}

fn play_pause(model:Model) {
  case model.is_playing {
    True -> html.button([event.on_click(Pause)],[html.text("pause")])
    False -> html.button([event.on_click(Resume)],[html.text("play")])
  }
}

//
fn add_song_src(song:Result(shared.Song,Nil))  {
  case song {
    Ok(song) ->  attribute.src(song_src(song))
    Error(_) -> attribute.none()
  }
}


fn queue_view(model:Model) {
  html.div([attribute.class("flex flex-col gap-2 h-full basis-1/4")],[
    html.text("queue"),
    html.div([attribute.class("flex flex-col gap-2")],list.index_map(model.queue,fn(song,i) {
      html.div([],[
        html.div([],[
          html.text(string.append(int.to_string(i+1),". ")),
          html.text(song.name),
        ]),
        html.button([event.on_click(Skip(Some(song)))],[html.text("skip")])
      ])
    }))
  ])
}

fn song_src(song:shared.Song) {
  string.append("/song/" ,uri.percent_encode(song.name))
}

type Audio {
  Audio(volume:Float)
}

@external(javascript, "./audio.mjs", "audio")
fn audio() -> Audio

@external(javascript, "./audio.mjs", "documentAudio")
fn document_audio(id:String) -> Audio

@external(javascript, "./audio.mjs", "debugAudio")
fn debug_audio(audio:Audio) -> Audio

@external(javascript, "./audio.mjs", "setVolume")
fn set_volume(audio:Audio,volume:Float) -> Audio

@external(javascript, "./audio.mjs", "setVolume")
fn set_playing(audio:Audio,playing:Bool) -> Audio

@external(javascript, "./audio.mjs", "setSrc")
fn set_src(audio:Audio,song:String) -> Audio

@external(javascript, "./audio.mjs", "resetAudio")
fn reset_audio(audio:Audio) -> Audio
