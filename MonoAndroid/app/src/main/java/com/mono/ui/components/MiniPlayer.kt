package com.mono.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mono.player.AudioPlaybackService
import com.mono.player.PlaybackState
import com.mono.ui.theme.Orange

@Composable
fun MiniPlayer(
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    var playbackState by remember { mutableStateOf(PlaybackState()) }
    
    // 轮询播放状态
    LaunchedEffect(Unit) {
        while (true) {
            val service = AudioPlaybackService.getInstance()
            if (service != null) {
                playbackState = service.getPlaybackState()
            }
            kotlinx.coroutines.delay(200)
        }
    }
    
    AnimatedVisibility(
        visible = playbackState.currentTrack != null,
        enter = slideInVertically { it },
        exit = slideOutVertically { it },
        modifier = modifier
    ) {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            tonalElevation = 3.dp,
            shadowElevation = 8.dp
        ) {
            Column {
                // 进度条
                LinearProgressIndicator(
                    progress = playbackState.progress,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(2.dp),
                    color = Orange,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant
                )
                
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onClick)
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // 音乐图标
                    Surface(
                        modifier = Modifier.size(44.dp),
                        shape = MaterialTheme.shapes.small,
                        color = Orange.copy(alpha = 0.15f)
                    ) {
                        Icon(
                            imageVector = Icons.Default.MusicNote,
                            contentDescription = null,
                            modifier = Modifier
                                .padding(10.dp)
                                .fillMaxSize(),
                            tint = Orange
                        )
                    }
                    
                    Spacer(modifier = Modifier.width(12.dp))
                    
                    // 标题和副标题
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = playbackState.currentTrack?.displayName ?: "未在播放",
                            style = MaterialTheme.typography.bodyMedium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = playbackState.currentTrack?.folderName ?: "",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    
                    // 播放/暂停按钮
                    IconButton(
                        onClick = {
                            AudioPlaybackService.getInstance()?.togglePlayPause()
                        }
                    ) {
                        Icon(
                            imageVector = if (playbackState.isPlaying) 
                                Icons.Default.Pause else Icons.Default.PlayArrow,
                            contentDescription = if (playbackState.isPlaying) "暂停" else "播放",
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }
            }
        }
    }
}

