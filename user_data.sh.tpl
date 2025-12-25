#!/bin/bash
yum update -y
amazon-linux-extras install nginx1 -y

# --- 1. Configure Nginx log format ---
sed -i '/http {/a \    log_format athena '"'$remote_addr - $remote_user [$time_local] \\"$request\\" $status $body_bytes_sent \\"$http_referer\\" \\"$http_user_agent\\""';' /etc/nginx/nginx.conf
sed -i 's|access_log  /var/log/nginx/access.log;.*|access_log  /var/log/nginx/access.log athena;|' /etc/nginx/nginx.conf

# --- 2. Create logrotate config ---
cat <<'EOT' > /etc/logrotate.d/nginx-hourly
/var/log/nginx/access.log /var/log/nginx/error.log {
    hourly
    rotate 24
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    dateext
    dateformat -%Y%m%d-%H
    postrotate
        /bin/systemctl reload nginx > /dev/null 2>/dev/null || true
    endscript
}
EOT

# --- 3. Create cron job for logrotate ---
cat <<'EOT' > /etc/cron.d/logrotate-nginx-hourly
0 * * * * root /usr/sbin/logrotate /etc/logrotate.d/nginx-hourly --state /var/lib/logrotate/status-nginx-hourly
EOT

# --- 4. Create the S3 archive script ---
# Note: ${s3_bucket_id} is a Terraform variable.
# $$ is used to escape shell variables like $$HOSTNAME or $${BASH_REMATCH[1]}
cat > /usr/local/bin/archive_nginx_logs_to_s3.sh << EOL
#!/bin/bash
LOG_DIR="/var/log/nginx"
BUCKET_NAME="${s3_bucket_id}/nginx"
HOSTNAME=$$(hostname -s)

find "\$$LOG_DIR" -name "*.gz" -type f -mmin +5 | while read -r file; do
    if [[ "\$$file" =~ -([0-9]{8})-([0-9]{2})\\.gz$ ]]; then
        DATE_STR="$${BASH_REMATCH[1]}"
        HOUR_STR="$${BASH_REMATCH[2]}"
        
        YEAR=$${DATE_STR:0:4}
        MONTH=$${DATE_STR:4:2}
        DAY=$${DATE_STR:6:2}
        
        S3_PATH="s3://$${BUCKET_NAME}/year=$${YEAR}/month=$${MONTH}/day=$${DAY}/hour=$${HOUR_STR}/"
        
        aws s3 mv "\$$file" "\$${S3_PATH}\$${HOSTNAME}-\$(basename "\$file")" --quiet
    fi
done
EOL

# --- 5. Make script executable ---
chmod +x /usr/local/bin/archive_nginx_logs_to_s3.sh

# --- 6. Create cron job for the archive script ---
cat <<'EOT' > /etc/cron.d/s3-archiver
10 * * * * root /usr/local/bin/archive_nginx_logs_to_s3.sh > /dev/null 2>&1
EOT

# --- 7. Start and enable Nginx ---
systemctl start nginx
systemctl enable nginx
