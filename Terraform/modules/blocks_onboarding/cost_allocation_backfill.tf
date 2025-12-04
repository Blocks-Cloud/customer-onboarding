########################################
# Cost Allocation Tag Backfill        #
########################################

resource "null_resource" "cost_allocation_backfill" {
  depends_on = [ aws_bcmdataexports_export.cur2 ]

  provisioner "local-exec" {
    command = "python3 ${path.module}/backfill_script.py"
  }

}
