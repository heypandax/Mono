package com.mono.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mono.MonoApplication
import com.mono.data.model.AudioFolder
import com.mono.data.model.AudioTrack
import com.mono.player.AudioPlaybackService
import com.mono.ui.theme.Orange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TrackListScreen(
    folder: AudioFolder,
    onBackClick: () -> Unit,
    onPlayerClick: () -> Unit
) {
    val fileRepository = MonoApplication.instance.fileRepository
    var tracks by remember { mutableStateOf<List<AudioTrack>>(emptyList()) }
    var trackToDelete by remember { mutableStateOf<AudioTrack?>(null) }
    var currentPlayingPath by remember { mutableStateOf<String?>(null) }
    
    // 快速加载音频列表（不含时长）
    LaunchedEffect(folder) {
        tracks = fileRepository.getTracks(folder)
        
        // 异步加载时长
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val tracksWithDuration = fileRepository.loadTracksWithDuration(folder)
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                tracks = tracksWithDuration
            }
        }
    }
    
    // 监听播放状态
    LaunchedEffect(Unit) {
        while (true) {
            val service = AudioPlaybackService.getInstance()
            currentPlayingPath = service?.getPlaybackState()?.currentTrack?.path
            kotlinx.coroutines.delay(500)
        }
    }
    
    val refreshTracks: () -> Unit = {
        tracks = fileRepository.getTracks(folder)
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = folder.name,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                },
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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(bottom = 80.dp)
        ) {
            itemsIndexed(
                items = tracks,
                key = { _, track -> track.path }
            ) { index, track ->
                val isPlaying = track.path == currentPlayingPath
                
                TrackItem(
                    track = track,
                    index = index + 1,
                    isPlaying = isPlaying,
                    onClick = {
                        // 启动播放服务并播放
                        val service = AudioPlaybackService.getInstance()
                        service?.play(track, tracks)
                    },
                    onLongClick = { trackToDelete = track }
                )
            }
        }
    }
    
    // 删除确认对话框
    trackToDelete?.let { track ->
        AlertDialog(
            onDismissRequest = { trackToDelete = null },
            title = { Text("删除音频") },
            text = { Text("确定要删除「${track.displayName}」吗？") },
            confirmButton = {
                TextButton(
                    onClick = {
                        val service = AudioPlaybackService.getInstance()
                        val currentTrack = service?.getPlaybackState()?.currentTrack
                        
                        if (currentTrack?.path == track.path) {
                            service?.pause()
                            MonoApplication.instance.preferencesManager.clearPlaybackState()
                        }
                        
                        fileRepository.deleteTrack(track)
                        refreshTracks()
                        
                        // 更新播放列表
                        service?.updatePlaylist(tracks.filter { it.path != track.path })
                        
                        trackToDelete = null
                        
                        // 如果没有音频了，返回上一页
                        if (tracks.size <= 1) {
                            onBackClick()
                        }
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = Color.Red)
                ) {
                    Text("删除")
                }
            },
            dismissButton = {
                TextButton(onClick = { trackToDelete = null }) {
                    Text("取消")
                }
            }
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun TrackItem(
    track: AudioTrack,
    index: Int,
    isPlaying: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.background
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .combinedClickable(
                    onClick = onClick,
                    onLongClick = onLongClick
                )
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 序号或播放指示
            Box(
                modifier = Modifier.width(32.dp),
                contentAlignment = Alignment.Center
            ) {
                if (isPlaying) {
                    Icon(
                        imageVector = Icons.Default.VolumeUp,
                        contentDescription = "正在播放",
                        modifier = Modifier.size(20.dp),
                        tint = Orange
                    )
                } else {
                    Text(
                        text = "$index",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            
            Spacer(modifier = Modifier.width(12.dp))
            
            // 文件名
            Text(
                text = track.displayName,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyLarge,
                color = if (isPlaying) Orange else MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            
            Spacer(modifier = Modifier.width(12.dp))
            
            // 时长
            Text(
                text = track.formattedDuration,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
