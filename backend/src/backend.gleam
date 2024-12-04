import gleam/bit_array
import gleam/json
import gleam/option.{None,Some}
import gleam/dict
import gleam/string
import gleam/io
import gleam/result
import gleam/http/response
import gleam/bytes_builder
import gleam/erlang/process
import lustre/element
import lustre/element/html.{html}
import mist.{type Connection, type ResponseData}
import lustre/attribute
import wisp
import wisp/wisp_mist
import frontend.{type Model,starting_vol}
import gleam/uri
import gleam/list
import simplifile
import file_streams/file_stream
import opus/thumbnail
import shared

pub type Context {
  Context(songs:dict.Dict(String,shared.Song))
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
        Ok(song) ->  serve_song(song)
        Error(e) -> { io.debug(e)  wisp.not_found() }
      }
    }
    // Any non-matching routes
    _ ->  { io.debug("dropped through")  wisp.not_found()}
  }
}
pub fn main() {
  let assert Ok(songs) = find_songs("/home/nickl/Music")
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let handler = handle_request(_, Context(songs))
  //mist_handler(handle_request,secret_key_base)
  let assert Ok(_) = wisp_mist.handler(handler,secret_key_base)
    |> mist.new
    |> mist.port(3000)
    |> mist.start_http

  process.sleep_forever()
}

fn serve_song(song:shared.Song) {
  // todo move playback serverside
  wisp.ok()
  |> wisp.file_download(song.name,song.path)
}

fn find_songs(path:String)  {
 use files <- result.try(simplifile.get_files(path))
 let songs = files
  |> list.filter(fn(song) { string.contains(song,"mp3") || string.contains(song,"opus")})
  |> list.map(fn(path) {
    let assert Ok(name) = list.last(string.split(path,"/"))
    #(name,shared.Song(name,path))
 })
 let assert Ok(song) =  list.first(list.shuffle(songs))
 thumbnail.get_thumbnails(song.1) |> io.debug
 Ok(songs |> dict.from_list)
}

fn encode_all_songs(songs) {
  json.array(dict.values(songs),shared.encode_song) |> json.to_string
}

fn home(ctx:Context) {
  let model = frontend.Model(ctx.songs,[],[],starting_vol,"",False,False,False,False)
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
