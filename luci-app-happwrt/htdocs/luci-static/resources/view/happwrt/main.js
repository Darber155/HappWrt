'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require ui';
'require dom';

var callStatus = rpc.declare({
	object: 'luci.happwrt',
	method: 'status',
	expect: {}
});

var callUpdate = rpc.declare({
	object: 'luci.happwrt',
	method: 'update',
	expect: {}
});

var callDelay = rpc.declare({
	object: 'luci.happwrt',
	method: 'test_delay',
	params: [ 'tag' ],
	expect: {}
});

var callSelect = rpc.declare({
	object: 'luci.happwrt',
	method: 'select_node',
	params: [ 'tag' ],
	expect: {}
});

var callSetEnabled = rpc.declare({
	object: 'luci.happwrt',
	method: 'set_enabled',
	params: [ 'enabled' ],
	expect: {}
});

var COUNTRY = {
	'netherlands': 'NL', 'nl': 'NL', 'holland': 'NL',
	'germany': 'DE', 'de': 'DE', 'deutschland': 'DE',
	'united states': 'US', 'usa': 'US', 'us': 'US', 'america': 'US',
	'united kingdom': 'GB', 'uk': 'GB', 'gb': 'GB', 'britain': 'GB', 'england': 'GB',
	'finland': 'FI', 'fi': 'FI', 'sweden': 'SE', 'se': 'SE', 'norway': 'NO', 'no': 'NO',
	'denmark': 'DK', 'dk': 'DK', 'france': 'FR', 'fr': 'FR', 'poland': 'PL', 'pl': 'PL',
	'turkey': 'TR', 'tr': 'TR', 'japan': 'JP', 'jp': 'JP', 'singapore': 'SG', 'sg': 'SG',
	'canada': 'CA', 'ca': 'CA', 'austria': 'AT', 'at': 'AT', 'switzerland': 'CH', 'ch': 'CH',
	'czech': 'CZ', 'cz': 'CZ', 'latvia': 'LV', 'lv': 'LV', 'lithuania': 'LT', 'lt': 'LT',
	'estonia': 'EE', 'ee': 'EE', 'romania': 'RO', 'ro': 'RO', 'bulgaria': 'BG', 'bg': 'BG',
	'hungary': 'HU', 'hu': 'HU', 'italy': 'IT', 'it': 'IT', 'spain': 'ES', 'es': 'ES',
	'ireland': 'IE', 'ie': 'IE', 'hong kong': 'HK', 'hk': 'HK', 'korea': 'KR', 'kr': 'KR',
	'india': 'IN', 'in': 'IN', 'australia': 'AU', 'au': 'AU', 'israel': 'IL', 'il': 'IL',
	'armenia': 'AM', 'am': 'AM', 'kazakhstan': 'KZ', 'kz': 'KZ', 'ukraine': 'UA', 'ua': 'UA',
	'russia': 'RU', 'ru': 'RU', 'moldova': 'MD', 'md': 'MD', 'serbia': 'RS', 'rs': 'RS',
	'belgium': 'BE', 'be': 'BE', 'portugal': 'PT', 'pt': 'PT', 'greece': 'GR', 'gr': 'GR',
	'croatia': 'HR', 'hr': 'HR', 'slovakia': 'SK', 'sk': 'SK', 'slovenia': 'SI', 'si': 'SI'
};

function isoToFlag(cc) {
	if (!cc || cc.length != 2)
		return '';
	return String.fromCodePoint(0x1F1E6 + cc.charCodeAt(0) - 65,
		0x1F1E6 + cc.charCodeAt(1) - 65);
}

function flagFor(name) {
	name = name || '';

	if (/[\u{1F1E6}-\u{1F1FF}]/u.test(name))
		return '';

	var m = name.match(/(^|[^A-Za-z])([A-Z]{2})([^A-Za-z]|$)/);
	if (m && COUNTRY[(m[2] || '').toLowerCase()])
		return isoToFlag(COUNTRY[m[2].toLowerCase()]);

	var lower = name.toLowerCase();
	var keys = Object.keys(COUNTRY).sort(function (a, b) {
		return b.length - a.length;
	});
	for (var i = 0; i < keys.length; i++) {
		if (keys[i].length >= 3 && lower.indexOf(keys[i]) >= 0)
			return isoToFlag(COUNTRY[keys[i]]);
	}

	return '';
}

function latencyText(ms) {
	if (ms == null || ms !== ms)
		return 'n/a';
	if (ms < 0)
		return _('timeout');
	return ms + ' ms';
}

