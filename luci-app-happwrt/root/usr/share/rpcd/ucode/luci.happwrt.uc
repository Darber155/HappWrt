'use strict';

import { readfile, stat, popen } from 'fs';
import { cursor } from 'uci';

function read_json(path) {
	let s;

	try {
		s = readfile(path, 32 * 1024 * 1024);
	} catch (e) {
		return null;
	}

	if (s == null)
		return null;

	return json(s);
}

function is_running() {
	let p, out;

	try {
		p = popen([ 'pidof', 'sing-box' ], 'r');
	} catch (e) {
		return false;
	}

	if (p == null)
		return false;

	out = p.read('all') || '';
	p.close();

	return length(trim(out)) > 0;
}

function run(cmd) {
	let p;

	try {
		p = popen(cmd, 'r');
	} catch (e) {
		return { code: -1, output: '' };
	}

	if (p == null)
		return { code: -1, output: '' };

	let out = p.read('all') || '';
	let code = p.close();

	return { code: (code == null ? 0 : code), output: out };
}

function status() {
	let uci = cursor();
	let nodes = read_json('/etc/happwrt/nodes.json') || [];
	let list = [];

	for (let i = 0; i < length(nodes); i++) {
		push(list, {
			tag: nodes[i].tag,
			name: nodes[i].name,
			type: nodes[i].type,
			server: nodes[i].server
		});
	}

	let st = {
		running: is_running(),
		enabled: uci.get('happwrt', 'main', 'enabled') == '1',
		subscription_url: uci.get('happwrt', 'main', 'subscription_url') || '',
		proxy_mode: uci.get('happwrt', 'main', 'proxy_mode') || 'bypass_ru',
		selected_node: uci.get('happwrt', 'main', 'selected_node') || '',
		node_count: length(list),
		nodes: list
	};

	try {
		let s = stat('/etc/happwrt/nodes.json');
		if (s != null && s.mtime != null)
			st.updated = s.mtime;
	} catch (e) {}

	return st;
}

const methods = {
	status: {
		call: function () {
			return status();
		}
	},
	nodes: {
		call: function () {
			return status().nodes;
		}
	},
	update: {
		call: function () {
			return run('/usr/bin/happwrt update');
		}
	},
	reload: {
		call: function () {
			return run('/usr/bin/happwrt generate');
		}
	}
};

return { 'luci.happwrt': methods };
