'use strict';

let uci = require('uci');
let cursor = uci.cursor();

function get(name, def) {
	let v = cursor.get('happwrt', 'main', name);
	if (v == null || v === '')
		return def;
	return '' + v;
}

function get_list(name) {
	let v = cursor.get('happwrt', 'main', name);
	let out = [];

	if (v == null)
		return out;

	if (type(v) == 'array') {
		for (let i = 0; i < length(v); i++) {
			let s = trim('' + v[i]);
			if (length(s))
				push(out, s);
		}
	} else {
		let s = trim('' + v);
		if (length(s))
			push(out, s);
	}

	return out;
}

let o = {
	enabled: get('enabled', '0') == '1',
	subscription_url: get('subscription_url', ''),
	update_interval: get('update_interval', '24'),
	proxy_mode: get('proxy_mode', 'bypass_blocked'),
	selected_node: get('selected_node', ''),
	dns_direct: get('dns_direct', '77.88.8.8'),
	dns_proxy: get('dns_proxy', '1.1.1.1'),
	dns_strategy: get('dns_strategy', 'ipv4_only'),
	tun_stack: get('tun_stack', 'system'),
	tun_mtu: get('tun_mtu', '9000'),
	tun_interface: get('tun_interface', 'happwrt0'),
	wan_interface: get('wan_interface', ''),
	log_level: get('log_level', 'warn'),
	clash_api: get('clash_api', '1') == '1',
	clash_api_port: get('clash_api_port', '9090'),
	urltest_url: get('urltest_url', 'http://cp.cloudflare.com/generate_204'),
	urltest_interval: get('urltest_interval', '3m'),
	ad_block: get('ad_block', '0') == '1',
	bypass_games: get('bypass_games', '1') == '1',
	rule_set_base: get('rule_set_base', 'https://raw.githubusercontent.com'),
	custom_direct_domains: get_list('custom_direct_domains'),
	custom_proxy_domains: get_list('custom_proxy_domains'),
	custom_direct_cidrs: get_list('custom_direct_cidrs'),
	custom_proxy_cidrs: get_list('custom_proxy_cidrs')
};

print(sprintf('%J', o));
