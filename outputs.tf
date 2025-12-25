# outputs.tf

output "s3_bucket_name" {
  description = "Name of the S3 bucket created for logs."
  value       = aws_s3_bucket.log_bucket.id
}

output "athena_database_name" {
  description = "Name of the Glue/Athena database."
  value       = aws_glue_catalog_database.nginx_db.name
}

output "athena_table_name" {
  description = "Name of the Athena table for querying logs."
  value       = aws_glue_catalog_table.nginx_logs_table.name
}

output "ec2_public_ip" {
  description = "Public IP address of the EC2 web server."
  value       = aws_instance.web_server.public_ip
}

output "ssh_command" {
  description = "Command to SSH into the EC2 instance."
  value       = "ssh ec2-user@${aws_instance.web_server.public_ip}"
}
