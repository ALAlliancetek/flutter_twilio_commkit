package com.twiliocommkit.android.video

import android.content.Context
import android.view.View
import com.twilio.video.VideoTextureView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory for native Twilio VideoTextureView platform views.
 *
 * Each view instance is registered by viewId. The video track (local or
 * remote) is attached/detached via [TwilioVideoTrackRegistry].
 */
class TwilioVideoViewFactory(private val registry: TwilioVideoTrackRegistry) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val trackId = params?.get("trackId") as? String ?: ""
        return TwilioNativeVideoView(context, viewId, trackId, registry)
    }
}

class TwilioNativeVideoView(
    context: Context,
    private val viewId: Int,
    private val trackId: String,
    private val registry: TwilioVideoTrackRegistry
) : PlatformView {

    private val videoView = VideoTextureView(context).apply {
        mirror = trackId == TwilioVideoTrackRegistry.LOCAL_TRACK_ID
    }

    init {
        registry.attachView(trackId, videoView)
    }

    override fun getView(): View = videoView

    override fun dispose() {
        registry.detachView(trackId)
    }
}

