"use strict";

let fs = require("fs");

let root = getenv("HAPPWRT_ROOT");
let ucode = getenv("UCODE") || "ucode";
let parse = root + "/happwrt/files/usr/share/happwrt/parse.uc";
let tmp = "/tmp/happwrt-parse-test";

try { fs.mkdir(tmp); } catch (e) {}

let failures = 0;

function check(cond, msg) {
	if (!cond) {
		print("FAIL: " + msg + "\n");
		failures++;
	}
}

function run(infile, outfile) {
	let p = fs.popen([ ucode, parse, infile, outfile ], "r");
	let output = p.read("all");
	let code = p.close();
	return { output: output, code: code };
}

let r = run(root + "/tests/fixtures/sample.txt", tmp + "/nodes.txt.json");
check(r.code == 0, "plain parse exit 0 (got " + r.code + " " + r.output + ")");

let rb = run(root + "/tests/fixtures/sample.b64", tmp + "/nodes.b64.json");
check(rb.code == 0, "base64 parse exit 0 (got " + rb.code + ")");

let nodes = json(fs.readfile(tmp + "/nodes.txt.json")) || [];
let nodesB = json(fs.readfile(tmp + "/nodes.b64.json")) || [];

check(length(nodes) == 7, "plain node count 7 (got " + length(nodes) + ")");
check(length(nodesB) == 7, "base64 node count 7 (got " + length(nodesB) + ")");

let byName = {};
for (let i = 0; i < length(nodes); i++)
	byName[nodes[i].name] = nodes[i];

let vless = byName["NL-1"];
check(vless != null, "vless node found");
if (vless != null) {
	check(vless.type == "vless", "vless type");
	check(vless.server == "example.com", "vless server");
	check(vless.server_port == 443, "vless port");
	check(vless.outbound.uuid == "11111111-1111-1111-1111-111111111111", "vless uuid");
	check(vless.outbound.tls != null && vless.outbound.tls.enabled == true, "vless tls");
	check(vless.outbound.transport != null && vless.outbound.transport.type == "ws", "vless ws transport");
	check(vless.outbound.transport.path == "/ws", "vless ws path");
}

let vmess = byName["DE-WM"];
check(vmess != null, "vmess node found");
if (vmess != null) {
	check(vmess.type == "vmess", "vmess type");
	check(vmess.server == "de.example.com", "vmess server");
	check(vmess.server_port == 8080, "vmess port");
	check(vmess.outbound.uuid == "22222222-2222-2222-2222-222222222222", "vmess uuid");
	check(vmess.outbound.transport != null && vmess.outbound.transport.type == "ws", "vmess ws");
}

let trojan = byName["TR-1"];
check(trojan != null, "trojan node found");
if (trojan != null) {
	check(trojan.outbound.password == "secretpass", "trojan password");
	check(trojan.outbound.tls != null && trojan.outbound.tls.enabled == true, "trojan tls");
}

let ss = byName["SS-1"];
check(ss != null, "ss node found");
if (ss != null) {
	check(ss.outbound.method == "aes-256-gcm", "ss method");
	check(ss.outbound.password == "password", "ss password");
	check(ss.server_port == 8388, "ss port");
}

let hy = byName["HY2-1"];
check(hy != null, "hy2 node found");
if (hy != null) {
	check(hy.outbound.tls != null && hy.outbound.tls.insecure == true, "hy2 insecure");
}

let tuic = byName["TUIC-1"];
check(tuic != null, "tuic node found");
if (tuic != null) {
	check(tuic.outbound.uuid == "33333333-3333-3333-3333-333333333333", "tuic uuid");
	check(tuic.outbound.password == "tpass", "tuic password");
	check(tuic.outbound.congestion_control == "bbr", "tuic cc");
}

let any = byName["ANY-1"];
check(any != null, "anytls node found");

if (failures > 0) {
	print(failures + " parse test(s) failed\n");
	exit(1);
}

print("parse: OK\n");
exit(0);
