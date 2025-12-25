# iam.tf

# 允許 EC2 實例扮演此角色的信任策略
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# IAM Role
resource "aws_iam_role" "ec2_s3_role" {
  name               = "${var.project_name}-ec2-s3-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

# 授權寫入 S3 的 IAM Policy
data "aws_iam_policy_document" "s3_write_policy" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_bucket.arn}/nginx/*"]
  }
}

resource "aws_iam_policy" "s3_write_policy" {
  name   = "${var.project_name}-s3-write-policy"
  policy = data.aws_iam_policy_document.s3_write_policy.json
}

# 將 Policy 綁定到 Role
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# 建立 EC2 Instance Profile，以便將 Role 附加到實例上
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}
