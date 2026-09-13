"use strict";

let fs = require("fs");

let root = getenv("HAPPWRT_ROOT");
let ucode = getenv("UCODE") || "ucode";
let gen = root + "/happwrt/files/usr/share/happwrt/gen.uc";
let nodes = root + "/tests/fixtures/nodes.json";
let tmp = "/tmp/happwrt-gen-test";

try { fs.mkdir(tmp); } catch (e) {}

let failures = 0;

function check(cond, msg) {
	if (!cond) {
		print("FAIL: " + msg + "\n");
		failures++;
	}
}

function generate(mode, opts) {
	opts.proxy_mode = mode;
	fs.writefile(tmp + "/opts.json", sprintf("%J", opts));

	let p = fs.popen([ ucode, gen, tmp + "/opts.json", nodes, tmp + "/config-" + mode + ".json" ], "r");
	let output = p.read("all");
	let code = p.close();

	return { code: code, output: output, cfg: json(fs.readfile(tmp + "/config-" + mode + ".json")) };
}

let baseOpts = {
	enabled: true,
	selected_node: "node-2",
	ad_block: true,
	clash_api: true,
	clash_api_port: 9090,
	tun_stack: "system",
	tun_mtu: 9000,
	dns_strategy: "ipv4_only",
	custom_direct_domains: [ "example.org" ],
	custom_proxy_domains: [ "example.net" ],
	custom_proxy_cidrs: [ "1.2.3.0/24" ],
	custom_direct_cidrs: []
};

let res = generate("bypass_ru", baseOpts);
check(res.code == 0, "gen bypass_ru exit 0 (got " + res.code + " " + res.output + ")");

let cfg = res.cfg || {};
check(cfg.route != null, "route present");
check(cfg.route.final == "proxy", "bypass_ru final proxy");
check(cfg.inbounds != null && cfg.inbounds[0].type == "tun", "tun inbound");
check(cfg.outbounds != null && cfg.outbounds[0].type == "selector", "selector first");
check(cfg.outbounds[0].default == "node-2", "selector default node-2");

let hasDirect = false;
for (let i = 0; i < length(cfg.outbounds); i++)
	if (cfg.outbounds[i].type == "direct")
		hasDirect = true;
check(hasDirect, "direct outbound present");

check(cfg.route.default_domain_resolver == "dns-direct", "default_domain_resolver");

let hasHijack = false, hasRu = false, hasAds = false, hasProxyDomain = false;
for (let i = 0; i < length(cfg.route.rules); i++) {
	let rr = cfg.route.rules[i];

	if (rr.action == "hijack-dns")
		hasHijack = true;
	if (rr.outbound == "direct" && rr.rule_set != null)
		hasRu = true;
	if (rr.outbound == "block" && rr.rule_set != null)
		hasAds = true;
	if (rr.outbound == "proxy" && rr.domain_suffix != null)
		hasProxyDomain = true;
}

check(hasHijack, "hijack-dns rule present");
check(hasRu, "RU direct rule present");
check(hasAds, "ads block rule present");
check(hasProxyDomain, "custom proxy domain rule present");

let hasRuSet = false, hasAdsSet = false;
for (let i = 0; i < length(cfg.route.rule_set); i++) {
	if (cfg.route.rule_set[i].tag == "geosite-ru")
		hasRuSet = true;
	if (cfg.route.rule_set[i].tag == "geosite-ads")
		hasAdsSet = true;
}
check(hasRuSet, "geosite-ru rule-set declared");
check(hasAdsSet, "geosite-ads rule-set declared");

let resGlobal = generate("global", baseOpts);
check(resGlobal.code == 0, "gen global exit 0");
check(resGlobal.cfg.route.final == "proxy", "global final proxy");
let globalHasRuRule = false;
for (let i = 0; i < length(resGlobal.cfg.route.rules); i++)
	if (resGlobal.cfg.route.rules[i].rule_set != null && resGlobal.cfg.route.rules[i].outbound == "direct")
		globalHasRuRule = true;
check(!globalHasRuRule, "global has no RU direct rule");

let resRules = generate("rules_only", baseOpts);
check(resRules.code == 0, "gen rules_only exit 0");
check(resRules.cfg.route.final == "direct", "rules_only final direct");

let resBlocked = generate("bypass_blocked", baseOpts);
check(resBlocked.code == 0, "gen bypass_blocked exit 0");
check(resBlocked.cfg.route.final == "direct", "bypass_blocked final direct");
check(resBlocked.cfg.dns.final == "dns-direct", "bypass_blocked dns final direct");
let hasRefilter = false, hasBlockedRule = false;
for (let i = 0; i < length(resBlocked.cfg.route.rule_set); i++)
	if (resBlocked.cfg.route.rule_set[i].tag == "refilter-domains" &&
	    resBlocked.cfg.route.rule_set[i].download_detour == "proxy")
		hasRefilter = true;
for (let i = 0; i < length(resBlocked.cfg.route.rules); i++)
	if (resBlocked.cfg.route.rules[i].rule_set != null &&
	    resBlocked.cfg.route.rules[i].outbound == "proxy")
		hasBlockedRule = true;
check(hasRefilter, "refilter rule-set declared via proxy");
check(hasBlockedRule, "blocked resources routed via proxy");

baseOpts.bypass_games = true;
let resGames = generate("bypass_blocked", baseOpts);
check(resGames.code == 0, "gen bypass_games exit 0");
let hasGameSet = false, hasGameDirect = false, hasGamePorts = false;
for (let i = 0; i < length(resGames.cfg.route.rule_set); i++)
	if (resGames.cfg.route.rule_set[i].tag == "geosite-games")
		hasGameSet = true;
for (let i = 0; i < length(resGames.cfg.route.rules); i++) {
	let rr = resGames.cfg.route.rules[i];
	if (rr.rule_set != null) {
		let hasGame = false;
		for (let k = 0; k < length(rr.rule_set); k++)
			if (rr.rule_set[k] == "geosite-games")
				hasGame = true;
		if (hasGame && rr.outbound == "direct")
			hasGameDirect = true;
	}
	if (rr.port_range != null && rr.outbound == "direct")
		hasGamePorts = true;
}
check(hasGameSet, "geosite-games rule-set declared");
check(hasGameDirect, "game domains routed direct");
check(hasGamePorts, "game ports routed direct");

if (failures > 0) {
	print(failures + " gen test(s) failed\n");
	exit(1);
}

print("gen: OK\n");
exit(0);
