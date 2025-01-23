module libswresample

#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <libavutil/frame.h>
#include <libavutil/opt.h>
#include <libavutil/mem.h>

#include <libswresample/swresample.h>

#pkgconfig --libs --cflags libavutil
#pkgconfig --libs --cflags libswresample

@[typedef]
pub struct C.SwrContext {
	
}

pub const av_ch_layout_mono = C.AV_CH_LAYOUT_MONO
pub const av_ch_layout_stereo = C.AV_CH_LAYOUT_STEREO
pub const av_ch_layout_5_1 = C.AV_CH_LAYOUT_5POINT1

fn C.swr_alloc() &C.SwrContext

fn C.swr_alloc_set_opts2(ps &&C.SwrContext, const_out_ch_layout &C.AVChannelLayout, out_sample_fmt int, out_sample_rate int, const_in_ch_layout &C.AVChannelLayout, in_sample_fmt int, in_sample_rate int, log_offset int, log_ctx voidptr) int

fn C.swr_init(swr_ctx &C.SwrContext) int
fn C.swr_free(swr_ctx &&C.SwrContext)
fn C.swr_convert(swr_ctx &C.SwrContext, out_data &&u8, out_count int, in_data &&u8, in_count int) int
fn C.swr_get_delay(swr_ctx &C.SwrContext, base int) i64

fn C.av_samples_get_buffer_size(linesize &int, channels int, nb_samples int, sample_fmt int, align int) int
fn C.av_rescale_rnd(a i64, b i64, c i64, rnd int) i64

fn C.av_samples_alloc_array_and_samples(audio_data &&&u8, linesize &int, nb_channels int, nb_samples int, sample_fmt int, align int) int
fn C.av_samples_get_buffer_size(linesize &int, nb_channels int, nb_samples int, sample_fmt int, align int) int