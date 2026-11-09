"""The rewriter image in front of PostgREST, over tests/api_tests' mock data.

The mock data registers alice/A, alice/B, alice/C, bob/A, bob/B and bob/C; alice/B has
instances held by alice and bob tagged X and Y. A REST path is compared with the GET
of /rpc/<function> PostgREST answers directly, which is what the rewriter forwarded
before it sent declared arguments as a form POST.
"""
import json

import pytest
from rest_client import Service

_PREFIXES = ("not.", "eq.", "gt.", "in.", "like.", "is.")


@pytest.mark.parametrize("prefix", _PREFIXES)
@pytest.mark.parametrize("target", ["/nfts/{value}/TEST", "/nfts/{value}/TEST/X", "/nfts/alice/B?holder={value}"])
def test_operator_prefixed_argument_reaches_the_function(rewriter: Service, target: str, prefix: str) -> None:
    answer = rewriter.get(target.format(value=prefix + "blocktrades"))
    assert (answer.status, answer.body) == (200, []), answer


@pytest.mark.parametrize(("upstream", "code"), [
    ("/rpc/get_nft_instances?creator=not.blocktrades&symbol=TEST", "PGRST100"),
    ("/rpc/get_nft_instances?creator=eq.blocktrades&symbol=TEST", "PGRST202"),
])
def test_postgrest_get_reads_the_prefixed_value_as_a_filter(postgrest: Service, upstream: str, code: str) -> None:
    # What the rewriter answered before it forwarded arguments in a form body
    assert postgrest.get(upstream).body["code"] == code


@pytest.mark.parametrize(("target", "upstream"), [
    ("/nfts", "/rpc/get_nft_types"),
    ("/nfts?count=2", "/rpc/get_nft_types?count=2"),
    ("/nfts/alice/B", "/rpc/get_nft_instances?creator=alice&symbol=B"),
    ("/nfts/alice/B?holder=bob", "/rpc/get_nft_instances?creator=alice&symbol=B&holder=bob"),
    ("/nfts/alice/C?holder=dan&count=1", "/rpc/get_nft_instances?creator=alice&symbol=C&holder=dan&count=1"),
    ("/nfts/alice/C/Y", "/rpc/get_nft_instances_with_tags?creator=alice&symbol=C&tags=Y"),
])
def test_real_creator_answers_as_before(rewriter: Service, postgrest: Service, target: str, upstream: str) -> None:
    answer = rewriter.get(target)
    assert answer.status == 200 and answer.body, answer
    assert answer == postgrest.get(upstream)


@pytest.mark.parametrize(("target", "upstream"), [
    ("/nfts?limit=1", "/rpc/get_nft_types?limit=1"),
    ("/nfts/alice/B?limit=1&offset=0", "/rpc/get_nft_instances?creator=alice&symbol=B&limit=1&offset=0"),
    # The endpoints return arrays, not row sets, so PostgREST rejects a column filter
    # (42703); moved to the body it would be an unknown argument (PGRST202) instead
    ("/nfts/alice/B?id=eq.1", "/rpc/get_nft_instances?creator=alice&symbol=B&id=eq.1"),
    ("/nfts?creator=eq.bob", "/rpc/get_nft_types?creator=eq.bob"),
])
def test_postgrest_parameters_keep_their_meaning(rewriter: Service, postgrest: Service, target: str,
                                                 upstream: str) -> None:
    assert rewriter.get(target) == postgrest.get(upstream)


@pytest.mark.parametrize(("target", "status"), [
    ("/nfts/not.blocktrades/TEST", 200),
    ("/nfts/alice/B", 200),
    ("/nfts", 200),
    ("/nfts/alice/B?count=notanumber", 400),
])
def test_head_answers_as_get_without_body(rewriter: Service, target: str, status: int) -> None:
    # A body sent after a HEAD's headers would stay on the connection and be read as the
    # start of the next answer, which then fails to parse.
    head, get, head_again, get_again = rewriter.in_turn(("HEAD", target), ("GET", target),
                                                        ("HEAD", target), ("GET", target))
    assert head.status == get.status == head_again.status == get_again.status == status, (head, get)
    assert (head.body, head_again.body) == (b"", b"")
    assert head.headers.get("content-type") == get.headers.get("content-type")
    assert json.loads(get.body) == json.loads(get_again.body) == rewriter.get(target).body
