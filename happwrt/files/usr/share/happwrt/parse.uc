'use strict';

let fs = require('fs');

function pct(s) {
	let out = '';
	let n = length(s);

	for (let i = 0; i < n; i++) {
		let c = substr(s, i, 1);

		if (c == '%' && i + 2 < n) {
			let v = int(substr(s, i + 1, 2), 16);
			if (v == v && v >= 0) {
				out += chr(v);
				i += 2;
				continue;
			}
		}

		out += c;
	}

	return out;
}

function parse_query(q) {
	let res = {};
	if (!q)
		return res;

	let parts = split(q, '&');
	for (let i = 0; i < length(parts); i++) {
		let p = parts[i];
		if (!length(p))
			continue;

		let eq = index(p, '=');
		let k = '', v = '';

		if (eq < 0) {
			k = p;
			v = '';
		} else {
			k = substr(p, 0, eq);
			v = substr(p, eq + 1);
		}

		res[pct(k)] = pct(v);
	}

	return res;
}

function num(v, def) {
	let n = int(v);
	if (n == null || n != n)
		return def;
	return n;
}

function supported_net(net) {
	if (net == '' || net == 'tcp' || net == 'ws' || net == 'grpc' ||
	    net == 'http' || net == 'h2' || net == 'quic' || net == 'httpupgrade')
		return true;
	return false;
}

function split_hostport(s) {
	let host = '', port = '';

	if (substr(s, 0, 1) == '[') {
		let e = index(s, ']');
		if (e < 0)
			return null;
		host = substr(s, 1, e - 1);
		let rest = substr(s, e + 1);
		if (substr(rest, 0, 1) == ':')
			rest = substr(rest, 1);
		port = rest;
	} else {
		let c = rindex(s, ':');
		if (c < 0) {
			host = s;
		} else {
			host = substr(s, 0, c);
			port = substr(s, c + 1);
		}
	}

	host = trim(host);
	port = trim(port);

	if (!length(host))
		return null;

	let p = int(port);
	if (p != p || p < 1 || p > 65535)
		return null;

	return { host: host, port: p };
}

function b64norm(s) {
	let out = '';
	let n = length(s);

	for (let i = 0; i < n; i++) {
		let c = substr(s, i, 1);

		if (c == ' ' || c == '\n' || c == '\r' || c == '\t')
			continue;

		if (c == '-')
			c = '+';
		else if (c == '_')
			c = '/';

		out += c;
	}

	while (length(out) % 4)
		out += '=';

	return out;
}

function try_b64(s) {
	if (!s || !length(s))
		return null;

	let d = b64dec(b64norm(s));
	if (d == null || !length(d))
		return null;
	return d;
}

function decode_subscription(body) {
	let b = trim(body);
	if (!length(b))
		return '';

	if (index(b, '://') >= 0)
		return b;

	let d = try_b64(b);
	if (d != null && index(d, '://') >= 0)
		return d;

	return b;
}

function parse_link(uri) {
	let sep = index(uri, '://');
	if (sep < 0)
		return null;

	let scheme = lc(substr(uri, 0, sep));
	let rest = substr(uri, sep + 3);
	let name = '';

	let h = index(rest, '#');
	if (h >= 0) {
		name = pct(substr(rest, h + 1));
		rest = substr(rest, 0, h);
	}

	let query = {};
	let q = index(rest, '?');
	if (q >= 0) {
		query = parse_query(substr(rest, q + 1));
		rest = substr(rest, 0, q);
	}

	return { scheme: scheme, rest: rest, query: query, name: name };
}

function build_tls(q, host) {
	let sec = q.security || '';
	if (sec != 'tls' && sec != 'reality' && sec != 'xtls')
		return null;

	let tls = { enabled: true };
	let sni = q.sni || q.peer || q.host || '';
	if (length(sni))
		tls.server_name = sni;

	if (q.alpn)
		tls.alpn = split(q.alpn, ',');

	if (q.fp)
		tls.utls = { enabled: true, fingerprint: q.fp };

	if (q.allowInsecure == '1' || q.insecure == '1' || q.allow_insecure == '1')
		tls.insecure = true;

	if (sec == 'reality' || q.pbk) {
		if (!q.fp)
			tls.utls = { enabled: true, fingerprint: 'chrome' };
		tls.reality = { enabled: true, public_key: q.pbk || '', short_id: q.sid || '' };
	}

	return tls;
}

function build_transport(q) {
	let net = q.type || q.net || '';

	if (net == 'ws') {
		let t = { type: 'ws', path: q.path || '/' };
		if (length(q.host || '')) {
			let headers = {};
			headers['Host'] = q.host;
			t.headers = headers;
		}
		return t;
	}

	if (net == 'grpc')
		return { type: 'grpc', service_name: q.serviceName || q.service_name || q.path || '' };

	if (net == 'http' || net == 'h2') {
		let t = { type: 'http', path: q.path || '/' };
		if (q.host)
			t.host = split(q.host, ',');
		return t;
	}

	if (net == 'quic')
		return { type: 'quic' };

	if (net == 'httpupgrade')
		return { type: 'httpupgrade', path: q.path || '/', host: q.host || '' };

	return null;
}

