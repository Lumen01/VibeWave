import Foundation

/// Type-safe localization access for VibeWave
/// Uses Swift 5+ String(localized:) for accessing localized strings
public enum L10n {
    // MARK: - Navigation
    public static var navOverview: String { LocalizationManager.shared.localizedString("nav.overview") }
    public static var navHistory: String { LocalizationManager.shared.localizedString("nav.history") }
    public static var navInsights: String { LocalizationManager.shared.localizedString("nav.insights") }
    public static var navProjects: String { LocalizationManager.shared.localizedString("nav.projects") }
    public static var navSettings: String { LocalizationManager.shared.localizedString("nav.settings") }

    // MARK: - App Name
    public static var appName: String { LocalizationManager.shared.localizedString("app.name") }

    // MARK: - KPI Cards
    public static var kpiSessions: String { LocalizationManager.shared.localizedString("kpi.sessions") }
    public static var kpiMessages: String { LocalizationManager.shared.localizedString("kpi.messages") }
    public static var kpiCost: String { LocalizationManager.shared.localizedString("kpi.cost") }
    public static var kpiInput: String { LocalizationManager.shared.localizedString("kpi.input") }
    public static var kpiOutput: String { LocalizationManager.shared.localizedString("kpi.output") }
    public static var kpiReasoning: String { LocalizationManager.shared.localizedString("kpi.reasoning") }
    public static var kpiCacheRead: String { LocalizationManager.shared.localizedString("kpi.cacheRead") }
    public static var kpiCacheWrite: String { LocalizationManager.shared.localizedString("kpi.cacheWrite") }
    public static var kpiAvgPerSession: String { LocalizationManager.shared.localizedString("kpi.avgPerSession") }

    // MARK: - KPI Short (for compact display)
    public static var kpiShortSessions: String { LocalizationManager.shared.localizedString("kpi.short.sessions") }
    public static var kpiShortMessages: String { LocalizationManager.shared.localizedString("kpi.short.messages") }
    public static var kpiShortCost: String { LocalizationManager.shared.localizedString("kpi.short.cost") }
    public static var kpiShortInput: String { LocalizationManager.shared.localizedString("kpi.short.input") }
    public static var kpiShortOutput: String { LocalizationManager.shared.localizedString("kpi.short.output") }
    public static var kpiShortReasoning: String { LocalizationManager.shared.localizedString("kpi.short.reasoning") }
    public static var kpiShortCacheRead: String { LocalizationManager.shared.localizedString("kpi.short.cacheRead") }
    public static var kpiShortCacheWrite: String { LocalizationManager.shared.localizedString("kpi.short.cacheWrite") }
    public static var kpiShortAvgPerSession: String { LocalizationManager.shared.localizedString("kpi.short.avgPerSession") }

    // MARK: - Chart Titles
    public static var chartTokens: String { LocalizationManager.shared.localizedString("chart.tokens") }
    public static var chartTopProjects: String { LocalizationManager.shared.localizedString("chart.topProjects") }
    public static var chartTopModels: String { LocalizationManager.shared.localizedString("chart.topModels") }
    public static var chartNetCode: String { LocalizationManager.shared.localizedString("chart.netCode") }
    public static var chartSessions: String { LocalizationManager.shared.localizedString("chart.sessions") }
    public static var chartHistory: String { LocalizationManager.shared.localizedString("chart.history") }
    public static var chartTokenUsage: String { LocalizationManager.shared.localizedString("chart.tokenUsage") }
    public static var chartActivity: String { LocalizationManager.shared.localizedString("chart.activity") }
    public static var chartConsumptionEfficiency: String { LocalizationManager.shared.localizedString("chart.consumptionEfficiency") }
    public static var chartModelLens: String { LocalizationManager.shared.localizedString("chart.modelLens") }
    public static var chartUserRhythm: String { LocalizationManager.shared.localizedString("chart.userRhythm") }
    public static var chartWorkIntensity: String { LocalizationManager.shared.localizedString("chart.workIntensity") }
    public static var chartIntensity24h: String { LocalizationManager.shared.localizedString("chart.intensity24h") }
    public static var chartPeak: String { LocalizationManager.shared.localizedString("chart.peak") }
    public static var chartAverage: String { LocalizationManager.shared.localizedString("chart.average") }
    public static var chartCumulative: String { LocalizationManager.shared.localizedString("chart.cumulative") }
    public static var chartDelta: String { LocalizationManager.shared.localizedString("chart.delta") }
    public static var chartSeparator: String { LocalizationManager.shared.localizedString("chart.separator") }

