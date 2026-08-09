package com.mono.data.preferences

import android.content.Context
import android.content.SharedPreferences

class PreferencesManager(context: Context) {
    
    companion object {
        private const val PREFS_NAME = "mono_prefs"
        private const val KEY_CURRENT_TRACK_PATH = "current_track_path"
        private const val KEY_CURRENT_POSITION = "current_position"
        private const val KEY_PLAYBACK_SPEED = "playback_speed"
        
        val AVAILABLE_SPEEDS = listOf(0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f, 2.5f, 3.0f)
    }
    
    private val prefs: SharedPreferences = 
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    /**
     * 当前播放的音频路径
     */
    var currentTrackPath: String?
        get() = prefs.getString(KEY_CURRENT_TRACK_PATH, null)
        set(value) = prefs.edit().putString(KEY_CURRENT_TRACK_PATH, value).apply()
    
    /**
     * 当前播放位置（毫秒）
     */
    var currentPosition: Long
        get() = prefs.getLong(KEY_CURRENT_POSITION, 0L)
        set(value) = prefs.edit().putLong(KEY_CURRENT_POSITION, value).apply()
    
    /**
     * 播放速度
     */
    var playbackSpeed: Float
        get() = prefs.getFloat(KEY_PLAYBACK_SPEED, 1.0f)
        set(value) = prefs.edit().putFloat(KEY_PLAYBACK_SPEED, value).apply()
    
    /**
     * 保存播放状态
     */
    fun savePlaybackState(trackPath: String?, position: Long) {
        prefs.edit()
            .putString(KEY_CURRENT_TRACK_PATH, trackPath)
            .putLong(KEY_CURRENT_POSITION, position)
            .apply()
    }
    
    /**
     * 清除播放状态
     */
    fun clearPlaybackState() {
        prefs.edit()
            .remove(KEY_CURRENT_TRACK_PATH)
            .remove(KEY_CURRENT_POSITION)
            .apply()
    }
}


