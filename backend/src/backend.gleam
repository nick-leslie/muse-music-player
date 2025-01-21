import gleam/string_tree
import gleam/http
import gleam/bit_array
import gleam/json
import gleam/option.{None,Some}
import gleam/dict
import gleam/string
import gleam/io
import gleam/result
import gleam/http/response
import gleam/erlang/process
import lustre/element
import lustre/element/html.{html}
import gleam/http/request.{type Request}
import mist.{type Connection, type ResponseData}
import lustre/attribute
import wisp
import wisp/wisp_mist
import gleam/uri
import gleam/list
import simplifile
import file_streams/file_stream
import frontend.{type Model,starting_vol}
import shared
import m3u
import websocket
import room
import routes/songs

const heart_beat = 10

pub type Context {
  Context(songs:dict.Dict(String,shared.Song),music_path:String)
}

pub fn main() {
  let assert Ok(songs) = find_songs("/home/nickl/Music")
  // let assert Ok(song) = list.sample(dict.values(songs),1)
  // |> list.first()
  //songs.create_image_thumbnail(song)

  // room.encode_song()
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let handler = handle_request(_, Context(songs,"/home/nickl/Music"))
  //mist_handler(handle_request,secret_key_base)
  let assert Ok(_) = handle_con(handler,websocket.socket_init(heart_beat),secret_key_base)
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

fn static_middleware(req: wisp.Request, fun: fn() -> wisp.Response) -> wisp.Response {
  let assert Ok(priv) = wisp.priv_directory("backend")
  wisp.serve_static(req, under: "/static", from: priv, next: fun)
}

pub fn handle_request(req:wisp.Request,ctx:Context) -> wisp.Response {
  // use <- cors_middleware(req)
  use <- static_middleware(req)

  case wisp.path_segments(req) {
    // Home
    [] -> home(ctx)
    ["song",name] ->  {
      let assert Ok(name) = uri.percent_decode(name)
      case dict.get(ctx.songs,name) {
        Ok(song) ->  songs.serve_song(song)
        Error(e) -> { io.debug(e)  wisp.not_found() }
      }
    }
    ["song",name,"thumbnail"] ->  {
      let assert Ok(name) = uri.percent_decode(name)
      case dict.get(ctx.songs,name) {
        Ok(song) ->  songs.serve_thumbnail(song)
        Error(e) -> { io.debug(e)  wisp.not_found() }
      }
    }
    ["playlist"] -> playlist_route(req,ctx.music_path)
    // Any non-matching routes
    _ ->  { io.debug("dropped through")  wisp.not_found()}
  }
}

pub fn playlist_route(req:wisp.Request,dir:String) {
  io.debug("creating playlist")
  case req.method {
    http.Post -> {
      use json <- wisp.require_json(req)
      case shared.decode_playlist(json) {
          Ok(playlist) ->  {
            let serlized_playlist = m3u.serlize(playlist.songs)
            let path = string.concat([dir,"/",playlist.name,".m3u"])
            case serlized_playlist |> simplifile.write(to: path) {
              Ok(_) ->  {
                io.debug(path)
                wisp.json_response(string_tree.from_string(serlized_playlist),200)
              }
              Error(write_err) ->  {
                io.debug(write_err)
                wisp.internal_server_error()
              }
            }
          }
          Error(err) ->  {
            io.debug(err)
            wisp.bad_request()
          }
      }
    }
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub fn handle_con(handler,websocket_handler,secret_key_base) {
  fn(req) {
    case request.path_segments(req) {
      ["ws","healthcheck"] -> websocket_handler(req)
      _ -> wisp_mist.handler(handler,secret_key_base)(req)
    }
  }
}


fn find_songs(path:String)  {
 use files <- result.try(simplifile.get_files(path))
 let songs = files
  |> list.filter(fn(song) { string.contains(song,"mp3") || string.contains(song,"opus")})
  |> list.map(fn(path) {
    let assert Ok(name) = list.last(string.split(path,"/"))
    #(name,shared.Song(name,path,"")) //todo add author parsing
 })
 Ok(songs |> dict.from_list)
}

fn find_playlists(path:String) {
   use files <-  result.try(simplifile.get_files(path))
   files
   |> list.filter(fn(song) { string.contains(song,"m3u") || string.contains(song,"m3u8")})
   |> list.map(fn(playlist_path) {
     use data <-  result.try(simplifile.read(playlist_path))
     Ok(m3u.deserlize(data))
   })
   |> result.all
}

fn encode_all_songs(songs) {
  json.array(dict.values(songs),shared.encode_song) |> json.to_string
}


fn home(ctx:Context) {
  let model = frontend.Model(ctx.songs,[],[],starting_vol,"",False,False,False,False,None,"")
  let content = // piped into from frontend
    frontend.view(model)
    |> page_scaffold(encode_all_songs(ctx.songs))

  wisp.response(200)
  |> wisp.set_header("Content-Type", "text/html")
  |> wisp.html_body(
    content
    |> element.to_document_string_builder(),
  )
}

fn page_scaffold(
  content: element.Element(a),
  init_json:String
) -> element.Element(a) {
  html.html([attribute.attribute("lang", "en")], [
    html.head([], [
      html.meta([attribute.attribute("charset", "UTF-8")]),
      html.meta([
        attribute.attribute("content", "width=device-width, initial-scale=1.0"),
        attribute.name("viewport"),
      ]),
      html.title([], "muse"),
      html.link([
               attribute.href("https://fonts.googleapis.com"),
               attribute.rel("preconnect"),
             ]),
             html.link([
               attribute.attribute("crossorigin", ""),
               attribute.href("https://fonts.gstatic.com"),
               attribute.rel("preconnect"),
             ]),
             html.link([
               attribute.rel("stylesheet"),
               attribute.href("https://fonts.googleapis.com/css2?family=Forum&display=swap"),
      ]),
      html.link([
                attribute.href("https://fonts.googleapis.com"),
                attribute.rel("preconnect"),
              ]),
              html.link([
                attribute.attribute("crossorigin", ""),
                attribute.href("https://fonts.gstatic.com"),
                attribute.rel("preconnect"),
              ]),
              html.link([
                attribute.rel("stylesheet"),
                attribute.href("https://fonts.googleapis.com/css2?family=Forum&family=Quicksand:wght@300..700&display=swap"),
              ]),
      html.script(
        [attribute.src("/static/static/frontend.mjs"), attribute.type_("module")],
        init_json,
      ),
      html.script(
        [attribute.type_("application/json"), attribute.id("model")]
        ,init_json
      ),
      html.link([
        attribute.href("static/static/frontend.css"),
        attribute.rel("stylesheet"),
      ]),
    ]),
    html.body([], [html.div([attribute.id("app")], [
      content
    ])]),
  ])
}
