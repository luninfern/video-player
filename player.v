import os
import gg
import gx
import ffmpeg
import libswscale as _
import libswresample as _
import time
import sokol.audio

struct Pixel {
	r u8
	g u8
	b u8
}

struct Frame {
mut:
	width  int
	height int
	pixels []Pixel
}

struct AudioFrame {
mut:
	samples     []f32
	//channels    int
	sample_rate int
	num_samples int
}

struct App {
mut:
	ctx                 &gg.Context = unsafe { nil }
	current_frame       int
	current_audio_frame int
	width               int
	height              int
	istream_idx         int
	pixels              &u32           = unsafe { nil }
	decoder_output      &DecoderOutput = unsafe { nil }
}

fn (mut app App) init_pixels(height int, width int) {
	app.pixels = unsafe { malloc(height * width * int(sizeof(u32))) }
}

fn (mut app App) free_pixels() {
	unsafe {
		free(app.pixels)
	}
}

fn (mut app App) set_pixel(x int, y int, color u32) {
	unsafe {
		index := y * app.width + x
		app.pixels[index] = color
	}
}

fn (app App) get_pixel(x int, y int) u32 {
	unsafe {
		index := y * app.width + x
		return app.pixels[index]
	}
}

fn (mut app App) run() {
	app.ctx = gg.new_context(
		bg_color:     gx.rgb(174, 198, 255)
		window_title: 'Video Player'
		width:        app.width
		height:       app.height
		frame_fn:     frame
		init_fn:      init
		user_data:    app
	)

	app.init_pixels(app.width, app.height)

	spawn app.update()
	app.ctx.run()
}

struct Decoder {
mut:
	fmt_ctx &C.AVFormatContext = unsafe { nil }

	video_dec &C.AVCodec = unsafe { nil }
	audio_dec &C.AVCodec = unsafe { nil }

	video_dec_ctx &C.AVCodecContext = unsafe { nil }
	audio_dec_ctx &C.AVCodecContext = unsafe { nil }

	video_stream_index int = -1
	audio_stream_index int = -1

	out &DecoderOutput = unsafe { nil }
}

struct DecoderOutput {
mut:
	frames     []Frame
	audio_data []f32
	width      int
	height     int
}

fn (mut dec Decoder) init(video_name string, decoder_output &DecoderOutput) {
	unsafe {
		dec.out = decoder_output

		mut ret := 0

		ret = C.avformat_open_input(&dec.fmt_ctx, video_name.str, nil, nil)
		if ret < 0 {
			println('Could not open source file')
			exit(ret)
		}

		ret = C.avformat_find_stream_info(dec.fmt_ctx, nil)
		if ret < 0 {
			println('Could not find stream information')
			exit(ret)
		}

		// video

		ret = C.av_find_best_stream(dec.fmt_ctx, C.AVMEDIA_TYPE_VIDEO, -1, -1, &dec.video_dec,
			0)
		if ret < 0 {
			println('Cannot find a video stream in the input file')
			exit(ret)
		}

		dec.video_dec_ctx = C.avcodec_alloc_context3(dec.video_dec)
		if dec.video_dec_ctx == nil {
			exit(ret)
		}
		dec.video_stream_index = ret

		mut video_st := dec.fmt_ctx.streams[dec.video_stream_index]
		mut video_dec_param := video_st.codecpar
		C.avcodec_parameters_to_context(dec.video_dec_ctx, video_dec_param)

		dec.out.width = dec.video_dec_ctx.width
		dec.out.height = dec.video_dec_ctx.height

		ret = C.avcodec_open2(dec.video_dec_ctx, dec.video_dec, nil)
		if ret < 0 {
			println('Cannot open video decoder')
			exit(ret)
		}

		// audio

		ret = C.av_find_best_stream(dec.fmt_ctx, C.AVMEDIA_TYPE_AUDIO, -1, -1, &dec.audio_dec,
			0)
		if ret < 0 {
			println('Cannot find a audio stream in the input file')
			exit(ret)
		}

		dec.audio_dec_ctx = C.avcodec_alloc_context3(dec.audio_dec)
		if dec.audio_dec_ctx == nil {
			exit(ret)
		}
		dec.audio_stream_index = ret

		mut audio_st := dec.fmt_ctx.streams[dec.audio_stream_index]
		mut audio_dec_param := audio_st.codecpar
		C.avcodec_parameters_to_context(dec.audio_dec_ctx, audio_dec_param)

		ret = C.avcodec_open2(dec.audio_dec_ctx, dec.audio_dec, nil)
		if ret < 0 {
			println('Cannot open audio decoder')
			exit(ret)
		}
	}
}

