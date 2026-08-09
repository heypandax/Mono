package com.mono

import android.app.Application
import com.mono.data.preferences.PreferencesManager
import com.mono.data.repository.FileRepository

class MonoApplication : Application() {
    
    companion object {
        lateinit var instance: MonoApplication
            private set
    }
    
    lateinit var fileRepository: FileRepository
        private set
    
    lateinit var preferencesManager: PreferencesManager
        private set
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        
        fileRepository = FileRepository(this)
        preferencesManager = PreferencesManager(this)
    }
}