    // MARK: - Chart Columns
    public static var chartColumnInput: String { LocalizationManager.shared.localizedString("chart.column.input") }
    public static var chartColumnOutput: String { LocalizationManager.shared.localizedString("chart.column.output") }
    public static var chartColumnReasoning: String { LocalizationManager.shared.localizedString("chart.column.reasoning") }
    public static var chartColumnNetCode: String { LocalizationManager.shared.localizedString("chart.column.netCode") }
    public static var chartColumnSession: String { LocalizationManager.shared.localizedString("chart.column.session") }
    public static var chartColumnMessage: String { LocalizationManager.shared.localizedString("chart.column.message") }
    public static var chartTotal: String { LocalizationManager.shared.localizedString("chart.total") }
    public static var chartType: String { LocalizationManager.shared.localizedString("chart.type") }

    // MARK: - History
    public static var historyUsage: String { LocalizationManager.shared.localizedString("history.usage") }
    public static var historyActivity: String { LocalizationManager.shared.localizedString("history.activity") }
    public static var historyTrend: String { LocalizationManager.shared.localizedString("history.trend") }
    public static var historyInputTokensCumulative: String { LocalizationManager.shared.localizedString("history.inputTokensCumulative") }
    public static var historyMessageDurationCumulative: String { LocalizationManager.shared.localizedString("history.messageDurationCumulative") }

    // MARK: - Time Range
    public static var timeToday: String { LocalizationManager.shared.localizedString("time.today") }
    public static var timeYesterday: String { LocalizationManager.shared.localizedString("time.yesterday") }
    public static var timeThisWeek: String { LocalizationManager.shared.localizedString("time.thisWeek") }
    public static var timeLastWeek: String { LocalizationManager.shared.localizedString("time.lastWeek") }
    public static var timeThisMonth: String { LocalizationManager.shared.localizedString("time.thisMonth") }
    public static var timeLastMonth: String { LocalizationManager.shared.localizedString("time.lastMonth") }
    public static var timeThisYear: String { LocalizationManager.shared.localizedString("time.thisYear") }
    public static var timeAll: String { LocalizationManager.shared.localizedString("time.all") }
    public static var time24hours: String { LocalizationManager.shared.localizedString("time.24hours") }
    public static var time30days: String { LocalizationManager.shared.localizedString("time.30days") }
    public static var timeAllTime: String { LocalizationManager.shared.localizedString("time.allTime") }
    public static var timeTodayShort: String { LocalizationManager.shared.localizedString("time.todayShort") }
    public static var time30daysShort: String { LocalizationManager.shared.localizedString("time.30daysShort") }
    public static var timeAllTimeShort: String { LocalizationManager.shared.localizedString("time.allTimeShort") }

    // MARK: - Common
    public static var commonLoading: String { LocalizationManager.shared.localizedString("common.loading") }
    public static var commonNoData: String { LocalizationManager.shared.localizedString("common.noData") }
    public static var commonNoDataShort: String { LocalizationManager.shared.localizedString("common.noDataShort") }
    public static var commonRetry: String { LocalizationManager.shared.localizedString("common.retry") }
    public static var commonConfirm: String { LocalizationManager.shared.localizedString("common.confirm") }
    public static var commonCancel: String { LocalizationManager.shared.localizedString("common.cancel") }
    public static var commonDone: String { LocalizationManager.shared.localizedString("common.done") }
    public static var commonSave: String { LocalizationManager.shared.localizedString("common.save") }
    public static var commonError: String { LocalizationManager.shared.localizedString("common.error") }
    public static var commonSuccess: String { LocalizationManager.shared.localizedString("common.success") }
    public static var commonFailed: String { LocalizationManager.shared.localizedString("common.failed") }
    public static var commonOK: String { LocalizationManager.shared.localizedString("common.ok") }
    public static var commonYes: String { LocalizationManager.shared.localizedString("common.yes") }
    public static var commonNo: String { LocalizationManager.shared.localizedString("common.no") }
    public static var commonClose: String { LocalizationManager.shared.localizedString("common.close") }
    public static var commonBack: String { LocalizationManager.shared.localizedString("common.back") }
    public static var commonNext: String { LocalizationManager.shared.localizedString("common.next") }
    public static var commonPrevious: String { LocalizationManager.shared.localizedString("common.previous") }