fn (mut dec Decoder) decode() {
	unsafe {
		mut ret := 0

		mut packet := C.av_packet_alloc()
		C.av_init_packet(packet)

		mut frame := C.av_frame_alloc()

		mut frame_rgb := C.av_frame_alloc()
		frame_rgb.width = dec.video_dec_ctx.width
		frame_rgb.height = dec.video_dec_ctx.height
		frame_rgb.format = int(ffmpeg.AVPixelFormat.rgb24)

		mut align := 24

		mut size := C.av_image_get_buffer_size(ffmpeg.AVPixelFormat.rgb24, frame_rgb.width,
			frame_rgb.height, align)
		mut rgb_data := C.av_malloc(size * int(sizeof(u8)))

		C.av_image_fill_arrays(frame_rgb.data, frame_rgb.linesize, rgb_data, ffmpeg.AVPixelFormat.rgb24,
			frame_rgb.width, frame_rgb.height, align)

		mut sws_ctx := C.sws_getContext(dec.video_dec_ctx.width, dec.video_dec_ctx.height,
			dec.video_dec_ctx.pix_fmt, dec.video_dec_ctx.width, dec.video_dec_ctx.height,
			ffmpeg.AVPixelFormat.rgb24, C.SWS_BILINEAR, nil, nil, nil)

		mut audio_frame := C.av_frame_alloc()

		for C.av_read_frame(dec.fmt_ctx, packet) >= 0 {
			if packet.stream_index == dec.video_stream_index {
				ret = C.avcodec_send_packet(dec.video_dec_ctx, packet)
				if ret < 0 {
					println('Error sending packet to the decoder')
					break
				}

				for ret >= 0 {
					ret = C.avcodec_receive_frame(dec.video_dec_ctx, frame)
					if ret == C.AVERROR_EOF || ret == -11 {
						break
					} else if ret < 0 {
						println('Error receiving frame from the decoder')
						break
					}

					C.sws_scale(sws_ctx, frame.data, frame.linesize, 0, dec.video_dec_ctx.height,
						frame_rgb.data, frame_rgb.linesize)
					dec.out.frames << populate_frame(frame_rgb, dec.video_dec_ctx.width,
						dec.video_dec_ctx.height)
				}
			} else if packet.stream_index == dec.audio_stream_index {
				ret = C.avcodec_send_packet(dec.audio_dec_ctx, packet)
				if ret < 0 {
					println('Error sending packet to the decoder')
					break
				}

				for ret >= 0 {
					ret = C.avcodec_receive_frame(dec.audio_dec_ctx, audio_frame)
					if ret == C.AVERROR_EOF || ret == -11 {
						break
					} else if ret < 0 {
						println('Error receiving frame from the decoder')
						break
					}

					dec.out.audio_data << get_samples(audio_frame, dec.audio_dec_ctx, ffmpeg.AVSampleFormat.fltp)
				}
			}

			C.av_packet_unref(packet)
		}

		C.av_frame_free(&frame)
		C.av_frame_free(&frame_rgb)
		C.av_free(frame_rgb)
		C.avformat_close_input(&dec.fmt_ctx)
	}
}

fn main() {
	mut app := &App{}

	if os.args.len != 2 {
		println('Enter a video name')
		return
	}

	video_name := os.args[1]

	app.decoder_output = &DecoderOutput{}

	mut decoder := &Decoder{}
	decoder.init(video_name, app.decoder_output)

	app.width = app.decoder_output.width
	app.height = app.decoder_output.height

	audio.setup(
		stream_userdata_cb: audio_stream_callback
		sample_rate:        48000
		user_data:          app
	)

	go decoder.decode()

	app.run()
	app.free_pixels()
}

