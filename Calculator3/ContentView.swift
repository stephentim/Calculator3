//
//  ContentView.swift
//  Calculator3
//
//  Created by Stephen Tim on 2025/3/21.
//
// 博学堂计算器3.0


import SwiftData
import SwiftUI

// 日期分组结构体
struct HistoryGroup: Identifiable {
    let id = Date()
    let date: Date
    var entries: [HistoryEntry]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

@Model
// 历史记录
final class HistoryEntry {
    var expression: String
    var result: String
    var memo: String = ""
    var timestamp: Date
    
    init(expression: String, result: String, timestamp: Date) {
        self.expression = expression
        self.result = result
        self.timestamp = timestamp
    }
    
    var formattedTime: String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .medium
        return timeFormatter.string(from: timestamp)
    }
    var formattedDateTime: String {
        let dateFormatter = DateFormatter()
        let timeFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        timeFormatter.timeStyle = .medium
        return dateFormatter.string(from: timestamp) + " " + timeFormatter.string(from: timestamp)
    }
    var description: String {
        return "\(expression) = \(result) "
    }
    var fullDescription: String {
        let memoText = memo.isEmpty ? "" : "\n备注：\(memo)"
        return "\(expression) = \(result) (\(formattedDateTime)) \(memoText)"
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HistoryEntry.timestamp, order: .reverse) private var history: [HistoryEntry]
    
    @State private var display = ""
    @State private var showingMemoInput = false
    @State private var selectedEntry: HistoryEntry?
    @State private var newMemoText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    let buttons: [[String]] = [
        ["C", "(", ")", "⌫", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "-"],
        ["1", "2", "3", "+"],
        ["0", ".", "="]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // 历史记录
            historyList
            // 显示屏
            displayView
            // 按钮
            ForEach(buttons, id: \.self) { row in
                DynamicButtonRow(row: row) { button in
                    handleButtonPress(button)
                }
            }
            
        }
        .padding(12)
        .alert("计算错误", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 逻辑处理
    func handleButtonPress(_ button: String) {
        switch button {
        case "0"..."9", ".", "(", ")", "+", "-", "×", "÷":
            addToDisplay(button)
        case "=":
            calculate()
        case "C":
            clear()
        case "⌫": // 删除按钮处理
            deleteLastCharacter()
        default:
            break
        }
    }
    
    func addToDisplay(_ char: String) {
        // 自动添加乘法符号的智能处理
        if let last = display.last {
            let lastIsNumber = last.isNumber || last == ")"
            let newIsNumber = char.first!.isNumber || char == "("
            
            if lastIsNumber && newIsNumber && char == "(" {
                display += "×("
                return
            }
        }
        display += char
    }
    
    func calculate() {
        do {
            let expression = display
                .replacingOccurrences(of: "×", with: "*")
                .replacingOccurrences(of: "÷", with: "/")
            
            let result = try evaluateExpression(expression)
            let formattedResult = formatNumber(result)
            
            let newEntry = HistoryEntry(
                expression: display,
                result: formattedResult,
                timestamp: Date()
            )
            modelContext.insert(newEntry)
            
            // 自动清理旧记录（保留最近100条）
            if history.count > 100 {
                let oldEntries = history.suffix(history.count - 100)
                for entry in oldEntries {
                    modelContext.delete(entry)
                }
            }
            
            display = formattedResult
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    func evaluateExpression(_ expr: String) throws -> Double {
        let expr = NSExpression(format: expr)
        guard let result = expr.expressionValue(with: nil, context: nil) as? Double else {
            throw CalculationError.invalidExpression
        }
        return result
    }
    
    func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "Error"
    }
    
    func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
        display = ""
    }
    
    func clear() {
        display = ""
    }
    
    // 删除最后一位功能
    func deleteLastCharacter() {
        guard !display.isEmpty else { return }
        display.removeLast()
        // 自动补零处理
        if display.isEmpty || display == "-" {
            display = ""
        }
    }
}

// MARK: - 错误处理
enum CalculationError: Error, LocalizedError {
    case invalidExpression
    case divisionByZero
    case mismatchedParentheses
    
