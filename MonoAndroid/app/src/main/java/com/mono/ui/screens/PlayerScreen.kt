package com.mono.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mono.data.model.AudioTrack
import com.mono.data.preferences.PreferencesManager
import com.mono.player.AudioPlaybackService
import com.mono.player.PlaybackState
import com.mono.ui.theme.Orange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlayerScreen(
    onBackClick: () -> Unit
) {
    var playbackState by remember { mutableStateOf(PlaybackState()) }
    var showSpeedDialog by remember { mutableStateOf(false) }
    
    // 轮询播放状态
    LaunchedEffect(Unit) {
        while (true) {
            val service = AudioPlaybackService.getInstance()
            if (service != null) {
                playbackState = playbackState.copy(
                    currentTrack = service.getPlaybackState().currentTrack,
                    playlist = service.getPlaybackState().playlist,
                    currentIndex = service.getPlaybackState().currentIndex,
                    isPlaying = service.isPlaying(),
                    currentPosition = service.getCurrentPosition(),
                    duration = service.getDuration(),
                    playbackSpeed = service.getPlaybackState().playbackSpeed
                )
            }
            kotlinx.coroutines.delay(200)
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "返回"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(40.dp))
            
            // 音乐图标
            Surface(
                modifier = Modifier.size(200.dp),
                shape = MaterialTheme.shapes.large,
                color = Orange.copy(alpha = 0.15f)
            ) {
                Icon(
                    imageVector = Icons.Default.MusicNote,
                    contentDescription = null,
                    modifier = Modifier
                        .padding(50.dp)
                        .fillMaxSize(),
                    tint = Orange
                )
            }
            
            Spacer(modifier = Modifier.height(32.dp))
            
            // 标题
            Text(
                text = playbackState.currentTrack?.displayName ?: "未在播放",
                style = MaterialTheme.typography.titleLarge,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // 文件夹名
            Text(
                text = playbackState.currentTrack?.folderName ?: "",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )
            
            Spacer(modifier = Modifier.height(40.dp))
            
            // 进度条
            Column(modifier = Modifier.fillMaxWidth()) {
                Slider(
                    value = if (playbackState.duration > 0) 
                        playbackState.currentPosition.toFloat() / playbackState.duration 
                    else 0f,
                    onValueChange = { progress ->
                        val newPosition = (progress * playbackState.duration).toLong()
                        AudioPlaybackService.getInstance()?.seekTo(newPosition)
                    },
                    colors = SliderDefaults.colors(
                        thumbColor = Orange,
                        activeTrackColor = Orange
                    )
                )
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = AudioTrack.formatDuration(playbackState.currentPosition),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "-${AudioTrack.formatDuration(
                            (playbackState.duration - playbackState.currentPosition).coerceAtLeast(0)
                        )}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(24.dp))
            
            // 播放控制
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 上一曲
                IconButton(
                    onClick = { AudioPlaybackService.getInstance()?.playPrevious() }
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipPrevious,
                        contentDescription = "上一曲",
                        modifier = Modifier.size(32.dp)
                    )
                }
                
                // 后退15秒
                IconButton(
                    onClick = { AudioPlaybackService.getInstance()?.skipBackward(15) }
                ) {
                    Icon(
                        imageVector = Icons.Default.Replay10,
                        contentDescription = "后退15秒",
                        modifier = Modifier.size(36.dp)
                    )
                }
                
                // 播放/暂停
                FilledIconButton(
                    onClick = { AudioPlaybackService.getInstance()?.togglePlayPause() },
                    modifier = Modifier.size(72.dp),
                    colors = IconButtonDefaults.filledIconButtonColors(
                        containerColor = Orange
                    )
                ) {
                    Icon(
                        imageVector = if (playbackState.isPlaying) 
                            Icons.Default.Pause else Icons.Default.PlayArrow,
                        contentDescription = if (playbackState.isPlaying) "暂停" else "播放",
                        modifier = Modifier.size(40.dp)
                    )
                }
                
                // 前进15秒
                IconButton(
                    onClick = { AudioPlaybackService.getInstance()?.skipForward(15) }
                ) {
                    Icon(
                        imageVector = Icons.Default.Forward10,
                        contentDescription = "前进15秒",
                        modifier = Modifier.size(36.dp)
                    )
                }
                
                // 下一曲
                IconButton(
                    onClick = { AudioPlaybackService.getInstance()?.playNext() }
                ) {
                    Icon(
                        imageVector = Icons.Default.SkipNext,
                        contentDescription = "下一曲",
                        modifier = Modifier.size(32.dp)
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(40.dp))
            
            // 倍速按钮
            FilledTonalButton(
                onClick = { showSpeedDialog = true }
            ) {
                Text(
                    text = if (playbackState.playbackSpeed == 1.0f) "1x" 
                           else "${playbackState.playbackSpeed}x"
                )
            }
        }
    }
    
    // 倍速选择对话框
    if (showSpeedDialog) {
        SpeedSelectionDialog(
            currentSpeed = playbackState.playbackSpeed,
            onSpeedSelected = { speed ->
                AudioPlaybackService.getInstance()?.setPlaybackSpeed(speed)
                showSpeedDialog = false
            },
            onDismiss = { showSpeedDialog = false }
        )
    }
}

@Composable
private fun SpeedSelectionDialog(
    currentSpeed: Float,
    onSpeedSelected: (Float) -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("播放速度") },
        text = {
            Column {
                PreferencesManager.AVAILABLE_SPEEDS.forEach { speed ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = speed == currentSpeed,
                            onClick = { onSpeedSelected(speed) },
                            colors = RadioButtonDefaults.colors(
                                selectedColor = Orange
                            )
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = if (speed == 1.0f) "正常" else "${speed}x"
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("取消")
            }
        }
    )
}