fn resample_frame(frame &C.AVFrame, codec_ctx &C.AVCodecContext, out_sample_rate int, out_channels int, out_sample_fmt ffmpeg.AVSampleFormat) []f32 {
	mut swr_ctx := C.swr_alloc()
	if swr_ctx == 0 {
		panic('Could not allocate resampler context')
	}

	mut in_channel_layout := &codec_ctx.ch_layout
	mut out_channel_layout := ffmpeg.create_channel_layout(out_channels)

	out_nb_channels := out_channel_layout.nb_channels

	in_nb_samples := frame.nb_samples
	in_sample_rate := codec_ctx.sample_rate

	C.swr_alloc_set_opts2(&swr_ctx, out_channel_layout, int(out_sample_fmt), out_sample_rate,
		in_channel_layout, int(codec_ctx.sample_fmt), in_sample_rate, 0, 0)

	C.swr_init(swr_ctx)

	out_nb_samples := C.av_rescale_rnd(C.swr_get_delay(swr_ctx, in_sample_rate) + in_nb_samples,
		out_sample_rate, in_sample_rate, 3)

	mut resampled_data := &&u8(0)
	mut out_linesize := 0

	C.av_samples_alloc_array_and_samples(&resampled_data, &out_linesize, out_nb_channels,
		out_nb_samples, int(out_sample_fmt), 0)

	resampled_data = frame.data

	unsafe {
		C.swr_convert(swr_ctx, resampled_data, out_nb_samples, frame.data, in_nb_samples)

		mut samples := []f32{len: int(out_nb_samples * out_nb_channels)}
		for c in 0 .. out_nb_channels {
			data := &f32(resampled_data[c])
			for i in 0 .. out_nb_samples {
				samples[c * out_nb_samples + i] = data[i]
			}
		}

		return samples
	}
	return []f32{}
}

fn get_samples(frame &C.AVFrame, codec_ctx &C.AVCodecContext, out_sample_fmt ffmpeg.AVSampleFormat) []f32 {
	return resample_frame(frame, codec_ctx, 48000, 1, out_sample_fmt)
}

fn get_frame(frame &C.AVFrame, codec_ctx &C.AVCodecContext, out_sample_fmt ffmpeg.AVSampleFormat) AudioFrame {
	mut samples := get_samples(frame, codec_ctx, out_sample_fmt)

	mut audioframe := AudioFrame{
		samples:     samples
		sample_rate: codec_ctx.sample_rate
		num_samples: frame.nb_samples
		//channels:    codec_ctx.channels
	}

	return audioframe
}

fn audio_stream_callback(mut soundbuffer &f32, num_frames int, num_channels int, mut app App) {
	mut index := app.current_audio_frame * num_channels
	for i in 0 .. num_frames * num_channels {
		if index < app.decoder_output.audio_data.len {
			soundbuffer[i] = app.decoder_output.audio_data[index]
			index++
		} else {
			soundbuffer[i] = 0.0
			app.current_audio_frame = 0
		}
	}
	app.current_audio_frame += num_frames
}

fn populate_frame(frame_data &C.AVFrame, width int, height int) Frame {
	mut frame := Frame{
		width:  width
		height: height
		pixels: []Pixel{cap: width * height}
	}

	unsafe {
		for y in 0 .. height {
			row_data := frame_data.data[0] + y * frame_data.linesize[0]
			for x in 0 .. width {
				r := row_data[x * 3]
				g := row_data[x * 3 + 1]
				b := row_data[x * 3 + 2]

				frame.pixels << Pixel{r, g, b}
			}
		}
	}
	return frame
}

fn (mut app App) render() {
	mut istream_image := app.ctx.get_cached_image_by_idx(app.istream_idx)
	istream_image.update_pixel_data(unsafe { &u8(app.pixels) })
	size := gg.window_size()
	app.ctx.draw_image(0, 0, size.width, size.height, istream_image)
}

@[direct_array_access]
fn (mut app App) update() {
	for {
		if app.decoder_output.frames.len > 0 {
			mut frame := app.decoder_output.frames[app.current_frame]

			for y in 0 .. frame.height {
				for x in 0 .. frame.width {
					pixel := frame.pixels[y * frame.width + x]
					app.set_pixel(x, y, 0xFF000000 | (u32(pixel.b) << 16) | (u32(pixel.g) << 8) | u32(pixel.r))
				}
			}

			if app.current_frame == app.decoder_output.frames.len - 1 {
				app.current_frame = 0
			} else {
				app.current_frame++
			}
		}

		time.sleep(28 * time.millisecond)
	}
}

fn init(mut app App) {
	app.istream_idx = app.ctx.new_streaming_image(app.width, app.height, 4, pixel_format: .rgba8)
}

fn frame(mut app App) {
	app.ctx.begin()
	app.render()
	app.ctx.end()
}
