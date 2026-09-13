'use strict';

let fs = require('fs');

if (length(ARGV) < 3) {
	warn('usage: gen.uc <options.json> <nodes.json> <config.json>\n');
	exit(1);
}

let optsRaw = fs.readfile(ARGV[0], 1024 * 1024);
let nodesRaw = fs.readfile(ARGV[1], 32 * 1024 * 1024);
let opts = (optsRaw != null) ? (json(optsRaw) || {}) : {};
let nodes = (nodesRaw != null) ? (json(nodesRaw) || []) : [];

if (type(nodes) != 'array' || !length(nodes)) {
	warn('no nodes available\n');
	exit(2);
}

function arr(v) {
	if (type(v) == 'array')
		return v;
	if (v == null)
		return [];
	return [ v ];
}

function str(v, d) {
	if (v == null || v === '')
		return d;
	return '' + v;
}

function num(v, d) {
	let n = int(v);
	if (n == null || n != n)
		return d;
	return n;
}

function bool(v) {
	return v === true || v === 1 || v == '1' || v == 'true';
}

let mode = str(opts.proxy_mode, 'bypass_blocked');
let selected = str(opts.selected_node, '');

let tagList = [];
for (let i = 0; i < length(nodes); i++)
	push(tagList, nodes[i].tag);

let selOuts = [ 'auto' ];
for (let i = 0; i < length(tagList); i++)
	push(selOuts, tagList[i]);

let def = 'auto';
if (length(selected)) {
	for (let i = 0; i < length(tagList); i++) {
		if (tagList[i] == selected) {
			def = selected;
			break;
		}
	}
}

let outbounds = [];
push(outbounds, { type: 'selector', tag: 'proxy', outbounds: selOuts, default: def, interrupt_exist_connections: true });
push(outbounds, {
	type: 'urltest',
	tag: 'auto',
	outbounds: tagList,
	url: str(opts.urltest_url, 'http://cp.cloudflare.com/generate_204'),
	interval: str(opts.urltest_interval, '3m'),
	tolerance: 50,
	idle_timeout: '30m',
	interrupt_exist_connections: true
});
for (let i = 0; i < length(nodes); i++)
	push(outbounds, nodes[i].outbound);
push(outbounds, { type: 'direct', tag: 'direct' });
push(outbounds, { type: 'block', tag: 'block' });

let rsBase = str(opts.rule_set_base, 'https://raw.githubusercontent.com');

let ruleSets = [];
if (mode == 'bypass_ru') {
	push(ruleSets, {
		type: 'remote', tag: 'geosite-ru', format: 'binary',
		url: rsBase + '/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs',
		download_detour: 'proxy', update_interval: '7d'
	});
	push(ruleSets, {
		type: 'remote', tag: 'geoip-ru', format: 'binary',
		url: rsBase + '/SagerNet/sing-geoip/rule-set/geoip-ru.srs',
		download_detour: 'proxy', update_interval: '7d'
	});
}

if (bool(opts.ad_block)) {
	push(ruleSets, {
		type: 'remote', tag: 'geosite-ads', format: 'binary',
		url: rsBase + '/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs',
		download_detour: 'proxy', update_interval: '7d'
	});
}

if (mode == 'bypass_blocked') {
	let rb = str(opts.blocked_list_base,
		'https://github.com/1andrevich/Re-filter-lists/releases/latest/download');
	push(ruleSets, {
		type: 'remote', tag: 'refilter-domains', format: 'binary',
		url: rb + '/ruleset-domain-refilter_domains.srs',
		download_detour: 'proxy', update_interval: '1d'
	});
	push(ruleSets, {
		type: 'remote', tag: 'refilter-ips', format: 'binary',
		url: rb + '/ruleset-ip-refilter_ipsum.srs',
		download_detour: 'proxy', update_interval: '1d'
	});
}

if (bool(opts.bypass_games)) {
	push(ruleSets, {
		type: 'remote', tag: 'geosite-games', format: 'binary',
		url: rsBase + '/SagerNet/sing-geosite/rule-set/geosite-category-games.srs',
		download_detour: 'proxy', update_interval: '7d'
	});
}

let ddom = arr(opts.custom_direct_domains);
let pdom = arr(opts.custom_proxy_domains);
let dcidr = arr(opts.custom_direct_cidrs);
let pcidr = arr(opts.custom_proxy_cidrs);

let rules = [];
push(rules, { action: 'sniff' });
push(rules, { port: 53, action: 'hijack-dns' });
push(rules, { ip_is_private: true, outbound: 'direct' });

