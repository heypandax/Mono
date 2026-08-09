package com.mono.data.model

import java.io.File

data class AudioFolder(
    val name: String,
    val path: String,
    val trackCount: Int
) {
    val file: File get() = File(path)
}


