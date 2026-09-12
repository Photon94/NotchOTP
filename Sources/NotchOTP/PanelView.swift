import SwiftUI
import OTPCore

struct CountdownRing: View {
    let account: OTPAccount
    let date: Date
    var size: CGFloat = 32
    private var remaining: Double { OTP.remaining(period: account.period, time: date.timeIntervalSince1970) }
    private var tint: Color { remaining <= 5 ? .orange : Color(red: 0.39, green: 0.9, blue: 0.73) }
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.17), lineWidth: 3)
            Circle().trim(from: 0, to: remaining / Double(account.period))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(ceil(remaining)))")
                .font(.system(size: size == 32 ? 11 : 9, weight: .medium, design: .rounded))
                .monospacedDigit().foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Осталось %d секунд", Int(ceil(remaining))))
    }
}

struct FluidReveal: Shape {
    var progress: CGFloat
    let neckHeight: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let visibleHeight = neckHeight + (rect.height - neckHeight) * min(1, max(0, progress))
        guard visibleHeight > 0 else { return Path() }
        let radius = min(18, visibleHeight / 2)
        var path = Path(roundedRect: CGRect(x: 0, y: 0, width: rect.width, height: visibleHeight), cornerRadius: radius)
        if neckHeight > 0 {
            // Square upper edge joins the physical notch; only the lower edge flows.
            path.addRect(CGRect(x: 0, y: 0, width: rect.width, height: min(neckHeight, visibleHeight)))
        }
        return path
    }
}

struct PanelView: View {
    @ObservedObject var model: AppModel
    let neckHeight: CGFloat
    let width: CGFloat
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !model.panelVisible)) { context in
            VStack(spacing: 0) {
                Color.clear.frame(height: neckHeight)
                Group {
                if model.vaultUnavailable {
                    emptyState(L10n.text("Связка ключей закрыта"), detail: L10n.text("Открыть настройки"), symbol: "lock.fill")
                } else if model.accounts.isEmpty {
                    emptyState(L10n.text("Добавьте первый аккаунт"), detail: L10n.text("Настроить NotchOTP"), symbol: "plus.circle")
                } else if model.searching {
                    searchContent(date: context.date)
                } else if let account = model.selected {
                    compactContent(account: account, date: context.date)
                }
                }
                .opacity(model.panelRevealed ? 1 : 0)
                .offset(y: model.panelRevealed || reduceMotion ? 0 : -12)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .background(Color.black)
        .mask(FluidReveal(progress: model.panelRevealed ? 1 : 0, neckHeight: neckHeight))
        .animation(reduceMotion ? nil : (model.panelRevealed
            ? .spring(response: 0.38, dampingFraction: 0.84)
            : .easeIn(duration: 0.16)), value: model.panelRevealed)
        .preferredColorScheme(.dark)
    }

    private func compactContent(account: OTPAccount, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: model.copied ? "checkmark.circle.fill" : "key.horizontal.fill")
                    .font(.system(size: 12)).foregroundStyle(model.copied ? Color.mint : .white)
                Text(model.copied ? L10n.text("Скопировано") : account.title)
                    .font(.system(size: 12, weight: .medium)).lineLimit(1)
                if !model.copied && !account.subtitle.isEmpty {
                    Text("· " + account.subtitle).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.65)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            HStack(alignment: .center) {
                Text((try? account.code(at: date)).map(OTP.formatted) ?? "— — —")
                    .font(.system(size: min(account.digits == 8 ? 22 : 27, (width - 78) / (CGFloat(account.digits + 1) * 0.62)), weight: .medium, design: .monospaced))
                    .tracking(1).foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                CountdownRing(account: account, date: date)
            }
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 13)
        .frame(height: 86)
        .contentShape(Rectangle())
        .onTapGesture { model.copySelected() }
        .help(L10n.text("Enter — скопировать · Tab — следующий · Начните печатать для поиска"))
        .accessibilityElement(children: .contain)
    }

    private func emptyState(_ title: String, detail: String, symbol: String) -> some View {
        Button { model.showManagement?() } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 24)).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(detail).font(.system(size: 11)).foregroundStyle(.gray)
                }
                Spacer(minLength: 0)
            }.padding(14).frame(height: 86)
        }.buttonStyle(.plain)
    }

    private func searchContent(date: Date) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.gray)
                Text(model.query.isEmpty ? L10n.text("Найти аккаунт…") : model.query)
                    .foregroundStyle(model.query.isEmpty ? Color.gray : .white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("esc").font(.system(size: 10)).foregroundStyle(.gray)
            }.font(.system(size: 13)).padding(.horizontal, 10).frame(height: 32)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            if model.filtered.isEmpty {
                Text(L10n.text("Ничего не найдено")).font(.system(size: 12)).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity).frame(height: 50)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(model.filtered) { account in
                                Button {
                                    model.selectedID = account.id
                                    model.copySelected()
                                } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(account.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                            Text((try? account.code(at: date)).map(OTP.formatted) ?? "—")
                                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                            if !account.subtitle.isEmpty {
                                                Text(account.subtitle).font(.system(size: 10)).foregroundStyle(.gray).lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 8)
                                        CountdownRing(account: account, date: date, size: 25)
                                    }
                                    .padding(.horizontal, 10).frame(height: 62)
                                    .background(model.selected?.id == account.id ? Color.white.opacity(0.12) : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain).id(account.id)
                            }
                        }
                    }
                    .onChange(of: model.selectedID) { id in if let id { proxy.scrollTo(id) } }
                }.frame(height: CGFloat(min(5, model.filtered.count)) * 65 - 3)
            }
            HStack {
                Text(L10n.text("↑↓ Выбрать"))
                Spacer()
                Text(model.copied ? L10n.text("Скопировано") : L10n.text("↵ Копировать"))
            }.font(.system(size: 10)).foregroundStyle(.gray).padding(.horizontal, 3)
        }.padding(12)
    }
}
