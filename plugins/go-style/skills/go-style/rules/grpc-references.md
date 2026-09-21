# gRPC lens: precedents and references

Companion to `rules/grpc.md`. Each rule there was derived from public API
contracts, RFCs and papers about programming routing state over gRPC and
similar RPC boundaries. This file records which precedent supports which
rule, and which popular claims the review found unsupported. It is distilled
from an internal PRISMA-style comparative survey (source snapshot 2026-09-03);
only public sources are cited, each pinned to a commit, RFC or DOI.

Reading guide: INCLUDED sources were read at the pinned revision; context-only
sources inform architecture but define no gRPC contract; EXCLUDED items could
not be verified and must not be cited.

## Precedent by design question

| Design question | Precedent | What it establishes | Rule in `grpc.md` |
|---|---|---|---|
| Per-operation results on a long-lived stream | gRIBI `Modify` (bidirectional stream, individually acknowledged operations); Juniper JET requests of 1-1000 routes; Cisco SL-API operation/get streams with replay and EOF | A batch is a correlation unit, not a rollback unit; every operation carries its own id and result | Ambiguous mutations; Backpressure and admission |
| Election, ownership and persistence | gRIBI session parameters: single-primary vs all-primary, delete vs preserve on disconnect, Uint128 election id; gNMI master arbitration; RFC 7921 client identity and priority | Ownership expiry is a protocol decision with explicit units and restart behaviour; transport keepalive does not define it | Keepalive and flow control (lease vs keepalive) |
| Acknowledgment levels | gRIBI `RIB_ACK` vs `RIB_AND_FIB_ACK`; OpenConfig AFT is explicitly not a 1:1 view of hardware | An ack names the owner that produced it; forwarding-plane success needs downstream evidence | Ambiguous mutations; Errors (never downgrade unknown to "not applied") |
| Identity | RFC 7921 client identity; gRIBI/gNMI authenticate at the transport | Principal comes from the transport (`auth_context`, X.509 SAN), never from a request field | Interceptors and metadata |
| Reconnect, replay, stale state | Cisco SL-API registration, replay, EOF, heartbeat and purge interval; JET client-name rebind and EOR; Arista EosSdkRpc resync init/complete; GoBGP `WatchEvent` | Reads are revision-bound; a reconnecting client resnapshots instead of stitching pages | Backpressure and admission (revision-bound reads); Deadlines |
| Telemetry separated from mutation | BMP RFC 7854 (one-way monitoring); RFC 7923 subscription requirements; gNMI `Subscribe` | Watch streams are not durable storage and never carry mutation authority | Interceptors and metadata; Testing |
| Traceability | RFC 7922 I2RS traceability (request and event audit fields) | Operation ids and correlation ids are propagated end to end | Interceptors and metadata; Ambiguous mutations |
| Serialising RPC work into a single-writer engine | GoBGP: RPC handlers submit to a serialised management loop; RustyBGP: bounded `mpsc` plus async locks; xBGP: verified hooks at protocol points | RPC threads validate and copy; one owner mutates; queues are bounded and failures are explicit | Backpressure and admission; Testing (fakes that panic on unexpected writes) |
| Throughput claims | Cisco IOS-XRv tutorial run (47,535.2 routes/s C++, 40,976 routes/s Go, tutorial workload only); Orion 1.16 M network updates/s (system-wide unit, not BGP updates); Espresso metrics scoped to controller-to-host programming | Publish a rate only with testbed, route mix, batch size, acknowledgment level and build flags; never rank unlike workloads | Testing |

## Claims the survey rejected

Do not cite these; no public source supports them.

- A 100x-1000x route-update advantage of gNMI or of any protocol over another.
- Vendor or daemon route rates such as 50k-100k (GoBGP), 150k+ (RustyBGP), 200k+ (Cisco, Nokia) or 80k-120k (FRR) updates/s.
- gRIBI mutating BGP Adj-RIB-In or Loc-RIB; it programs abstract AFT/system-RIB state.
- BMP wrapped into gNMI as a mutation path; BMP is one-way monitoring.
- RFC 8431 as an I2RS fast-reroute framework; it is the YANG RIB data model.
- Zero-copy protobuf decoding in RustyBGP.
- B4, Orion, Espresso or Meta papers exposing a public gRPC BGP route-injection API.
- A public `sonic-gribi` daemon; only the FPM to `fpmsyncd` to Redis to `orchagent` path is documented.

