########################################
# Cost Allocation Tag Backfill        #
########################################

resource "aws_ce_cost_allocation_tag" "created_by" {
  tag_key = "aws:createdBy"
  status  = "Active"
}

resource "null_resource" "cost_allocation_backfill" {
  triggers = {
    tag_status = aws_ce_cost_allocation_tag.created_by.status
  }

  provisioner "local-exec" {
    command = <<-EOF
      BACKFILL_DATE=$(python3 -c "
import datetime
current_date = datetime.datetime.utcnow()
backfill_from = datetime.datetime(current_date.year - 1, current_date.month, 1, 0, 0, 0)
print(backfill_from.strftime('%Y-%m-%dT%H:%M:%SZ'))
")

      echo "Starting cost allocation tag backfill from: $BACKFILL_DATE"
      
      aws ce start-cost-allocation-tag-backfill \
        --backfill-from "$BACKFILL_DATE" \
        --region us-east-1 || echo "Backfill already in progress or completed"
    EOF
  }

  depends_on = [aws_ce_cost_allocation_tag.created_by]
}
