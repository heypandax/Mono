package com.mono

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import com.mono.player.AudioPlaybackService
import com.mono.ui.navigation.MonoNavGraph
import com.mono.ui.theme.MonoTheme
import java.io.File

class MainActivity : ComponentActivity() {
    
    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        // 权限结果处理
        val allGranted = permissions.all { it.value }
        if (allGranted) {
            restorePlaybackIfNeeded()
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        // 启动播放服务
        startService(Intent(this, AudioPlaybackService::class.java))
        
        // 请求权限
        requestPermissions()
        
        setContent {
            MonoTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MonoNavGraph()
                }
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        // 恢复播放状态
        if (hasStoragePermission()) {
            restorePlaybackIfNeeded()
        }
    }
    
    override fun onPause() {
        super.onPause()
        // 保存播放状态
        val service = AudioPlaybackService.getInstance()
        if (service != null) {
            val state = service.getPlaybackState()
            MonoApplication.instance.preferencesManager.savePlaybackState(
                state.currentTrack?.path,
                service.getCurrentPosition()
            )
        }
    }
    
    private fun requestPermissions() {
        val permissions = mutableListOf<String>()
        
        // Android 13+ 需要 READ_MEDIA_AUDIO
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }
        
        if (permissions.isNotEmpty()) {
            permissionLauncher.launch(permissions.toTypedArray())
        } else {
            restorePlaybackIfNeeded()
        }
    }
    
    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
        }
    }
    
    private fun restorePlaybackIfNeeded() {
        val prefs = MonoApplication.instance.preferencesManager
        val savedPath = prefs.currentTrackPath ?: return
        val savedPosition = prefs.currentPosition
        
        // 检查文件是否存在
        if (!File(savedPath).exists()) {
            prefs.clearPlaybackState()
            return
        }
        
        // 查找对应的文件夹和曲目
        val fileRepo = MonoApplication.instance.fileRepository
        val folder = fileRepo.findFolderForTrack(savedPath) ?: return
        val tracks = fileRepo.getTracks(folder)
        val track = tracks.find { it.path == savedPath } ?: return
        
        // 恢复播放
        val service = AudioPlaybackService.getInstance()
        service?.restorePlayback(track, tracks, savedPosition)
    }
}