    // MARK: - Settings - Data Source
    public static var settingsData: String { LocalizationManager.shared.localizedString("settings.data") }
    public static var settingsDataSource: String { LocalizationManager.shared.localizedString("settings.dataSource") }
    public static var settingsDataSourcePath: String { LocalizationManager.shared.localizedString("settings.dataSourcePath") }
    public static var settingsChoosePath: String { LocalizationManager.shared.localizedString("settings.choosePath") }
    public static var settingsRestoreDefault: String { LocalizationManager.shared.localizedString("settings.restoreDefault") }
    public static var settingsDefaultSource: String { LocalizationManager.shared.localizedString("settings.defaultSource") }
    public static var settingsConfirmDataSource: String { LocalizationManager.shared.localizedString("settings.confirmDataSource") }
    public static var settingsDataSourceHelp: String { LocalizationManager.shared.localizedString("settings.dataSourceHelp") }
    public static var settingsChoosePathHelp: String { LocalizationManager.shared.localizedString("settings.choosePathHelp") }
    public static var settingsRestoreDefaultHelp: String { LocalizationManager.shared.localizedString("settings.restoreDefaultHelp") }

    // MARK: - Settings - Sync
    public static var settingsSyncStrategy: String { LocalizationManager.shared.localizedString("settings.syncStrategy") }
    public static var settingsSyncStrategyHelp: String { LocalizationManager.shared.localizedString("settings.syncStrategyHelp") }
    public static var settingsSyncAuto: String { LocalizationManager.shared.localizedString("settings.sync.auto") }
    public static var settingsSync1Min: String { LocalizationManager.shared.localizedString("settings.sync.1min") }
    public static var settingsSync5Min: String { LocalizationManager.shared.localizedString("settings.sync.5min") }
    public static var settingsSync10Min: String { LocalizationManager.shared.localizedString("settings.sync.10min") }
    public static var settingsSync15Min: String { LocalizationManager.shared.localizedString("settings.sync.15min") }
    public static var settingsSyncAutoDesc: String { LocalizationManager.shared.localizedString("settings.sync.autoDesc") }
    public static var settingsSyncIntervalDesc: String { LocalizationManager.shared.localizedString("settings.sync.intervalDesc") }

