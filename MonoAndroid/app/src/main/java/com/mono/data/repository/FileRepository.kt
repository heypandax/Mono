package com.mono.data.repository

import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Environment
import com.mono.data.model.AudioFolder
import com.mono.data.model.AudioTrack
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class FileRepository(private val context: Context) {
    
    companion object {
        private val SUPPORTED_EXTENSIONS = listOf(
            "mp3", "m4a", "m4b", "wav", "aac", "flac", "ogg", "wma"
        )
        
        private const val APP_FOLDER_NAME = "Mono"
    }
    
    // 时长缓存
    private val durationCache = ConcurrentHashMap<String, Long>()
    
    /**
     * 获取 App 的音频根目录：Music/Mono
     */
    val audioRootDir: File
        get() {
            val musicDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
            val appDir = File(musicDir, APP_FOLDER_NAME)
            if (!appDir.exists()) {
                appDir.mkdirs()
            }
            return appDir
        }
    
    /**
     * 获取所有包含音频的文件夹（按名称排序）
     */
    fun getFolders(): List<AudioFolder> {
        val rootDir = audioRootDir
        if (!rootDir.exists() || !rootDir.isDirectory) {
            return emptyList()
        }
        
        return rootDir.listFiles()
            ?.filter { it.isDirectory }
            ?.mapNotNull { folder ->
                val trackCount = countTracks(folder)
                if (trackCount > 0) {
                    AudioFolder(
                        name = folder.name,
                        path = folder.absolutePath,
                        trackCount = trackCount
                    )
                } else null
            }
            ?.sortedWith(NaturalOrderComparator { it.name })
            ?: emptyList()
    }
    
    /**
     * 计算文件夹内音频文件数量
     */
    private fun countTracks(folder: File): Int {
        return folder.listFiles()
            ?.count { isAudioFile(it) }
            ?: 0
    }
    
    /**
     * 获取文件夹内的音频文件（按文件名排序）- 快速返回，使用缓存时长
     */
    fun getTracks(folder: AudioFolder): List<AudioTrack> {
        val dir = folder.file
        if (!dir.exists() || !dir.isDirectory) {
            return emptyList()
        }
        
        return dir.listFiles()
            ?.filter { isAudioFile(it) }
            ?.map { file ->
                AudioTrack(
                    fileName = file.name,
                    path = file.absolutePath,
                    folderName = folder.name,
                    duration = durationCache[file.absolutePath] ?: 0L
                )
            }
            ?.sortedWith(NaturalOrderComparator { it.fileName })
            ?: emptyList()
    }
    
    /**
     * 加载音频时长（在后台调用）
     */
    fun loadTracksWithDuration(folder: AudioFolder): List<AudioTrack> {
        val dir = folder.file
        if (!dir.exists() || !dir.isDirectory) {
            return emptyList()
        }
        
        return dir.listFiles()
            ?.filter { isAudioFile(it) }
            ?.map { file ->
                val cachedDuration = durationCache[file.absolutePath]
                val duration = cachedDuration ?: run {
                    val d = getAudioDuration(file)
                    durationCache[file.absolutePath] = d
                    d
                }
                
                AudioTrack(
                    fileName = file.name,
                    path = file.absolutePath,
                    folderName = folder.name,
                    duration = duration
                )
            }
            ?.sortedWith(NaturalOrderComparator { it.fileName })
            ?: emptyList()
    }
    
    /**
     * 根据路径获取对应的文件夹
     */
    fun findFolderForTrack(trackPath: String): AudioFolder? {
        val trackFile = File(trackPath)
        val parentDir = trackFile.parentFile ?: return null
        val trackCount = countTracks(parentDir)
        
        return AudioFolder(
            name = parentDir.name,
            path = parentDir.absolutePath,
            trackCount = trackCount
        )
    }
    
    /**
     * 删除文件夹
     */
    fun deleteFolder(folder: AudioFolder): Boolean {
        return try {
            // 清除该文件夹下所有文件的时长缓存
            folder.file.listFiles()?.forEach { file ->
                durationCache.remove(file.absolutePath)
            }
            folder.file.deleteRecursively()
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
    
    /**
     * 删除音频文件
     */
    fun deleteTrack(track: AudioTrack): Boolean {
        return try {
            durationCache.remove(track.path)
            track.file.delete()
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
    
    /**
     * 判断是否为支持的音频文件
     */
    private fun isAudioFile(file: File): Boolean {
        if (!file.isFile) return false
        val extension = file.extension.lowercase()
        return extension in SUPPORTED_EXTENSIONS
    }
    
    /**
     * 获取音频时长（毫秒）
     */
    private fun getAudioDuration(file: File): Long {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(file.absolutePath)
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            retriever.release()
            duration?.toLongOrNull() ?: 0L
        } catch (e: Exception) {
            0L
        }
    }
    
    /**
     * 自然排序比较器（数字感知）
     */
    private class NaturalOrderComparator<T>(private val selector: (T) -> String) : Comparator<T> {
        private val regex = Regex("(\\d+)")
        
        override fun compare(a: T, b: T): Int {
            val strA = selector(a)
            val strB = selector(b)
            
            val partsA = splitByNumbers(strA)
            val partsB = splitByNumbers(strB)
            
            val minSize = minOf(partsA.size, partsB.size)
            for (i in 0 until minSize) {
                val partA = partsA[i]
                val partB = partsB[i]
                
                val numA = partA.toLongOrNull()
                val numB = partB.toLongOrNull()
                
                val cmp = when {
                    numA != null && numB != null -> numA.compareTo(numB)
                    else -> partA.compareTo(partB, ignoreCase = true)
                }
                
                if (cmp != 0) return cmp
            }
            
            return partsA.size - partsB.size
        }
        
        private fun splitByNumbers(s: String): List<String> {
            val result = mutableListOf<String>()
            var lastEnd = 0
            
            for (match in regex.findAll(s)) {
                if (match.range.first > lastEnd) {
                    result.add(s.substring(lastEnd, match.range.first))
                }
                result.add(match.value)
                lastEnd = match.range.last + 1
            }
            
            if (lastEnd < s.length) {
                result.add(s.substring(lastEnd))
            }
            
            return result
        }
    }
}
