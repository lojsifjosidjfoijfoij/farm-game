import Foundation

/// Money in and out during one week, by category ("Market sales", "Fuel" …).
public struct Ledger: Codable, Equatable, Sendable {
    /// 1-based week number.
    public var week: Int
    public var income: [String: Int]
    public var expenses: [String: Int]

    public init(week: Int, income: [String: Int] = [:], expenses: [String: Int] = [:]) {
        self.week = week
        self.income = income
        self.expenses = expenses
    }

    public var totalIncome: Int { income.values.reduce(0, +) }
    public var totalExpenses: Int { expenses.values.reduce(0, +) }
    public var profit: Int { totalIncome - totalExpenses }
}

/// Ledger categories.
public enum LedgerCategory {
    public static let marketSales = "Market sales"
    public static let contracts = "Contracts"
    public static let goals = "Goal rewards"
    public static let loans = "Bank loans"
    public static let shopSales = "Shop sales"
    public static let seeds = "Seeds & saplings"
    public static let animals = "Animals & feed"
    public static let fuel = "Fuel"
    public static let repairs = "Repairs"
    public static let propertyTax = "Property tax"
    public static let loanPayments = "Loan payments"
    public static let rent = "Shop rent"
    public static let wages = "Wages"
    public static let land = "Land"
    public static let buildings = "Buildings"
    public static let machines = "Machines"
    public static let village = "Village projects"
}

/// A bank loan, paid back in equal weekly instalments.
public struct Loan: Codable, Equatable, Sendable {
    public var amount: Int
    /// Still owed (amount plus interest, minus what's been paid).
    public var balance: Int
    public var weeklyPayment: Int
    public var weeksLeft: Int

    public init(amount: Int, balance: Int, weeklyPayment: Int, weeksLeft: Int) {
        self.amount = amount
        self.balance = balance
        self.weeklyPayment = weeklyPayment
        self.weeksLeft = weeksLeft
    }
}

/// The farm's books: this week's ledger, last week's, and any loan.
public struct Finance: Codable, Equatable, Sendable {
    public var thisWeek: Ledger
    public var lastWeek: Ledger?
    public var loan: Loan?
    /// The last game day whose morning business (bills, contracts) was done.
    public var lastProcessedDay: Int

    public init(thisWeek: Ledger = Ledger(week: 1), lastWeek: Ledger? = nil, loan: Loan? = nil, lastProcessedDay: Int = 0) {
        self.thisWeek = thisWeek
        self.lastWeek = lastWeek
        self.loan = loan
        self.lastProcessedDay = lastProcessedDay
    }

    public mutating func earn(_ amount: Int, _ category: String) {
        guard amount > 0 else { return }
        thisWeek.income[category, default: 0] += amount
    }

    public mutating func spend(_ amount: Int, _ category: String) {
        guard amount > 0 else { return }
        thisWeek.expenses[category, default: 0] += amount
    }
}

/// A loan the bank offers.
public struct LoanOffer: Equatable, Sendable, Identifiable {
    public let amount: Int
    public let weeks: Int
    public let unlockLevel: Int
    public var id: Int { amount }

    /// Total to pay back (flat interest).
    public func total(interest: Double) -> Int { Int((Double(amount) * (1 + interest)).rounded()) }

    public func weeklyPayment(interest: Double) -> Int {
        Int((Double(total(interest: interest)) / Double(weeks)).rounded(.up))
    }
}

public enum Bank {
    public static let offers: [LoanOffer] = [
        LoanOffer(amount: 1_000, weeks: 4, unlockLevel: 1),
        LoanOffer(amount: 5_000, weeks: 8, unlockLevel: 4),
        LoanOffer(amount: 20_000, weeks: 12, unlockLevel: 8),
    ]

    /// Money due every Monday morning.
    public static func weeklyBills(_ state: GameState, balance: Balance) -> [(category: String, amount: Int)] {
        var bills: [(String, Int)] = [(LedgerCategory.propertyTax, balance.propertyTaxPerWeek * state.ownedProperties.count)]
        if state.store.isRented { bills.append((LedgerCategory.rent, balance.storeRentPerWeek)) }
        if !state.estate.workers.isEmpty { bills.append((LedgerCategory.wages, balance.workerWagePerWeek * state.estate.workers.count)) }
        if let loan = state.finance.loan { bills.append((LedgerCategory.loanPayments, min(loan.weeklyPayment, loan.balance))) }
        return bills.filter { $0.1 > 0 }
    }
}
