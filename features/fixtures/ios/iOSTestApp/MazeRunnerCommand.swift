//
//  MazeRunnerCommand.swift
//  iOSTestApp
//
//  Created by Karl Stenerud on 11.03.24.
//  Copyright © 2024 Bugsnag. All rights reserved.
//

import Foundation

class MazeRunnerCommand: Codable {
    let message: String
    let action: String
    let uuid: String
    let args: Array<String>
    
    init(uuid: String, action: String, args: Array<String>, message: String) {
        self.uuid = uuid
        self.message = message
        self.action = action
        self.args = args
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
        self.message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        self.action = try container.decodeIfPresent(String.self, forKey: .action) ?? ""
        self.args = try container.decodeIfPresent(Array<String>.self, forKey: .args) ?? []
    }
}