function latencyColor(ms) {
	if (ms == null || ms !== ms || ms < 0)
		return '#999';
	if (ms < 200)
		return '#2e7d32';
	if (ms < 500)
		return '#f9a825';
	return '#c62828';
}

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('happwrt'),
			callStatus()
		]);
	},

	rowStyle: function (selected) {
		return 'display:flex;align-items:center;gap:10px;padding:9px 10px;' +
			'border-bottom:1px solid var(--border-color,#eee);cursor:pointer;' +
			(selected ? 'background:rgba(46,125,50,0.10);' : '');
	},

	serverRow: function (opts) {
		var self = this;
		var cellId = 'happwrt-delay-' + (opts.testTag || 'auto');

		var children = [
			E('span', { style: 'font-size:20px;width:26px;text-align:center' },
				opts.flag != null ? opts.flag : flagFor(opts.name)),
			E('span', {
				style: 'flex:1;min-width:120px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap'
			}, opts.name),
			opts.type ? E('span', { class: 'ifacebadge' }, opts.type) : '',
			opts.server ? E('span', {
				class: 'ifacebadge',
				style: 'opacity:0.7;max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap'
			}, opts.server) : '',
			E('span', {
				class: 'ifacebadge',
				id: cellId,
				style: 'min-width:64px;text-align:center'
			}, '-'),
			E('button', {
				class: 'cbi-button cbi-button-action',
				click: function (ev) {
					ev.stopPropagation();
					self.testOne(opts.testTag || 'auto', cellId);
				}
			}, _('ping')),
			opts.selected
				? E('span', {
					class: 'ifacebadge',
					style: 'background:#2e7d32;color:#fff'
				}, _('selected'))
				: ''
		];

		return E('div', {
			style: this.rowStyle(opts.selected),
			click: function () { self.select(opts.selectTag); }
		}, children);
	},

	renderStatus: function (st) {
		var self = this;
		var running = !!st.running;

		return E('div', { class: 'cbi-section' }, [
			E('div', {
				style: 'display:flex;align-items:center;gap:12px;flex-wrap:wrap;padding:6px 0'
			}, [
				E('span', {
					class: 'ifacebadge',
					style: 'background:' + (st.enabled ? '#2e7d32' : '#9e9e9e') + ';color:#fff'
				}, st.enabled ? _('Enabled') : _('Disabled')),
				E('span', {
					class: 'ifacebadge',
					style: 'background:' + (running ? '#1565c0' : '#9e9e9e') + ';color:#fff'
				}, running ? _('running') : _('stopped')),
				E('span', { class: 'ifacebadge' },
					_('Mode') + ': ' + (st.proxy_mode || '')),
				E('span', { class: 'ifacebadge' },
					_('Servers') + ': ' + (st.node_count || 0)),
				E('span', { style: 'flex:1' }),
				E('button', {
					class: 'cbi-button ' + (st.enabled ? 'cbi-button-reset' : 'cbi-button-apply'),
					click: function () { self.toggleEnabled(!st.enabled); }
				}, st.enabled ? _('Disable') : _('Enable')),
				E('button', {
					class: 'cbi-button cbi-button-action',
					click: function () { self.doUpdate(); }
				}, _('Update subscription'))
			]),
			E('div', {
				style: 'font-size:12px;opacity:0.7;padding:2px 0'
			}, st.subscription_url || _('No subscription URL'))
		]);
	},

	renderServers: function (st) {
		var self = this;
		var nodes = st.nodes || [];
		var selected = st.selected_node || '';
		var list = E('div', {});

		list.appendChild(this.serverRow({
			selectTag: '',
			testTag: 'auto',
			name: _('Auto (fastest)'),
			type: 'url-test',
			server: '',
			flag: '\u26A1',
			selected: selected === ''
		}));

		nodes.forEach(function (n) {
			list.appendChild(self.serverRow({
				selectTag: n.tag,
				testTag: n.tag,
				name: n.name || n.tag,
				type: n.type,
				server: n.server,
				selected: selected === n.tag
			}));
		});

		var card = E('div', { class: 'cbi-section' }, [
			E('div', {
				style: 'display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding:6px 0'
			}, [
				E('strong', {}, _('Servers') + ' (' + nodes.length + ')'),
				E('span', { style: 'flex:1' }),
				E('button', {
					class: 'cbi-button',
					click: function () { self.testAll(nodes); }
				}, _('Test all')),
				E('span', { class: 'ifacebadge' }, _('Click a row to select'))
			]),
			list
		]);

		return card;
	},

	renderSettings: function (st) {
		var m, s, o;

		m = new form.Map('happwrt', _('Settings'),
			_('Subscription, routing and DNS options.'));

		s = m.section(form.NamedSection, 'main', 'happwrt');
		s.anonymous = true;

		o = s.option(form.Value, 'subscription_url', _('Subscription URL'),
			_('Happ / v2ray subscription link.'));
		o.datatype = 'string';
		o.rmempty = true;

		o = s.option(form.ListValue, 'proxy_mode', _('Routing mode'));
		o.value('bypass_ru', _('Proxy all except Russia (RU direct)'));
		o.value('rules_only', _('Proxy only the listed domains and IPs'));
		o.value('global', _('Proxy everything'));
		o.default = 'bypass_ru';
		o.rmempty = false;

		o = s.option(form.Value, 'update_interval', _('Update interval'),
			_('Hours between automatic subscription updates.'));
		o.datatype = 'uinteger';
		o.default = '24';
		o.rmempty = true;

		o = s.option(form.ListValue, 'tun_stack', _('TUN stack'),
			_('Use gVisor unless you know why you need another stack.'));
		o.value('gvisor', _('gVisor (recommended)'));
		o.value('system', _('System'));
		o.value('mixed', _('Mixed'));
		o.default = 'gvisor';

		o = s.option(form.Value, 'wan_interface', _('WAN interface'),
			_('Optional. Outgoing interface for the proxy, e.g. pppoe-wan or eth1.'));
		o.datatype = 'string';
		o.rmempty = true;

		o = s.option(form.Value, 'dns_direct', _('Direct DNS'));
		o.datatype = 'ipaddr';
		o.default = '77.88.8.8';
		o.rmempty = true;

		o = s.option(form.Value, 'dns_proxy', _('Proxy DNS'));
		o.datatype = 'ipaddr';
		o.default = '1.1.1.1';
		o.rmempty = true;

		o = s.option(form.ListValue, 'dns_strategy', _('DNS strategy'));
		o.value('ipv4_only', _('IPv4 only'));
		o.value('prefer_ipv4', _('Prefer IPv4'));
		o.value('ipv6_only', _('IPv6 only'));
		o.value('prefer_ipv6', _('Prefer IPv6'));
		o.default = 'ipv4_only';

		o = s.option(form.ListValue, 'log_level', _('Log level'));
		o.value('error', 'error');
		o.value('warn', 'warn');
		o.value('info', 'info');
		o.value('debug', 'debug');
		o.value('trace', 'trace');
		o.default = 'warn';

		o = s.option(form.Flag, 'ad_block', _('Block ads'));
		o = s.option(form.Flag, 'clash_api', _('Clash API'),
			_('Local API used for latency tests and statistics.'));

		o = s.option(form.DynamicList, 'custom_proxy_domains', _('Always proxy domains'));
		o.datatype = 'string';
		o = s.option(form.DynamicList, 'custom_direct_domains', _('Always direct domains'));
		o.datatype = 'string';
		o = s.option(form.DynamicList, 'custom_proxy_cidrs', _('Always proxy IPs'));
		o.datatype = 'string';
		o = s.option(form.DynamicList, 'custom_direct_cidrs', _('Always direct IPs'));
		o.datatype = 'string';

		o = s.option(form.Value, 'rule_set_base', _('Rule-set base URL'));
		o.datatype = 'string';
		o.default = 'https://raw.githubusercontent.com';
		o.rmempty = true;

		return m;
	},

	render: function (data) {
		var self = this;
		var st = data[1] || {};
		var container = E('div', { class: 'cbi-map' }, [
			E('h2', { name: 'content' }, _('HappWRT')),
			this.renderStatus(st),
			this.renderServers(st)
		]);

		var map = this.renderSettings(st);

		return map.render().then(function (node) {
			dom.append(container, node);
			self.testAll(st.nodes || [], true);
			return container;
		});
	},

	select: function (tag) {
		ui.showModal(null, E('p', { class: 'spinning' }, _('Applying...')));
		return callSelect(tag || '').then(function () {
			ui.hideModal();
			window.location.reload();
		}, function () {
			ui.hideModal();
			ui.addNotification(null, E('p', {}, _('Failed to select server')), 'error');
		});
	},

	toggleEnabled: function (enabled) {
		ui.showModal(null, E('p', { class: 'spinning' }, _('Applying...')));
		return callSetEnabled(enabled ? '1' : '0').then(function () {
			ui.hideModal();
			window.location.reload();
		}, function () {
			ui.hideModal();
			ui.addNotification(null, E('p', {}, _('Failed to change state')), 'error');
		});
	},

	doUpdate: function () {
		ui.showModal(null, E('p', { class: 'spinning' }, _('Updating subscription...')));
		return uci.save()
			.then(function () { return callUpdate(); })
			.then(function (res) {
				ui.hideModal();
				ui.addNotification(null,
					E('pre', { style: 'white-space:pre-wrap' }, (res && res.output) || ''),
					'info');
				window.location.reload();
			}, function () {
				ui.hideModal();
			});
	},

	testOne: function (tag, cellId) {
		var el = document.getElementById(cellId);
		if (el) {
			el.textContent = '...';
			el.style.color = '#999';
		}

		return callDelay(tag).then(function (res) {
			var el = document.getElementById(cellId);
			if (!el)
				return;

			var ms = (res && res.delay != null) ? res.delay : null;
			el.textContent = latencyText(ms);
			el.style.color = latencyColor(ms);
		}, function () {
			var el = document.getElementById(cellId);
			if (el) {
				el.textContent = 'n/a';
				el.style.color = '#999';
			}
		});
	},

	testAll: function (nodes, auto) {
		var self = this;
		var tags = [ 'auto' ];

		(nodes || []).forEach(function (n) { tags.push(n.tag); });

		var idx = 0, active = 0, concurrency = 4;

		function pump() {
			if (idx >= tags.length && active === 0)
				return;

			while (active < concurrency && idx < tags.length) {
				var tag = tags[idx++];
				active++;
				self.testOne(tag, 'happwrt-delay-' + tag).then(function () {
					active--;
					pump();
				});
			}
		}

		if (!auto)
			pump();
		else
			window.setTimeout(pump, 300);
	}
});