    // MARK: - Settings - Backup
    public static var settingsBackup: String { LocalizationManager.shared.localizedString("settings.backup") }
    public static var settingsEnableBackup: String { LocalizationManager.shared.localizedString("settings.enableBackup") }
    public static var settingsBackupDescription: String { LocalizationManager.shared.localizedString("settings.backupDescription") }
    public static var settingsBackupRetention: String { LocalizationManager.shared.localizedString("settings.backupRetention") }
    public static var settingsBackupRetentionHelp: String { LocalizationManager.shared.localizedString("settings.backupRetentionHelp") }
    public static var settingsBackupInterval: String { LocalizationManager.shared.localizedString("settings.backupInterval") }
    public static var settingsBackupNow: String { LocalizationManager.shared.localizedString("settings.backupNow") }
    public static var settingsBackupNowHelp: String { LocalizationManager.shared.localizedString("settings.backupNowHelp") }
    public static var settingsBackupList: String { LocalizationManager.shared.localizedString("settings.backupList") }
    public static var settingsBackupCreatedAt: String { LocalizationManager.shared.localizedString("settings.backup.createdAt") }
    public static var settingsBackupSize: String { LocalizationManager.shared.localizedString("settings.backup.size") }
    public static var settingsBackupIntervalHelp: String { LocalizationManager.shared.localizedString("settings.backupIntervalHelp") }
    public static var settingsEnableBackupHelp: String { LocalizationManager.shared.localizedString("settings.enableBackupHelp") }
    public static var settingsBackupInterval6h: String { LocalizationManager.shared.localizedString("settings.backup.interval.6h") }
    public static var settingsBackupInterval12h: String { LocalizationManager.shared.localizedString("settings.backup.interval.12h") }
    public static var settingsBackupInterval24h: String { LocalizationManager.shared.localizedString("settings.backup.interval.24h") }
    public static var settingsBackupInterval48h: String { LocalizationManager.shared.localizedString("settings.backup.interval.48h") }
    public static var settingsRestoreBackup: String { LocalizationManager.shared.localizedString("settings.restoreBackup") }
    public static var settingsDeleteBackup: String { LocalizationManager.shared.localizedString("settings.deleteBackup") }
    public static var settingsConfirmRestore: String { LocalizationManager.shared.localizedString("settings.confirmRestore") }
    public static var settingsRestoreWarning: String { LocalizationManager.shared.localizedString("settings.restoreWarning") }
    public static var settingsBackupSuccess: String { LocalizationManager.shared.localizedString("settings.backupSuccess") }
    public static var settingsBackupFailed: String { LocalizationManager.shared.localizedString("settings.backupFailed") }
    public static var settingsRestoreSuccess: String { LocalizationManager.shared.localizedString("settings.restoreSuccess") }
    public static var settingsRestoreFailed: String { LocalizationManager.shared.localizedString("settings.restoreFailed") }
    public static var settingsDeleteSuccess: String { LocalizationManager.shared.localizedString("settings.deleteSuccess") }
    public static var settingsDeleteFailed: String { LocalizationManager.shared.localizedString("settings.deleteFailed") }
    public static var settingsBackupNotInitialized: String { LocalizationManager.shared.localizedString("settings.backupNotInitialized") }
    public static var settingsBackupKindAutomatic: String { LocalizationManager.shared.localizedString("settings.backup.kind.automatic") }
    public static var settingsBackupKindManual: String { LocalizationManager.shared.localizedString("settings.backup.kind.manual") }
    public static var settingsBackupKindSystem: String { LocalizationManager.shared.localizedString("settings.backup.kind.system") }
    public static var settingsBackupKindLegacy: String { LocalizationManager.shared.localizedString("settings.backup.kind.legacy") }

    // MARK: - Settings - Appearance
    public static var settingsGeneral: String { LocalizationManager.shared.localizedString("settings.general") }
    public static var settingsAppearance: String { LocalizationManager.shared.localizedString("settings.appearance") }
    public static var settingsLanguages: String { LocalizationManager.shared.localizedString("settings.languages") }
    public static var settingsTheme: String { LocalizationManager.shared.localizedString("settings.theme") }
    public static var settingsThemeSystem: String { LocalizationManager.shared.localizedString("settings.theme.system") }
    public static var settingsThemeLight: String { LocalizationManager.shared.localizedString("settings.theme.light") }
    public static var settingsThemeDark: String { LocalizationManager.shared.localizedString("settings.theme.dark") }
    public static var settingsThemeHelp: String { LocalizationManager.shared.localizedString("settings.themeHelp") }
    public static var settingsIconStyle: String { LocalizationManager.shared.localizedString("settings.iconStyle") }
    public static var settingsLanguageRestartHint: String { LocalizationManager.shared.localizedString("settings.languageRestartHint") }

    // MARK: - Settings - Log
    public static var settingsLog: String { LocalizationManager.shared.localizedString("settings.log") }
    public static var settingsLogLevel: String { LocalizationManager.shared.localizedString("settings.logLevel") }
    public static var settingsLogLevelVerbose: String { LocalizationManager.shared.localizedString("settings.logLevel.verbose") }
    public static var settingsLogLevelError: String { LocalizationManager.shared.localizedString("settings.logLevel.error") }
    public static var settingsLogLevelWarn: String { LocalizationManager.shared.localizedString("settings.logLevel.warn") }
    public static var settingsLogLevelInfo: String { LocalizationManager.shared.localizedString("settings.logLevel.info") }
    public static var settingsLogLevelDebug: String { LocalizationManager.shared.localizedString("settings.logLevel.debug") }
    public static var settingsLogLevelDesc: String { LocalizationManager.shared.localizedString("settings.logLevelDesc") }

