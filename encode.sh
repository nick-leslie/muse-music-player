  ffmpeg -f s16le -ar 48k -ac 2 -i hello.opus -acodec pcm_u8 -ar 48000 -f aiff pipe:1
 # ffmpeg \
 #         -i hello.opus \
 #         -f segment -segment_format mpegts -segment_time 10 \
 #         -hls_flags append_list \
 #         -segment_list ./demo/audio_pl.m3u8 \
 #         ./demo/audio_segment%05d.ts  | cat

# ffmpeg \
# 	-i audio_name.mp3 \
# 	-vn -ac 2 -acodec aac \
# 	-f segment -segment_format mpegts -segment_time 10 \
# 	-segment_list audio_pl.m3u8 \
# 	audio_segment%05d.ts
