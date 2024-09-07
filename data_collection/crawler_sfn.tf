resource "aws_sfn_state_machine" "sfn_crawler" {
  name     = "CID-DC-CrawlerExecution-StateMachine"
  role_arn = aws_iam_role.step_function_execution_role.arn

  definition = templatefile("./definitions/crawler.asl.json", {
  "crawlers" : [] })
}
