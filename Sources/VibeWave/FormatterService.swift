import Foundation
import SwiftUI

public final class FormatterService {
  private static let enUSLocale = Locale(identifier: "en_US")
  
  public static func formatCount(_ value: Int) -> String {
    let nf = NumberFormatter()
    nf.locale = enUSLocale
    nf.numberStyle = .decimal
    nf.usesGroupingSeparator = true
    nf.groupingSeparator = ","
    nf.maximumFractionDigits = 0
    if let s = nf.string(from: NSNumber(value: value)) {
      return s
    }
    return String(value)
  }
  
  public static func formatNumber(_ value: Int) -> String {
    return formatCount(value)
  }
  
  public static func formatCost(_ value: Double) -> String {
    return formatCurrency(value)
  }
  
  public static func formatCurrency(_ value: Double) -> String {
    let nf = NumberFormatter()
    nf.locale = Locale(identifier: "en_US_POSIX")
    nf.numberStyle = .currency
    nf.currencySymbol = "$"
    nf.positiveFormat = "¤#,##0.00"
    nf.maximumFractionDigits = 2
    nf.minimumFractionDigits = 2
    if let s = nf.string(from: NSNumber(value: value)) {
      return s
    }
    return "$" + String(format: "%.2f", value)
  }
  
  public static func formatDate(_ date: Date) -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .none
    return df.string(from: date)
  }
  
  public static func formatDateTime(_ date: Date) -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df.string(from: date)
  }
  
  public static func formatPercentage(_ value: Double) -> String {
    let nf = NumberFormatter()
    nf.locale = enUSLocale
    nf.numberStyle = .percent
    nf.maximumFractionDigits = 1
    nf.minimumFractionDigits = 0
    if let s = nf.string(from: NSNumber(value: value)) {
      return s
    }
    return String(format: "%.1f%%", value * 100)
  }
  
}
