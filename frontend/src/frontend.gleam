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
const starting_vol:Float = 0.2

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
  #(Model(inital_play_list,init_controls()),effect.none())
}

pub type Model {
  Model(
    songs:dict.Dict(String,shared.Song),
    controls:Controls
  )
}

pub type Controls {
  Controls(
    queue:List(shared.Song),
    volume:Float,
    search:String
  )
}

pub fn init_controls() {
  Controls([],starting_vol,"")
}

pub type Msg {
  Play(shared.Song)
  End
  IncreaseVol(by:Float)
  DecreaseVol(by:Float)
  SearchLibrary(String)
  Skip(option.Option(shared.Song))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Play(song) -> {
      document_audio("audio-controls") |> io.debug |> debug_audio
      #(Model(..model,controls:Controls(..model.controls,queue:list.append(model.controls.queue,[song]))),effect.none())
    }
    End ->  #(Model(..model,controls:Controls(..model.controls,queue:list.drop(model.controls.queue,1))),effect.none())
    IncreaseVol(by) -> {
      let vol = model.controls.volume +. by
      set_volume(document_audio("audio-controls"),vol)
      #(Model(..model,controls:Controls(..model.controls,volume:vol)), effect.none())
    }
    DecreaseVol(by) -> {
      let vol = model.controls.volume -. by
      set_volume(document_audio("audio-controls"),vol)
      #(Model(..model,controls:Controls(..model.controls,volume:vol)), effect.none())
    }
    SearchLibrary(value) -> {
      io.debug(value)
      #(Model(..model,controls:Controls(..model.controls,search:value)),effect.none())
    }
    Skip(optional_song) -> {
      case optional_song {
        Some(song) -> #(Model(..model,controls:Controls(..model.controls,queue:list.filter(model.controls.queue,fn(queue_song) { !shared.song_is_equal(song,queue_song) }))),effect.none())
        None -> {
          let new_queue = list.drop(model.controls.queue,1)
          case list.first(new_queue) {
            Ok(song) ->  set_src(document_audio("audio-controls"),song_src(song))
            Error(_) ->  reset_audio(document_audio("audio-controls"))
          }
          #(Model(..model,controls:Controls(..model.controls,queue:new_queue)),effect.none())
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
      search_view(model),
      html.div([attribute.class("grid grid-cols-6 gap-5 overflow-y-scroll")],
        dict.values(model.songs)
        |> list.filter(fn(song) {
              song_filter(song,model.controls.search)
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

pub fn search_view(model: Model) -> Element(Msg) {
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

pub fn control_pannel(model: Model) -> element.Element(Msg) {
  io.debug("re render")
  let song = list.first(model.controls.queue)
  html.div([attribute.class("sticky top-[100vh]")],[
    html.div([attribute.class("flex flex-row")],[
      html.button([event.on_click(IncreaseVol(0.1))],[html.text("+")]),
      html.div([],[html.text(float.to_string(model.controls.volume))]),
      html.button([event.on_click(DecreaseVol(0.1))],[html.text("-")]),
      html.button([event.on_click(Skip(None))],[html.text("skip")]),
    ]),
    case song {
      Ok(song) -> html.div([],[
        html.h1([],[html.text(string.append("now playing:",song.name))]),
      ])
      Error(_) -> html.div([],[html.text("please select play song")])
    },
    html.audio([
      on_end()
      ,attribute.id("audio-controls")
      ,attribute.autoplay(True)
      ,attribute.controls(True)
      ,add_song_src(song)
      ],[])
    ])
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
    html.div([attribute.class("flex flex-col gap-2")],list.index_map(model.controls.queue,fn(song,i) {
      html.div([],[
        html.text(string.append(int.to_string(i+1),". ")),
        html.text(song.name)
      ])
    }))
  ])
}

fn song_src(song:shared.Song) {
  string.append("/song/" ,uri.percent_encode(song.name))
}

type Audio

@external(javascript, "./audio.mjs", "audio")
fn audio() -> Audio

@external(javascript, "./audio.mjs", "documentAudio")
fn document_audio(id:String) -> Audio

@external(javascript, "./audio.mjs", "debugAudio")
fn debug_audio(audio:Audio) -> Audio

@external(javascript, "./audio.mjs", "setVolume")
fn set_volume(audio:Audio,volume:Float) -> Audio

@external(javascript, "./audio.mjs", "setSrc")
fn set_src(audio:Audio,song:String) -> Audio


@external(javascript, "./audio.mjs", "resetAudio")
fn reset_audio(audio:Audio) -> Audio
