package com.mono.player

import com.mono.data.model.AudioTrack

/**
 * 播放状态数据类
 */
data class PlaybackState(
    val currentTrack: AudioTrack? = null,
    val playlist: List<AudioTrack> = emptyList(),
    val currentIndex: Int = 0,
    val isPlaying: Boolean = false,
    val currentPosition: Long = 0L,
    val duration: Long = 0L,
    val playbackSpeed: Float = 1.0f
) {
    val progress: Float
        get() = if (duration > 0) currentPosition.toFloat() / duration else 0f
    
    val hasNext: Boolean
        get() = currentIndex < playlist.size - 1
    
    val hasPrevious: Boolean
        get() = currentIndex > 0
}