function parse_vless(l) {
	let at = rindex(l.rest, '@');
	if (at < 0)
		return null;

	let uuid = pct(substr(l.rest, 0, at));
	let hp = split_hostport(substr(l.rest, at + 1));
	if (hp == null || !length(uuid))
		return null;

	if (!supported_net(l.query.type || l.query.net || ''))
		return null;

	let out = { type: 'vless', server: hp.host, server_port: hp.port, uuid: uuid };

	if (l.query.flow)
		out.flow = l.query.flow;
	if (l.query.packetEncoding)
		out.packet_encoding = l.query.packetEncoding;

	let tls = build_tls(l.query, hp.host);
	if (tls)
		out.tls = tls;

	let tr = build_transport(l.query);
	if (tr)
		out.transport = tr;

	return out;
}

function parse_vmess(l) {
	let raw = try_b64(l.rest);
	if (raw == null)
		return null;

	let j = json(raw);
	if (j == null || type(j) != 'object')
		return null;

	let add = j.add || '';
	let port = num(j.port, -1);
	if (!length(add) || port < 1)
		return null;

	let out = {
		type: 'vmess',
		server: add,
		server_port: port,
		uuid: j.id || '',
		security: j.scy || j.security || 'auto',
		alter_id: num(j.aid, 0)
	};

	if (j.tls == 'tls') {
		let tls = { enabled: true, server_name: j.sni || j.host || add };
		if (j.alpn)
			tls.alpn = split(j.alpn, ',');
		if (j.fp)
			tls.utls = { enabled: true, fingerprint: j.fp };
		out.tls = tls;
	}

	let net = j.net || '';
	if (!supported_net(net))
		return null;

	if (net == 'ws') {
		let t = { type: 'ws', path: j.path || '/' };
		if (j.host) {
			let headers = {};
			headers['Host'] = j.host;
			t.headers = headers;
		}
		out.transport = t;
	} else if (net == 'grpc') {
		out.transport = { type: 'grpc', service_name: j.path || '' };
	} else if (net == 'h2' || net == 'http') {
		let t = { type: 'http', path: j.path || '/' };
		if (j.host)
			t.host = split(j.host, ',');
		out.transport = t;
	} else if (net == 'quic') {
		out.transport = { type: 'quic' };
	} else if (net == 'httpupgrade') {
		out.transport = { type: 'httpupgrade', path: j.path || '/', host: j.host || '' };
	}

	if (j.ps)
		l.name = j.ps;

	return out;
}

function parse_trojan(l) {
	let at = rindex(l.rest, '@');
	if (at < 0)
		return null;

	let pass = pct(substr(l.rest, 0, at));
	let hp = split_hostport(substr(l.rest, at + 1));
	if (hp == null)
		return null;

	if (!supported_net(l.query.type || l.query.net || ''))
		return null;

	let q = l.query;
	let out = { type: 'trojan', server: hp.host, server_port: hp.port, password: pass };

	let tls = { enabled: true, server_name: q.sni || q.peer || hp.host };
	if (q.alpn)
		tls.alpn = split(q.alpn, ',');
	if (q.fp)
		tls.utls = { enabled: true, fingerprint: q.fp };
	if (q.allowInsecure == '1' || q.insecure == '1')
		tls.insecure = true;
	out.tls = tls;

	let tr = build_transport(q);
	if (tr)
		out.transport = tr;

	return out;
}

function parse_ss(l) {
	let rest = l.rest;
	let q = l.query;
	let method = '', password = '', host = '', port = 0;

	let at = rindex(rest, '@');
	if (at >= 0) {
		let userinfo = substr(rest, 0, at);
		let dec = try_b64(userinfo);

		if (dec != null && index(dec, ':') >= 0) {
			let c = index(dec, ':');
			method = substr(dec, 0, c);
			password = substr(dec, c + 1);
		} else {
			let ui = pct(userinfo);
			let c = index(ui, ':');
			if (c < 0)
				return null;
			method = substr(ui, 0, c);
			password = substr(ui, c + 1);
		}

		let hp = split_hostport(substr(rest, at + 1));
		if (hp == null)
			return null;
		host = hp.host;
		port = hp.port;
	} else {
		let dec = try_b64(rest);
		if (dec == null)
			return null;

		let at2 = rindex(dec, '@');
		if (at2 < 0)
			return null;

		let cred = substr(dec, 0, at2);
		let c = index(cred, ':');
		if (c < 0)
			return null;

		method = substr(cred, 0, c);
		password = substr(cred, c + 1);

		let hp = split_hostport(substr(dec, at2 + 1));
		if (hp == null)
			return null;
		host = hp.host;
		port = hp.port;
	}

	if (!length(method))
		return null;

	let out = { type: 'shadowsocks', server: host, server_port: port, method: method, password: password };

	if (q.plugin) {
		let semi = index(q.plugin, ';');
		if (semi >= 0) {
			out.plugin = substr(q.plugin, 0, semi);
			out.plugin_opts = substr(q.plugin, semi + 1);
		} else {
			out.plugin = q.plugin;
		}
	}

	return out;
}

