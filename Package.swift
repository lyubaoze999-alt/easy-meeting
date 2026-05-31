// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MeetingNotes",
    // 部署目标 macOS 14.4+（需求 2.1）。SPM 平台粒度为大版本，
    // 精确到 14.4 的最低系统由 Info.plist 的 LSMinimumSystemVersion 约束，
    // Core Audio Process Tap 等 14.4 才有的 API 在调用处用可用性检查保护。
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MeetingNotes", targets: ["MeetingNotes"])
    ],
    dependencies: [
        // 本地存储：纪要元数据入 SQLite（基础设施层 NoteRepository 使用）
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.9.0"),
        // 属性测试：守护设计文档定义的 8 条正确性属性
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "MeetingNotes",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            // Info.plist 不作为 SPM 资源处理，改由链接器嵌入，故从源码编译中排除。
            // 各分层目录下的 README.md 仅作架构说明，非源码/资源，一并排除以避免 unhandled 警告。
            exclude: [
                "Resources/Info.plist",
                "UI/README.md",
                "AppServices/README.md",
                "Domain/README.md",
                "Infrastructure/README.md"
            ],
            // Info.plist 通过链接器 -sectcreate 嵌入可执行文件的 __TEXT,__info_plist 段，
            // 使 swift run 产出的二进制也遵守 LSUIElement（菜单栏常驻、无 Dock 图标）。
            // 注意：SPM 不允许把 Info.plist 作为 resources 资源，故仅用链接器嵌入。
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/MeetingNotes/Resources/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "MeetingNotesTests",
            dependencies: [
                "MeetingNotes",
                .product(name: "SwiftCheck", package: "SwiftCheck")
            ]
        )
    ]
)
