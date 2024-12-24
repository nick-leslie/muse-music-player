 ffmpeg \
         -i hello.opus \
         -f segment -segment_format mpegts -segment_time 10 \
         -segment_list audio_pl.m3u8 \
         audio_segment%05d.ts
