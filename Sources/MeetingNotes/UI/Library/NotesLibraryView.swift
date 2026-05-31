import SwiftUI

/// 纪要库主窗口（界面层，任务 15.1，需求 11.1-11.5）。
///
/// 左右分栏布局（需求 11.1）：左侧为按日期分组（今天 / 昨天 / 本周早些时候 / 更早，
/// 需求 11.2）的纪要列表，每行展示标题、时间与时长（需求 11.3），顶部含搜索框，
/// 输入关键词按标题 / 正文过滤（需求 11.4）；右侧展示当前选中纪要的正文，选中行
/// 在左侧高亮（需求 11.5）。
///
/// 用 `HSplitView` 实现左右分栏：macOS 上原生支持可拖拽分隔，左窄右宽。右侧正文
/// 在本任务先做基础渲染（标题 / 元信息 / 分区文字 / 待办），完整的结构化展示与图文
/// 模式切换由任务 15.2、15.3 在 `NoteDetailView` 上继续完善。
///
/// 取色全部来自 `@Environment(\.themeTokens)`，不写死色值（需求 17.4）；自有文案均为
/// 中文（需求 1.1），接口地址 / 模型名等用户输入按原样展示（需求 1.2）。
struct NotesLibraryView: View {
    @Environment(\.themeTokens) private var tokens
    @StateObject private var viewModel: NotesLibraryViewModel

    /// - Parameter viewModel: 纪要库视图模型（持有仓储依赖与列表 / 选中状态）。
    init(viewModel: NotesLibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// 便捷构造：直接注入仓储，由视图内部建立视图模型。
    /// - Parameter store: 纪要仓储依赖。
    init(store: NoteStoring) {
        _viewModel = StateObject(wrappedValue: NotesLibraryViewModel(store: store))
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            detail
                .frame(minWidth: 360, maxWidth: .infinity)
        }
        .background(tokens.background)
        .onAppear { viewModel.load() }
    }
}

// MARK: - 左侧：搜索 + 日期分组列表（需求 11.2、11.3、11.4）

private extension NotesLibraryView {
    /// 左侧栏：顶部搜索框 + 按日期分组的纪要列表。
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                .padding(tokens.spacingUnit * 1.5)
            Divider()
            listContent
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(tokens.surface)
    }

    /// 搜索框：输入关键词按标题 / 正文过滤（需求 11.4）。
    var searchField: some View {
        HStack(spacing: tokens.spacingUnit) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(tokens.textSecondary)
            TextField("搜索标题或正文", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .foregroundColor(tokens.textPrimary)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(tokens.textSecondary)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
            }
        }
        .padding(.horizontal, tokens.spacingUnit)
        .padding(.vertical, tokens.spacingUnit * 0.75)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.background)
        )
    }

    /// 列表主体：有数据按分组展示，无数据展示中文空态（需求 11.2、1.1）。
    @ViewBuilder
    var listContent: some View {
        if viewModel.sections.isEmpty {
            emptyListPlaceholder
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: tokens.spacingUnit * 1.5, pinnedViews: [.sectionHeaders]) {
                    ForEach(viewModel.sections) { section in
                        Section {
                            ForEach(section.notes) { note in
                                NoteListRow(
                                    note: note,
                                    isSelected: viewModel.isSelected(note)
                                ) {
                                    viewModel.select(note)
                                }
                            }
                        } header: {
                            groupHeader(section.group)
                        }
                    }
                }
                .padding(tokens.spacingUnit)
            }
        }
    }

    /// 分组小标题（今天 / 昨天 / 本周早些时候 / 更早，需求 11.2）。
    func groupHeader(_ group: NoteDateGroup) -> some View {
        Text(group.title)
            .font(.caption.bold())
            .foregroundColor(tokens.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, tokens.spacingUnit * 0.5)
            .padding(.vertical, tokens.spacingUnit * 0.5)
            .background(tokens.surface)
    }

    /// 列表空态：区分"无任何纪要"与"搜索无结果"两种中文提示（需求 1.1）。
    var emptyListPlaceholder: some View {
        VStack(spacing: tokens.spacingUnit) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(tokens.textSecondary)
            Text(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "还没有纪要"
                 : "没有匹配的纪要")
                .font(.callout)
                .foregroundColor(tokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(tokens.spacingUnit * 2)
    }
}

// MARK: - 右侧：正文展示（需求 11.5）

private extension NotesLibraryView {
    /// 右侧正文区：有选中项展示其正文，否则展示中文占位（需求 11.5）。
    @ViewBuilder
    var detail: some View {
        if let note = viewModel.selectedNote {
            NoteDetailView(note: note)
        } else {
            VStack(spacing: tokens.spacingUnit) {
                Image(systemName: "doc.text")
                    .font(.largeTitle)
                    .foregroundColor(tokens.textSecondary)
                Text("从左侧选择一条纪要查看正文")
                    .font(.callout)
                    .foregroundColor(tokens.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tokens.background)
        }
    }
}

#if DEBUG
/// 预览：覆盖含多日期分组的纪要列表（浅色）与空列表（深色）两种典型场景。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
struct NotesLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NotesLibraryView(viewModel: NotesLibraryPreviewSupport.populatedViewModel())
                .frame(width: 720, height: 480)
                .themeTokens(.light)
                .previewDisplayName("纪要库-有数据-浅色")

            NotesLibraryView(viewModel: NotesLibraryPreviewSupport.emptyViewModel())
                .frame(width: 720, height: 480)
                .themeTokens(.dark)
                .previewDisplayName("纪要库-空-深色")
        }
    }
}
#endif
