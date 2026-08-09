package com.mono.data.model

import android.net.Uri
import java.io.File

data class AudioTrack(
    val fileName: String,
    val path: String,
    val folderName: String,
    val duration: Long = 0L // 毫秒
) {
    val file: File get() = File(path)
    
    val uri: Uri get() = Uri.fromFile(file)
    
    val displayName: String
        get() = fileName.substringBeforeLast(".")
    
    val formattedDuration: String
        get() = formatDuration(duration)
    
    companion object {
        fun formatDuration(millis: Long): String {
            if (millis <= 0) return "00:00"
            
            val totalSeconds = millis / 1000
            val hours = totalSeconds / 3600
            val minutes = (totalSeconds % 3600) / 60
            val seconds = totalSeconds % 60
            
            return if (hours > 0) {
                String.format("%d:%02d:%02d", hours, minutes, seconds)
            } else {
                String.format("%02d:%02d", minutes, seconds)
            }
        }
    }
}


