module libswscale

import ffmpeg

#include <libswscale/swscale.h>
#pkgconfig --libs --cflags libswscale

@[typedef]
pub struct C.SwsContext {}

pub fn C.sws_getContext(srcW int, srcH int, srcFormat ffmpeg.AVPixelFormat, dstW int, dstH int, dstFormat ffmpeg.AVPixelFormat, flags int, srcFilter voidptr, dstFilter voidptr, param f64) voidptr
pub fn C.sws_freeContext(ctx &C.SwsContext)

pub fn C.sws_scale(
    ctx &C.SwsContext,
    const_src_slice &&u8,
    const_src_stride &int,
    srcSliceY int,
    srcSliceH int,
    const_dst &&u8,
    const_dst_stride &int
) int