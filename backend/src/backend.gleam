import gleam/json
import gleam/option.{None,Some}
import gleam/dict
import gleam/string
import gleam/io
import gleam/result
import shared
import gleam/http/response
import gleam/bytes_builder
import gleam/erlang/process
import lustre/element
import lustre/element/html.{html}
import mist.{type Connection, type ResponseData}
import lustre/attribute
import wisp
import wisp/wisp_mist
import frontend.{type Model}
import gleam/uri
import gleam/list
import simplifile

pub type Context {
  Context(songs:dict.Dict(String,shared.Song))
}

fn static_middleware(req: wisp.Request, fun: fn() -> wisp.Response) -> wisp.Response {
  let assert Ok(priv) = wisp.priv_directory("backend")
  io.debug(priv)
  wisp.serve_static(req, under: "/static", from: priv, next: fun) |> io.debug
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
  wisp.ok()
  |> wisp.file_download(song.name,song.path)
}

fn find_songs(path:String)  {
 use files <- result.try(simplifile.get_files(path))
 Ok(files |> list.filter(fn(song) { string.contains(song,"mp3") || string.contains(song,"opus")}) |> list.map(fn(path) {
    let assert Ok(name) = list.last(string.split(path,"/"))
    #(name,shared.Song(name,path))
 }) |> dict.from_list)
}

fn encode_all_songs(songs) {
  json.array(dict.values(songs),shared.encode_song) |> json.to_string
}

fn home(ctx:Context) {
  let model = frontend.Model(ctx.songs,frontend.init_controls())
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

fn get_thumbnails() {
  todo
  //"metadata_block_picture"
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