    // MARK: - Settings - Groups
    public static var settingsGroupDataSync: String { LocalizationManager.shared.localizedString("settings.group.dataSync") }
    public static var settingsGroupBackupRestore: String { LocalizationManager.shared.localizedString("settings.group.backupRestore") }
    public static var settingsGroupAppearance: String { LocalizationManager.shared.localizedString("settings.group.appearance") }
    public static var settingsGroupLog: String { LocalizationManager.shared.localizedString("settings.group.log") }

    // MARK: - Error Messages
    public static var errorLoadFailed: String { LocalizationManager.shared.localizedString("error.loadFailed") }
    public static var errorCannotLoadStats: String { LocalizationManager.shared.localizedString("error.cannotLoadStats") }
    public static var errorConfirmDataSource: String { LocalizationManager.shared.localizedString("error.confirmDataSource") }
    public static var errorInvalidDataSource: String { LocalizationManager.shared.localizedString("error.invalidDataSource") }
    public static var errorDataSourceUnavailable: String { LocalizationManager.shared.localizedString("error.dataSourceUnavailable") }
    public static var errorLoadStats: String { LocalizationManager.shared.localizedString("error.loadStats") }
    public static var errorFailedToLoad: String { LocalizationManager.shared.localizedString("error.failedToLoad") }

    // MARK: - Insights - Metrics
    public static var insightInputTokens: String { LocalizationManager.shared.localizedString("insight.inputTokens") }
    public static var insightMessages: String { LocalizationManager.shared.localizedString("insight.messages") }
    public static var insightCost: String { LocalizationManager.shared.localizedString("insight.cost") }
    public static var insightAll: String { LocalizationManager.shared.localizedString("insight.all") }
    public static var insightWeekday: String { LocalizationManager.shared.localizedString("insight.weekday") }
    public static var insightWeekend: String { LocalizationManager.shared.localizedString("insight.weekend") }
    public static var insightModel: String { LocalizationManager.shared.localizedString("insight.model") }
    public static var insightProvider: String { LocalizationManager.shared.localizedString("insight.provider") }
    public static var insightTPS: String { LocalizationManager.shared.localizedString("insight.tps") }
    public static var insightInput: String { LocalizationManager.shared.localizedString("insight.input") }
    public static var insightOutputTPS: String { LocalizationManager.shared.localizedString("insight.outputTPS") }
    public static var insightTPSCoverage: String { LocalizationManager.shared.localizedString("insight.tpsCoverage") }
    public static var insightTPSCoverageAggregated: String { LocalizationManager.shared.localizedString("insight.tpsCoverageAggregated") }
    public static var insightUserRhythm: String { LocalizationManager.shared.localizedString("insight.userRhythm") }
    public static var insightWorkIntensity: String { LocalizationManager.shared.localizedString("insight.workIntensity") }
    public static var insightModelLens: String { LocalizationManager.shared.localizedString("insight.modelLens") }
    public static var insight24hIntensity: String { LocalizationManager.shared.localizedString("insight.24hIntensity") }
    public static var insightNoModelData: String { LocalizationManager.shared.localizedString("insight.noModelData") }

    // MARK: - Insights - Filters
    public static var insightFilterDayType: String { LocalizationManager.shared.localizedString("insight.filter.dayType") }
    public static var insightFilterDistribution: String { LocalizationManager.shared.localizedString("insight.filter.distribution") }
    public static var insightFilterDimension: String { LocalizationManager.shared.localizedString("insight.filter.dimension") }
    public static var insightFilterHeatmapMetric: String { LocalizationManager.shared.localizedString("insight.filter.heatmapMetric") }
    public static var insightFilterMetricInputTokens: String { LocalizationManager.shared.localizedString("insight.filter.metric.inputTokens") }
    public static var insightFilterMetricMessages: String { LocalizationManager.shared.localizedString("insight.filter.metric.messages") }