    var errorDescription: String? {
        switch self {
        case .invalidExpression: return "无效的数学表达式"
        case .divisionByZero: return "不能除以零"
        case .mismatchedParentheses: return "括号不匹配"
        }
    }
}

// MARK: - 历史记录视图
extension ContentView {
    private var displayView: some View {
        Text(display.isEmpty ? "0" : display)
            .font(.system(size: 48))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
    
    private var historyList1: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(history.reversed()) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.expression)
                            .font(.caption)
                        Text("= \(entry.result)")
                            .font(.body.weight(.bold))
                        Text(entry.formattedTime)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = "\(entry.expression) = \(entry.result)"
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .padding()
        }
        .frame(height: 150)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    // 历史记录视图组件
    private var historyList: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(groupedHistory) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            historyRow(entry: entry)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // 删除按钮
                                    Button(role: .destructive) {
                                        deleteHistoryEntry(entry)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                    // 备注按钮
                                    Button {
                                        selectedEntry = entry
                                        newMemoText = entry.memo
                                        showingMemoInput = true
                                    } label: {
                                        Label("备注", systemImage: "pencil.circle")
                                    }
                                    .tint(.orange)
                                    // 复制按钮
                                    Button {
                                        UIPasteboard.general.string = entry.fullDescription
                                    } label: {
                                        Label("复制", systemImage: "doc.on.doc")
                                    }
                                    .tint(.blue)
                                }
                        }
                    } header: {
                        Text(group.formattedDate)
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .frame(maxHeight: 300)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingMemoInput) {
            memoEditView
        }
    }
    
    // 日期分组 计算属性 逻辑
    private var groupedHistory: [HistoryGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: history) { entry in
            calendar.startOfDay(for: entry.timestamp)
        }
        
        return grouped.map { key, value in
            HistoryGroup(date: key, entries: value.sorted { $0.timestamp > $1.timestamp })
        }.sorted { $0.date > $1.date }
    }
    
    // 备注编辑视图
    private var memoEditView: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("输入备注内容", text: $newMemoText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Spacer()
            }
            .navigationTitle("备注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingMemoInput = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let index = history.firstIndex(where: { $0.id == selectedEntry?.id }) {
                            history[index].memo = newMemoText
                        }
                        showingMemoInput = false
                    }
                }
            }
        }
        .onDisappear {
            // 自动保存修改
            do {
                try modelContext.save()
            } catch {
                print("保存备注失败：\(error)")
            }
        }
    }

    // 删除方法
    private func deleteHistoryEntry(_ entry: HistoryEntry) {
        modelContext.delete(entry)
    }

    // 历史记录条目视图
    private func historyRow(entry: HistoryEntry) -> some View {
        VStack(alignment: .leading) {
                Text(entry.description)
                Text(entry.formattedTime)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
                if !entry.memo.isEmpty {
                    Text(entry.memo)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.leading, 20)
                }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading) // 对齐修饰符
        .contentShape(Rectangle())                       // 扩大点击区域
    }
}

// MARK: - 其他组件
struct CalculatorButton: View {
    let title: String
    let action: () -> Void
    var isWide = false
    var isSmall = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(fontSize)
                .frame(width: buttonWidth, height: 70)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .clipShape(Capsule())
        }
    }
    
    // 动态宽度计算
    private var buttonWidth: CGFloat {
        if isWide {
            return 160
        } else if isSmall {
            return 30
        }
        return 70
    }
    
    // 动态字体大小
    private var fontSize: Font {
        isSmall ? .system(size: 22) : .system(size: 28)
    }

    private var backgroundColor: Color {
        switch title {
        case "C", "(", ")", "⌫": return Color(.lightGray)
        case ".": return .gray
        case "÷", "×", "-", "+", "=": return .orange
        default: return Color(.darkGray)
        }
    }
    
    private var foregroundColor: Color {
        [.orange, .black, .white].contains(backgroundColor) ? .white : .black
    }
}

// 动态按钮行组件
struct DynamicButtonRow: View {
    let row: [String]
    let action: (String) -> Void
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(row, id: \.self) { button in
                CalculatorButton(
                    title: button,
                    action: { action(button) },
                    isWide: button == "0",
                    isSmall: ["(", ")"].contains(button)
                )
            }
        }
        .padding(.horizontal, sizeClass == .compact ? 8 : 16)
    }
}