if (length(dcidr))
	push(rules, { ip_cidr: dcidr, outbound: 'direct' });
if (length(ddom))
	push(rules, { domain_suffix: ddom, outbound: 'direct' });

if (bool(opts.bypass_games)) {
	push(rules, { rule_set: [ 'geosite-games' ], outbound: 'direct' });
	push(rules, {
		port_range: [
			'27000:27100', '27015', '27036',
			'3478:3480', '9295:9304',
			'3074', '3544', '4500',
			'5000:5500'
		],
		outbound: 'direct'
	});
}

if (mode == 'bypass_ru')
	push(rules, { rule_set: [ 'geosite-ru', 'geoip-ru' ], outbound: 'direct' });

if (mode == 'bypass_blocked')
	push(rules, { rule_set: [ 'refilter-domains', 'refilter-ips' ], outbound: 'proxy' });

if (bool(opts.ad_block))
	push(rules, { rule_set: [ 'geosite-ads' ], outbound: 'block' });

if (length(pcidr))
	push(rules, { ip_cidr: pcidr, outbound: 'proxy' });
if (length(pdom))
	push(rules, { domain_suffix: pdom, outbound: 'proxy' });

let final = (mode == 'rules_only' || mode == 'bypass_blocked') ? 'direct' : 'proxy';

let dnsServers = [
	{ type: 'udp', tag: 'dns-direct', server: str(opts.dns_direct, '77.88.8.8') },
	{ type: 'udp', tag: 'dns-proxy', server: str(opts.dns_proxy, '1.1.1.1'), detour: 'proxy' }
];

let dnsRules = [];
if (length(ddom))
	push(dnsRules, { domain_suffix: ddom, server: 'dns-direct' });
if (bool(opts.bypass_games))
	push(dnsRules, { rule_set: [ 'geosite-games' ], server: 'dns-direct' });
if (mode == 'bypass_ru')
	push(dnsRules, { rule_set: [ 'geosite-ru' ], server: 'dns-direct' });
if (mode == 'bypass_blocked')
	push(dnsRules, { rule_set: [ 'refilter-domains' ], server: 'dns-proxy' });
if (length(pdom))
	push(dnsRules, { domain_suffix: pdom, server: 'dns-proxy' });
if (bool(opts.clash_api)) {
	push(dnsRules, { clash_mode: 'direct', server: 'dns-direct' });
	push(dnsRules, { clash_mode: 'global', server: 'dns-proxy' });
}

let dnsFinal = (mode == 'rules_only' || mode == 'bypass_blocked') ? 'dns-direct' : 'dns-proxy';

let dns = {
	servers: dnsServers,
	rules: dnsRules,
	final: dnsFinal,
	strategy: str(opts.dns_strategy, 'ipv4_only'),
	independent_cache: true
};

let route = {
	rules: rules,
	rule_set: ruleSets,
	final: final,
	default_domain_resolver: 'dns-direct'
};

let wan = str(opts.wan_interface, '');
if (length(wan))
	route.default_interface = wan;
else
	route.auto_detect_interface = true;

let tun = {
	type: 'tun',
	tag: 'tun-in',
	interface_name: str(opts.tun_interface, 'happwrt0'),
	address: [ '172.19.0.1/30', 'fdfe:dcba:9876::1/126' ],
	mtu: num(opts.tun_mtu, 9000),
	auto_route: true,
	strict_route: false,
	stack: str(opts.tun_stack, 'gvisor'),
	endpoint_independent_nat: true,
	udp_timeout: '5m',
	route_exclude_address: [
		'10.0.0.0/8',
		'192.168.0.0/16',
		'169.254.0.0/16',
		'127.0.0.0/8',
		'::1/128',
		'fc00::/7',
		'fe80::/10'
	]
};

let experimental = {
	cache_file: { enabled: true, path: '/etc/happwrt/cache.db' }
};

if (bool(opts.clash_api)) {
	experimental.clash_api = {
		external_controller: '127.0.0.1:' + ('' + num(opts.clash_api_port, 9090)),
		default_mode: (mode == 'global') ? 'global' : ((mode == 'rules_only') ? 'direct' : 'rule')
	};
}

let config = {
	log: { level: str(opts.log_level, 'warn'), timestamp: true },
	dns: dns,
	inbounds: [ tun ],
	outbounds: outbounds,
	route: route,
	experimental: experimental
};

fs.writefile(ARGV[2], sprintf('%.J', config));
exit(0);
