import lustre_http
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
import lustre_websocket


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
  #(Model(inital_play_list,[],[],starting_vol,"",False,False,False,False,None,""),lustre_websocket.init("ws://localhost:3000/ws/healthcheck", fn(msg) { io.debug(WsWrapper(msg))}))
}

pub type Model {
  Model(
    songs:dict.Dict(String,shared.Song),
    queue:List(shared.Song),
    history:List(shared.Song),
    volume:Float,
    search:String,
    history_open:Bool,
    is_playing:Bool,
    is_looping:Bool,
    is_infinite:Bool,
    ws:option.Option(lustre_websocket.WebSocket),
    create_playlist_name:String
  )
}

pub type Msg {
  Play(shared.Song)
  Resume
  Pause
  SetVol(vol:option.Option(Float))
  SearchLibrary(String)
  End
  Skip(option.Option(#(Int,shared.Song)))
  Loop(should:Bool)
  Infinite(should:Bool)
  ToggleHistory(toggle:Bool)
  WsWrapper(lustre_websocket.WebSocketEvent)
  CreatePlaylistRequest
  UpdateCratePlayListName(name:String)
  NetworkResponse(Result(NetworkRes,Nil))
}

pub type NetworkRes {
  CreatedPlaylist
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
    ToggleHistory(toggle) -> {
      #(Model(..model,history_open:toggle),effect.none())
    }
    WsWrapper(event) -> handle_websocket(model,event)
    CreatePlaylistRequest -> {
      io.debug("creating playlist")
      let playlist  = shared.Playlist(model.create_playlist_name,model.history)
      io.debug(playlist)
      let json = shared.encode_playlist(playlist)
      io.debug(json)
      //todo update loading state
      #(model, lustre_http.post("http://localhost:3000/playlist",json,lustre_http.expect_json(shared.decode_playlist,fn(res) {
        io.debug(res)
        NetworkResponse(Ok(CreatedPlaylist))
      })))
    }
    NetworkResponse(res) -> {
      io.debug(res)
      #(model,effect.none())
    }
    UpdateCratePlayListName(name) -> {
      io.debug(name)
      #(Model(..model,create_playlist_name:name),effect.none())
    }
  }
}

pub fn handle_websocket(model,ws_msg) {
  case ws_msg {
    lustre_websocket.OnOpen(socket) ->  {
      io.debug("hello world")
      io.debug(socket)
      #(Model(..model, ws: Some(socket)), lustre_websocket.send(socket, "client-init"))
    }
    lustre_websocket.OnTextMessage(msg) -> {
      io.debug(msg)
      #(model,effect.none())
    }
    lustre_websocket.OnBinaryMessage(msg) -> todo as "either-or"
    lustre_websocket.OnClose(reason) -> {
      io.debug(reason)
      #(Model(..model, ws: None), effect.none())
    }
    lustre_websocket.InvalidUrl -> panic
  }
}



fn skip(model:Model,optional_song:option.Option(#(Int,shared.Song))) {
  io.debug(model)
  case optional_song {
    Some(song) -> {
      io.debug("test")
      //todo bug here with filtering multiple songs
      let new_queue = list.filter(model.queue,fn(queue_song) { !shared.song_is_equal(song.1,queue_song) })
      case new_queue {
        [] ->  {
          let model = Model(..model,history:list.append([song.1],model.history))
          infinite_skip_or_reset(model,new_queue)
        }
        _ -> {
          #(Model(..model,queue:new_queue),effect.none())
        }
      }
    }
    None -> {
      case model.queue {
        [last_song,next_song,..new_queue] -> {
          io.debug("hit")
          set_src(document_audio("audio-controls"),song_src(next_song))
          #(Model(..model,queue:list.append([next_song],new_queue),history:list.append([last_song],model.history)),effect.none())
        }
        [next_song] -> {
          reset_audio(document_audio("audio-controls"))
          #(Model(..model,queue:[],history:list.append([next_song],model.history)),effect.none())
        }
        [] -> {
          infinite_skip_or_reset(model,[])
        }
      }
    }
  }
}

pub fn infinite_skip_or_reset(model:Model,new_queue) {
  case model.is_infinite {
    False-> {
      let assert Ok(last_song) = list.first(model.queue) // this is ok bc we know we just played a song
      reset_audio(document_audio("audio-controls"))
      #(Model(..model,queue:new_queue,history:list.append([last_song],model.history)),effect.none())
    }
    True -> {
      let songs = dict.values(model.songs)
      let songs = list.shuffle(songs)
      case songs {
        [song,..] -> {
          let new_queue = [song]
          let assert Ok(last_song) = list.first(model.queue) // this is ok bc we know we just played a song
          set_src(document_audio("audio-controls"),song_src(song))
          #(Model(..model,queue:new_queue,history:list.append([last_song],model.history)),effect.none())
        }
        [] -> {
          panic as "you have no songs"
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
  html.div([attribute.class("px-5 h-screen flex flex-row gap-5 bg bg-eerie-black text-tea-rose-(red) font-quicksand")],[
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
    history_view(model)
  ])
}

fn history_view(model:Model) {
  case model.history_open {
    True -> {
      html.div([attribute.class("flex flex-col w-fit overflow-scroll")],[
          html.button([event.on_click(ToggleHistory(False))],[html.text("Close History")]),
          html.div([attribute.class("gap-5")],list.map(model.history,song_view)),
          html.div([],[
            html.input([attribute.id("playlist-name"), attribute.class("w-full"),event.on_input(UpdateCratePlayListName)]),
            html.button([attribute.class("w-full border border-rounded-2xl"),event.on_click(CreatePlaylistRequest)],[
              html.text("Create playlist")
            ])
          ])
        ]
      )
    }
    False -> html.div([],[
      html.button([event.on_click(ToggleHistory(True))],[html.text("Open History")])
    ])
  }
}



fn song_filter(song:shared.Song,current_search:String) -> Bool {
  //todo generate similar strings
  string.contains(string.lowercase(song.name),string.lowercase(current_search))
}
//search todo

pub fn search_view() -> Element(Msg) {
  html.div([attribute.class("w-full p-2")],[
    html.input([attribute.class("w-full  rounded-lg p-2 border-2 border-tea-rose-(red)"),attribute.placeholder("Search"), event.on_input(fn(value) {
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
  io.debug(model.is_infinite)
  let song = list.first(model.queue)
  html.div([attribute.class("sticky top-[100vh]")],[
    html.div([attribute.class("flex flex-row gap-5")],[
      html.button([event.on_click(SetVol(Some(model.volume +. 0.01)))],[html.text("+")]),
      html.div([],[html.text(float.to_string(model.volume))]),
      //html.input([attribute.type_("range"),attribute.value(float.to_string(model.volume *. 100.0)) , attribute.min("1"), attribute.max("100")]),
      html.button([event.on_click(SetVol(Some(model.volume -. 0.01)))],[html.text("-")]),
      html.button([event.on_click(Skip(None))],[html.text("skip")]),
      html.button([attribute.classes([#("font-bold",model.is_looping)]),event.on_click(Loop(!model.is_looping))],[
        html.text("loop")
      ]),
      html.button([attribute.classes([#("font-bold",model.is_infinite)]),event.on_click(Infinite(!model.is_infinite))],[
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

//border-2 p-2 border-tea-rose-(red)
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

@external(javascript, "./audio.mjs", "wsTest")
fn test_ws() -> String
