import sys
import types
from pathlib import Path

import pytest
import yaml

TEMPLATE = Path(__file__).resolve().parents[1] / "Cloudformation" / "02_step" / "Blocks-CostOptimization.yaml"
RESOURCE_ID = "abc123def456"
ROOT_ID, OU_ID = "r-root", "ou-blocks"
NAMES = [f"Blocks-Compute-{i}-{RESOURCE_ID}" for i in (1, 2, 3)] + [f"Blocks-Database-1-{RESOURCE_ID}"]


class _Loader(yaml.SafeLoader):
    pass


_Loader.add_multi_constructor("!", lambda loader, suffix, node: None)


def lambda_source(function_name):
    doc = yaml.load(TEMPLATE.read_text(), Loader=_Loader)
    code = doc["Resources"][function_name]["Properties"]["Code"]["ZipFile"]
    return code.replace("{{BLOCKS_CUSTOMER_RESOURCE_ID}}", RESOURCE_ID)


class FakeContext:
    def __init__(self, log_stream_name):
        self.log_stream_name = log_stream_name

    def get_remaining_time_in_millis(self):
        return 900_000


class FakeOrgs:
    def __init__(self, parents=None):
        self.parent = dict(parents or {})
        self.moves = []

    def accounts(self):
        return [{"Id": f"id-{n}", "Name": n, "Status": "ACTIVE"} for n in self.parent]

    def list_accounts(self, **kwargs):
        return {"Accounts": self.accounts()}

    def list_create_account_status(self, **kwargs):
        return {"CreateAccountStatuses": []}

    def list_parents(self, ChildId):
        name = ChildId.removeprefix("id-")
        return {"Parents": [{"Id": self.parent[name]}]}

    def move_account(self, AccountId, SourceParentId, DestinationParentId):
        self.parent[AccountId.removeprefix("id-")] = DestinationParentId
        self.moves.append((AccountId, SourceParentId, DestinationParentId))

    def describe_organization(self):
        return {"Organization": {"MasterAccountId": "111111111111"}}


class Harness:
    def __init__(self, monkeypatch):
        self.responses = []
        self.orgs = FakeOrgs({n: OU_ID for n in NAMES})
        self.log_stream = 0
        self.monkeypatch = monkeypatch
        self.module = types.ModuleType("index")
        cfnresponse = types.ModuleType("cfnresponse")
        cfnresponse.SUCCESS, cfnresponse.FAILED = "SUCCESS", "FAILED"

        def send(event, context, status, data, physicalResourceId=None, noEcho=False, reason=None):
            # Same default as the real cfn-response module
            self.responses.append({"status": status, "physical_id": physicalResourceId or context.log_stream_name})

        cfnresponse.send = send
        monkeypatch.setitem(sys.modules, "cfnresponse", cfnresponse)
        monkeypatch.setattr("boto3.client", lambda service, **kw: self.orgs)
        exec(compile(lambda_source("CreateBlocksAccountsLambda"), "CreateBlocksAccountsLambda", "exec"), self.module.__dict__)

    def invoke(self, request_type, physical_id=None):
        self.log_stream += 1
        event = {
            "RequestType": request_type,
            "ResourceProperties": {"OrganizationalUnitId": OU_ID, "OrganizationRootId": ROOT_ID},
        }
        if physical_id:
            event["PhysicalResourceId"] = physical_id
        self.module.handler(event, FakeContext(f"2026/11/16/[$LATEST]stream{self.log_stream}"))
        return self.responses[-1]["physical_id"]

    def redeploy(self, current_physical_id):
        # CloudFormation: a changed physical id on Update is a replacement, cleaned up with a Delete of the old id
        new_id = self.invoke("Update", current_physical_id)
        if new_id != current_physical_id:
            self.invoke("Delete", current_physical_id)
        return new_id

    def parents(self):
        return set(self.orgs.parent.values())


@pytest.fixture
def harness(monkeypatch):
    return Harness(monkeypatch)
