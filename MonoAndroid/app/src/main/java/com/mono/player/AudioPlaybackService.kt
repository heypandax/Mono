package com.mono.player

import android.app.PendingIntent
import android.content.Intent
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.mono.MainActivity
import com.mono.MonoApplication
import com.mono.data.model.AudioTrack

class AudioPlaybackService : MediaSessionService() {
    
    private var mediaSession: MediaSession? = null
    private var exoPlayer: ExoPlayer? = null
    
    companion object {
        private var instance: AudioPlaybackService? = null
        
        fun getInstance(): AudioPlaybackService? = instance
    }
    
    // 当前播放状态
    private var currentTrack: AudioTrack? = null
    private var playlist: List<AudioTrack> = emptyList()
    private var currentIndex: Int = 0
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        // 创建 ExoPlayer
        exoPlayer = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .setUsage(C.USAGE_MEDIA)
                    .build(),
                true
            )
            .setHandleAudioBecomingNoisy(true)
            .build()
            .apply {
                // 恢复播放速度
                val savedSpeed = MonoApplication.instance.preferencesManager.playbackSpeed
                playbackParameters = PlaybackParameters(savedSpeed)
                
                // 监听播放状态变化
                addListener(object : Player.Listener {
                    override fun onPlaybackStateChanged(playbackState: Int) {
                        if (playbackState == Player.STATE_ENDED) {
                            onTrackEnded()
                        }
                        notifyStateChanged()
                    }
                    
                    override fun onIsPlayingChanged(isPlaying: Boolean) {
                        notifyStateChanged()
                        if (!isPlaying) {
                            saveCurrentState()
                        }
                    }
                    
                    override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                        notifyStateChanged()
                    }
                })
            }
        
        // 创建 MediaSession
        val sessionActivityIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        mediaSession = MediaSession.Builder(this, exoPlayer!!)
            .setSessionActivity(sessionActivityIntent)
            .build()
    }
    
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }
    
    override fun onDestroy() {
        saveCurrentState()
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        exoPlayer = null
        instance = null
        super.onDestroy()
    }
    
    // MARK: - 播放控制
    
    fun play(track: AudioTrack, trackList: List<AudioTrack>) {
        playlist = trackList
        currentIndex = trackList.indexOf(track).coerceAtLeast(0)
        currentTrack = track
        
        exoPlayer?.apply {
            setMediaItem(MediaItem.fromUri(track.uri))
            prepare()
            play()
        }
        
        notifyStateChanged()
    }
    
    fun playAtIndex(index: Int) {
        if (index in playlist.indices) {
            currentIndex = index
            currentTrack = playlist[index]
            
            exoPlayer?.apply {
                setMediaItem(MediaItem.fromUri(currentTrack!!.uri))
                prepare()
                play()
            }
            
            notifyStateChanged()
        }
    }
    
    fun togglePlayPause() {
        exoPlayer?.let { player ->
            if (player.isPlaying) {
                player.pause()
            } else {
                player.play()
            }
        }
    }
    
    fun play() {
        exoPlayer?.play()
    }
    
    fun pause() {
        exoPlayer?.pause()
        saveCurrentState()
    }
    
    fun seekTo(position: Long) {
        exoPlayer?.seekTo(position)
    }
    
    fun skipForward(seconds: Int = 15) {
        exoPlayer?.let { player ->
            val newPosition = (player.currentPosition + seconds * 1000).coerceAtMost(player.duration)
            player.seekTo(newPosition)
        }
    }
    
    fun skipBackward(seconds: Int = 15) {
        exoPlayer?.let { player ->
            val newPosition = (player.currentPosition - seconds * 1000).coerceAtLeast(0)
            player.seekTo(newPosition)
        }
    }
    
    fun playNext() {
        if (currentIndex < playlist.size - 1) {
            playAtIndex(currentIndex + 1)
        }
    }
    
    fun playPrevious() {
        val currentPos = exoPlayer?.currentPosition ?: 0
        if (currentPos > 3000) {
            // 播放超过3秒，回到开头
            exoPlayer?.seekTo(0)
        } else if (currentIndex > 0) {
            playAtIndex(currentIndex - 1)
        } else {
            exoPlayer?.seekTo(0)
        }
    }
    
    fun setPlaybackSpeed(speed: Float) {
        exoPlayer?.playbackParameters = PlaybackParameters(speed)
        MonoApplication.instance.preferencesManager.playbackSpeed = speed
        notifyStateChanged()
    }
    
    // MARK: - 状态获取
    
    fun getPlaybackState(): PlaybackState {
        val player = exoPlayer
        return PlaybackState(
            currentTrack = currentTrack,
            playlist = playlist,
            currentIndex = currentIndex,
            isPlaying = player?.isPlaying == true,
            currentPosition = player?.currentPosition ?: 0L,
            duration = player?.duration?.takeIf { it > 0 } ?: 0L,
            playbackSpeed = player?.playbackParameters?.speed ?: 1.0f
        )
    }
    
    fun getCurrentPosition(): Long = exoPlayer?.currentPosition ?: 0L
    
    fun getDuration(): Long = exoPlayer?.duration?.takeIf { it > 0 } ?: 0L
    
    fun isPlaying(): Boolean = exoPlayer?.isPlaying == true
    
    // MARK: - 恢复播放
    
    fun restorePlayback(track: AudioTrack, trackList: List<AudioTrack>, position: Long) {
        playlist = trackList
        currentIndex = trackList.indexOf(track).coerceAtLeast(0)
        currentTrack = track
        
        exoPlayer?.apply {
            setMediaItem(MediaItem.fromUri(track.uri))
            prepare()
            seekTo(position)
            // 不自动播放，只是准备好
        }
        
        notifyStateChanged()
    }
    
    // MARK: - 私有方法
    
    private fun onTrackEnded() {
        if (currentIndex < playlist.size - 1) {
            playNext()
        }
    }
    
    private fun saveCurrentState() {
        val prefs = MonoApplication.instance.preferencesManager
        prefs.savePlaybackState(
            currentTrack?.path,
            exoPlayer?.currentPosition ?: 0L
        )
    }
    
    private fun notifyStateChanged() {
        // 状态变化通知 - UI 通过轮询或 Flow 获取状态
    }
    
    // 更新播放列表（删除后调用）
    fun updatePlaylist(newPlaylist: List<AudioTrack>) {
        playlist = newPlaylist
        if (currentTrack != null && currentTrack !in newPlaylist) {
            // 当前播放的曲目被删除
            pause()
            currentTrack = null
            MonoApplication.instance.preferencesManager.clearPlaybackState()
        } else if (currentTrack != null) {
            currentIndex = newPlaylist.indexOf(currentTrack).coerceAtLeast(0)
        }
        notifyStateChanged()
    }
}


