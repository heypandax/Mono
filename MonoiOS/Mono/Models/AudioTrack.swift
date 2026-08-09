//
//  AudioTrack.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation

struct AudioFolder: Equatable {
    let name: String
    let url: URL
    var trackCount: Int = 0
    
    static func == (lhs: AudioFolder, rhs: AudioFolder) -> Bool {
        return lhs.url == rhs.url
    }
}

struct AudioTrack: Equatable {
    let fileName: String
    let url: URL
    let folderName: String
    var duration: TimeInterval = 0
    
    var displayName: String {
        // 移除文件扩展名
        return (fileName as NSString).deletingPathExtension
    }
    
    static func == (lhs: AudioTrack, rhs: AudioTrack) -> Bool {
        return lhs.url == rhs.url
    }
}



