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

//todo this only realy works if we have no description
pub fn get_thumbnails(song:shared.Song) {
  io.debug(song.name)
  use stream <- result.try(result.map_error(file_stream.open_read(song.path),fn(_) {StreamError}))

  use val <- result.try(find_metadata(stream))
  io.debug(val)
  //todo decode the bytes to find a valid image
  //55
  use data <- result.try(result.map_error(file_stream.read_bytes(stream,val),fn(_) {ReadError}))
  let assert Ok(write_stream) = file_stream.open_write("data.txt")
  case file_stream.write_bytes(write_stream,data) {
    Ok(_) -> io.debug("yipeee")
    Error(e) -> { io.debug(e) "fuck" }
  }
  io.debug("bruh")
  file_stream.close(write_stream)
  
  
  use bytes <- result.try(decode_base_64_byte_array(data))
  io.debug(bytes)
  let assert Ok(meta_data) = case bytes {
    <<image_type:size(8)-unit(4),mime_length:size(8)-unit(4),rest:bytes>>  -> {
      io.debug(image_type)
      io.debug(mime_length)
      io.debug(rest)
      let assert Ok(mime) = bit_array.to_string(result.unwrap(bit_array.slice(rest,0,mime_length),<<>>))
      use rest <- result.try(bit_array.slice(rest,mime_length,bit_array.byte_size(rest) - mime_length))
      let assert Ok(description_length) = bit_array.slice(rest,0,4)
      case description_length {
        <<length:size(8)-unit(4)>> -> {
          use rest <- result.try(bit_array.slice(rest,4,bit_array.byte_size(rest) - 4)) // remove the description length
          let assert Ok(description) = bit_array.to_string(result.unwrap(bit_array.slice(rest,0,length),<<>>))
          io.debug(description)
          use rest <- result.try(bit_array.slice(rest,length,bit_array.byte_size(rest) - length))
          case rest {
            <<width:size(8)-unit(4),height:size(8)-unit(4)
            ,color_depth:size(8)-unit(4)
            ,colors_used:size(8)-unit(4)
            ,image_data_length:size(8)-unit(4),rest:bytes>> -> {
              io.debug(width)
              io.debug(height)
              io.debug(color_depth)
              io.debug(colors_used)
              io.debug(image_data_length)
              Ok(ThumbnailMetaData(
                image_type,
                mime_length,
                mime,
                length,
                description,
                width,
                height,
                color_depth,
                colors_used,
                image_data_length
              ))
            }
            t -> {
              io.debug(t)
              panic as "failed to get data"
            }
          }
        }
        _ -> panic as " we should never get here"
      }
    }
    _ -> panic as ":)"
  } |> io.debug

  file_stream.position(stream,file_stream.CurrentLocation(-55))
  use png_data <- result.try(result.map_error(file_stream.read_bytes(stream,meta_data.image_data_length),fn(_) {ReadError}))
  // io.debug(png_data)
  use bytes <- result.try(decode_base_64_byte_array(png_data))
  // io.debug(bytes)
  io.debug(bit_array.byte_size(bytes))
  // let assert Ok(img_stream) = file_stream.open_write("test2.png")
  // case file_stream.write_bytes(img_stream,png_data) {
  //   Ok(_) -> io.debug("yipeee")
  //   Error(e) -> { io.debug(e) "fuck" }
  // }
  // io.debug("bruh")
  // file_stream.close(img_stream)
  Ok(bytes)
  //"metadata_block_picture"
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

pub fn find_metadata(stream) {
  case file_stream.read_bytes(stream,1) {
    Ok(<<"M">>) -> {

      io.debug("hit")
      let bytes = file_stream.read_bytes(stream,22)
      // string.from_utf_codepoints(bytes)
          case bytes {
            Ok(<<"ETADATA_BLOCK_PICTURE=":utf8>>) -> {
              file_stream.position(stream,file_stream.CurrentLocation(-{4 + 23}))
              use length <-  result.try(result.map_error(file_stream.read_uint32_le(stream),fn(_) { DecodeError }))
              io.debug(bytes)
              file_stream.position(stream,file_stream.CurrentLocation({23}))
              Ok(length)
            }
            _ -> find_metadata(stream)
          }
        }
    Error(_) -> {
      Error(CantFindTag)
    }
    _ -> {
      find_metadata(stream)
    }
  }
}
