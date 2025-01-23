module ffmpeg

#include <libavformat/avformat.h>
#include <libavutil/avutil.h>
#include <libavcodec/avcodec.h>

#pkgconfig --libs --cflags libavformat
#pkgconfig --libs --cflags libavutil
#pkgconfig --libs --cflags libavcodec

@[typedef]
pub struct C.AVCodec {
pub:
	id int
}

@[typedef]
pub struct C.AVFrame {
	data &&u8
	linesize &int
	width int
	height int
	format int
	nb_samples int
}

@[typedef]
pub struct C.AVCodecParserContext {
	
}

pub enum AVPixelFormat {
	none = C.AV_PIX_FMT_NONE
	yuv420p = C.AV_PIX_FMT_YUV420P
	yuyv422 = C.AV_PIX_FMT_YUYV422
	rgb24 = C.AV_PIX_FMT_RGB24
}

pub enum AVSampleFormat {
	none = C.AV_SAMPLE_FMT_NONE
	u8 = C.AV_SAMPLE_FMT_U8
	s16 = C.AV_SAMPLE_FMT_S16
	s32 = C.AV_SAMPLE_FMT_S32
	flt = C.AV_SAMPLE_FMT_FLT
	dbl = C.AV_SAMPLE_FMT_DBL
	u8p = C.AV_SAMPLE_FMT_U8P
	s16p = C.AV_SAMPLE_FMT_S16P
	s32p = C.AV_SAMPLE_FMT_S32P
	fltp = C.AV_SAMPLE_FMT_FLTP
	dblp = C.AV_SAMPLE_FMT_DBLP
	s64 = C.AV_SAMPLE_FMT_S64
	s64p = C.AV_SAMPLE_FMT_S64P
	nb = C.AV_SAMPLE_FMT_NB
}

@[typedef]
struct C.AVChannelLayout {
	nb_channels int
	order int
}

@[typedef]
pub struct C.AVCodecContext {
	width int
	height int
	pix_fmt AVPixelFormat
	frame_number int

	sample_rate int
	channels int

	sample_fmt AVSampleFormat
	ch_layout C.AVChannelLayout
}

@[typedef]
pub struct C.AVCodecParameters {}

@[typedef]
pub struct C.AVStream {
	codecpar &C.AVCodecParameters
}

@[typedef]
pub struct C.AVFormatContext {
	streams &&C.AVStream
}

@[typedef]
pub struct C.AVPacket {
	stream_index int
}

pub enum MediaType {
	unknown = C.AVMEDIA_TYPE_UNKNOWN -1
	video = C.AVMEDIA_TYPE_VIDEO
	audio = C.AVMEDIA_TYPE_AUDIO
	data = C.AVMEDIA_TYPE_DATA
	subtitle = C.AVMEDIA_TYPE_SUBTITLE
	attachment = C.AVMEDIA_TYPE_ATTACHMENT
	nb = C.AVMEDIA_TYPE_NB
}

pub fn C.avformat_open_input(ps &&C.AVFormatContext, const_url &char, voidptr, voidptr) int
pub fn C.avformat_find_stream_info(ic &C.AVFormatContext, voidptr) int
pub fn C.av_find_best_stream(fmt_ctx &C.AVFormatContext, media_type int, wanted_stream_nb int, related_stream int, const_decoder_ret &&C.AVCodec, flags int) int
pub fn C.avcodec_alloc_context3(&C.AVCodec) &C.AVCodecContext

pub fn C.avcodec_parameters_to_context(codec &C.AVCodecContext, const_par &C.AVCodecParameters) int
pub fn C.avcodec_open2(avctx &C.AVCodecContext, const_codec &C.AVCodec, voidptr) int
pub fn C.av_packet_alloc() &C.AVPacket
pub fn C.av_init_packet(avpkt &C.AVPacket)
pub fn C.av_frame_alloc() &C.AVFrame

pub fn C.av_read_frame(s &C.AVFormatContext, pkt &C.AVPacket) int
pub fn C.avcodec_send_packet(avctx &C.AVCodecContext, const_avpkt &C.AVPacket) int
pub fn C.avcodec_receive_frame(avctx &C.AVCodecContext, frame &C.AVFrame) int

//
pub fn C.av_malloc(size int) &u8
pub fn C.av_image_get_buffer_size(pix_fmt AVPixelFormat, width int, height int, align int) int
pub fn C.av_image_fill_arrays(dst_data &&u8, dst_linesize &int, src &u8, pix_fmt AVPixelFormat, width int, height int, align int)

pub fn C.av_free(ptr voidptr)
pub fn C.av_frame_free(frame &&C.AVFrame)
pub fn C.av_packet_unref(pkt &C.AVPacket)
pub fn C.avformat_close_input(s &&C.AVFormatContext)
pub fn C.avcodec_close(avctx &C.AVCodecContext) int

//
fn C.av_channel_layout_default(ch_layout &C.AVChannelLayout, nb_channels int)
fn C.av_channel_layout_describe(channel_layout &C.AVChannelLayout, buf &char, buf_size usize) int

pub fn create_channel_layout(nb_channels int) &C.AVChannelLayout {
	mut channel_layout := &C.AVChannelLayout{}
	C.av_channel_layout_default(channel_layout, nb_channels)
	return channel_layout
}