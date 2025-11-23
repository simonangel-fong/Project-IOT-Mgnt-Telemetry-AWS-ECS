# ########################################
# AWS S3 bucket for static web host
# ########################################

resource "aws_s3_bucket" "web_host_bucket" {
  bucket = "${var.project}-${var.env}-web-bucket"

  tags = {
    Name = "${var.project}-${var.env}-web-bucket"
  }
}

# resource "random_string" "bucket_suffix" {
#   length  = 8
#   special = false
#   upper   = false
# }

# Enabe bucket versioning
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.web_host_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ########################################
# Upload web files
# ########################################

module "template_files" {
  source   = "hashicorp/dir/template"
  version  = "1.0.2"
  base_dir = "${path.module}/../app/html"
}

# update S3 object resource for hosting bucket files
resource "aws_s3_object" "web_file" {
  bucket = aws_s3_bucket.web_host_bucket.id

  # loop all files
  for_each     = module.template_files.files
  key          = each.key
  content_type = each.value.content_type

  source  = each.value.source_path
  content = each.value.content

  # ETag of the S3 object
  etag = each.value.digests.md5
}

# ########################################
# Enable static website hosting
# ########################################

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.web_host_bucket.id

  index_document {
    suffix = "index.html"
  }

  #   error_document {
  #     key = "error.html"
  #   }
}

# ########################################
# Configure bucket permission
# ########################################

# Enable bucket public access block
resource "aws_s3_bucket_public_access_block" "bucket_public_access" {
  bucket = aws_s3_bucket.web_host_bucket.id

  # block_public_acls       = true
  # ignore_public_acls      = true
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

# set ownership
resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.web_host_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# set access control list
resource "aws_s3_bucket_acl" "bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.bucket_ownership,
    aws_s3_bucket_public_access_block.bucket_public_access
  ]

  bucket = aws_s3_bucket.web_host_bucket.id
  acl    = "public-read"
}

# Enable bucket policy for public read access
resource "aws_s3_bucket_policy" "example" {
  bucket = aws_s3_bucket.web_host_bucket.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${aws_s3_bucket.web_host_bucket.id}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.bucket_public_access]
}