function parse_hy2(l) {
	let at = rindex(l.rest, '@');
	if (at < 0)
		return null;

	let pass = pct(substr(l.rest, 0, at));
	let hp = split_hostport(substr(l.rest, at + 1));
	if (hp == null)
		return null;

	let q = l.query;
	let out = { type: 'hysteria2', server: hp.host, server_port: hp.port, password: pass };

	if (q.obfs) {
		let ob = { type: q.obfs };
		if (q['obfs-password'])
			ob.password = q['obfs-password'];
		out.obfs = ob;
	}

	let tls = { enabled: true, server_name: q.sni || hp.host };
	if (q.alpn)
		tls.alpn = split(q.alpn, ',');
	if (q.insecure == '1' || q.allowInsecure == '1')
		tls.insecure = true;
	out.tls = tls;

	return out;
}

function parse_tuic(l) {
	let at = rindex(l.rest, '@');
	if (at < 0)
		return null;

	let cred = substr(l.rest, 0, at);
	let c = index(cred, ':');
	let uuid = '', pass = '';

	if (c >= 0) {
		uuid = pct(substr(cred, 0, c));
		pass = pct(substr(cred, c + 1));
	} else {
		uuid = pct(cred);
	}

	let hp = split_hostport(substr(l.rest, at + 1));
	if (hp == null)
		return null;

	let q = l.query;
	let out = {
		type: 'tuic',
		server: hp.host,
		server_port: hp.port,
		uuid: uuid,
		password: pass,
		congestion_control: q.congestion_control || 'cubic',
		udp_relay_mode: q.udp_relay_mode || 'native'
	};

	let tls = { enabled: true, server_name: q.sni || hp.host };
	if (q.alpn)
		tls.alpn = split(q.alpn, ',');
	else
		tls.alpn = [ 'h3' ];
	if (q.allow_insecure == '1' || q.insecure == '1')
		tls.insecure = true;
	out.tls = tls;

	return out;
}

function parse_anytls(l) {
	let at = rindex(l.rest, '@');
	if (at < 0)
		return null;

	let pass = pct(substr(l.rest, 0, at));
	let hp = split_hostport(substr(l.rest, at + 1));
	if (hp == null)
		return null;

	let q = l.query;
	let out = { type: 'anytls', server: hp.host, server_port: hp.port, password: pass };

	let tls = { enabled: true, server_name: q.sni || hp.host };
	if (q.insecure == '1' || q.allow_insecure == '1')
		tls.insecure = true;
	out.tls = tls;

	return out;
}

function parse_one(line) {
	let l = parse_link(line);
	if (l == null)
		return null;

	let out = null;

	if (l.scheme == 'vless')
		out = parse_vless(l);
	else if (l.scheme == 'vmess')
		out = parse_vmess(l);
	else if (l.scheme == 'trojan')
		out = parse_trojan(l);
	else if (l.scheme == 'ss')
		out = parse_ss(l);
	else if (l.scheme == 'hysteria2' || l.scheme == 'hy2')
		out = parse_hy2(l);
	else if (l.scheme == 'tuic')
		out = parse_tuic(l);
	else if (l.scheme == 'anytls')
		out = parse_anytls(l);

	if (out == null)
		return null;

	return { name: l.name || (out.server + ':' + out.server_port), out: out };
}

if (length(ARGV) < 2) {
	warn('usage: parse.uc <input> <output>\n');
	exit(1);
}

let body = fs.readfile(ARGV[0], 16 * 1024 * 1024);
if (body == null) {
	warn('cannot read ' + ARGV[0] + '\n');
	exit(1);
}

let content = decode_subscription(body);
let lines = split(content, '\n');
let nodes = [];
let seq = 0;

for (let i = 0; i < length(lines); i++) {
	let line = trim(lines[i]);
	if (!length(line))
		continue;
	if (substr(line, 0, 1) == '#')
		continue;
	if (index(line, '://') < 0)
		continue;

	let r = parse_one(line);
	if (r == null)
		continue;

	seq++;
	let tag = 'node-' + seq;
	r.out.tag = tag;

	push(nodes, { tag: tag, name: r.name, type: r.out.type, server: r.out.server, server_port: r.out.server_port, outbound: r.out });
}

if (!length(nodes)) {
	warn('no supported nodes found\n');
	exit(2);
}

fs.writefile(ARGV[1], sprintf('%J', nodes));
exit(0);