## Source ledger

| Key | Artifact | Pin | URL |
|---|---|---|---|
| OC-gRIBI-spec | OpenConfig gRIBI specification v1.0.1 | commit 69e0fb2 | https://github.com/openconfig/gribi/blob/69e0fb2ec18c78b4fdd0110e65d71aa07193dd8a/doc/specification.md |
| OC-gRIBI-proto | gRIBI service protobuf | commit 69e0fb2 | https://github.com/openconfig/gribi/blob/69e0fb2ec18c78b4fdd0110e65d71aa07193dd8a/v1/proto/service/gribi.proto |
| OC-gNMI | gNMI specification and core proto | reference ba9fb52; proto a4e40e6 | https://github.com/openconfig/reference/blob/ba9fb52d1456bb1ec9c58a786fe2f3131ff4af35/rpc/gnmi/gnmi-specification.md |
| OC-AFT | openconfig-aft.yang (context-only) | commit 6039bd7 | https://github.com/openconfig/public/blob/6039bd7b294ad45161da3a258e7f6b4e48b0495c/release/models/aft/openconfig-aft.yang |
| OC-BGP | openconfig-bgp.yang 9.9.1 (context-only) | commit 6039bd7 | https://github.com/openconfig/public/blob/6039bd7b294ad45161da3a258e7f6b4e48b0495c/release/models/bgp/openconfig-bgp.yang |
| OC-BGP-RIB | openconfig-rib-bgp.yang (context-only) | commit 6039bd7 | https://github.com/openconfig/public/blob/6039bd7b294ad45161da3a258e7f6b4e48b0495c/release/models/rib/openconfig-rib-bgp.yang |
| RFC-7921 | I2RS architecture | RFC 7921 | https://www.rfc-editor.org/rfc/rfc7921.html |
| RFC-7922 | I2RS traceability (context-only) | RFC 7922 | https://www.rfc-editor.org/rfc/rfc7922.html |
| RFC-7923 | Subscription to YANG datastores (telemetry-only) | RFC 7923 | https://www.rfc-editor.org/rfc/rfc7923.html |
| RFC-8431 | YANG RIB data model | RFC 8431 | https://www.rfc-editor.org/rfc/rfc8431.html |
| RFC-7854 | BGP Monitoring Protocol (telemetry-only) | RFC 7854 | https://www.rfc-editor.org/rfc/rfc7854.html |
| RFC-4271 | BGP-4 (normative context) | RFC 4271 | https://www.rfc-editor.org/rfc/rfc4271.html |
| GoBGP | API-first BGP engine | commit a1136ee | https://github.com/osrg/gobgp/tree/a1136eedbdeb384e4ff35736c9c32c3c20a960a3 |
| RustyBGP | Tokio/Tonic BGP engine | commit 9eeeebb | https://github.com/osrg/rustybgp/tree/9eeeebbd507b6cb6511a8414cdf968b3cc31d06a |
| Wirtgen-2023-xBGP | xBGP: Faster Innovation in Routing Protocols, NSDI 2023 | paper | https://www.usenix.org/conference/nsdi23/presentation/wirtgen |
| xBGP-Code | xBGP FRR integration | commit 2e6ff4a | https://github.com/pluginized-protocols/xbgp_frr/tree/2e6ff4ad48bf80b6ac80fe5bd784abbdaf09e803 |
| Cisco-SL-API | IOS-XR Service Layer object model | commit 49ab790 | https://github.com/Cisco-Service-Layer/service-layer-objmodel/tree/49ab790cd7937026a090e3065c929b161079e3b0 |
| Cisco-SL-Tutorial | Service Layer APIs with Vagrant IOS-XR (rate figures are tutorial-only) | 2017-09-25 | https://xrdocs.io/cisco-service-layer/tutorials/2017-09-25-using-service-layer-apis-with-vagrant-iosxr |
| Juniper-JET | Junos Extension Toolkit BGP/RIB protos | commit d1ed9bb | https://github.com/Juniper/junos-extension-toolkit/tree/d1ed9bbfbaf3027ac7353958fe6eaff4c0e4bf0e |
| Arista-EosSdkRpc | EosSdkRpc gRPC transport | commit 92dfda3 | https://github.com/aristanetworks/eossdkrpc/tree/92dfda31532bc808db71ebce6527811466316150 |
| Nokia-NDK | SR Linux NDK protobufs | commit 40ab81f | https://github.com/nokia/srlinux-ndk-protobufs/tree/40ab81f4275f6fd8df3e0516234e1824c22dc361 |
| Nokia-gRIBI | SR Linux gRIBI guide | 25-3 | https://documentation.nokia.com/srlinux/25-3/books/gribi/about-gribi.html |
| Yap-2017-Espresso | Taking the Edge off with Espresso, SIGCOMM 2017 (context-only) | DOI 10.1145/3098822.3098854 | https://dblp.org/rec/conf/sigcomm/YapMRPHBHKNJLRR17.html |
| Jain-2013-B4 | B4: Globally-Deployed SDN WAN, SIGCOMM 2013 (context-only) | DOI 10.1145/2486001.2486019 | https://dblp.org/rec/conf/sigcomm/JainKMOPSVWZZZHSV13.html |
| Ferguson-2021-Orion | Orion: Google's SDN Control Plane, NSDI 2021 (context-only) | paper | https://www.usenix.org/system/files/nsdi21-ferguson.pdf |
| Abhashkumar-2021-Facebook-BGP | Running BGP in Data Centers at Scale, NSDI 2021 (context-only) | paper | https://www.usenix.org/conference/nsdi21/presentation/abhashkumar |
| Schlinker-2017-Edge-Fabric | Engineering Egress with Edge Fabric, SIGCOMM 2017 (context-only) | DOI 10.1145/3098822.3098853 | https://www.cs.princeton.edu/courses/archive/fall17/cos561/papers/EdgeFabric17.pdf |
| Meta-FBOSS-ctrl-thrift | FBOSS agent control IDL (Thrift, not gRPC; context-only) | commit 0b5e27f | https://github.com/facebook/fboss/blob/0b5e27f1a28a9edf3aa4b52e88fae1bf8766fc72/fboss/agent/if/ctrl.thrift |
| SONiC | SONiC architecture and fpmsyncd HLD (context-only) | commit 5442b77 | https://github.com/sonic-net/SONiC/tree/5442b77718f5cb21b7373051e8679d10760efd18 |
| SONiC-sonic-swss | sonic-swss route pipeline (context-only) | commit d8d6f89 | https://github.com/sonic-net/sonic-swss/tree/d8d6f89932d1d49a2ed303e2d7300798c4b7ba99 |
| FRRouting | FRR generic gRPC northbound (server-side worker isolation precedent) | commit 261ef54 | https://github.com/FRRouting/frr/tree/261ef54894ee975c77aec65f6b3502bff7d61671 |
| BIRD | BIRD routing daemon (control socket, no gRPC; context-only) | commit 292a46a | https://github.com/CZ-NIC/bird/tree/292a46adc54d6cce1aa6a8146fdc2ada69408632 |
| NAF-Framework | Network Automation Forum reference architecture (context-only) | commit 0fa465e | https://github.com/Network-Automation-Forum/reference/blob/0fa465e716a654b714dd50bc4879033059e92c84/docs/Framework/Framework.md |
| Henderickx-IETF123 | Automation API Software, IETF 123 OPSAREA (context-only) | slides | https://datatracker.ietf.org/meeting/123/materials/slides-123-opsarea-api-automation-software-wim-henderickx/ |
| Page-2021-PRISMA | PRISMA 2020 statement (reporting method) | DOI 10.1136/bmj.n71 | https://www.bmj.com/content/372/bmj.n71 |

Excluded and unverified: `sonic-net/sonic-gribi` (no public anchor found).
