package com.mono.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.mono.data.model.AudioFolder
import com.mono.ui.components.MiniPlayer
import com.mono.ui.screens.FolderListScreen
import com.mono.ui.screens.PlayerScreen
import com.mono.ui.screens.TrackListScreen
import java.net.URLDecoder
import java.net.URLEncoder

sealed class Screen(val route: String) {
    object FolderList : Screen("folder_list")
    object TrackList : Screen("track_list/{folderName}/{folderPath}") {
        fun createRoute(folder: AudioFolder): String {
            val encodedName = URLEncoder.encode(folder.name, "UTF-8")
            val encodedPath = URLEncoder.encode(folder.path, "UTF-8")
            return "track_list/$encodedName/$encodedPath"
        }
    }
    object Player : Screen("player")
}

@Composable
fun MonoNavGraph(
    navController: NavHostController = rememberNavController()
) {
    Scaffold { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            NavHost(
                navController = navController,
                startDestination = Screen.FolderList.route,
                modifier = Modifier.fillMaxSize()
            ) {
                composable(Screen.FolderList.route) {
                    FolderListScreen(
                        onFolderClick = { folder ->
                            navController.navigate(Screen.TrackList.createRoute(folder))
                        },
                        onPlayerClick = {
                            navController.navigate(Screen.Player.route)
                        }
                    )
                }
                
                composable(Screen.TrackList.route) { backStackEntry ->
                    val folderName = backStackEntry.arguments?.getString("folderName")?.let {
                        URLDecoder.decode(it, "UTF-8")
                    } ?: ""
                    val folderPath = backStackEntry.arguments?.getString("folderPath")?.let {
                        URLDecoder.decode(it, "UTF-8")
                    } ?: ""
                    
                    val folder = AudioFolder(
                        name = folderName,
                        path = folderPath,
                        trackCount = 0
                    )
                    
                    TrackListScreen(
                        folder = folder,
                        onBackClick = { navController.popBackStack() },
                        onPlayerClick = { navController.navigate(Screen.Player.route) }
                    )
                }
                
                composable(Screen.Player.route) {
                    PlayerScreen(
                        onBackClick = { navController.popBackStack() }
                    )
                }
            }
            
            // 底部迷你播放栏（在播放器页面不显示）
            val currentRoute = navController.currentBackStackEntryFlow
                .collectAsState(initial = null)
                .value?.destination?.route
            
            if (currentRoute != Screen.Player.route) {
                MiniPlayer(
                    modifier = Modifier.align(Alignment.BottomCenter),
                    onClick = { navController.navigate(Screen.Player.route) }
                )
            }
        }
    }
}


