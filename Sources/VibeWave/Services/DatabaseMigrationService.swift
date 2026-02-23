import Foundation
import GRDB

/// 数据库迁移服务 - 负责修复现有用户的数据问题
public final class DatabaseMigrationService {
    private let logger = AppLogger(category: "DatabaseMigrationService")
    private let dbPool: DatabasePool
    
    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }
    
    /// 执行所有必要的迁移
    public func performMigrations() throws {
        logger.info("开始执行数据库迁移")
        
        try migrate1_fixProjectNameExtraction()
        try migrate2_fixEmptyProjectNames()
        try migrate3_rebuildAggregations()
        
        logger.info("数据库迁移完成")
    }
    
    // MARK: - Migration 1: 修复 project_name 提取逻辑
    /// 修复由于 SUBSTR/INSTR bug 导致的 project_name 提取错误
    /// 问题：INSTR 只返回第一个 '/' 的位置，导致提取出完整路径而非项目名称
    private func migrate1_fixProjectNameExtraction() throws {
        try dbPool.write { db in
            // 检查是否需要迁移
            let emptyProjectCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sessions WHERE project_name IS NULL OR project_name = ''
            """) ?? 0
            
            let wrongProjectCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sessions 
                WHERE project_name LIKE '%/%' OR project_name LIKE '%\\%'
            """) ?? 0
            
            if emptyProjectCount == 0 && wrongProjectCount == 0 {
                logger.info("Migration 1: 无需修复，project_name 数据正常")
                return
            }
            
            logger.info("Migration 1: 发现 \(emptyProjectCount) 个空 project_name, \(wrongProjectCount) 个错误 project_name")
            
            // 修复空的 project_name
            try db.execute(sql: """
                UPDATE sessions
                SET project_name = (
                    SELECT NULLIF(
                        REPLACE(
                            RTRIM(m2.project_root, '/'),
                            RTRIM(RTRIM(m2.project_root, '/'), REPLACE(RTRIM(m2.project_root, '/'), '/', '')),
                            ''
                        ),
                        ''
                    )
                    FROM messages m2
                    WHERE m2.session_id = sessions.session_id
                      AND m2.project_root IS NOT NULL
                      AND m2.project_root != ''
                      AND m2.project_root != '/'
                    LIMIT 1
                )
                WHERE (project_name IS NULL OR project_name = '')
                  AND EXISTS (
                    SELECT 1 FROM messages m2
                    WHERE m2.session_id = sessions.session_id
                      AND m2.project_root IS NOT NULL
                      AND m2.project_root != ''
                      AND m2.project_root != '/'
                  )
            """)
            
            // 修复错误的 project_name（完整路径）
            try db.execute(sql: """
                UPDATE sessions
                SET project_name = NULLIF(
                    REPLACE(
                        RTRIM(project_name, '/'),
                        RTRIM(RTRIM(project_name, '/'), REPLACE(RTRIM(project_name, '/'), '/', '')),
                        ''
                    ),
                    ''
                )
                WHERE project_name LIKE '%/%' OR project_name LIKE '%\\%'
            """)
            let fixedCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sessions WHERE project_name IS NOT NULL AND project_name != '' AND project_name NOT LIKE '%/%'
            """) ?? 0
            logger.info("Migration 1: 已修复 project_name，当前有 \(fixedCount) 个有效 project_name")
        }
    }
    
    // MARK: - Migration 2: 修复空 project_name 使用 project_cwd 后备
    /// 对于 project_root 为 '/' 或空的情况，使用 project_cwd 提取项目名
    private func migrate2_fixEmptyProjectNames() throws {
        try dbPool.write { db in
            // 检查剩余的空 project_name
            let emptyCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sessions WHERE project_name IS NULL OR project_name = ''
            """) ?? 0
            
            if emptyCount == 0 {
                logger.info("Migration 2: 无需修复，没有空 project_name")
                return
            }
            
            logger.info("Migration 2: 发现 \(emptyCount) 个空 project_name，尝试使用 project_cwd 修复")
            
            // 使用 project_cwd 作为后备
            try db.execute(sql: """
                UPDATE sessions
                SET project_name = (
                    SELECT NULLIF(
                        REPLACE(
                            RTRIM(
                                COALESCE(
                                    NULLIF(m2.project_root, '/'),
                                    NULLIF(m2.project_root, ''),
                                    m2.project_cwd
                                ),
                                '/'
                            ),
                            RTRIM(
                                RTRIM(
                                    COALESCE(
                                        NULLIF(m2.project_root, '/'),
                                        NULLIF(m2.project_root, ''),
                                        m2.project_cwd
                                    ),
                                    '/'
                                ),
                                REPLACE(
                                    RTRIM(
                                        COALESCE(
                                            NULLIF(m2.project_root, '/'),
                                            NULLIF(m2.project_root, ''),
                                            m2.project_cwd
                                        ),
                                        '/'
                                    ),
                                    '/',
                                    ''
                                )
                            ),
                            ''
                        ),
                        ''
                    )
                    FROM messages m2
                    WHERE m2.session_id = sessions.session_id
                      AND (m2.project_root IS NOT NULL OR m2.project_cwd IS NOT NULL)
                    LIMIT 1
                )
                WHERE (project_name IS NULL OR project_name = '')
                  AND EXISTS (
                    SELECT 1 FROM messages m2
                    WHERE m2.session_id = sessions.session_id
                      AND (m2.project_root IS NOT NULL OR m2.project_cwd IS NOT NULL)
                  )
            """)
            
            // 剩余的空值标记为"未命名项目"
            try db.execute(sql: """
                UPDATE sessions
                SET project_name = '未命名项目'
                WHERE project_name IS NULL OR project_name = ''
            """)
            
            let finalEmptyCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sessions WHERE project_name IS NULL OR project_name = ''
            """) ?? 0
            
            logger.info("Migration 2: 修复完成，剩余 \(finalEmptyCount) 个空 project_name")
        }
    }
    
    // MARK: - Migration 3: 重新构建聚合数据
    /// 使用修复后的 project_name 重新构建 hourly_stats、daily_stats 和 monthly_stats
    private func migrate3_rebuildAggregations() throws {
        logger.info("Migration 3: 开始重新构建聚合数据")
        try AggregationService(dbPool: dbPool).rebuildAllAggregations()
        logger.info("Migration 3: 聚合数据重建完成")
    }
}
