resource "aws_sfn_state_machine" "sfn_crawler" {
  name     = "CID-DC-CrawlerExecution-StateMachine"
  role_arn = aws_iam_role.glue_role.arn

  definition = templatefile("./definitions/crawler.asl.json", {
  "crawlers" : [] })
}
