import api from './index'

export interface BackupConfig {
  id: number
  family_id: number
  backup_type: string
  schedule: string
  is_enabled: boolean
  target: string
  target_config: Record<string, unknown> | null
  retention_days: number
  max_backups: number
}

export interface BackupLog {
  id: number
  backup_type: string
  backup_target: string
  file_path: string | null
  file_size: number | null
  file_format: string | null
  table_counts: Record<string, number | string> | null
  status: string
  error_message: string | null
  duration_ms: number | null
  created_at: string | null
}

export interface BackupConfigCreate {
  backup_type: string
  schedule: string
  target: string
  target_config?: Record<string, unknown>
  retention_days?: number
  max_backups?: number
}

export function getBackupConfigs() {
  return api.get<BackupConfig[]>('/backup/configs')
}

export function createBackupConfig(data: BackupConfigCreate) {
  return api.post<BackupConfig>('/backup/configs', data)
}

export function triggerBackup() {
  return api.post<BackupLog>('/backup/trigger')
}

export function getBackupLogs() {
  return api.get<BackupLog[]>('/backup/logs')
}

export function deleteBackupLog(logId: number) {
  return api.delete(`/backup/logs/${logId}`)
}
