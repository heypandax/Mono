package com.mono.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.mono.MonoApplication
import com.mono.data.model.AudioFolder
import com.mono.player.AudioPlaybackService
import com.mono.ui.theme.Orange

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FolderListScreen(
    onFolderClick: (AudioFolder) -> Unit,
    onPlayerClick: () -> Unit
) {
    val fileRepository = MonoApplication.instance.fileRepository
    var folders by remember { mutableStateOf<List<AudioFolder>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var folderToDelete by remember { mutableStateOf<AudioFolder?>(null) }
    
    // 加载文件夹（在 IO 线程）
    LaunchedEffect(Unit) {
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            val result = fileRepository.getFolders()
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Main) {
                folders = result
                isLoading = false
            }
        }
    }
    
    // 刷新函数
    val refreshFolders: () -> Unit = {
        folders = fileRepository.getFolders()
    }
    
    Scaffold(
        topBar = {
            LargeTopAppBar(
                title = { Text("听书") },
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background
                )
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center),
                    color = Orange
                )
            } else if (folders.isEmpty()) {
                // 空状态
                Text(
                    text = "暂无音频文件\n\n请将音频文件夹复制到\nMusic/Mono 目录",
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(40.dp),
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(bottom = 80.dp) // 为 MiniPlayer 留空间
                ) {
                    items(
                        items = folders,
                        key = { it.path }
                    ) { folder ->
                        FolderItem(
                            folder = folder,
                            onClick = { onFolderClick(folder) },
                            onLongClick = { folderToDelete = folder }
                        )
                    }
                }
            }
        }
    }
    
    // 删除确认对话框
    folderToDelete?.let { folder ->
        AlertDialog(
            onDismissRequest = { folderToDelete = null },
            title = { Text("删除文件夹") },
            text = { Text("确定要删除「${folder.name}」及其中的所有音频文件吗？") },
            confirmButton = {
                TextButton(
                    onClick = {
                        // 如果正在播放该文件夹的内容，停止播放
                        val service = AudioPlaybackService.getInstance()
                        val currentTrack = service?.getPlaybackState()?.currentTrack
                        if (currentTrack?.folderName == folder.name) {
                            service?.pause()
                            MonoApplication.instance.preferencesManager.clearPlaybackState()
                        }
                        
                        fileRepository.deleteFolder(folder)
                        refreshFolders()
                        folderToDelete = null
                    },
                    colors = ButtonDefaults.textButtonColors(contentColor = Color.Red)
                ) {
                    Text("删除")
                }
            },
            dismissButton = {
                TextButton(onClick = { folderToDelete = null }) {
                    Text("取消")
                }
            }
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FolderItem(
    folder: AudioFolder,
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
            // 文件夹图标
            Surface(
                modifier = Modifier.size(48.dp),
                shape = MaterialTheme.shapes.medium,
                color = Orange.copy(alpha = 0.15f)
            ) {
                Icon(
                    imageVector = Icons.Default.Folder,
                    contentDescription = null,
                    modifier = Modifier
                        .padding(12.dp)
                        .fillMaxSize(),
                    tint = Orange
                )
            }
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = folder.name,
                    style = MaterialTheme.typography.bodyLarge
                )
                Text(
                    text = "${folder.trackCount} 个音频",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}
