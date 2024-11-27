import base64

def fix_base64_padding(base64_data):
    """Ensure Base64 string has correct padding."""
    while len(base64_data) % 4 != 0:
        base64_data += "="
    return base64_data

def parse_metadata_block_picture(decoded_data):
    """Parse the METADATA_BLOCK_PICTURE structure."""
    offset = 0

    def read_int(data, offset):
        """Read a 4-byte integer from the data."""
        return int.from_bytes(data[offset:offset + 4], byteorder="big"), offset + 4

    try:
        # Parse the metadata block picture structure
        picture_type, offset = read_int(decoded_data, offset)
        mime_length, offset = read_int(decoded_data, offset)
        mime_type = decoded_data[offset:offset + mime_length].decode("utf-8")
        offset += mime_length

        description_length, offset = read_int(decoded_data, offset)
        description = decoded_data[offset:offset + description_length].decode("utf-8")
        offset += description_length

        width, offset = read_int(decoded_data, offset)
        height, offset = read_int(decoded_data, offset)
        color_depth, offset = read_int(decoded_data, offset)
        num_colors, offset = read_int(decoded_data, offset)
        image_data_length, offset = read_int(decoded_data, offset)

        # Attempt to extract image data
        image_data = decoded_data[offset:offset + image_data_length]

            # # Check if there's additional data
            # remaining_data = decoded_data[offset + image_data_length:]
            # if len(image_data) != image_data_length:
            #     print(f"Warning: Expected {image_data_length} bytes but found {len(image_data)} bytes.")
            # if remaining_data:
            #     print(f"Additional data found: {len(remaining_data)} bytes appended.")
            #     image_data += remaining_data  # Include remaining data if the image data appears incomplete

        print(f"Picture type: {picture_type}")
        print(f"MIME type: {mime_type}")
        print(f"Description: {description}")
        print(f"Width: {width}, Height: {height}")
        print(f"Color Depth: {color_depth}, Number of Colors: {num_colors}")
        print(f"Image data length (reported): {image_data_length}")
        print(f"Image data length (actual): {len(image_data)}")

        return image_data, mime_type
    except Exception as e:
        print(f"Error parsing METADATA_BLOCK_PICTURE: {e}")
        return None, None

def find_metadata_block_picture(file_path):
    with open(file_path, "rb") as f:
        data = f.read()

    # Locate the OpusTags header
    vorbis_comment_signature = b"OpusTags"
    signature_index = data.find(vorbis_comment_signature)
    if signature_index == -1:
        print("Vorbis Comment header not found.")
        return None

    metadata_start = signature_index + len(vorbis_comment_signature)
    metadata = data[metadata_start:]

    # Locate METADATA_BLOCK_PICTURE tag
    tag_start = metadata.find(b"METADATA_BLOCK_PICTURE=")
    if tag_start == -1:
        print("METADATA_BLOCK_PICTURE tag not found.")
        return None

    # Extract Base64-encoded data
    tag_start += len("METADATA_BLOCK_PICTURE=")
    tag_end = metadata.find(b"\x00", tag_start)
    if tag_end == -1:
        tag_end = len(metadata)  # Assume tag continues to the end of metadata

    base64_data = metadata[tag_start:tag_end].decode("utf-8")
    base64_data = fix_base64_padding(base64_data)

    try:
        decoded_data = base64.b64decode(base64_data)
        print(f"Decoded data length: {len(decoded_data)} bytes")
    except base64.binascii.Error as e:
        print(f"Base64 decoding error: {e}")
        return None

    return decoded_data

# Main Script
file_path = "hello.opus"  # Replace with your Opus file path
decoded_data = find_metadata_block_picture(file_path)

if decoded_data:
    image_data, mime_type = parse_metadata_block_picture(decoded_data)

    if image_data:
        # Save the extracted image
        extension = ".jpg" if mime_type == "image/jpeg" else ".png"
        output_path = "output_image" + extension
        with open(output_path, "wb") as img_file:
            img_file.write(image_data)
        print(f"Image saved to {output_path}")
    else:
        print("Failed to extract image data.")
else:
    print("No METADATA_BLOCK_PICTURE found.")
