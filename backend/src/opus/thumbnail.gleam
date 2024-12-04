import gleam/result
import gleam/bit_array
import file_streams/file_stream
import gleam/io
import shared

pub type ThumbnailError {
  StreamError
  ReadError
  DecodeError
  CantFindTag
}

pub type MetaDataTag {
  MetaDataTag(name:String,length:Int,data:BitArray)
  ImageTag(name:String,length:Int,data:BitArray,meta_data:ThumbnailMetaData)
}

pub type OpusPacket {
  OpusPacket(
    data:BitArray,
    first_packet_pg:Bool,
    first_packet_stream:Bool,
    last_packet_pg:Bool,
    last_packet_stream:Bool,
    absgp_page:Int, // u64
    stream_serial:Int, // u64
   	checksum_page:Int,
  )
}


pub type ThumbnailMetaData{
  ThumbnailMetaData(
    image_type:Int,
    mime_length:Int,
    mime_string:String,
    description_length:Int,
    description:String,
    width:Int,
    height:Int,
    color_depth:Int,
    colors_used:Int,
    image_data_length:Int
  )
}

pub fn read_packet(stream:file_stream.FileStream) {
    file_stream.read_bytes(stream,4) |> io.debug // capture_pattern
    file_stream.read_bytes(stream,1) |> io.debug // stream_structure_version
    file_stream.read_bytes(stream,1) |> io.debug
}

//todo this only realy works if we have no description
pub fn get_thumbnails(song:shared.Song) {
  use stream <- result.try(result.map_error(file_stream.open_read(song.path),fn(_) {StreamError}))
  read_packet(stream)
  Ok("hello world")
}

pub fn decode_base_64_byte_array(byte_array) {
  use decoded <- result.try(case bit_array.to_string(byte_array) {
    Ok(value) -> Ok(value)
    Error(e) -> {
      io.debug(e)
      Error(DecodeError)
    }
  })
  result.map_error(bit_array.base64_decode(decoded) , fn(_) {DecodeError})
}
