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
                    SELECT REPLACE(
                        m2.project_root,
                        RTRIM(m2.project_root, REPLACE(m2.project_root, '/', '')),
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
                SET project_name = REPLACE(
                    project_name,
                    RTRIM(project_name, REPLACE(project_name, '/', '')),
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
                    SELECT REPLACE(
                        COALESCE(
                            NULLIF(m2.project_root, '/'),
                            NULLIF(m2.project_root, ''),
                            m2.project_cwd
                        ),
                        RTRIM(
                            COALESCE(
                                NULLIF(m2.project_root, '/'),
                                NULLIF(m2.project_root, ''),
                                m2.project_cwd
                            ),
                            REPLACE(
                                COALESCE(
                                    NULLIF(m2.project_root, '/'),
                                    NULLIF(m2.project_root, ''),
                                    m2.project_cwd
                                ),
                                '/',
                                ''
                            )
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
    /// 使用修复后的 project_name 重新构建 hourly_stats 和 daily_stats
    private func migrate3_rebuildAggregations() throws {
        try dbPool.write { db in
            logger.info("Migration 3: 开始重新构建聚合数据")
            
            // 删除旧的聚合数据
            try db.execute(sql: "DELETE FROM hourly_stats")
            try db.execute(sql: "DELETE FROM daily_stats")
            try db.execute(sql: "DELETE FROM monthly_stats")
            
            // 获取时间范围
            let timeRange = try Row.fetchOne(db, sql: """
                SELECT MIN(created_at) as min_time, MAX(created_at) as max_time FROM messages
            """)
            guard let minTime = timeRange?["min_time"] as? Int64,
                  let maxTime = timeRange?["max_time"] as? Int64 else {
                logger.info("Migration 3: 没有消息数据，跳过聚合")
                return
            }
            
            // 重新聚合 hourly_stats
            try db.execute(sql: """
                INSERT INTO hourly_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
                    cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
                    last_created_at_ms
                )
                SELECT
                    (m.created_at / 3600000) * 3600000 as time_bucket_ms,
                    COALESCE(NULLIF(s.project_name, ''), '未命名项目') as project_id,
                    COALESCE(m.provider_id, 'unknown') as provider_id,
                    COALESCE(m.model_id, 'unknown') as model_id,
                    COALESCE(m.role, 'unknown') as role,
                    COALESCE(m.agent, 'unknown') as agent,
                    COALESCE(m.tool_id, 'opencode') as tool_id,
                    COUNT(DISTINCT m.session_id) as session_count,
                    COUNT(*) as message_count,
                    COALESCE(SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)), 0) as input_tokens,
                    COALESCE(SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)), 0) as output_tokens,
                    COALESCE(SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)), 0) as reasoning_tokens,
                    COALESCE(SUM(m.cache_read), 0) as cache_read,
                    COALESCE(SUM(m.cache_write), 0) as cache_write,
                    COALESCE(SUM(m.completed_at - m.created_at), 0) as duration_ms,
                    COALESCE(SUM(m.cost), 0) as cost,
                    COALESCE(SUM(COALESCE(m.summary_total_additions, 0) - COALESCE(m.summary_total_deletions, 0)), 0) as net_code_lines,
                    COALESCE(SUM(COALESCE(m.summary_file_count, 0)), 0) as file_count,
                    MAX(m.created_at) as last_created_at_ms
                FROM messages m
                LEFT JOIN sessions s ON m.session_id = s.session_id
                WHERE m.created_at >= ? AND m.created_at < ?
                GROUP BY
                    (m.created_at / 3600000) * 3600000,
                    COALESCE(NULLIF(s.project_name, ''), '未命名项目'),
                    COALESCE(m.provider_id, 'unknown'),
                    COALESCE(m.model_id, 'unknown'),
                    COALESCE(m.role, 'unknown'),
                    COALESCE(m.agent, 'unknown'),
                    COALESCE(m.tool_id, 'opencode')
            """, arguments: [minTime, maxTime + 3600000])
            
            // 重新聚合 daily_stats
            try db.execute(sql: """
                INSERT INTO daily_stats (
                    time_bucket_ms, project_id, provider_id, model_id, role, agent, tool_id,
                    session_count, message_count, input_tokens, output_tokens, reasoning_tokens,
                    cache_read, cache_write, duration_ms, cost, net_code_lines, file_count,
                    last_created_at_ms
                )
                SELECT
                    (m.created_at / 86400000) * 86400000 as time_bucket_ms,
                    COALESCE(NULLIF(s.project_name, ''), '未命名项目') as project_id,
                    COALESCE(m.provider_id, 'unknown') as provider_id,
                    COALESCE(m.model_id, 'unknown') as model_id,
                    COALESCE(m.role, 'unknown') as role,
                    COALESCE(m.agent, 'unknown') as agent,
                    COALESCE(m.tool_id, 'opencode') as tool_id,
                    COUNT(DISTINCT m.session_id) as session_count,
                    COUNT(*) as message_count,
                    COALESCE(SUM(CAST(COALESCE(m.token_input, '0') AS INTEGER)), 0) as input_tokens,
                    COALESCE(SUM(CAST(COALESCE(m.token_output, '0') AS INTEGER)), 0) as output_tokens,
                    COALESCE(SUM(CAST(COALESCE(m.token_reasoning, '0') AS INTEGER)), 0) as reasoning_tokens,
                    COALESCE(SUM(m.cache_read), 0) as cache_read,
                    COALESCE(SUM(m.cache_write), 0) as cache_write,
                    COALESCE(SUM(m.completed_at - m.created_at), 0) as duration_ms,
                    COALESCE(SUM(m.cost), 0) as cost,
                    COALESCE(SUM(COALESCE(m.summary_total_additions, 0) - COALESCE(m.summary_total_deletions, 0)), 0) as net_code_lines,
                    COALESCE(SUM(COALESCE(m.summary_file_count, 0)), 0) as file_count,
                    MAX(m.created_at) as last_created_at_ms
                FROM messages m
                LEFT JOIN sessions s ON m.session_id = s.session_id
                WHERE m.created_at >= ? AND m.created_at < ?
                GROUP BY
                    (m.created_at / 86400000) * 86400000,
                    COALESCE(NULLIF(s.project_name, ''), '未命名项目'),
                    COALESCE(m.provider_id, 'unknown'),
                    COALESCE(m.model_id, 'unknown'),
                    COALESCE(m.role, 'unknown'),
                    COALESCE(m.agent, 'unknown'),
                    COALESCE(m.tool_id, 'opencode')
            """, arguments: [minTime, maxTime + 86400000])
            
            logger.info("Migration 3: 聚合数据重建完成")
        }
    }
}