    // MARK: - Insights - Enum Values
    public static var insightMetricInputTokens: String { LocalizationManager.shared.localizedString("insight.metric.inputTokens") }
    public static var insightMetricMessages: String { LocalizationManager.shared.localizedString("insight.metric.messages") }
    public static var insightMetricCost: String { LocalizationManager.shared.localizedString("insight.metric.cost") }
    public static var insightDayTypeAll: String { LocalizationManager.shared.localizedString("insight.dayType.all") }
    public static var insightDayTypeWeekdays: String { LocalizationManager.shared.localizedString("insight.dayType.weekdays") }
    public static var insightDayTypeWeekends: String { LocalizationManager.shared.localizedString("insight.dayType.weekends") }
    public static var insightGroupByModel: String { LocalizationManager.shared.localizedString("insight.groupBy.model") }
    public static var insightGroupByProvider: String { LocalizationManager.shared.localizedString("insight.groupBy.provider") }
    public static var insightTpsCoverageBasedOn: String { LocalizationManager.shared.localizedString("insight.tpsCoverageBasedOn") }

    // MARK: - Insights - Time Ranges
    public static var insightRecent365Days: String { LocalizationManager.shared.localizedString("insight.recent365Days") }
    public static var insightLittle: String { LocalizationManager.shared.localizedString("insight.little") }
    public static var insightMuch: String { LocalizationManager.shared.localizedString("insight.much") }

    // MARK: - Insights - Comparison
    public static var insightWeekdayVsWeekend: String { LocalizationManager.shared.localizedString("insight.weekdayVsWeekend") }
    public static var insightWeekdayTotal: String { LocalizationManager.shared.localizedString("insight.weekdayTotal") }
    public static var insightWeekendTotal: String { LocalizationManager.shared.localizedString("insight.weekendTotal") }
    public static var insightTotal: String { LocalizationManager.shared.localizedString("insight.total") }

    // MARK: - Insights - Time Periods
    public static var insightNight: String { LocalizationManager.shared.localizedString("insight.night") }
    public static var insightDaytime: String { LocalizationManager.shared.localizedString("insight.daytime") }
    public static var insightEvening: String { LocalizationManager.shared.localizedString("insight.evening") }

    // MARK: - Consumption Efficiency
    public static var consumptionConsumptionAndEfficiency: String { LocalizationManager.shared.localizedString("consumption.consumptionAndEfficiency") }
    public static var consumptionCost: String { LocalizationManager.shared.localizedString("consumption.cost") }
    public static var consumptionInput: String { LocalizationManager.shared.localizedString("consumption.input") }
    public static var consumptionOutput: String { LocalizationManager.shared.localizedString("consumption.output") }
    public static var consumptionReasoning: String { LocalizationManager.shared.localizedString("consumption.reasoning") }
    public static var consumptionPerCodeLines: String { LocalizationManager.shared.localizedString("consumption.perCodeLines") }
    public static var consumptionAutomationLevel: String { LocalizationManager.shared.localizedString("consumption.automationLevel") }

    // MARK: - Session Depth
    public static var sessionDepth: String { LocalizationManager.shared.localizedString("session.depth") }
    public static var sessionDepthShallow: String { LocalizationManager.shared.localizedString("session.depth.shallow") }
    public static var sessionDepthMedium: String { LocalizationManager.shared.localizedString("session.depth.medium") }
    public static var sessionDepthDeep: String { LocalizationManager.shared.localizedString("session.depth.deep") }
    public static var sessionDepthDesc: String { LocalizationManager.shared.localizedString("session.depth.desc") }
    public static var sessionDepthRange: String { LocalizationManager.shared.localizedString("session.depth.range") }
    public static var sessionDepthRangeMedium: String { LocalizationManager.shared.localizedString("session.depth.rangeMedium") }
    public static var sessionDepthRangeDeep: String { LocalizationManager.shared.localizedString("session.depth.rangeDeep") }

