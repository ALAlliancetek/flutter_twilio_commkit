package com.twiliocommkit.android.video

import com.twilio.video.LocalVideoTrack
import com.twilio.video.RemoteVideoTrack
import com.twilio.video.VideoTextureView

/**
 * Central registry that maps track IDs to their VideoTextureView sinks.
 *
 * When a platform view is created Flutter side, it calls [attachView] with a
 * trackId.  When the native track becomes available it calls [setLocalTrack]
 * or [setRemoteTrack] to connect them.
 */
class TwilioVideoTrackRegistry {

    companion object {
        const val LOCAL_TRACK_ID = "__local__"
    }

    // trackId -> pending view waiting for a track
    private val pendingViews = mutableMapOf<String, VideoTextureView>()

    // Currently active local track
    private var localVideoTrack: LocalVideoTrack? = null

    // participantSid -> RemoteVideoTrack
    private val remoteTracks = mutableMapOf<String, RemoteVideoTrack>()

    // ── Attach/detach views (called from PlatformView lifecycle) ─────────────

    fun attachView(trackId: String, view: VideoTextureView) {
        pendingViews[trackId] = view
        // Try to connect immediately if track is already available
        if (trackId == LOCAL_TRACK_ID) {
            localVideoTrack?.addSink(view)
        } else {
            remoteTracks[trackId]?.addSink(view)
        }
    }

    fun detachView(trackId: String) {
        val view = pendingViews.remove(trackId) ?: return
        if (trackId == LOCAL_TRACK_ID) {
            localVideoTrack?.removeSink(view)
        } else {
            remoteTracks[trackId]?.removeSink(view)
        }
    }

    // ── Track registration (called from TwilioVideoManager) ──────────────────

    fun setLocalTrack(track: LocalVideoTrack?) {
        // Remove old sinks
        localVideoTrack?.let { old ->
            pendingViews[LOCAL_TRACK_ID]?.let { old.removeSink(it) }
        }
        localVideoTrack = track
        // Attach to any waiting view
        track?.let { t ->
            pendingViews[LOCAL_TRACK_ID]?.let { t.addSink(it) }
        }
    }

    fun addRemoteTrack(participantSid: String, track: RemoteVideoTrack) {
        remoteTracks[participantSid] = track
        pendingViews[participantSid]?.let { track.addSink(it) }
    }

    fun removeRemoteTrack(participantSid: String) {
        val track = remoteTracks.remove(participantSid)
        pendingViews[participantSid]?.let { track?.removeSink(it) }
    }

    fun clear() {
        localVideoTrack?.let { track ->
            pendingViews[LOCAL_TRACK_ID]?.let { track.removeSink(it) }
        }
        remoteTracks.forEach { (sid, track) ->
            pendingViews[sid]?.let { track.removeSink(it) }
        }
        localVideoTrack = null
        remoteTracks.clear()
    }
}

