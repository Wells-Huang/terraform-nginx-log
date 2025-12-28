
# EC2 Nginx 日誌生命週期管理

## 專案簡介

建立一套針對 EC2 上 Nginx 日誌的生命週期管理流程，使本地僅保留短期日誌，歷史日誌自動封存至 S3，並可透過 Athena 查詢指定時間區段的存取紀錄。

---

### 任務內容與做法方向

#### Nginx 日誌輪替（Log Rotate）
- 僅針對 Nginx 的 `access.log`。
- 採用 **每小時** 輪替的方式，避免單一檔案過大。
- 本地僅保留最近 **24 小時** 的日誌資料。

#### 歷史日誌封存至 S3
- 僅處理「已完成輪替、不再寫入、即將被刪除」的日誌檔案。
- 將日誌壓縮檔 (`.gz`) 上傳至 S3。
- 上傳完成後，本地舊日誌可被安全清理，以控制磁碟用量。

#### Athena 查詢支援
- 在 Athena 中建立對應的 External Table 指向 S3 日誌目錄。
- 表結構需支援依 **日期與小時** 進行分割區查詢 (Partition)，以提升查詢效率並降低成本。

---

### 示例

**日誌格式：** Nginx access.log（常見 format）
```
127.0.0.1 - - [19/Dec/2025:10:15:32 +0800] "GET /index.html HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
```

**S3 路徑：**
```
s3://my-nginx-log-bucket/nginx/YYYY/MM/DD/HH/hostname/*.gz
```

**Athena 查詢：**
透過 Partition (year, month, day)，你可以高效地進行分區查詢。
```sql
SELECT *
FROM nginx_logs
WHERE client_ip = '203.0.113.5'
  AND year = '2025'
  AND month = '12'
  AND day = '28';
```

---

## 使用說明

### 1. 基礎環境部署
在您的 WSL (Windows Subsystem for Linux) 環境下執行：
```bash
terraform init
terraform apply
```
成功後，Terraform 會輸出 `Athena database name`, `Athena table name`, `ec2 public ip`, `s3 bucket name` 以及 `ssh command`。

### 2. 連線至 EC2
根據上一步輸出的 `ssh command` 以及對應的私鑰，在 PowerShell 環境下連上 EC2。
*(注意：直接在 WSL 環境下連線可能會遇到私鑰權限問題，需先行解決)*

### 3. 在 EC2 上進行設定驗證
1.  **檢查 Nginx 服務是否正在運行**
    ```bash
    systemctl status nginx
    ```
    > 預期輸出應包含 `active (running)`

2.  **檢查 Logrotate 每小時輪替設定**
    ```bash
    cat /etc/logrotate.d/nginx-hourly
    ```
    > 預期應能看到 `hourly` 與 `rotate 24` 等設定。

3.  **檢查 Logrotate 的 Cron 排程**
    ```bash
    cat /etc/cron.d/logrotate-nginx-hourly
    ```
    > 預期應能看到 `0 * * * * root /usr/sbin/logrotate ...`

4.  **檢查 S3 封存腳本的 Cron 排程**
    ```bash
    cat /etc/cron.d/s3-archiver
    ```
    > 預期應能看到 `10 * * * * root /usr/local/bin/archive_nginx_logs_to_s3.sh ...`

5.  **檢查 S3 封存腳本是否存在且可執行**
    ```bash
    ls -l /usr/local/bin/archive_nginx_logs_to_s3.sh
    ```
    > 預期應能看到該檔案，並且具有 `x` (執行) 權限。

### 4. 手動觸發與驗證流程
1.  **手動產生 access.log**
    ```bash
    # 將 ec2_public_ip 替換為您的 EC2 公開 IP
    curl http://<ec2_public_ip>
    curl http://<ec2_public_ip>
    ```

2.  **確認日誌已產生**
    ```bash
    sudo tail /var/log/nginx/access.log
    ```

3.  **手動觸發 log rotate**
    ```bash
    sudo /usr/sbin/logrotate -f /etc/logrotate.d/nginx-hourly --state /var/lib/logrotate/status-nginx-hourly
    ```

4.  **再次產生流量以生成新的 access.log**
    ```bash
    curl http://<ec2_public_ip>
    ```

5.  **再次觸發 log rotate 以生成壓縮檔**
    ```bash
    sudo /usr/sbin/logrotate -f /etc/logrotate.d/nginx-hourly --state /var/lib/logrotate/status-nginx-hourly
    ```

6.  **確認 `access.log.*.gz` 檔案已生成**
    等待約一分鐘後，檢查日誌目錄。
    ```bash
    sudo ls -l /var/log/nginx/
    ```

7.  **手動執行 S3 封存腳本**
    ```bash
    sudo /usr/local/bin/archive_nginx_logs_to_s3.sh
    ```
    > 此腳本會將 `access.log.1.gz` 上傳到 S3。

---

## 驗證步驟

1.  登入 AWS Console，前往 **Athena** 服務頁面。
2.  在左側的 **Database** 下拉選單中，選擇 Terraform 輸出的資料庫名稱 (預設: `nginx-log-poc_db`)。
3.  確認 **Tables** 下出現了 Terraform 輸出的資料表 (預設: `nginx_logs`)。
4.  在右側的查詢編輯器中，執行以下查詢 (請將年月日修改為當前日期)：
    ```sql
    SELECT *
    FROM "nginx-log-poc_db"."nginx_logs"
    WHERE year = '2025'
      AND month = '12'
      AND day = '28'
    LIMIT 10;
    ```
5.  檢查查詢結果是否符合預期的日誌格式。

---

## 驗證完成後的清理

為避免產生不必要的費用，驗證成功後，請務必執行以下指令來清除所有已建立的 AWS 資源。
```bash
terraform destroy
```
```