    // MARK: - Code Impact
    public static var codeFileEdit: String { LocalizationManager.shared.localizedString("code.fileEdit") }
    public static var codeFileIncludeDoc: String { LocalizationManager.shared.localizedString("code.fileIncludeDoc") }
    public static var codeLines: String { LocalizationManager.shared.localizedString("code.lines") }
    public static var codeFiles: String { LocalizationManager.shared.localizedString("code.files") }
    public static var codeAdditions: String { LocalizationManager.shared.localizedString("code.additions") }
    public static var codeDeletions: String { LocalizationManager.shared.localizedString("code.deletions") }
    public static var codeNetCodeLines: String { LocalizationManager.shared.localizedString("code.netCodeLines") }

    // MARK: - Project Stats
    public static var projectProjectList: String { LocalizationManager.shared.localizedString("project.projectList") }
    public static var projectActiveDays: String { LocalizationManager.shared.localizedString("project.activeDays") }
    public static var projectActiveDaysShort: String { LocalizationManager.shared.localizedString("project.activeDaysShort") }
    public static var projectActivityOutput: String { LocalizationManager.shared.localizedString("project.activityOutput") }
    public static var projectNetCodeLines: String { LocalizationManager.shared.localizedString("project.netCodeLines") }
    public static var projectTotalDuration: String { LocalizationManager.shared.localizedString("project.totalDuration") }
    public static var projectNoProjectData: String { LocalizationManager.shared.localizedString("project.noProjectData") }
    public static var projectImportDataHint: String { LocalizationManager.shared.localizedString("project.importDataHint") }
    public static var projectActiveDaysDesc: String { LocalizationManager.shared.localizedString("project.activeDaysDesc") }
    public static var projectLastActive: String { LocalizationManager.shared.localizedString("project.lastActive") }
    public static var projectUnknown: String { LocalizationManager.shared.localizedString("project.unknown") }
    public static var projectDays: String { LocalizationManager.shared.localizedString("project.days") }
    public static var projectHours: String { LocalizationManager.shared.localizedString("project.hours") }
    public static var projectMinutes: String { LocalizationManager.shared.localizedString("project.minutes") }
    public static var projectSeconds: String { LocalizationManager.shared.localizedString("project.seconds") }
    public static var projectSessionCount: String { LocalizationManager.shared.localizedString("project.sessionCount") }
    public static var projectMessageCount: String { LocalizationManager.shared.localizedString("project.messageCount") }
    public static var projectTokens: String { LocalizationManager.shared.localizedString("project.tokens") }
    public static var projectCost: String { LocalizationManager.shared.localizedString("project.cost") }
    public static var projectDay: String { LocalizationManager.shared.localizedString("project.day") }

    // MARK: - Top3 Metrics
    public static var top3NetCodeLines: String { LocalizationManager.shared.localizedString("top3.netCodeLines") }
    public static var top3Messages: String { LocalizationManager.shared.localizedString("top3.messages") }
    public static var top3TotalDuration: String { LocalizationManager.shared.localizedString("top3.totalDuration") }
    public static var top3Cost: String { LocalizationManager.shared.localizedString("top3.cost") }

    // MARK: - Model & Agent
    public static var modelAndAgentTitle: String { LocalizationManager.shared.localizedString("modelAndAgent.title") }
    public static var modelModel: String { LocalizationManager.shared.localizedString("model.model") }
    public static var modelAgent: String { LocalizationManager.shared.localizedString("model.agent") }
    public static var modelUsageRatio: String { LocalizationManager.shared.localizedString("model.usageRatio") }
    public static var modelNoModelData: String { LocalizationManager.shared.localizedString("model.noModelData") }
    public static var modelDimensionModel: String { LocalizationManager.shared.localizedString("model.dimension.model") }
    public static var modelDimensionProvider: String { LocalizationManager.shared.localizedString("model.dimension.provider") }
    public static var modelNoData: String { LocalizationManager.shared.localizedString("model.noData") }
    public static var modelStatDimension: String { LocalizationManager.shared.localizedString("model.statDimension") }

