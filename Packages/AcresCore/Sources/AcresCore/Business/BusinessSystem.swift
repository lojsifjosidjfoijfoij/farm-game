import Foundation

/// The farm's business rhythm, run once per game morning: late contracts
/// fail, the contract board gets fresh orders, and every Monday the weekly
/// bills are paid and the books close for the week.
///
/// Runs whenever the calendar has moved on (playing or sleeping; the
/// calendar doesn't run while the app is closed).
public struct BusinessSystem: SimulationSystem {
    public init() {}

    public func step(_ state: inout GameState, _ context: inout StepContext) {
        let today = state.clock.dayIndex
        if state.contracts.nextID == 1 {
            // A brand-new (or newly upgraded) farm: put the first orders up.
            Contracts(balance: context.balance).refreshOffers(&state)
        }
        if state.daily.day < 0 {
            // First chores and market special.
            DailyRoutine(balance: context.balance).rollOver(&state, day: today)
        }
        guard today > state.finance.lastProcessedDay else { return }
        for day in (state.finance.lastProcessedDay + 1)...today {
            context.events += Self.morning(of: day, &state, balance: context.balance)
        }
        state.finance.lastProcessedDay = today
    }

    static func morning(of day: Int, _ state: inout GameState, balance: Balance) -> [SimEvent] {
        var events: [SimEvent] = []
        let contracts = Contracts(balance: balance)
        // Deadlines compare against "today", so look at the day being processed.
        let realClock = state.clock
        state.clock = GameClock(totalMinutes: Double(day) * GameClock.minutesPerDay)
        events += contracts.expire(&state)
        if day % 7 == 0 {
            events += payWeeklyBills(&state, week: day / 7 + 1, balance: balance)
        }
        contracts.refreshOffers(&state)
        DailyRoutine(balance: balance).rollOver(&state, day: day)
        state.clock = realClock
        return events
    }

    /// Closes last week's books and pays this week's bills (money can dip
    /// below zero: then it's debt, and buying waits until it's paid off).
    static func payWeeklyBills(_ state: inout GameState, week: Int, balance: Balance) -> [SimEvent] {
        state.finance.lastWeek = state.finance.thisWeek
        state.finance.thisWeek = Ledger(week: week)
        var total = 0
        for bill in Bank.weeklyBills(state, balance: balance) {
            state.money -= bill.amount
            state.finance.spend(bill.amount, bill.category)
            total += bill.amount
        }
        if var loan = state.finance.loan {
            let payment = min(loan.weeklyPayment, loan.balance)
            loan.balance -= payment
            loan.weeksLeft -= 1
            state.finance.loan = loan.balance <= 0 || loan.weeksLeft <= 0 ? nil : loan
        }
        return [.weeklyBills(week: week, total: total)]
    }
}
