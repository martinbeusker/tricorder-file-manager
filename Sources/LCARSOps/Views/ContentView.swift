import SwiftUI

enum FocusField: Hashable { case list, search }

struct ContentView: View {
    @ObservedObject var model: FileSystemModel
    @FocusState private var focus: FocusField?

    var body: some View {
        VStack(spacing: Metric.outerGap) {
            TopFrame(model: model)

            // middle: rail + content
            HStack(spacing: Metric.outerGap) {
                NavRail(model: model)

                GeometryReader { geo in
                    let recordW = min(300, max(190, geo.size.width * 0.23))
                    HStack(spacing: 16) {
                        FileListView(model: model, focus: $focus)
                            .frame(maxWidth: .infinity)
                        RecordPanel(model: model)
                            .frame(width: recordW)
                    }
                    .padding(.init(top: 6, leading: 12, bottom: 6, trailing: 4))
                }
            }
            .frame(maxHeight: .infinity)

            BottomFrame(model: model)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 30)                       // clearance for the traffic-light controls
        .frame(minWidth: 1000, idealWidth: 1200, maxWidth: .infinity,
               minHeight: 680, idealHeight: 780, maxHeight: .infinity)
        .background(LC.black)
        .font(.antonio(15))
        .focusable()
        .focused($focus, equals: .list)
        .focusEffectDisabled()
        .onAppear { focus = .list }
        .onChange(of: model.searchFocusRequests) { _, _ in focus = .search }
        .onChange(of: model.query) { _, _ in model.searchQueryChanged() }
        .onKeyPress(.downArrow) { guard focus == .list else { return .ignored }; model.moveSelection(1); return .handled }
        .onKeyPress(.upArrow)   { guard focus == .list else { return .ignored }; model.moveSelection(-1); return .handled }
        .onKeyPress(.return)    { guard focus == .list else { return .ignored }; model.openSelected(); return .handled }
        .onKeyPress(.rightArrow) {
            guard focus == .list, let s = model.selected, s.isDir else { return .ignored }
            model.open(s); return .handled
        }
        .onKeyPress(.leftArrow) { guard focus == .list else { return .ignored }; model.goUp(); return .handled }
        .onKeyPress(.deleteForward) { guard focus == .list else { return .ignored }; model.purgeSelected(); return .handled }
    }
}