    // MARK: - Menu Bar
    public static var menuBarTotalUsage: String { LocalizationManager.shared.localizedString("menuBar.totalUsage") }
    public static var menuBarDays: String { LocalizationManager.shared.localizedString("menuBar.days") }
    public static var menuBarFrom: String { LocalizationManager.shared.localizedString("menuBar.from") }
    public static var menuBarSince: String { LocalizationManager.shared.localizedString("menuBar.since") }
    public static var menuBarOpen: String { LocalizationManager.shared.localizedString("menuBar.open") }
    public static var menuBarQuit: String { LocalizationManager.shared.localizedString("menuBar.quit") }
    public static var menuAbout: String { LocalizationManager.shared.localizedString("menu.about") }
    public static var menuCheckForUpdates: String { LocalizationManager.shared.localizedString("menu.checkForUpdates") }
    public static var menuBarTopModels: String { LocalizationManager.shared.localizedString("menuBar.topModels") }
    public static var menuBarTopProjects: String { LocalizationManager.shared.localizedString("menuBar.topProjects") }
    public static var menuBarKpiSessions: String { LocalizationManager.shared.localizedString("menuBar.kpi.sessions") }
    public static var menuBarKpiMessages: String { LocalizationManager.shared.localizedString("menuBar.kpi.messages") }
    public static var menuBarKpiCost: String { LocalizationManager.shared.localizedString("menuBar.kpi.cost") }
    public static var menuBarKpiInput: String { LocalizationManager.shared.localizedString("menuBar.kpi.input") }
    public static var menuBarKpiOutput: String { LocalizationManager.shared.localizedString("menuBar.kpi.output") }
    public static var menuBarKpiReasoning: String { LocalizationManager.shared.localizedString("menuBar.kpi.reasoning") }
    public static var menuBarKpiCacheRead: String { LocalizationManager.shared.localizedString("menuBar.kpi.cacheRead") }
    public static var menuBarKpiCacheWrite: String { LocalizationManager.shared.localizedString("menuBar.kpi.cacheWrite") }
    public static var menuBarKpiAvgPerSession: String { LocalizationManager.shared.localizedString("menuBar.kpi.avgPerSession") }

    // MARK: - Import
    public static var importData: String { LocalizationManager.shared.localizedString("import.data") }

    // MARK: - Aggregation Dimension
    public static var dimensionProject: String { LocalizationManager.shared.localizedString("dimension.project") }
    public static var dimensionModel: String { LocalizationManager.shared.localizedString("dimension.model") }

    // MARK: - About
    public static var aboutTab: String { LocalizationManager.shared.localizedString("about.tab") }
    public static var aboutVersion: String { LocalizationManager.shared.localizedString("about.version") }
    public static var aboutBuild: String { LocalizationManager.shared.localizedString("about.build") }
    public static var aboutCopyright: String { LocalizationManager.shared.localizedString("about.copyright") }
    public static var aboutDeveloper: String { LocalizationManager.shared.localizedString("about.developer") }
    public static var aboutGitHub: String { LocalizationManager.shared.localizedString("about.github") }
    public static var aboutTwitter: String { LocalizationManager.shared.localizedString("about.twitter") }
    public static var aboutDescription: String { LocalizationManager.shared.localizedString("about.description") }
    public static var aboutCheckForUpdates: String { LocalizationManager.shared.localizedString("about.checkForUpdates") }
    public static var aboutCheckingForUpdates: String { LocalizationManager.shared.localizedString("about.checkingForUpdates") }
    public static var aboutUpToDate: String { LocalizationManager.shared.localizedString("about.upToDate") }
    public static var aboutNewVersionAvailable: String { LocalizationManager.shared.localizedString("about.newVersionAvailable") }
    public static var aboutCurrentVersion: String { LocalizationManager.shared.localizedString("about.currentVersion") }
    public static var aboutLatestVersion: String { LocalizationManager.shared.localizedString("about.latestVersion") }
    public static var aboutReleaseNotes: String { LocalizationManager.shared.localizedString("about.releaseNotes") }
    public static var aboutViewRelease: String { LocalizationManager.shared.localizedString("about.viewRelease") }
    public static var aboutDownload: String { LocalizationManager.shared.localizedString("about.download") }
    public static var aboutLater: String { LocalizationManager.shared.localizedString("about.later") }
    public static var aboutUpdateError: String { LocalizationManager.shared.localizedString("about.updateError") }
}
