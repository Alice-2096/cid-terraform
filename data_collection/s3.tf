
############################################ S3 Bucket ############################################
resource "aws_s3_bucket" "cid_s3_bucket" {
  bucket = "cid-data-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_ownership_controls" "CID-bucket-ownership" {
  bucket = aws_s3_bucket.cid_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "cid-bucket-versioning" {
  bucket = aws_s3_bucket.cid_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "CID-bucket-public-access" {
  bucket                  = aws_s3_bucket.cid_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_policy" "s3_data_bucket_policy" {
  bucket = aws_s3_bucket.cid_s3_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowSSLOnly",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = "${aws_s3_bucket.cid_s3_bucket.arn}/*",
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "AllowTLS12Only",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = "${aws_s3_bucket.cid_s3_bucket.arn}/*",
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = 1.2
          }
        }
      }
    ]
  })
}

output "bucket_name" {
  value = aws_s3_bucket.cid_s3_bucket.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.cid_s3_bucket.arn
}

