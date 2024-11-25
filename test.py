import base64

def fix_base64_padding(base64_data):
    """Ensure Base64 string has correct padding."""
    while len(base64_data) % 4 != 0:
        base64_data += "="
    return base64_data

def find_metadata_block_picture(file_path):
    with open(file_path, "rb") as f:
        data = f.read()

    # Look for the Ogg Opus Vorbis Comment header
    vorbis_comment_signature = b"OpusTags"
    signature_index = data.find(vorbis_comment_signature)

    if signature_index == -1:
        print("Vorbis Comment header not found.")
        return None

    # Locate the METADATA_BLOCK_PICTURE tag
    metadata_start = signature_index + len(vorbis_comment_signature)
    metadata = data[metadata_start:]
    tag_start = metadata.find(b"METADATA_BLOCK_PICTURE=")

    if tag_start == -1:
        print("METADATA_BLOCK_PICTURE tag not found.")
        return None

    tag_start += len("METADATA_BLOCK_PICTURE=")

    # Extract the Base64-encoded data
    tag_end = metadata.find(b"\x00", tag_start)  # Tags are null-terminated
    base64_data = metadata[tag_start:tag_end].decode("utf-8")
    print(f"Base64-encoded METADATA_BLOCK_PICTURE found:\n{base64_data}...")  # Print a snippet

    # Decode the Base64 data
    decoded_data = base64.b64decode(fix_base64_padding(base64_data))
    print(f"Decoded METADATA_BLOCK_PICTURE length: {len(decoded_data)} bytes")

    # Parse the METADATA_BLOCK_PICTURE structure
    picture_type = int.from_bytes(decoded_data[0:4], byteorder="big")
    mime_length = int.from_bytes(decoded_data[4:8], byteorder="big")
    mime_type = decoded_data[8:8 + mime_length].decode("utf-8")

    description_length_offset = 8 + mime_length
    description_length = int.from_bytes(decoded_data[description_length_offset:description_length_offset + 4], byteorder="big")
    description = decoded_data[description_length_offset + 4:description_length_offset + 4 + description_length].decode("utf-8")

    image_data_length_offset = description_length_offset + 4 + description_length + 8
    image_data_length = int.from_bytes(decoded_data[image_data_length_offset:image_data_length_offset + 4], byteorder="big")

    print(f"Picture type: {picture_type}")
    print(f"MIME type: {mime_type}")
    print(f"Description: {description}")
    print(f"Image data length: {image_data_length}")

import base64

def fix_base64_padding(base64_data):
    """Ensure Base64 string has correct padding."""
    while len(base64_data) % 4 != 0:
        base64_data += "="
    return base64_data

def parse_metadata_block_picture(file_path):
    with open(file_path, "rb") as f:
        data = f.read()

    # Look for the Ogg Opus Vorbis Comment header
    vorbis_comment_signature = b"OpusTags"
    signature_index = data.find(vorbis_comment_signature)

    if signature_index == -1:
        print("Vorbis Comment header not found.")
        return None

    # Locate the METADATA_BLOCK_PICTURE tag
    metadata_start = signature_index + len(vorbis_comment_signature)
    metadata = data[metadata_start:]
    tag_start = metadata.find(b"METADATA_BLOCK_PICTURE=")

    if tag_start == -1:
        print("METADATA_BLOCK_PICTURE tag not found.")
        return None

    tag_start += len("METADATA_BLOCK_PICTURE=")

    # Extract the Base64-encoded data
    tag_end = metadata.find(b"\x00", tag_start)  # Tags are null-terminated
    base64_data = metadata[tag_start:tag_end].decode("utf-8")
    base64_data = fix_base64_padding(base64_data)  # Fix padding
    print(f"Base64-encoded METADATA_BLOCK_PICTURE found:\n{base64_data[:60]}...")  # Print a snippet

    # Decode the Base64 data
    decoded_data = base64.b64decode(base64_data)
    print(f"Decoded METADATA_BLOCK_PICTURE length: {len(decoded_data)} bytes")

    # Parse the FLAC picture metadata structure
    offset = 0

    def read_int(data, offset):
        """Helper function to read a 4-byte integer."""
        return int.from_bytes(data[offset:offset + 4], byteorder="big"), offset + 4

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

    print(f"Picture type: {picture_type}")
    print(f"MIME type: {mime_type}")
    print(f"Description: {description}")
    print(f"Width: {width}, Height: {height}")
    print(f"Color Depth: {color_depth}, Number of Colors: {num_colors}")
    print(f"Image data length: {image_data_length}")

    # Extract the image data
    image_data = decoded_data[offset:offset + image_data_length]

    if len(image_data) != image_data_length:
        print("Warning: Image data length mismatch!")
    else:
        print(f"Extracted image data size: {len(image_data)} bytes")

    return image_data

# Replace 'your_file.opus' with the path to your Opus file
image_data = parse_metadata_block_picture("test.opus")

# Optionally save the image
if image_data:
    with open("output_image", "wb") as img_file:
        img_file.write(image_data)
    print("Image data saved to 'output_image'")

image_data = find_metadata_block_picture("test.opus")

# Optionally save the image
if image_data:
    with open("output_image", "wb") as img_file:
        img_file.write(image_data)
    print("Image data saved to 'output_image'")
